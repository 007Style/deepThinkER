/// Parser for LLM tool-call tags embedded in a text stream.
///
/// Scans text for patterns like `[SEARCH: query]` or `[FETCH: https://...]`
/// and returns a list of [ParsedToolCall] value objects.
///
/// This file has zero Flutter imports — pure Dart only.
library tool_call_parser;

// ---------------------------------------------------------------------------
// ParsedToolCall
// ---------------------------------------------------------------------------

/// A single tool-call tag found in a text buffer.
class ParsedToolCall {
  /// Tag name, always uppercased (e.g. `'SEARCH'`).
  final String tag;

  /// The argument after the colon (e.g. `'latest AI news'`).
  final String argument;

  /// Character offset of the opening `[` in the source text.
  final int startIndex;

  /// Character offset immediately after the closing `]` in the source text.
  final int endIndex;

  const ParsedToolCall({
    required this.tag,
    required this.argument,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  String toString() =>
      'ParsedToolCall(tag=$tag, argument="$argument", '
      'range=[$startIndex, $endIndex])';
}

// ---------------------------------------------------------------------------
// ToolCallParser
// ---------------------------------------------------------------------------

/// Parses `[TAG: argument]` tool-call tags from a string.
///
/// Tags may span multiple lines (the dot-all flag is set on the regex).
/// Only uppercase ASCII tags (`A-Z` and `_`) are matched.
class ToolCallParser {
  ToolCallParser._();

  /// Regex matching `[TAG: argument]` — TAG must be uppercase letters + `_`.
  static final RegExp _tagRegex = RegExp(
    r'\[([A-Z_]+):\s*(.*?)\]',
    dotAll: true,
  );

  /// Parses all tool-call tags found in [text].
  ///
  /// Returns an empty list if no tags are found.
  /// Tags are returned in the order they appear in [text].
  static List<ParsedToolCall> parse(String text) {
    final results = <ParsedToolCall>[];
    for (final m in _tagRegex.allMatches(text)) {
      results.add(ParsedToolCall(
        tag: m.group(1)!.toUpperCase(),
        argument: (m.group(2) ?? '').trim(),
        startIndex: m.start,
        endIndex: m.end,
      ));
    }
    return results;
  }
}
