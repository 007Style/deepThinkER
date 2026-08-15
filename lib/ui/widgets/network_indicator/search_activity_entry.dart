// SearchActivityEntry — collapsible entry showing a web search/fetch result.
//
// Collapsed: single-line label  e.g. 🔍 SEARCH  "quantum computing"  via DuckDuckGo
// Expanded:  full scrollable response body in a monospace text area.
import 'package:flutter/material.dart';

import '../app_theme.dart';

// ---------------------------------------------------------------------------
// SearchActivityEntry
// ---------------------------------------------------------------------------

/// An expandable tile showing one network tool call made by a character.
///
/// [label]        — one-line summary shown when collapsed (already formatted).
/// [responseBody] — full tool response text; null for blocked/rate-limited calls.
class SearchActivityEntry extends StatelessWidget {
  final String label;
  final String? responseBody;

  const SearchActivityEntry({
    required this.label,
    this.responseBody,
    super.key,
  });

  /// Whether this entry has a response body worth expanding.
  bool get _hasBody =>
      responseBody != null && responseBody!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: _hasBody
          ? ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              dense: true,
              collapsedIconColor:
                  AppColors.textSecondary.withValues(alpha: 0.4),
              iconColor: AppColors.accent.withValues(alpha: 0.6),
              title: _LabelLine(label: label),
              // Expanded body — full scrollable response
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        responseBody!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          // No body — just a static label row (blocked / rate-limited).
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: _LabelLine(label: label),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LabelLine — the single-line summary text
// ---------------------------------------------------------------------------

class _LabelLine extends StatelessWidget {
  final String label;
  const _LabelLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
