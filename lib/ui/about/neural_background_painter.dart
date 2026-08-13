// Animated neural-network background painter for deepThink About screen.
//
// Draws a subtle grid of 20 nodes and 35 connecting edges.  All positions and
// connections are deterministic (seeded random) so they never jump around on
// each rebuild.  Opacity and glow intensity pulse via [animationValue].
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// NeuralBackgroundPainter
// ---------------------------------------------------------------------------

/// [CustomPainter] that renders a pulsing neural-network background.
///
/// Pass [animationValue] (0.0–1.0, looping) from a [AnimationController] to
/// drive the shimmer effect on edges and the glow intensity on nodes.
class NeuralBackgroundPainter extends CustomPainter {
  /// Drives edge shimmer and node glow (0.0 → 1.0, looping).
  final double animationValue;

  NeuralBackgroundPainter({required this.animationValue});

  // ── Deterministic layout ──────────────────────────────────────────────────

  static const int _nodeCount = 20;
  static const int _edgeCount = 35;
  static const int _seed = 0xDEED; // stable across rebuilds

  /// Returns [_nodeCount] normalised node positions (x, y each in 0..1).
  static List<Offset> _nodePositions() {
    final rng = math.Random(_seed);
    return List.generate(
      _nodeCount,
      (_) => Offset(rng.nextDouble(), rng.nextDouble()),
    );
  }

  /// Returns [_edgeCount] index-pairs connecting nodes.
  static List<(int, int)> _edgePairs() {
    final rng = math.Random(_seed + 1);
    return List.generate(_edgeCount, (_) {
      final a = rng.nextInt(_nodeCount);
      int b = rng.nextInt(_nodeCount);
      while (b == a) {
        b = rng.nextInt(_nodeCount);
      }
      return (a, b);
    });
  }

  // Pre-compute once at class level — dart statics are lazily initialised.
  static final List<Offset> _positions = _nodePositions();
  static final List<(int, int)> _edges = _edgePairs();

  // ── Paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = (math.sin(animationValue * math.pi * 2) + 1.0) / 2.0;

    // Map normalised positions to canvas coordinates.
    final pts = _positions
        .map((n) => Offset(n.dx * size.width, n.dy * size.height))
        .toList();

    // ── Draw edges ────────────────────────────────────────────────────────

    for (int i = 0; i < _edges.length; i++) {
      final (a, b) = _edges[i];
      // Stagger each edge's phase slightly for a travelling-wave feel.
      final phase = (i / _edges.length + animationValue) % 1.0;
      final edgePulse = (math.sin(phase * math.pi * 2) + 1.0) / 2.0;
      final alpha = lerpDouble(0.04, 0.14, edgePulse)!;

      final edgePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: alpha)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(pts[a], pts[b], edgePaint);
    }

    // ── Draw nodes ────────────────────────────────────────────────────────

    for (int i = 0; i < pts.length; i++) {
      final pt = pts[i];
      // Each node has a slightly different phase offset.
      final phase = (i / pts.length + animationValue) % 1.0;
      final nodePulse = (math.sin(phase * math.pi * 2) + 1.0) / 2.0;

      // Outer glow
      final glowRadius = lerpDouble(6.0, 12.0, nodePulse)!;
      final glowAlpha = lerpDouble(0.04, 0.18, pulse)!;
      final glowPaint = Paint()
        ..color =
            AppColors.accent.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pt, glowRadius, glowPaint);

      // Core dot
      final coreAlpha = lerpDouble(0.2, 0.5, nodePulse)!;
      final corePaint = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: coreAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 2.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(NeuralBackgroundPainter old) =>
      old.animationValue != animationValue;
}
