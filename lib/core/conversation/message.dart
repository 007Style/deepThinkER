/// Message model for deepThink.
///
/// Represents a single utterance in the shared conversation log.
/// This file has zero Flutter imports — pure Dart only.
library message;

import 'dart:math';

// ---------------------------------------------------------------------------
// UUID helper (dart:math-based v4, no external package needed)
// ---------------------------------------------------------------------------

String _uuid4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Version 4
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Variant 10xx
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
      '-${hex(bytes[4])}${hex(bytes[5])}'
      '-${hex(bytes[6])}${hex(bytes[7])}'
      '-${hex(bytes[8])}${hex(bytes[9])}'
      '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
      '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

/// A single utterance in the deepThinkER conversation.
///
/// Each message records who said it ([participantName]), what they said
/// ([content]), when they said it ([timestamp]), and whether it is a
/// pass ([isPass]) or a user message ([isUser]).
///
/// [roundIndex] groups messages into conversation rounds — all responses
/// triggered by the same user or kickoff message share the same index.
/// The UI uses this to apply a consistent color band across all four panels,
/// so you can visually see which responses belong together.
///
/// [isEphemeral] marks tool-result injections that should not be included
/// in the context-reset seed (they are too large and are one-shot).
class Message {
  /// Unique UUID v4 identifier for this message.
  final String id;

  /// Name of the participant who produced this message.
  ///
  /// One of `"WATSON"`, `"DEEP"`, `"NOVA"`, `"SAGE"`, or the dynamic user
  /// name (defaults to `"User"`).
  final String participantName;

  /// The text content of the message.
  ///
  /// An empty string means the participant chose to pass (see [isPass]).
  final String content;

  /// UTC timestamp when this message was created.
  final DateTime timestamp;

  /// `true` when [content] is empty — the participant chose not to respond.
  bool get isPass => content.isEmpty;

  /// `true` when this message originates from the human user.
  final bool isUser;

  /// Conversation round index (0-based).
  ///
  /// Incremented each time a new user message or the kickoff is appended.
  /// All AI responses to that trigger share the same index.
  /// Used by the UI to apply a color band grouping responses together.
  final int roundIndex;

  /// `true` for tool-result injection messages that should not be carried
  /// forward in a context-window reset seed.
  final bool isEphemeral;

  /// Full response body for ephemeral search/fetch messages.
  ///
  /// Non-null only when [isEphemeral] is true and the tool returned content.
  /// Never persisted — only used for in-session UI display.
  final String? responseBody;

  /// `true` for whisper messages (visible only to the target character).
  bool get isWhisper => false;

  /// Creates a [Message] with an auto-generated UUID and current timestamp.
  Message({
    required this.participantName,
    required this.content,
    required this.isUser,
    this.roundIndex = 0,
    this.isEphemeral = false,
    this.responseBody,
    String? id,
    DateTime? timestamp,
  })  : id = id ?? _uuid4(),
        timestamp = timestamp ?? DateTime.now().toUtc();

  /// Formats the message as `[HH:MM:SS] NAME: content`.
  String toPlainText() {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '[$h:$m:$s] $participantName: $content';
  }

  @override
  String toString() =>
      'Message(id=$id, participant=$participantName, pass=$isPass)';
}
