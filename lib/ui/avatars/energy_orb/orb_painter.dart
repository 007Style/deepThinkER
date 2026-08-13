// CustomPainter that renders the Energy Orb avatar.
//
// Driven by two animation values — [animationValue] for continuous rotation
// and [secondaryAnimValue] for state-dependent pulse — it draws:
//   • a glowing central orb (radial gradient)
//   • 16 orbiting particles at varying radii and angular offsets
//   • an outer glow ring whose intensity and size change with [state]
//   • concentric shimmer rings during the `thinking` state
//
// This file has no business-logic imports — pure Flutter/painting only.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../avatar_widget.dart';
import 'orb_config.dart';

// ---------------------------------------------------------------------------
// _Particle  (private data class)
// ---------------------------------------------------------------------------

/// Fixed per-particle seed data; animation drives the actual position.
class _Particle {
  /// Base orbit radius as a fraction of the canvas half-size.
  final double orbitRadius;

  /// Initial angular offset in radians, giving each particle a unique start.
  final double angleOffset;

  /// Angular velocity multiplier relative to the primary animation.
  final double speed;

  /// Particle radius in logical pixels (before state scaling).
  final double radius;

  /// Base opacity (0.0–1.0); fades further in the `waiting` state.
  final double baseAlpha;

  const _Particle({
    required this.orbitRadius,
    required this.angleOffset,
    required this.speed,
    required this.radius,
    required this.baseAlpha,
  });
}

// ---------------------------------------------------------------------------
// OrbPainter
// ---------------------------------------------------------------------------

/// Stateless [CustomPainter] for the Energy Orb.
///
/// All state is derived from the two animation values passed in; the widget
/// layer is responsible for rebuilding whenever they change.
class OrbPainter extends CustomPainter {
  /// Per-character color and motion configuration.
  final OrbConfig config;

  /// Primary animation value in [0.0, 1.0] — drives orbital rotation.
  final double animationValue;

  /// Secondary animation value in [0.0, 1.0] — drives pulse / glow.
  final double secondaryAnimValue;

  /// Current activity state of the participant.
  final AvatarState state;

  /// Creates an [OrbPainter].
  const OrbPainter({
    required this.config,
    required this.animationValue,
    required this.secondaryAnimValue,
    required this.state,
  });

  // -------------------------------------------------------------------------
  // Particle seeds — built once, reused on every repaint
  // -------------------------------------------------------------------------

