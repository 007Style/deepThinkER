/// ConversationFormatter — strips system/tool messages and formats a clean
/// human-readable transcript.
///
/// This file has zero Flutter imports — pure Dart only.
library conversation_formatter;

// ---------------------------------------------------------------------------
// ConversationFormatter
// ---------------------------------------------------------------------------

/// Formats a list of message maps into a clean plain-text conversation
/// transcript, stripping tool-call injection markers and system messages.
class ConversationFormatter {
  const ConversationFormatter();

  // Tags that indicate injected system content — lines containing these
  // prefixes are stripped entirely.
  static const List<String> _stripPrefixes = [
    '[WEB_RESULT',
    '[SYSTEM_STEER',
    '[PROACTIVE_WEB_RESULT',
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Formats [messages] as a human-readable transcript.
  ///
  /// Each [messages] entry must have:
  /// - `'sender'`    — character or user name
  /// - `'content'`   — raw message text
  /// - `'timestamp'` — ISO-8601 string or any human-readable timestamp
  ///
  /// Lines within `content` that start with a strip-prefix are removed.
  /// Returns a single formatted string.
  String format(List<Map<String, String>> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final sender = msg['sender'] ?? 'Unknown';
      final timestamp = msg['timestamp'] ?? '';
      final rawContent = msg['content'] ?? '';

      final cleanContent = _cleanContent(rawContent);
      if (cleanContent.isEmpty) continue;

      buffer.writeln('[$timestamp] $sender: $cleanContent');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  String _cleanContent(String raw) {
    final lines = raw.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      final isSystem = _stripPrefixes.any((p) => trimmed.startsWith(p));
      if (!isSystem) {
        kept.add(line);
      }
    }
    return kept.join('\n').trim();
  }
}
