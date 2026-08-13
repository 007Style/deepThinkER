// Wandering characters layer for the deepThink About screen.
//
// Manages 7 autonomous characters that smoothly walk to random target
// positions.  A single repeating AnimationController drives all movement.
// Characters are kept in the top/bottom 15 % margins so they never obscure
// the main content column.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'wandering_character.dart';

// ---------------------------------------------------------------------------
// _CharacterState — per-character runtime state
// ---------------------------------------------------------------------------

class _CharacterState {
  final CharacterType type;

  /// Current rendered position.
  Offset current;

  /// Next target position we are interpolating toward.
  Offset target;

  /// Time remaining (in seconds) before we pick a new target.
  double secondsUntilNewTarget;

  /// Phase offset so each character bounces at a different point in the cycle.
  final double phaseOffset;

  _CharacterState({
    required this.type,
    required this.current,
    required this.target,
    required this.secondsUntilNewTarget,
    required this.phaseOffset,
  });
}

// ---------------------------------------------------------------------------
// WanderingCharactersLayer
// ---------------------------------------------------------------------------

/// A full-size [Stack] overlay that wanders 7 emoji characters around the
/// margins of the About screen.
///
/// Uses a [Ticker] (via [SingleTickerProviderStateMixin]) so movement is driven
/// by the framework's animation scheduler without needing an explicit
/// [AnimationController].
class WanderingCharactersLayer extends StatefulWidget {
  const WanderingCharactersLayer({super.key});

  @override
  State<WanderingCharactersLayer> createState() =>
      _WanderingCharactersLayerState();
}

class _WanderingCharactersLayerState extends State<WanderingCharactersLayer>
    with SingleTickerProviderStateMixin {
  static const int _count = 7;
  // Speed: logical pixels per second.
  static const double _speed = 30.0;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Global 0..1 looping value used for bounce animation.
  double _animValue = 0.0;

  final List<_CharacterState> _characters = [];
  final math.Random _rng = math.Random(0xABCD);

  // Predefined character sequence — cycles through the four types.
  static const List<CharacterType> _types = [
    CharacterType.robot,
    CharacterType.brain,
    CharacterType.lightbulb,
    CharacterType.spark,
    CharacterType.robot,
    CharacterType.brain,
    CharacterType.spark,
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Characters are spawned lazily in the first build when we know the size.
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Ticker callback ────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6; // seconds
    _lastTick = elapsed;

    // Update global bounce value (1 full cycle every 2 seconds).
    _animValue = (_animValue + dt / 2.0) % 1.0;

    if (_characters.isEmpty) return;

    bool changed = false;
    for (final c in _characters) {
      // Move toward target.
      final delta = c.target - c.current;
      final dist = delta.distance;
      if (dist > 1.0) {
        final step = math.min(_speed * dt, dist);
        c.current = c.current + Offset(delta.dx / dist, delta.dy / dist) * step;
        changed = true;
      }

      // Count down to next target selection.
      c.secondsUntilNewTarget -= dt;
      if (c.secondsUntilNewTarget <= 0) {
        c.target = _randomMarginPosition();
        c.secondsUntilNewTarget = 3.0 + _rng.nextDouble() * 2.0; // 3–5 s
        changed = true;
      }
    }

    if (changed || true) {
      // Always rebuild to keep the bounce animation smooth.
      if (mounted) setState(() {});
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Spawns initial characters once we have size info.
  void _ensureCharacters(Size size) {
    if (_characters.isNotEmpty) return;
    for (int i = 0; i < _count; i++) {
      final pos = _randomMarginPositionForSize(size);
      _characters.add(_CharacterState(
        type: _types[i],
        current: pos,
        target: _randomMarginPositionForSize(size),
        secondsUntilNewTarget: 1.0 + _rng.nextDouble() * 4.0,
        phaseOffset: i / _count,
      ));
    }
  }

  /// Returns a position in the top 15 % or bottom 15 % margin band.
  Offset _randomMarginPosition() {
    final context = this.context;
    if (!context.mounted) return Offset.zero;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return _randomMarginPositionForSize(box.size);
  }

  Offset _randomMarginPositionForSize(Size size) {
    final inTopBand = _rng.nextBool();
    final x = _rng.nextDouble() * (size.width - 40);
    final y = inTopBand
        ? _rng.nextDouble() * size.height * 0.15
        : size.height * 0.85 + _rng.nextDouble() * size.height * 0.15;
    return Offset(x, y.clamp(0, size.height - 40));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureCharacters(size);

        return Stack(
          children: [
            for (int i = 0; i < _characters.length; i++)
              WanderingCharacter(
                key: ValueKey(i),
                position: _characters[i].current,
                type: _characters[i].type,
                animationValue:
                    (_animValue + _characters[i].phaseOffset) % 1.0,
              ),
          ],
        );
      },
    );
  }
}
