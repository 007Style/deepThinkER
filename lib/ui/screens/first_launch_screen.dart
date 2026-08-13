// First-launch model download screen for deepThink.
//
// Shown once when one or more of the four registry models are not yet
// installed in the local Ollama instance. Displays per-model progress bars
// and auto-advances to StartupConfigScreen when all models are ready.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/ollama/hardware_detector.dart';
import '../../core/ollama/model_manager.dart';
import '../../core/ollama/model_registry.dart';
import '../../core/ollama/ollama_client.dart';
import '../avatars/avatar_registry.dart';
import '../avatars/avatar_widget.dart';
import '../widgets/app_theme.dart';
import 'startup_config_screen.dart';
import 'welcome_screen.dart';

// ---------------------------------------------------------------------------
// FirstLaunchScreen
// ---------------------------------------------------------------------------

/// One-time model download screen.
///
/// Shown when [ModelManager.checkModels] reports that at least one model is
/// missing. Uses [ModelManager.downloadAllMissing] to pull models sequentially
/// and displays per-model progress bars. On completion navigates to
/// [StartupConfigScreen].
class FirstLaunchScreen extends StatefulWidget {
  /// Pre-computed initial statuses (so we don't re-check on mount).
  final List<ModelStatus> initialStatuses;

  /// Hardware info passed back to WelcomeScreen if the user cancels.
  /// Optional — WelcomeScreen can re-detect if not provided.
  final HardwareInfo? hardware;

  const FirstLaunchScreen({
    required this.initialStatuses,
    this.hardware,
    super.key,
  });

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

// ---------------------------------------------------------------------------
// Per-model download state
// ---------------------------------------------------------------------------

enum _DlState { waiting, downloading, done, failed }

class _ModelDlState {
  final ModelInfo model;
  _DlState state;
  double progress; // 0.0–1.0
  String statusText;
  int completedBytes;
  int totalBytes;

  _ModelDlState({
    required this.model,
    required bool isInstalled,
  })  : state = isInstalled ? _DlState.done : _DlState.waiting,
        progress = isInstalled ? 1.0 : 0.0,
        statusText = isInstalled ? '\u2713 Ready' : 'Waiting\u2026',
        completedBytes = 0,
        totalBytes = 0;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _FirstLaunchScreenState extends State<FirstLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final List<_ModelDlState> _states;
  late final ModelManager _manager;

  // Orb animation controller
  late final AnimationController _orbController;

  bool _isDownloading = false;
  bool _allDone = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _manager = ModelManager(client: OllamaClient());

    _states = widget.initialStatuses
        .map((s) => _ModelDlState(model: s.model, isInstalled: s.isInstalled))
        .toList();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _allDone = _states.every((s) => s.state == _DlState.done);

    if (!_allDone) {
      // Start downloading on the next frame so the UI can render first.
      SchedulerBinding.instance.addPostFrameCallback((_) => _startDownloads());
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Download orchestration
  // -------------------------------------------------------------------------

  Future<void> _startDownloads() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _hasFailed = false;
      // Reset any previously failed states back to waiting.
      for (final s in _states) {
        if (s.state == _DlState.failed) {
          s.state = _DlState.waiting;
          s.statusText = 'Waiting\u2026';
          s.progress = 0.0;
        }
      }
    });

    for (final dlState in _states) {
      if (dlState.state == _DlState.done) continue;

      setState(() {
        dlState.state = _DlState.downloading;
        dlState.statusText = 'Connecting\u2026';
      });

      bool failed = false;

      try {
        await for (final p
            in _manager.downloadModel(dlState.model.id)) {
          if (!mounted) return;
          setState(() {
            dlState.progress = p.percent;
            dlState.completedBytes = p.completed;
            dlState.totalBytes = p.total;
            if (p.isDone) {
              dlState.state = _DlState.done;
              dlState.progress = 1.0;
              dlState.statusText = '\u2713 Ready';
            } else {
              dlState.statusText = _buildStatusText(p);
            }
          });
          if (p.isDone) break;
        }
      } catch (e) {
        failed = true;
        if (mounted) {
          setState(() {
            dlState.statusText = e.toString()
                .replaceFirst('HttpException: ', '')
                .replaceFirst('Exception: ', '');
          });
        }
      }

      if (!mounted) return;

      if (failed || dlState.state != _DlState.done) {
        setState(() {
          dlState.state = _DlState.failed;
          if (dlState.statusText.isEmpty ||
              dlState.statusText.startsWith('Downloading') ||
              dlState.statusText.startsWith('Connecting') ||
              dlState.statusText.startsWith('Waiting')) {
            dlState.statusText = 'Download failed';
          }
          // statusText already set to the actual error in the catch block above
          _hasFailed = true;
        });
        // Stop sequential downloads on first failure; user must retry.
        break;
      }
    }

