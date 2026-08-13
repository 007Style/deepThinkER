// SearchActivityEntry — collapsible entry showing a web search result.
//
// Collapsed: "🌐 searched: {query}"
// Expanded:  raw HTML in a scrollable monospace text area.
import 'package:flutter/material.dart';

import '../app_theme.dart';

// ---------------------------------------------------------------------------
// SearchActivityEntry
// ---------------------------------------------------------------------------

/// An expandable tile showing a web search or fetch that was performed.
///
/// [query] is the search term or URL used.
/// [rawHtml] is the truncated HTML returned by the fetcher.
class SearchActivityEntry extends StatelessWidget {
  final String query;
  final String rawHtml;

  const SearchActivityEntry({
    required this.query,
    required this.rawHtml,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A13), // subtle teal tint
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        dense: true,
        collapsedIconColor: AppColors.textSecondary.withValues(alpha: 0.5),
        iconColor: AppColors.accent.withValues(alpha: 0.7),
        title: Text(
          '\uD83C\uDF10 searched: $query',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Container(
            height: 200,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(
                rawHtml,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
