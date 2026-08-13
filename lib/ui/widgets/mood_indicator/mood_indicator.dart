// MoodIndicator widget — compact animated emoji + label for a character's mood.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/mood/mood_score.dart';

// ---------------------------------------------------------------------------
// MoodIndicator
// ---------------------------------------------------------------------------

/// A compact row widget showing the character's current mood as emoji + label.
///
/// Listens to [scoreStream] and animates when the mood state changes.
class MoodIndicator extends StatefulWidget {
  /// Initial mood score to display before the stream emits.
  final MoodScore initialScore;

  /// Stream of mood score updates.
  final Stream<MoodScore> scoreStream;

  const MoodIndicator({
    required this.initialScore,
    required this.scoreStream,
    super.key,
  });

  @override
  State<MoodIndicator> createState() => _MoodIndicatorState();
}

class _MoodIndicatorState extends State<MoodIndicator> {
  late MoodScore _current;
  StreamSubscription<MoodScore>? _sub;

  @override
  void initState() {
    super.initState();
    _current = widget.initialScore;
    _sub = widget.scoreStream.listen((s) {
      if (mounted) setState(() => _current = s);
    });
  }

  @override
  void didUpdateWidget(MoodIndicator old) {
    super.didUpdateWidget(old);
    if (old.scoreStream != widget.scoreStream) {
      _sub?.cancel();
      _sub = widget.scoreStream.listen((s) {
        if (mounted) setState(() => _current = s);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _emoji(MoodState state) {
    switch (state) {
      case MoodState.engaged:
        return '😊';
      case MoodState.neutral:
        return '😐';
      case MoodState.withdrawn:
        return '😶';
      case MoodState.agitated:
        return '😤';
      case MoodState.excited:
        return '🤩';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _current.moodState;
    final emoji = _emoji(state);
    final label = state == MoodState.neutral ? '' : state.name;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Row(
        key: ValueKey<MoodState>(state),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            key: ValueKey<String>(emoji),
            style: const TextStyle(fontSize: 12),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8A8A9A),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