    if (!mounted) return;
    final allNowDone = _states.every((s) => s.state == _DlState.done);
    setState(() {
      _isDownloading = false;
      _allDone = allNowDone;
    });

    if (allNowDone) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const StartupConfigScreen(),
        ),
      );
    }
  }

  String _buildStatusText(dynamic p) {
    if (p.total <= 0) return 'Downloading\u2026';
    final completedGb = p.completed / (1024 * 1024 * 1024);
    final totalGb = p.total / (1024 * 1024 * 1024);
    return 'Downloading\u2026 '
        '${completedGb.toStringAsFixed(1)} GB of '
        '${totalGb.toStringAsFixed(1)} GB';
  }

  // -------------------------------------------------------------------------
  // Build helpers
  // -------------------------------------------------------------------------

  double get _overallProgress {
    if (_states.isEmpty) return 0.0;
    return _states.fold(0.0, (sum, s) => sum + s.progress) / _states.length;
  }

  Color _progressColor(_DlState state) {
    switch (state) {
      case _DlState.done:
        return const Color(0xFF4CAF50);
      case _DlState.failed:
        return const Color(0xFFF44336);
      case _DlState.downloading:
        return AppColors.accent;
      case _DlState.waiting:
        return AppColors.border;
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Animated orb ─────────────────────────────────────────
                _AnimatedOrbSection(
                  controller: _orbController,
                  isActive: _isDownloading,
                  allDone: _allDone,
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
                const Text(
                  'Setting up deepThink',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Downloading AI models to your machine.\nThis happens once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Per-model rows ────────────────────────────────────────
                ...(_states.map(_buildModelRow)),

                const SizedBox(height: 24),

                // ── Overall progress ──────────────────────────────────────
                _OverallProgressBar(progress: _overallProgress),

                const SizedBox(height: 24),

                // ── Retry / status ────────────────────────────────────────
                if (_hasFailed)
                  _RetryButton(onPressed: _startDownloads)
                else if (_allDone)
                  const Text(
                    'All models ready — launching\u2026',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (_isDownloading)
                  const Text(
                    'Please keep the app open during download.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),

                const SizedBox(height: 32),

                // ── Cancel ────────────────────────────────────────────────
                if (!_allDone) _CancelButton(onPressed: _cancel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Cancel — stop downloads and go back to WelcomeScreen.
  // Any model already in _DlState.done is preserved: the download loop
  // checks state == done and skips it, so nothing is re-downloaded.
  // -------------------------------------------------------------------------

  void _cancel() {
    // Build current statuses: done models are marked installed, others not.
    final currentStatuses = _states
        .map((s) => ModelStatus(
              model: s.model,
              isInstalled: s.state == _DlState.done,
            ))
        .toList();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WelcomeScreen(
          // Re-use passed hardware or let WelcomeScreen rebuild with defaults.
          hardware: widget.hardware ??
              HardwareInfo(
                totalRamGb: 0,
                freeRamGb: 0,
                ramTier: RamTier.tier32,
                inferenceBackend: InferenceBackend.cpu,
                backendDisplayName: 'Unknown',
              ),
          modelStatuses: currentStatuses,
        ),
      ),
    );
  }

  Widget _buildModelRow(_ModelDlState dl) {
    final barColor = _progressColor(dl.state);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + RAM + status
          Row(
            children: [
              Text(
                dl.model.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '~${dl.model.ramGb.toStringAsFixed(1)} GB',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Text(
                dl.statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: barColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: dl.progress,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnimatedOrbSection
// ---------------------------------------------------------------------------

class _AnimatedOrbSection extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;
  final bool allDone;

  const _AnimatedOrbSection({
    required this.controller,
    required this.isActive,
    required this.allDone,
  });

  @override
  Widget build(BuildContext context) {
    final state = allDone
        ? AvatarState.idle
        : isActive
            ? AvatarState.thinking
            : AvatarState.waiting;

    return SizedBox(
      width: 96,
      height: 96,
      child: AvatarRegistry.build(
        'energyOrb',
        state: state,
        characterName: 'DEEP',
        size: 96,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OverallProgressBar
// ---------------------------------------------------------------------------

class _OverallProgressBar extends StatelessWidget {
  final double progress;

  const _OverallProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overall progress',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pct %',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _RetryButton
// ---------------------------------------------------------------------------

class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'One or more downloads failed.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFFF44336),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(
            'Retry',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CancelButton
// ---------------------------------------------------------------------------

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.border),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text(
              'Cancel and go back',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Any completed downloads will not be lost.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
