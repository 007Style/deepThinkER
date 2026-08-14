// deepThink entry point.
//
// Startup flow:
//   1. Show splash with live status while Ollama starts + model check runs.
//   2. If any models missing  → WelcomeScreen (greet user, ask permission to download).
//   3. If all models present  → WelcomeScreen (greet user, show where models live, go).
//   4. After welcome          → StartupConfigScreen (configure & launch session).
import 'dart:io' show Directory, Platform, ProcessSignal, exit;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'core/ollama/hardware_detector.dart';
import 'core/ollama/model_manager.dart';
import 'core/ollama/ollama_client.dart';
import 'core/ollama/ollama_launcher.dart';
import 'core/paths/app_paths.dart';
import 'core/network/network_fetcher.dart';
import 'core/tools/calc/calc_tool.dart';
import 'core/tools/file/file_read_tool.dart';
import 'core/tools/file/file_write_tool.dart';
import 'core/tools/image/image_tool.dart';
import 'core/tools/memory/recall_tool.dart';
import 'core/tools/memory/remember_tool.dart';
import 'core/tools/network/network_fetch_tool.dart';
import 'core/tools/network/network_search_tool.dart';
import 'core/tools/tool_registry.dart';
import 'ui/avatars/avatar_registry.dart';
import 'ui/screens/external_ollama_screen.dart';
import 'ui/screens/resource_gate_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/widgets/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AvatarRegistry.registerDefaults();

  // Register all tools — including network tools.
  final fetcher = NetworkFetcher();
  ToolRegistry.instance
    ..register(RememberTool())
    ..register(RecallTool())
    ..register(FileReadTool())
    ..register(FileWriteTool())
    ..register(CalcTool())
    ..register(ImageTool())
    ..register(NetworkSearchTool(fetcher))
    ..register(NetworkFetchTool(fetcher));

  // Belt-and-suspenders: if the Dart VM exits for any reason (crash, signal,
  // etc.) kill the Ollama process we may have spawned.  AppDelegate handles
  // the normal ⌘Q / window-close case; this covers everything else.
  ProcessSignal.sigterm.watch().listen((_) => OllamaLauncher.killAll());
  ProcessSignal.sigint.watch().listen((_) {
    OllamaLauncher.killAll();
    exit(0);
  });

  // Catch all unhandled Flutter framework errors and print them so
  // we can see silent crashes in the terminal.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // Catch all unhandled async / platform errors.
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('UNCAUGHT ERROR: $error\n$stack');
    return true; // keep the app alive — show the error screen instead of crashing
  };

  runApp(const DeepThinkApp());
}

// ---------------------------------------------------------------------------
// DeepThinkApp
// ---------------------------------------------------------------------------

class DeepThinkApp extends StatelessWidget {
  const DeepThinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'deepThinkER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppLoader(),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppLoader — starts Ollama, detects hardware, checks models, then routes
// ---------------------------------------------------------------------------

class _AppLoader extends StatefulWidget {
  const _AppLoader();
  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  // Status messages shown on the splash while work happens
  String _status = 'Starting up\u2026';
  bool _done = false;

  HardwareInfo? _hardware;
  List<ModelStatus>? _modelStatuses;
  String? _errorMessage;
  ExternalOllamaException? _externalOllama;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Reset any previous error state when retrying.
    if (mounted) {
      setState(() {
        _done = false;
        _errorMessage = null;
        _externalOllama = null;
        _status = 'Starting Ollama\u2026';
      });
    }

    // Guard: verify app data directory is accessible before doing anything else.
    // macOS TCC will silently deny writes to ~/Library if the user dismissed the
    // permission prompt (though Library/Application Support does not prompt).
    // This also catches a completely missing home directory.
    try {
      final testDir = AppPaths.base;
      final dir = Directory(testDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'App data directory is not accessible.\n\n'
            'Expected: ${AppPaths.base}\n\nError: $e\n\n'
            'This can happen if macOS has denied file access. '
            'Go to System Settings → Privacy & Security → Files and Folders '
            'and allow deepThinkER to access the required folder, then restart the app.';
        _done = true;
      });
      return;
    }

    try {
      // ── Step 1: Start Ollama ───────────────────────────────────────────────
      _setStatus('Starting Ollama\u2026');
      final launcher = OllamaLauncher();
      // Show a more informative message after a few seconds if Ollama is
      // still initialising (e.g. loading GPU runtime on first launch).
      final slowTimer = Future<void>.delayed(
        const Duration(seconds: 5),
        () => _setStatus(
            'Starting Ollama\u2026 (this may take a minute on first launch)'),
      );
      await launcher.start();
      slowTimer.ignore();

      // ── Step 2: Detect hardware ────────────────────────────────────────────
      _setStatus('Detecting hardware\u2026');
      final hardware = await HardwareDetector.detect();

      // ── Step 3: Check which models are installed ───────────────────────────
      _setStatus('Checking installed models\u2026');
      final statuses =
          await ModelManager(client: OllamaClient()).checkModels();

      if (!mounted) return;
      setState(() {
        _hardware = hardware;
        _modelStatuses = statuses;
        _done = true;
      });
    } on ExternalOllamaException catch (e) {
      // Port is blocked by a foreign process — show the dedicated screen.
      if (!mounted) return;
      setState(() {
        _externalOllama = e;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _done = true;
      });
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return _SplashScreen(status: _status);
    }

    // Port is held by a foreign Ollama — let the user kill it and retry.
    if (_externalOllama != null) {
      return ExternalOllamaScreen(
        error: _externalOllama!,
        onRetry: _initialize,
      );
    }

    if (_errorMessage != null) {
      return _ErrorScreen(message: _errorMessage!);
    }

    // If RAM is tight, show the live Resource Gate so the user can free up
    // memory and watch deepThink self-provision in real time.
    if (_hardware!.freeRamGb < 24.0) {
      return ResourceGateScreen(
        hardware: _hardware!,
        modelStatuses: _modelStatuses!,
      );
    }

    // Enough RAM — go straight to the welcome/config flow.
    return WelcomeScreen(
      hardware: _hardware!,
      modelStatuses: _modelStatuses!,
    );
  }
}

// ---------------------------------------------------------------------------
// _SplashScreen — shown while Ollama starts and models are checked
// ---------------------------------------------------------------------------

class _SplashScreen extends StatelessWidget {
  final String status;
  const _SplashScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'deepThinkER',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'v1.1.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            // Live status — the user always knows what's happening
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                status,
                key: ValueKey<String>(status),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorScreen — shown if Ollama failed to start (binary missing etc.)
// ---------------------------------------------------------------------------

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF44336), size: 48),
                const SizedBox(height: 20),
                const Text(
                  'deepThinkER could not start',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The bundled Ollama engine failed to launch. '
                  'This usually means the app was not built correctly or '
                  'is being run outside the .app bundle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a0a0a),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4a1a1a)),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFFF7070),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Try: Help \u2192 Model Downloads \u2026 for manual setup.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
