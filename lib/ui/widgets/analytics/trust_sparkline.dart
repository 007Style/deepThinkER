// TrustSparkline — draws a small trust score sparkline.
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TrustSparkline
// ---------------------------------------------------------------------------

/// Draws a line chart of trust score samples.
///
/// Input: [scores] — a list of trust score values (0.0 – 100.0).
/// The line is drawn in [lineColor].
class TrustSparkline extends CustomPainter {
  final List<double> scores;
  final Color lineColor;

  const TrustSparkline({
    required this.scores,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (scores.length - 1);

    for (var i = 0; i < scores.length; i++) {
      final x = i * stepX;
      final y = size.height - (scores[i].clamp(0.0, 100.0) / 100.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrustSparkline old) => old.scores != scores;
}
