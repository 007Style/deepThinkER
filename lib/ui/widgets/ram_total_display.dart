// Live RAM total display widget for deepThink startup config screen.
//
// Shows the sum of RAM for all four assigned models and color-codes the result.
import 'package:flutter/material.dart';

import 'app_theme.dart';

// ---------------------------------------------------------------------------
// RamTotalDisplay
// ---------------------------------------------------------------------------

/// Displays the total RAM allocated across all four character models.
///
/// Color coding:
/// - Green  : ≤ 20 GB
/// - Amber  : 20–26 GB
/// - Orange : 26–28 GB
/// - Red    : > 28 GB (with warning text)
///
/// Takes [modelRamValues] — one [double] per character, in GB.
class RamTotalDisplay extends StatelessWidget {
  /// RAM values (in GB) for each of the four characters.
  final List<double> modelRamValues;

  const RamTotalDisplay({
    required this.modelRamValues,
    super.key,
  });

  double get _totalGb => modelRamValues.fold(0.0, (a, b) => a + b);

  Color _totalColor(double total) {
    if (total <= 20) return const Color(0xFF4CAF50); // green
    if (total <= 26) return const Color(0xFFFFC107); // amber
    if (total <= 28) return const Color(0xFFFF9800); // orange
    return const Color(0xFFF44336); // red
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalGb;
    final color = _totalColor(total);
    final overLimit = total > 28;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Total RAM allocated  ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '~${total.toStringAsFixed(1)} GB',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              // Subtle breakdown
              Text(
                modelRamValues
                      .map((v) => v.toStringAsFixed(1))
                      .join(' + '),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (overLimit) ...[
            const SizedBox(height: 4),
            const Text(
              '\u26a0 May exceed available RAM on 32 GB machines',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF44336),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
