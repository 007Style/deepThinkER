// Real-time system resource monitor for deepThink.
//
// Polls available (free + reclaimable) RAM every [pollInterval] and exposes
// it as a broadcast [Stream<ResourceSnapshot>]. Also captures the top memory-
// consuming processes so the UI can tell the user exactly what to close.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:io';

// ---------------------------------------------------------------------------
// ResourceSnapshot
// ---------------------------------------------------------------------------

/// A point-in-time view of system memory.
class ResourceSnapshot {
  /// Total physical RAM in GB.
  final double totalGb;

  /// Free + reclaimable RAM in GB (free + inactive + speculative pages on
  /// macOS; FreePhysicalMemory on Windows).
  final double freeGb;

  /// Top memory-consuming processes, sorted by descending RSS.
  final List<ProcessMemInfo> topProcesses;

  /// UTC timestamp when this snapshot was taken.
  final DateTime timestamp;

  const ResourceSnapshot({
    required this.totalGb,
    required this.freeGb,
    required this.topProcesses,
    required this.timestamp,
  });

  /// Fraction of total RAM that is free (0.0–1.0).
  double get freefraction => totalGb > 0 ? (freeGb / totalGb).clamp(0.0, 1.0) : 0.0;

  /// Used RAM in GB.
  double get usedGb => (totalGb - freeGb).clamp(0.0, totalGb);
}

// ---------------------------------------------------------------------------
// ProcessMemInfo
// ---------------------------------------------------------------------------

/// Memory footprint of a single running process.
class ProcessMemInfo {
  /// Process name (truncated to 30 chars).
  final String name;

  /// Resident set size in megabytes.
  final double rssGb;

  const ProcessMemInfo({required this.name, required this.rssGb});
}

// ---------------------------------------------------------------------------
// ResourceMonitor
// ---------------------------------------------------------------------------

/// Polls system resources on a fixed interval and broadcasts snapshots.
///
/// ```dart
/// final monitor = ResourceMonitor();
/// monitor.snapshots.listen((snap) {
///   print('Free: ${snap.freeGb.toStringAsFixed(1)} GB');
/// });
/// monitor.start();
/// // ...
/// monitor.dispose();
/// ```
class ResourceMonitor {
  /// How often to poll. Defaults to 2 seconds.
  final Duration pollInterval;

  /// The total physical RAM, detected once on first poll.
  double _totalGb = 0.0;

  final StreamController<ResourceSnapshot> _controller =
      StreamController<ResourceSnapshot>.broadcast();

  Timer? _timer;
  bool _polling = false;

  ResourceMonitor({this.pollInterval = const Duration(seconds: 2)});

  /// Broadcast stream of [ResourceSnapshot] objects.
  Stream<ResourceSnapshot> get snapshots => _controller.stream;

