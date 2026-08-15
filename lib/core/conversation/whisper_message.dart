// WhisperMessage — a private message directed to a single character.
//
// Extends [Message] with a [targetCharacter] field. Only the target
// character's [InferenceWorker] receives it.
//
// This file has zero Flutter imports — pure Dart only.

import 'message.dart';

// ---------------------------------------------------------------------------
// WhisperMessage
// ---------------------------------------------------------------------------

/// A message visible only to [targetCharacter].
class WhisperMessage extends Message {
  /// The character that receives this whisper.
  final String targetCharacter;

  /// Always `true` for whisper messages.
  @override
  bool get isWhisper => true;

  WhisperMessage({
    required super.participantName,
    required super.content,
    required this.targetCharacter,
    super.roundIndex,
    super.id,
    super.timestamp,
  }) : super(
          isUser: true, // whispers come from the user
          isEphemeral: false,
        );

  @override
  String toPlainText() {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '[$h:$m:$s] $participantName→$targetCharacter (whisper): $content';
  }
}
