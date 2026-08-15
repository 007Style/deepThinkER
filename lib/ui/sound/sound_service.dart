// SoundService — plays audio cues using the audioplayers package.

import 'package:audioplayers/audioplayers.dart';

// ---------------------------------------------------------------------------
// SoundEvent
// ---------------------------------------------------------------------------

/// Identifies which audio cue to play.
enum SoundEvent {
  /// New message arrived from a character.
  message,

  /// User sent a message.
  send,

  /// A rate-limit violation was triggered.
  rateLimit,

  /// Research phase changed.
  phaseChange,

  /// Research cycle completed.
  researchComplete,

  /// Trust score changed.
  trustChange,

  /// Image was analysed by the vision model.
  imageAnalysed,
}

// ---------------------------------------------------------------------------
// SoundService
// ---------------------------------------------------------------------------

/// Wraps [AudioPlayer] from audioplayers to play one-shot sound cues.
///
/// Lazily initialises players on first [play] call.
/// Set [globalEnabled] to `false` to silence all sounds.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  /// Master on/off switch.
  bool globalEnabled = true;

  /// Per-event enable map.  Defaults to `true` for all events.
  final Map<SoundEvent, bool> eventEnabled = {
    for (final e in SoundEvent.values) e: true,
  };

  // One AudioPlayer per event type so concurrent sounds don't cancel each other.
  final Map<SoundEvent, AudioPlayer> _players = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Plays the sound associated with [event] if enabled.
  Future<void> play(SoundEvent event) async {
    if (!globalEnabled) return;
    if (eventEnabled[event] == false) return;

    final player = _players.putIfAbsent(event, AudioPlayer.new);
    await player.play(AssetSource(_assetPath(event)));
  }

  /// Releases all [AudioPlayer] resources.
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static String _assetPath(SoundEvent event) {
    return switch (event) {
      SoundEvent.message => 'sounds/message.mp3',
      SoundEvent.send => 'sounds/send.mp3',
      SoundEvent.rateLimit => 'sounds/rate_limit.mp3',
      SoundEvent.phaseChange => 'sounds/phase_change.mp3',
      SoundEvent.researchComplete => 'sounds/research_complete.mp3',
      SoundEvent.trustChange => 'sounds/trust_change.mp3',
      SoundEvent.imageAnalysed => 'sounds/image_analysed.mp3',
    };
  }
}
