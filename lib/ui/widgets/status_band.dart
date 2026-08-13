// Thin status bar displayed at the very bottom of the main window.
//
// Shows inference backend, RAM tier, and active session name.
import 'package:flutter/material.dart';

import '../../core/ollama/hardware_detector.dart';
import 'app_theme.dart';

// ---------------------------------------------------------------------------
// StatusBand
// ---------------------------------------------------------------------------

/// A fixed-height (28 px) status bar for hardware and session info.
///
/// Layout:
/// - Left  : inference backend icon + label
/// - Center: RAM capacity and context window
/// - Right : active session name
class StatusBand extends StatelessWidget {
  /// Detected hardware info from [HardwareDetector.detect].
  final HardwareInfo hardware;

  /// Display name of the current session (e.g. `"thetaByte"`).
  final String sessionName;

  const StatusBand({
    required this.hardware,
    required this.sessionName,
    super.key,
  });

  // -------------------------------------------------------------------------
  // Backend label helpers
  // -------------------------------------------------------------------------

  String _backendIcon() {
    switch (hardware.inferenceBackend) {
      case InferenceBackend.appleMetal:
        return '⚡';
      case InferenceBackend.cuda:
      case InferenceBackend.rocm:
        return '🖥';
      case InferenceBackend.cpu:
        return '🖥';
    }
  }

  String _ramLabel() {
    final gb = hardware.totalRamGb.round();
    final ctx = _formatCtx(hardware.standardContextWindow);
    return 'RAM: $gb GB · Context: $ctx';
  }

  String _formatCtx(int tokens) {
    if (tokens >= 1024) {
      return '${(tokens ~/ 1024)}K';
    }
    return '$tokens';
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      color: AppColors.textSecondary,
      height: 1.0,
    );

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.statusBackground,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left — backend
          Expanded(
            child: Text(
              '${_backendIcon()} ${hardware.backendDisplayName}',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Center — RAM tier
          Expanded(
            child: Center(
              child: Text(
                _ramLabel(),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Right — session name
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                sessionName.isNotEmpty ? 'Session: $sessionName' : '',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
