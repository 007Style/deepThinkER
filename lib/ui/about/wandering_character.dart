// Wandering character widget for the deepThink About screen.
//
// Renders one of four cute emoji characters at a given [position] with a
// subtle idle bounce driven by [animationValue] (0.0–1.0 looping).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// WanderingCharacter
// ---------------------------------------------------------------------------

/// The set of supported character types.
enum CharacterType {
  robot,
  brain,
  lightbulb,
  spark,
}

/// Renders a single 32×32 emoji character with a gentle bounce.
///
/// Parameters:
/// - [position]       — top-left anchor for the widget inside a [Stack].
/// - [type]           — which emoji to show.
/// - [animationValue] — 0.0–1.0 looping value from the parent controller.
class WanderingCharacter extends StatelessWidget {
  /// Top-left anchor position inside a [Stack].
  final Offset position;

  /// Which emoji character to display.
  final CharacterType type;

  /// 0.0–1.0 looping animation value from the parent's [AnimationController].
  final double animationValue;

  const WanderingCharacter({
    required this.position,
    required this.type,
    required this.animationValue,
    super.key,
  });

  // ── Emoji lookup ──────────────────────────────────────────────────────────

  String get _emoji {
    switch (type) {
      case CharacterType.robot:
        return '🤖';
      case CharacterType.brain:
        return '🧠';
      case CharacterType.lightbulb:
        return '💡';
      case CharacterType.spark:
        return '⚡';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Gentle vertical bounce: ±3 px sinusoidal oscillation.
    final bounce = math.sin(animationValue * math.pi * 2) * 3.0;

    return Positioned(
      left: position.dx,
      top: position.dy + bounce,
      child: Text(
        _emoji,
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}
