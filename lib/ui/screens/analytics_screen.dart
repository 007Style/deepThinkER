// AnalyticsScreen — post-session analytics view for deepThinkER.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/analytics/session_analytics.dart';
import '../widgets/analytics/heatmap_painter.dart';
import '../widgets/analytics/trust_sparkline.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// AnalyticsScreen
// ---------------------------------------------------------------------------

/// Shows session analytics: heatmap, trust sparklines, tool call table,
/// mood change timeline, and an export button.
class AnalyticsScreen extends StatelessWidget {
  final SessionAnalytics analytics;

  static const _characters = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];
  static const _charColors = {
    'WATSON': Color(0xFF4FC3F7), // blue
    'DEEP': Color(0xFFAB47BC), // purple
    'NOVA': Color(0xFF66BB6A), // green
    'SAGE': Color(0xFFFFCA28), // amber
  };

  const AnalyticsScreen({
    required this.analytics,
    super.key,
  });

  Map<String, List<int>> _buildBucketCounts() {
    final now = DateTime.now();

    // Find session start time from first event.
    if (analytics.events.isEmpty) return {};
    final start = analytics.events.first.timestamp;
    final totalMinutes = now.difference(start).inMinutes + 1;

    final result = <String, List<int>>{};
    for (final char in _characters) {
      result[char] = List.filled(totalMinutes, 0);
    }

    for (final event in analytics.events) {
      if (event.type != AnalyticsEventType.message) continue;
      final char = event.characterName;
      if (char == null || !result.containsKey(char)) continue;
      final bucket = event.timestamp.difference(start).inMinutes;
      if (bucket >= 0 && bucket < totalMinutes) {
        result[char]![bucket]++;
      }
    }
    return result;
  }

  Map<String, int> _toolCallCounts() {
    final counts = <String, int>{};
    for (final event in analytics.events) {
      if (event.type != AnalyticsEventType.toolCall) continue;
      final tag = event.payload['tag'] as String? ?? 'unknown';
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
    return counts;
  }

  List<AnalyticsEvent> _moodChanges() => analytics.events
      .where((e) => e.type == AnalyticsEventType.moodChange)
      .take(20)
      .toList();

  Future<void> _exportJson(BuildContext context) async {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      final path = '$home/Downloads/${analytics.sessionName}_analytics.json';
      await analytics.flush();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analytics exported to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBucketCounts();
    final toolCounts = _toolCallCounts();
    final moodChanges = _moodChanges();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Session Analytics — ${analytics.sessionName}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _exportJson(context),
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Export JSON'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Message counts ─────────────────────────────────────────────
            _SectionHeader(label: 'MESSAGE COUNTS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _characters.map((c) {
                final count = analytics.messageCountByCharacter[c] ?? 0;
                final color = _charColors[c] ?? AppColors.accent;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$c: $count',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Conversation heatmap ───────────────────────────────────────
            _SectionHeader(label: 'CONVERSATION HEATMAP'),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: buckets.isEmpty
                  ? const Center(
                      child: Text(
                        'No data',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: HeatmapPainter(
                        bucketCounts: buckets,
                        characterNames: _characters
                            .where(buckets.containsKey)
                            .toList(),
                        characterColors: _charColors,
                      ),
                      size: const Size(double.infinity, 120),
                    ),
            ),

            const SizedBox(height: 20),

            // ── Trust sparklines ───────────────────────────────────────────
            _SectionHeader(label: 'TRUST TRAJECTORIES'),
            const SizedBox(height: 8),
            Row(
              children: _characters.map((c) {
                final history = analytics.trustHistory[c] ?? [];
                final color = _charColors[c] ?? AppColors.accent;
                return Expanded(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.substring(0, 2),
                          style: TextStyle(
                            fontSize: 8,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: CustomPaint(
                            painter: TrustSparkline(
                              scores: history,
                              lineColor: color,
                            ),
                            size: const Size(double.infinity, 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Tool call table ─────────────────────────────────────────────
            _SectionHeader(label: 'TOOL CALLS'),
            const SizedBox(height: 8),
            if (toolCounts.isEmpty)
              const Text(
                'No tool calls recorded.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
            else
              DataTable(
                headingRowHeight: 30,
                dataRowMinHeight: 26,
                dataRowMaxHeight: 26,
                columns: const [
                  DataColumn(
                      label: Text('Tool',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary))),
                  DataColumn(
                      label: Text('Count',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary))),
                ],
                rows: toolCounts.entries.map((e) {
                  return DataRow(cells: [
                    DataCell(Text(e.key,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textPrimary))),
                    DataCell(Text(e.value.toString(),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textPrimary))),
                  ]);
                }).toList(),
              ),

            const SizedBox(height: 20),

            // ── Mood changes ────────────────────────────────────────────────
            _SectionHeader(label: 'MOOD CHANGES'),
            const SizedBox(height: 8),
            if (moodChanges.isEmpty)
              const Text(
                'No mood changes recorded.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...moodChanges.map((e) {
                final ts = e.timestamp.toLocal();
                final time =
                    '${_p(ts.hour)}:${_p(ts.minute)}:${_p(ts.second)}';
                final char = e.characterName ?? '?';
                final state = e.payload['newState'] as String? ?? '?';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$time  $char → $state',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// _SectionHeader
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}
