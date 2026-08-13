/// Ollama process launcher for deepThink.
///
/// Manages the bundled Ollama binary lifecycle. On macOS the full Ollama
/// runtime is copied into the .app bundle at build time by the Xcode
/// "Copy Ollama Runtime" shell-script build phase and lives at:
///
///   `<app>.app/Contents/Resources/ollama/ollama`
///
/// On Windows the runtime is placed next to the executable under:
///
///   `<install dir>\ollama\ollama.exe`
///
/// This file has zero Flutter imports — pure Dart only.
library ollama_launcher;

import 'dart:io';
import 'dart:async';

// ---------------------------------------------------------------------------
// ExternalOllamaException
// ---------------------------------------------------------------------------

/// Thrown by [OllamaLauncher.start] when port 11434 is already held by a
/// process that is NOT the one we spawned — i.e. a pre-existing external
/// Ollama that isn't responding to HTTP.
///
/// The caller should surface a UI letting the user kill the external process
/// and retry rather than silently spinning forever.
class ExternalOllamaException implements Exception {
  /// PID of the process holding port 11434, or -1 if unknown.
  final int pid;

  /// Human-readable path or name of the offending process, if determinable.
  final String processPath;

  const ExternalOllamaException({required this.pid, required this.processPath});

  @override
  String toString() =>
      'ExternalOllamaException: port 11434 is held by "$processPath" (pid $pid). '
      'Kill that process and try again.';
}

// ---------------------------------------------------------------------------
// OllamaLauncher
// ---------------------------------------------------------------------------

/// Manages the lifecycle of the bundled Ollama background process.
class OllamaLauncher {
  /// Base URL for the Ollama REST API.
  final String baseUrl;

  Process? _process;

  /// Creates an [OllamaLauncher].
  ///
  /// [baseUrl] defaults to `http://localhost:11434`.
  OllamaLauncher({this.baseUrl = 'http://localhost:11434'});

  // -------------------------------------------------------------------------
  // PID file — written on spawn, read by AppDelegate on quit
  // -------------------------------------------------------------------------

  /// Path to the PID file written when we spawn Ollama.
  ///
  /// AppDelegate.swift reads this file in `applicationWillTerminate` so it
  /// can kill the process synchronously without any Flutter channel.
  static String get _pidFilePath {
    final tmp = Platform.environment['TMPDIR'] ?? '/tmp';
    // Strip trailing slash that macOS TMPDIR often has.
    final dir = tmp.endsWith('/') ? tmp.substring(0, tmp.length - 1) : tmp;
    return '$dir/deepthink_ollama.pid';
  }

  static void _writePid(int pid) {
    try {
      File(_pidFilePath).writeAsStringSync('$pid');
    } catch (_) {}
  }

