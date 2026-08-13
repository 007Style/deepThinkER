// TrustSparklineWidget — compact 60-point sparkline of trust score history.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/trust/trust_manager.dart';

// ---------------------------------------------------------------------------
// TrustSparklineWidget
// ---------------------------------------------------------------------------

/// Draws a compact live-updating sparkline of trust score history.
///
/// Subscribes to [TrustManager.trustStream] and repaints on each tick.
/// Width: 60px, Height: 20px. Color matches the last point's trust tier.
class TrustSparklineWidget extends StatefulWidget {
  final TrustManager trustManager;
  final String characterName;

  const TrustSparklineWidget({
    required this.trustManager,
    required this.characterName,
    super.key,
  });

  @override
  State<TrustSparklineWidget> createState() => _TrustSparklineWidgetState();
}

class _TrustSparklineWidgetState extends State<TrustSparklineWidget> {
  late List<double> _scores;
  StreamSubscription<TrustEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _scores = List<double>.from(
        widget.trustManager.historyFor(widget.characterName));
    _sub = widget.trustManager.trustStream.listen((event) {
      if (event.characterName == widget.characterName && mounted) {
        setState(() {
          _scores = List<double>.from(
              widget.trustManager.historyFor(widget.characterName));
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scores.isEmpty) return const SizedBox(width: 60, height: 20);
    return SizedBox(
      width: 60,
      height: 20,
      child: CustomPaint(
        painter: _SparklinePainter(_scores),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SparklinePainter
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final List<double> scores;

  _SparklinePainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final lastScore = scores.last;
    final tier = TrustTier.fromScore(lastScore);
    final color = _tierColor(tier);

    final minY = scores.reduce(math.min);
    final maxY = scores.reduce(math.max);
    final range = (maxY - minY).abs();
    final effectiveRange = range < 5 ? 5.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final n = scores.length;
    for (int i = 0; i < n; i++) {
      final x = (i / math.max(n - 1, 1)) * size.width;
      final normalised = (scores[i] - minY) / effectiveRange;
      final y = size.height - normalised * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  Color _tierColor(TrustTier tier) {
    switch (tier) {
      case TrustTier.high:
        return const Color(0xFF00C853);
      case TrustTier.mid:
        return const Color(0xFFFFB300);
      case TrustTier.low:
        return const Color(0xFFFF5252);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.scores != scores;
}
