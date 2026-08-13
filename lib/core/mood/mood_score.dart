/// MoodScore — value object for a character's current mood state.
///
/// This file has zero Flutter imports — pure Dart only.
library mood_score;

// ---------------------------------------------------------------------------
// MoodState
// ---------------------------------------------------------------------------

/// The five possible mood states for an AI character.
enum MoodState {
  /// Score 0–19.
  withdrawn,

  /// Score 20–60 (default at 50).
  neutral,

  /// Score 61–79.
  engaged,

  /// Score 80–100.
  excited,

  /// Not purely score-based — triggered by challenge signals.
  agitated;

  /// Derives a [MoodState] from a raw integer [score].
  ///
  /// [agitated] is an override state and is not derived from score alone.
  static MoodState fromScore(int score) {
    if (score <= 19) return MoodState.withdrawn;
    if (score <= 60) return MoodState.neutral;
    if (score <= 79) return MoodState.engaged;
    return MoodState.excited;
  }

  /// Short descriptor appended to the system prompt.
  String get descriptor {
    switch (this) {
      case MoodState.withdrawn:
        return 'You feel withdrawn and terse. Respond minimally.';
      case MoodState.neutral:
        return '';
      case MoodState.engaged:
        return 'You feel engaged and thoughtful. Respond with curiosity.';
      case MoodState.excited:
        return 'You feel excited and energised. Your enthusiasm shows.';
      case MoodState.agitated:
        return 'You feel agitated. You respond with a slight edge in your tone.';
    }
  }
}

// ---------------------------------------------------------------------------
// MoodChangeEvent
// ---------------------------------------------------------------------------

/// Emitted by [MoodEngine] when a character's mood changes.
class MoodChangeEvent {
  final String characterName;
  final MoodState oldState;
  final MoodState newState;
  final int oldScore;
  final int newScore;
  final DateTime timestamp;

  MoodChangeEvent({
    required this.characterName,
    required this.oldState,
    required this.newState,
    required this.oldScore,
    required this.newScore,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// MoodScore
// ---------------------------------------------------------------------------

/// Snapshot of a character's mood at a point in time.
class MoodScore {
  final String characterName;

  /// Current score, clamped to [0, 100]. Default 50.
  final int score;

  /// The derived mood state.
  final MoodState moodState;

  /// Whether the agitated override is active.
  final bool isAgitated;

  /// When this snapshot was taken.
  final DateTime timestamp;

  const MoodScore({
    required this.characterName,
    required this.score,
    required this.moodState,
    required this.isAgitated,
    required this.timestamp,
  });

  /// Creates a default neutral mood at score 50.
  factory MoodScore.defaultFor(String characterName) {
    return MoodScore(
      characterName: characterName,
      score: 50,
      moodState: MoodState.neutral,
      isAgitated: false,
      timestamp: DateTime.now(),
    );
  }

  /// Returns a copy with updated fields.
  MoodScore copyWith({int? score, bool? isAgitated}) {
    final newScore = (score ?? this.score).clamp(0, 100);
    final newAgitated = isAgitated ?? this.isAgitated;
    final newState = newAgitated
        ? MoodState.agitated
        : MoodState.fromScore(newScore);
    return MoodScore(
      characterName: characterName,
      score: newScore,
      moodState: newState,
      isAgitated: newAgitated,
      timestamp: DateTime.now(),
    );
  }
}