  static final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    final rng = math.Random(42); // fixed seed → deterministic layout
    return List.generate(16, (i) {
      final ring = i % 4; // 4 concentric rings of 4 particles each
      return _Particle(
        orbitRadius: 0.28 + ring * 0.10 + rng.nextDouble() * 0.04,
        angleOffset: (i / 16) * math.pi * 2 + rng.nextDouble() * 0.4,
        speed: 0.6 + rng.nextDouble() * 0.8, // 0.6× – 1.4× base
        radius: 2.0 + rng.nextDouble() * 2.5,
        baseAlpha: 0.55 + rng.nextDouble() * 0.35,
      );
    });
  }

  // -------------------------------------------------------------------------
  // State-derived animation parameters
  // -------------------------------------------------------------------------

  /// Computes per-state visual parameters from [state] and the two anim values.
  _StateParams _stateParams(double halfSize) {
    final pulse = (math.sin(secondaryAnimValue * math.pi * 2) + 1) / 2;

    switch (state) {
      case AvatarState.idle:
        return _StateParams(
          orbRadius: halfSize * 0.32,
          orbBrightness: 0.7,
          glowRadius: halfSize * 0.55 + pulse * halfSize * 0.04,
          glowAlpha: 0.18 + pulse * 0.06,
          particleAlphaMultiplier: 0.75,
          particleRadiusMultiplier: 1.0,
          showShimmerRings: false,
          shimmerAlpha: 0,
        );

      case AvatarState.thinking:
        return _StateParams(
          orbRadius: halfSize * 0.30 + pulse * halfSize * 0.04,
          orbBrightness: 0.85 + pulse * 0.15,
          glowRadius: halfSize * 0.60 + pulse * halfSize * 0.08,
          glowAlpha: 0.28 + pulse * 0.14,
          particleAlphaMultiplier: 1.0,
          particleRadiusMultiplier: 1.1,
          showShimmerRings: true,
          shimmerAlpha: 0.12 + pulse * 0.10,
        );

      case AvatarState.speaking:
        final heartbeat = (math.sin(secondaryAnimValue * math.pi * 4) + 1) / 2;
        return _StateParams(
          orbRadius: halfSize * (0.30 + heartbeat * 0.06),
          orbBrightness: 0.9 + heartbeat * 0.10,
          glowRadius: halfSize * (0.62 + heartbeat * 0.10),
          glowAlpha: 0.35 + heartbeat * 0.20,
          particleAlphaMultiplier: 1.0,
          particleRadiusMultiplier: 1.0 + heartbeat * 0.18,
          showShimmerRings: false,
          shimmerAlpha: 0,
        );

      case AvatarState.waiting:
        return _StateParams(
          orbRadius: halfSize * 0.28,
          orbBrightness: 0.40,
          glowRadius: halfSize * 0.44,
          glowAlpha: 0.08,
          particleAlphaMultiplier: 0.30,
          particleRadiusMultiplier: 0.85,
          showShimmerRings: false,
          shimmerAlpha: 0,
        );
    }
  }

  // -------------------------------------------------------------------------
  // paint
  // -------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfSize = math.min(cx, cy);
    final center = Offset(cx, cy);
    final params = _stateParams(halfSize);

    _drawGlowRing(canvas, center, halfSize, params);
    if (params.showShimmerRings) {
      _drawShimmerRings(canvas, center, halfSize, params);
    }
    _drawParticles(canvas, center, halfSize, params);
    _drawOrb(canvas, center, params);
  }

  // -------------------------------------------------------------------------
  // Drawing helpers
  // -------------------------------------------------------------------------

  void _drawGlowRing(
    Canvas canvas,
    Offset center,
    double halfSize,
    _StateParams p,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          config.glowColor.withAlpha((p.glowAlpha * 255).round()),
          config.glowColor.withAlpha(0),
        ],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: p.glowRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, p.glowRadius, paint);
  }

  void _drawShimmerRings(
    Canvas canvas,
    Offset center,
    double halfSize,
    _StateParams p,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 1; i <= 3; i++) {
      final fraction = (animationValue + i * 0.33) % 1.0;
      final ringR = halfSize * (0.35 + fraction * 0.30);
      final alpha = (p.shimmerAlpha * (1.0 - fraction) * 255).round();
      ringPaint.color = config.secondaryColor.withAlpha(alpha.clamp(0, 255));
      canvas.drawCircle(center, ringR, ringPaint);
    }
  }

  void _drawParticles(
    Canvas canvas,
    Offset center,
    double halfSize,
    _StateParams p,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rotation = animationValue * math.pi * 2;

    for (final particle in _particles) {
      final angle =
          rotation * particle.speed * config.swirlFrequency + particle.angleOffset;
      final r = halfSize * particle.orbitRadius * p.particleRadiusMultiplier;
      final px = center.dx + math.cos(angle) * r;
      final py = center.dy + math.sin(angle) * r;

      final alpha =
          (particle.baseAlpha * p.particleAlphaMultiplier * 255).round().clamp(0, 255);

      paint.color = config.primaryColor.withAlpha(alpha);
      canvas.drawCircle(
        Offset(px, py),
        particle.radius,
        paint,
      );
    }
  }

  void _drawOrb(Canvas canvas, Offset center, _StateParams p) {
    final brightness = p.orbBrightness.clamp(0.0, 1.0);

    // Inner bright core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            config.primaryColor,
            const Color(0xFFFFFFFF),
            brightness * 0.55,
          )!,
          config.primaryColor.withAlpha((brightness * 255).round()),
          config.secondaryColor.withAlpha((brightness * 180).round()),
          config.secondaryColor.withAlpha(0),
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: p.orbRadius * 1.2))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, p.orbRadius * 1.2, corePaint);

    // Sharp bright highlight dot
    final highlightOffset =
        center + Offset(p.orbRadius * -0.22, p.orbRadius * -0.22);
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
          .withAlpha((brightness * 130).round().clamp(0, 255))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(highlightOffset, p.orbRadius * 0.18, highlightPaint);
  }

  // -------------------------------------------------------------------------
  // shouldRepaint
  // -------------------------------------------------------------------------

  @override
  bool shouldRepaint(OrbPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.secondaryAnimValue != secondaryAnimValue ||
      oldDelegate.state != state ||
      oldDelegate.config != config;
}

// ---------------------------------------------------------------------------
// _StateParams  (private value type)
// ---------------------------------------------------------------------------

class _StateParams {
  final double orbRadius;
  final double orbBrightness;
  final double glowRadius;
  final double glowAlpha;
  final double particleAlphaMultiplier;
  final double particleRadiusMultiplier;
  final bool showShimmerRings;
  final double shimmerAlpha;

  const _StateParams({
    required this.orbRadius,
    required this.orbBrightness,
    required this.glowRadius,
    required this.glowAlpha,
    required this.particleAlphaMultiplier,
    required this.particleRadiusMultiplier,
    required this.showShimmerRings,
    required this.shimmerAlpha,
  });
}
