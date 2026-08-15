// ContentFilter — scans and sanitises text against category keyword lists.
//
// Keyword lists are loaded from asset text files (newline-delimited).
// In a Flutter context, use [ContentFilter.fromAssets] which calls
// rootBundle.loadString.  In pure-Dart tests or non-Flutter code, use
// [ContentFilter.fromMap] to supply the word lists directly.
//
// This file has zero Flutter imports — pure Dart only.

import 'filter_config.dart';

// ---------------------------------------------------------------------------
// ContentFilter
// ---------------------------------------------------------------------------

/// Scans text for category keyword matches and optionally sanitises them.
class ContentFilter {
  /// The active configuration.
  final FilterConfig config;

  // category name → set of lowercase keywords
  final Map<String, Set<String>> _keywords;

  ContentFilter._({
    required this.config,
    required Map<String, Set<String>> keywords,
  }) : _keywords = keywords; // ignore: prefer_initializing_formals

  /// Creates a [ContentFilter] from pre-loaded keyword lists.
  ///
  /// [keywordLists] maps category name to a multi-line string of keywords
  /// (one per line, empty lines and `#` comment lines are skipped).
  factory ContentFilter.fromMap(
    FilterConfig config,
    Map<String, String> keywordLists,
  ) {
    final keywords = <String, Set<String>>{};
    for (final entry in keywordLists.entries) {
      keywords[entry.key] = _parseLines(entry.value);
    }
    // Merge custom keywords from config.
    for (final custom in config.customKeywords.entries) {
      keywords.putIfAbsent(custom.key, () => <String>{});
      keywords[custom.key]!.addAll(custom.value.map((k) => k.toLowerCase()));
    }
    return ContentFilter._(config: config, keywords: keywords);
  }

  /// Creates a no-op [ContentFilter] with an empty keyword set.
  factory ContentFilter.empty() => ContentFilter._(
        config: const FilterConfig(enabled: false),
        keywords: {},
      );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Scans [text] and returns a list of matched category names.
  ///
  /// Returns an empty list when the filter is disabled or no matches are found.
  List<String> scan(String text) {
    if (!config.enabled) return [];
    final lower = text.toLowerCase();
    final matched = <String>[];
    for (final category in config.activeCategories) {
      final words = _keywords[category];
      if (words == null) continue;
      if (words.any((word) => lower.contains(word))) {
        matched.add(category);
      }
    }
    return matched;
  }

  /// Sanitises [text] by replacing matched keyword occurrences with a
  /// `[CONTENT_FILTERED: category]` placeholder.
  ///
  /// Returns [text] unchanged when the filter is disabled.
  String sanitise(String text) {
    if (!config.enabled) return text;
    var result = text;
    for (final category in config.activeCategories) {
      final words = _keywords[category];
      if (words == null) continue;
      for (final word in words) {
        final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
        result = result.replaceAll(pattern, '[CONTENT_FILTERED: $category]');
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Set<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();
  }
}
