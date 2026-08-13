/// CharacterSwapEvent — emitted when a character is hot-swapped mid-session.
///
/// This file has zero Flutter imports — pure Dart only.
library character_swap_event;

// ---------------------------------------------------------------------------
// CharacterSwapEvent
// ---------------------------------------------------------------------------

/// Describes a character hot-swap that occurred in the engine.
class CharacterSwapEvent {
  /// Name of the character being removed.
  final String outgoingCharacter;

  /// Name of the character being added.
  final String incomingCharacter;

  /// When the swap occurred.
  final DateTime timestamp;

  /// Number of recent messages injected as catch-up context.
  final int catchUpMessageCount;

  const CharacterSwapEvent({
    required this.outgoingCharacter,
    required this.incomingCharacter,
    required this.timestamp,
    required this.catchUpMessageCount,
  });
}
