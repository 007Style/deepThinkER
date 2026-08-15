// MarkdownExporter — formats a conversation as a Markdown document.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// MarkdownExporter
// ---------------------------------------------------------------------------

/// Renders a list of message maps and optional search activity entries as a
/// Markdown string suitable for export.
///
/// Message entries (each a `Map<String,String>`) must have:
/// - `'sender'`    — character or user name
/// - `'content'`   — raw message text
/// - `'timestamp'` — ISO-8601 or human-readable timestamp
///
/// Search activity entries (each a `Map<String,String>`) may have:
/// - `'query'`     — the search query
/// - `'timestamp'` — when the search happened
/// - `'result'`    — brief result summary (optional)
class MarkdownExporter {
  const MarkdownExporter();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Formats [messages] as Markdown.
  ///
  /// Optionally appends a Search Activity section from [searchActivity].
  String export({
    required String sessionName,
    required List<Map<String, String>> messages,
    List<Map<String, String>>? searchActivity,
  }) {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('# $sessionName');
    buffer.writeln();

    // Conversation
    buffer.writeln('## Conversation');
    buffer.writeln();

    for (final msg in messages) {
      final sender = msg['sender'] ?? 'Unknown';
      final timestamp = msg['timestamp'] ?? '';
      final content = msg['content'] ?? '';

      if (content.trim().isEmpty) continue;

      buffer.writeln('**$sender**  ');
      if (timestamp.isNotEmpty) {
        buffer.writeln('_${timestamp}_');
        buffer.writeln();
      }
      buffer.writeln(content.trim());
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    // Search activity
    if (searchActivity != null && searchActivity.isNotEmpty) {
      buffer.writeln('## Search Activity');
      buffer.writeln();
      for (final entry in searchActivity) {
        final query = entry['query'] ?? '';
        final ts = entry['timestamp'] ?? '';
        final result = entry['result'];
        if (ts.isNotEmpty) {
          buffer.write('> _${ts}_ — ');
        } else {
          buffer.write('> ');
        }
        buffer.writeln('**$query**');
        if (result != null && result.isNotEmpty) {
          buffer.writeln('> $result');
        }
        buffer.writeln('>');
      }
    }

    return buffer.toString();
  }
}