  static void _clearPid() {
    try {
      final f = File(_pidFilePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Kills all Ollama processes recorded in the PID file and removes it.
  ///
  /// Safe to call from any isolate or from the Dart VM shutdown hook.
  static void killAll() {
    try {
      final f = File(_pidFilePath);
      if (!f.existsSync()) return;
      final pid = int.tryParse(f.readAsStringSync().trim());
      if (pid != null && pid > 0) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
      f.deleteSync();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns `true` if the Ollama HTTP server is responding on [baseUrl].
  Future<bool> isRunning() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(baseUrl);
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(uri);
      // Cap the full round-trip so we don't hang indefinitely when Ollama has
      // opened the port but isn't yet processing HTTP (e.g. loading GPU runtime).
      final response =
          await request.close().timeout(const Duration(seconds: 3));
      // Drain with a timeout — if the connection stays open, don't block forever.
      await response.drain<void>().timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Starts the Ollama background process.
  ///
  /// **Flow:**
  /// 1. If `isRunning()` → Ollama already up, return immediately.
  /// 2. If port 11434 is taken by a foreign process → throw [ExternalOllamaException].
  /// 3. Otherwise spawn the bundled binary and poll until responsive.
  ///
  /// Throws [ExternalOllamaException] if port 11434 is held by an external
  /// process that isn't responding.
  ///
  /// Throws [StateError] if the binary cannot be found / executed, or if
  /// our own process doesn't become responsive within the timeout.
  Future<void> start() async {
    // Fast path — already serving HTTP.
    if (await isRunning()) return;

    // Check whether the port is already taken by a foreign process.
    // If so, we must not attempt to bind it ourselves — surface the error
    // immediately instead of spinning for 120 s.
    final blocker = await _findPortBlocker();
    if (blocker != null) {
      throw ExternalOllamaException(
        pid: blocker.pid,
        processPath: blocker.path,
      );
    }

    final binaryPath = _binaryPath();
    final file = File(binaryPath);
    if (!await file.exists()) {
      throw StateError(
        'Bundled Ollama binary not found at "$binaryPath".\n'
        'Ensure the "Copy Ollama Runtime" Xcode build phase ran successfully.',
      );
    }

    // Ensure executable bit is set (may be lost during packaging on some systems).
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', binaryPath]);
    }

    // Also chmod the helper binaries in the same directory.
    if (Platform.isMacOS) {
      final dir = file.parent;
      for (final name in ['llama-server', 'llama-quantize']) {
        final helper = File('${dir.path}/$name');
        if (await helper.exists()) {
          await Process.run('chmod', ['+x', helper.path]);
        }
      }
    }

    _process = await Process.start(
      binaryPath,
      ['serve'],
      environment: {
        ...Platform.environment,
        'OLLAMA_KEEP_ALIVE': '-1',
        // Tell Ollama where its own binaries live (same directory).
        'OLLAMA_RUNNERS_DIR': file.parent.path,
      },
      mode: ProcessStartMode.normal,
    );

    // Record the PID so AppDelegate can kill it on app termination.
    _writePid(_process!.pid);

    // Forward Ollama's output to the Dart console so errors are visible.
    _process!.stdout.listen((data) {
      // ignore: avoid_print
      print('[ollama] ${String.fromCharCodes(data).trimRight()}');
    });
    _process!.stderr.listen((data) {
      // ignore: avoid_print
      print('[ollama:err] ${String.fromCharCodes(data).trimRight()}');
    });

    // Wait up to 120 seconds for the server to become responsive.
    // On first launch Ollama may spend significant time initialising the
    // GPU runtime before it starts handling HTTP requests.
    const maxWait = Duration(seconds: 120);
    const pollInterval = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      if (await isRunning()) return;
      await Future<void>.delayed(pollInterval);
    }

    throw StateError(
      'Ollama process started but server did not respond within '
      '${maxWait.inSeconds}s at $baseUrl',
    );
  }

  /// Stops the managed Ollama process if one was started by this instance.
  ///
  /// Has no effect if Ollama was already running externally before [start]
  /// was called.
  Future<void> stop() async {
    _process?.kill(ProcessSignal.sigkill);
    _process = null;
    _clearPid();
  }

  // -------------------------------------------------------------------------
  // Port blocker detection
  // -------------------------------------------------------------------------

  /// Returns info about the process holding port 11434 if the port is taken
  /// but NOT responding to HTTP.  Returns null if the port is free.
  Future<_ProcessInfo?> _findPortBlocker() async {
    if (!Platform.isMacOS && !Platform.isWindows) return null;

    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        // -F pn → structured output: p=pid line, n=name line
        result = await Process.run(
          'lsof',
          ['-i', 'TCP:11434', '-sTCP:LISTEN', '-F', 'pn'],
        );
      } else {
        result = await Process.run('netstat', ['-ano']);
      }

      final output = result.stdout as String;
      if (output.trim().isEmpty) return null; // port is free

      return Platform.isMacOS
          ? _parseLsofOutput(output)
          : _parseNetstatOutput(output);
    } catch (_) {
      return null; // if we can't determine, don't block startup
    }
  }

  _ProcessInfo? _parseLsofOutput(String output) {
    // lsof -F pn produces lines like:
    //   p65010
    //   n*:11434
    int pid = -1;
    for (final line in output.split('\n')) {
      if (line.startsWith('p')) {
        pid = int.tryParse(line.substring(1).trim()) ?? -1;
      }
    }
    if (pid == -1) return null;

    String path = 'unknown';
    try {
      final r = Process.runSync('ps', ['-p', '$pid', '-o', 'comm=']);
      path = (r.stdout as String).trim();
    } catch (_) {}

    return _ProcessInfo(pid: pid, path: path.isEmpty ? 'unknown' : path);
  }

  _ProcessInfo? _parseNetstatOutput(String output) {
    final re = RegExp(r'TCP\s+\S+:11434\s+\S+\s+LISTENING\s+(\d+)');
    final m = re.firstMatch(output);
    if (m == null) return null;
    final pid = int.tryParse(m.group(1) ?? '') ?? -1;
    if (pid == -1) return null;
    return _ProcessInfo(pid: pid, path: 'unknown');
  }

  // -------------------------------------------------------------------------
  // Path helpers
  // -------------------------------------------------------------------------

  /// Returns the filesystem path to the bundled Ollama binary.
  String _binaryPath() {
    if (Platform.isMacOS) {
      // Executable: <app>.app/Contents/MacOS/deep_think
      // Binary:     <app>.app/Contents/Resources/ollama/ollama
      final exeDir = File(Platform.resolvedExecutable).parent;
      final contentsDir = exeDir.parent;
      return '${contentsDir.path}/Resources/ollama/ollama';
    } else if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent;
      return '${exeDir.path}\\ollama\\ollama.exe';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ProcessInfo {
  final int pid;
  final String path;
  const _ProcessInfo({required this.pid, required this.path});
}

/// Kills the process with [pid] using SIGKILL (macOS/Linux) or
/// `taskkill /F` (Windows).  Returns true if the signal was sent.
Future<bool> killExternalOllama(int pid) async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run('taskkill', ['/F', '/PID', '$pid']);
      return (r.exitCode == 0);
    } else {
      final r = await Process.run('kill', ['-9', '$pid']);
      return (r.exitCode == 0);
    }
  } catch (_) {
    return false;
  }
}
