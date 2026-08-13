// replay_banner.dart — top-of-screen banner shown when a session is replaying.
import 'package:flutter/material.dart';

import '../../core/session/replay_mode.dart';

// ---------------------------------------------------------------------------
// ReplayBanner
// ---------------------------------------------------------------------------

/// A narrow amber banner displayed at the top of [MainScreen] during replay.
///
/// Shows the session name, the active [ReplayMode] label, and a dismiss button.
class ReplayBanner extends StatelessWidget {
  /// The name of the session being replayed.
  final String sessionName;

  /// The active replay mode.
  final ReplayMode mode;

  /// Called when the user taps the dismiss (×) button.
  final VoidCallback onDismiss;

  const ReplayBanner({
    required this.sessionName,
    required this.mode,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = mode == ReplayMode.reflection ? 'Reflection' : 'Continue';

    return SafeArea(
      bottom: false,
      child: Container(
        color: const Color(0xFFFFF8E1), // amber[50]
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Text(
              '\u23EA',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Replaying: $sessionName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5D4037), // brown[700]
                      ),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: modeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: mode == ReplayMode.reflection
                            ? const Color(0xFF6A1B9A) // purple[800]
                            : const Color(0xFF1565C0), // blue[800]
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: const Color(0xFF5D4037),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDismiss,
              tooltip: 'Dismiss replay banner',
            ),
          ],
        ),
      ),
    );
  }
}