  /// Starts polling. Safe to call multiple times — no-ops if already running.
  void start() {
    if (_polling) return;
    _polling = true;
    // Fire immediately, then on interval.
    _poll();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  /// Stops polling and closes the stream.
  void dispose() {
    _polling = false;
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }

  // -------------------------------------------------------------------------
  // Internal poll
  // -------------------------------------------------------------------------

  Future<void> _poll() async {
    if (!_polling) return;
    try {
      if (_totalGb == 0.0) _totalGb = await _detectTotalRam();
      final freeGb = await _detectFreeRam();
      final procs = await _detectTopProcesses();

      if (!_controller.isClosed) {
        _controller.add(ResourceSnapshot(
          totalGb: _totalGb,
          freeGb: freeGb,
          topProcesses: procs,
          timestamp: DateTime.now().toUtc(),
        ));
      }
    } catch (_) {
      // Silently swallow — transient failures are normal (fast user switching,
      // screensaver, etc.). The next poll will succeed.
    }
  }

  // -------------------------------------------------------------------------
  // Total RAM (detected once)
  // -------------------------------------------------------------------------

  static Future<double> _detectTotalRam() async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (r.exitCode == 0) {
          final bytes = int.tryParse((r.stdout as String).trim()) ?? 0;
          return bytes / (1024 * 1024 * 1024);
        }
      } else if (Platform.isWindows) {
        final r = await Process.run(
          'wmic', ['ComputerSystem', 'get', 'TotalPhysicalMemory', '/value'],
          runInShell: true,
        );
        if (r.exitCode == 0) {
          final match = RegExp(r'TotalPhysicalMemory=(\d+)')
              .firstMatch(r.stdout as String);
          if (match != null) {
            final bytes = int.tryParse(match.group(1)!) ?? 0;
            return bytes / (1024 * 1024 * 1024);
          }
        }
      }
    } catch (_) {}
    return 16.0; // safe fallback
  }

  // -------------------------------------------------------------------------
  // Free / available RAM
  // -------------------------------------------------------------------------

  static Future<double> _detectFreeRam() async {
    if (Platform.isMacOS) return _macFreeRam();
    if (Platform.isWindows) return _winFreeRam();
    return 0.0;
  }

  /// `vm_stat` free + inactive + speculative pages.
  static Future<double> _macFreeRam() async {
    final r = await Process.run('vm_stat', []);
    if (r.exitCode != 0) return 0.0;
    final out = r.stdout as String;

    int pageSize = 16384;
    final psMatch = RegExp(r'page size of (\d+) bytes').firstMatch(out);
    if (psMatch != null) pageSize = int.tryParse(psMatch.group(1)!) ?? pageSize;

    int pages(String key) {
      final m = RegExp('$key:\\s+(\\d+)\\.').firstMatch(out);
      return int.tryParse(m?.group(1) ?? '0') ?? 0;
    }

    final bytes = (pages('Pages free') +
            pages('Pages inactive') +
            pages('Pages speculative')) *
        pageSize;
    return bytes / (1024 * 1024 * 1024);
  }

  /// WMIC FreePhysicalMemory (KB).
  static Future<double> _winFreeRam() async {
    final r = await Process.run(
      'wmic', ['OS', 'get', 'FreePhysicalMemory', '/value'],
      runInShell: true,
    );
    if (r.exitCode != 0) return 0.0;
    final match =
        RegExp(r'FreePhysicalMemory=(\d+)').firstMatch(r.stdout as String);
    if (match == null) return 0.0;
    final kb = int.tryParse(match.group(1)!) ?? 0;
    return kb / (1024 * 1024);
  }

  // -------------------------------------------------------------------------
  // Top processes by memory
  // -------------------------------------------------------------------------

  static Future<List<ProcessMemInfo>> _detectTopProcesses() async {
    if (Platform.isMacOS) return _macTopProcesses();
    if (Platform.isWindows) return _winTopProcesses();
    return [];
  }

  /// `ps aux` sorted by RSS, top 8, excluding this process and system daemons.
  static Future<List<ProcessMemInfo>> _macTopProcesses() async {
    final r = await Process.run(
      'ps', ['-axo', 'rss,comm', '--no-headers'],
      runInShell: false,
    );
    if (r.exitCode != 0) return [];
    return _parseAndSort(r.stdout as String, isWindows: false);
  }

  /// WMIC process list sorted by WorkingSetSize.
  static Future<List<ProcessMemInfo>> _winTopProcesses() async {
    final r = await Process.run(
      'wmic', ['process', 'get', 'Name,WorkingSetSize', '/format:csv'],
      runInShell: true,
    );
    if (r.exitCode != 0) return [];
    return _parseAndSort(r.stdout as String, isWindows: true);
  }

  static List<ProcessMemInfo> _parseAndSort(String output,
      {required bool isWindows}) {
    final entries = <MapEntry<double, String>>[];

    if (!isWindows) {
      // macOS ps format: "  123456 /path/to/process"
      for (final line in output.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) continue;
        final kb = double.tryParse(parts[0]) ?? 0.0;
        if (kb < 100 * 1024) continue; // skip tiny processes (< 100 MB)
        final name = parts.sublist(1).join(' ').split('/').last;
        if (_isSystemNoise(name)) continue;
        entries.add(MapEntry(kb * 1024, name)); // convert KB → bytes
      }
    } else {
      // Windows WMIC CSV: "Node,Name,WorkingSetSize"
      for (final line in output.split('\n').skip(1)) {
        final cols = line.trim().split(',');
        if (cols.length < 3) continue;
        final bytes = double.tryParse(cols[2].trim()) ?? 0.0;
        if (bytes < 100 * 1024 * 1024) continue; // < 100 MB
        final name = cols[1].trim();
        if (_isSystemNoise(name)) continue;
        entries.add(MapEntry(bytes, name));
      }
    }

    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.take(8).map((e) {
      final gb = e.key / (1024 * 1024 * 1024);
      final trimmed =
          e.value.length > 32 ? '${e.value.substring(0, 32)}…' : e.value;
      return ProcessMemInfo(name: trimmed, rssGb: gb);
    }).toList();
  }

  /// Returns true for processes too noisy/low-value to show the user.
  static bool _isSystemNoise(String name) {
    const noise = {
      'kernel_task', 'launchd', 'WindowServer', 'mds_stores',
      'com.apple.WebKit', 'coreautha', 'coreauthd', 'loginwindow',
      'mds', 'mdworker', 'CommCenter', 'UserEventAgent',
      'system_process', 'System', 'Idle', 'csrss.exe', 'lsass.exe',
      'svchost.exe', 'System Idle Process',
    };
    return noise.any((n) => name.toLowerCase().contains(n.toLowerCase()));
  }
}
