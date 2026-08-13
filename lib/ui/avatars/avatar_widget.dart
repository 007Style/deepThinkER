// Abstract base class for all deepThink avatar widgets.
//
// Every avatar implementation extends [AvatarWidget] and responds to
// [AvatarState] changes to animate accordingly.
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// AvatarState
// ---------------------------------------------------------------------------

/// The current activity state of an AI participant.
///
/// Drives animation speed and visual style in avatar implementations.
enum AvatarState {
  /// Default state — the AI is idle, listening to the conversation.
  idle,

  /// The AI is processing / forming its next response.
  thinking,

  /// The AI is actively streaming tokens (speaking).
  speaking,

  /// The AI is waiting for a context reset or network event.
  waiting,
}

// ---------------------------------------------------------------------------
// AvatarWidget
// ---------------------------------------------------------------------------

/// Contract that all avatar widgets must satisfy.
///
/// Subclasses receive the current [state] and a fixed [size] and are
/// responsible for managing their own animations internally.
abstract class AvatarWidget extends StatefulWidget {
  /// Current activity state of the participant.
  final AvatarState state;

  /// Width and height of the avatar canvas in logical pixels.
  final double size;

  /// Creates an [AvatarWidget].
  const AvatarWidget({
    required this.state,
    this.size = 80.0,
    super.key,
  });
}
