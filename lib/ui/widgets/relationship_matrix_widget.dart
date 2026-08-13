// RelationshipMatrixWidget — compact 4x4 grid showing character pair scores.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/relationships/relationship_matrix.dart';
import '../../core/relationships/relationship_score.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// RelationshipMatrixWidget
// ---------------------------------------------------------------------------

/// A compact grid showing the relationship scores between all character pairs.
///
/// Rows and columns each represent one of the four characters. The diagonal is
/// blank; each off-diagonal cell shows the score with a color-coded background.
class RelationshipMatrixWidget extends StatefulWidget {
  final RelationshipMatrix matrix;

  const RelationshipMatrixWidget({
    required this.matrix,
    super.key,
  });

  @override
  State<RelationshipMatrixWidget> createState() =>
      _RelationshipMatrixWidgetState();
}

class _RelationshipMatrixWidgetState extends State<RelationshipMatrixWidget> {
  static const _chars = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];
  StreamSubscription<RelationshipChangeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.matrix.changeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color _cellColor(int score) {
    if (score >= 60) return const Color(0xFF1A3A1A); // deep green
    if (score >= 20) return const Color(0xFF1A2A1A); // mid green
    if (score >= -19) return AppColors.card; // neutral grey
    if (score >= -59) return const Color(0xFF2A1A1A); // mid red
    return const Color(0xFF3A1A1A); // deep red
  }

  Color _textColor(int score) {
    if (score > 0) return const Color(0xFF66BB6A);
    if (score < 0) return const Color(0xFFEF5350);
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RELATIONSHIPS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Header row
          Row(
            children: [
              const SizedBox(width: 56), // row label width
              ..._chars.map(
                (c) => SizedBox(
                  width: 52,
                  child: Text(
                    c.substring(0, 2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Data rows
          ..._chars.asMap().entries.map((rowEntry) {
            final rowChar = rowEntry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      rowChar.substring(0, 2),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ..._chars.asMap().entries.map((colEntry) {
                    final colChar = colEntry.value;
                    if (rowChar == colChar) {
                      return Container(
                        width: 52,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }
                    final rel = widget.matrix.disposition(rowChar, colChar);
                    return Container(
                      width: 52,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _cellColor(rel.score),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${rel.score > 0 ? '+' : ''}${rel.score}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _textColor(rel.score),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
