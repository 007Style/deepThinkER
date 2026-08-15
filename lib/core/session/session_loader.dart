// SessionLoader — parses a session log file into a [ConversationLog].
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:io';

import '../conversation/conversation_log.dart';
import '../conversation/message.dart';
import '../conversation/whisper_message.dart';

// ---------------------------------------------------------------------------
// SessionLoader
// ---------------------------------------------------------------------------

/// Parses a saved deepThinkER session log file into a [ConversationLog].
///
/// Expected log formats:
/// - Normal message: `[2024-01-15 14:23:01] WATSON: Some message content`
/// - Whisper message: `[2024-01-15 14:23:01] USER→WATSON (whisper): content`
///
/// Lines that do not match either pattern (headers, footers, blank lines) are
/// silently skipped.
class SessionLoader {
  // Normal message: [timestamp] NAME: content
  static final _normalPattern =
      RegExp(r'^\[([^\]]+)\]\s+([^:→]+):\s+(.+)$');

  // Whisper message: [timestamp] USER→TARGET (whisper): content
  static final _whisperPattern =
      RegExp(r'^\[([^\]]+)\]\s+USER→(\w+)\s+\(whisper\):\s+(.+)$');

  /// Reads [filePath] line by line and returns a [ConversationLog] populated
  /// with the parsed [Message] and [WhisperMessage] objects.
  ///
  /// Lines that don't match either pattern are skipped.
  static Future<ConversationLog> load(String filePath) async {
    final log = ConversationLog();
    final file = File(filePath);
    final lines = await file.readAsLines();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Try whisper pattern first (more specific).
      final whisperMatch = _whisperPattern.firstMatch(trimmed);
      if (whisperMatch != null) {
        final timestampStr = whisperMatch.group(1)!;
        final targetName = whisperMatch.group(2)!;
        final content = whisperMatch.group(3)!;
        final parsedTime = _parseTimestamp(timestampStr);

        final msg = WhisperMessage(
          participantName: 'USER',
          content: content,
          targetCharacter: targetName,
          timestamp: parsedTime,
        );
        log.append(msg);
        continue;
      }

      // Try normal message pattern.
      final normalMatch = _normalPattern.firstMatch(trimmed);
      if (normalMatch != null) {
        final timestampStr = normalMatch.group(1)!;
        final name = normalMatch.group(2)!.trim();
        final content = normalMatch.group(3)!.trim();
        final parsedTime = _parseTimestamp(timestampStr);

        final msg = Message(
          participantName: name,
          content: content,
          timestamp: parsedTime,
          isUser: name == 'USER',
        );
        log.append(msg);
        continue;
      }

      // Line does not match — skip (header, footer, blank).
    }

    return log;
  }

  /// Parses a timestamp string such as `2024-01-15 14:23:01` or `14:23:01`
  /// into a [DateTime].  Falls back to [DateTime.now] on parse failure.
  static DateTime _parseTimestamp(String raw) {
    final trimmed = raw.trim();
    return DateTime.tryParse(trimmed) ?? DateTime.now().toUtc();
  }
}
