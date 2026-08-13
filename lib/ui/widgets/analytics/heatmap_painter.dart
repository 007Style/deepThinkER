// HeatmapPainter — draws a conversation activity heatmap.
import 'dart:math';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// HeatmapPainter
// ---------------------------------------------------------------------------

/// Draws a grid heatmap where:
/// - x-axis = time buckets (minutes)
/// - y-axis = characters
/// - cell color intensity = message count in that bucket
class HeatmapPainter extends CustomPainter {
  /// Per-character lists of per-minute message counts.
  final Map<String, List<int>> bucketCounts;

  /// Character names in display order.
  final List<String> characterNames;

  /// Base color per character.
  final Map<String, Color> characterColors;

  const HeatmapPainter({
    required this.bucketCounts,
    required this.characterNames,
    required this.characterColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (characterNames.isEmpty) return;

    final rows = characterNames.length;
    int maxBuckets = 0;
    for (final counts in bucketCounts.values) {
      if (counts.length > maxBuckets) maxBuckets = counts.length;
    }
    if (maxBuckets == 0) maxBuckets = 1;

    final cellW = size.width / maxBuckets;
    final cellH = size.height / rows;

    int maxCount = 1;
    for (final counts in bucketCounts.values) {
      for (final c in counts) {
        if (c > maxCount) maxCount = c;
      }
    }

    for (var r = 0; r < rows; r++) {
      final name = characterNames[r];
      final counts = bucketCounts[name] ?? [];
      final baseColor = characterColors[name] ?? Colors.grey;

      for (var c = 0; c < maxBuckets; c++) {
        final count = c < counts.length ? counts[c] : 0;
        final intensity = count / maxCount;
        final paint = Paint()
          ..color = count == 0
              ? const Color(0xFF1A1A2A)
              : Color.lerp(
                    const Color(0xFF1A1A2A),
                    baseColor,
                    min(intensity, 1.0),
                  ) ??
                  const Color(0xFF1A1A2A);

        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW - 1, cellH - 1);
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(HeatmapPainter old) =>
      old.bucketCounts != bucketCounts;
}
