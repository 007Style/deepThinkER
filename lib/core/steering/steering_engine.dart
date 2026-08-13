/// SteeringEngine — injects silent steering messages into all workers.
///
/// This file has zero Flutter imports — pure Dart only.
library steering_engine;

import '../conversation/conversation_engine.dart';
import '../conversation/message.dart';

// ---------------------------------------------------------------------------
// SteeringEngine
// ---------------------------------------------------------------------------

/// Injects `[SYSTEM_STEER: text]` as an ephemeral system message into all
/// four character contexts simultaneously.
///
/// Steering messages are NOT shown in the conversation log — they modify
/// behaviour silently without being acknowledged by characters.
class SteeringEngine {
  final ConversationEngine engine;

  SteeringEngine({required this.engine});

  /// Injects [text] as a silent system steering message.
  ///
  /// The message is ephemeral and will not be carried through context resets.
  void steer(String text) {
    if (text.trim().isEmpty) return;
    final message = Message(
      participantName: 'System',
      content: '[SYSTEM_STEER: ${text.trim()}]',
      isUser: false,
      isEphemeral: true,
    );
    engine.log.append(message);
  }
}
