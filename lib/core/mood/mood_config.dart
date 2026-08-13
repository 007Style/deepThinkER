/// MoodConfig — per-character mood sensitivity configuration.
///
/// This file has zero Flutter imports — pure Dart only.
library mood_config;

// ---------------------------------------------------------------------------
// MoodConfig
// ---------------------------------------------------------------------------

/// Per-character sensitivity and delta configuration for the mood engine.
class MoodConfig {
  /// How strongly this character reacts to mood signals (multiplier).
  final double sensitivity;

  /// Score delta when the character is directly addressed by name.
  final int directAddressDelta;

  /// Score delta when a challenge keyword is detected.
  final int challengeDelta;

  /// Score delta when an agreement keyword is detected.
  final int agreementDelta;

  /// Score delta per silence-streak tick (negative).
  final int silenceStreakDelta;

  /// Number of messages without this character responding before silence
  /// streak triggers.
  final int silenceThreshold;

  const MoodConfig({
    required this.sensitivity,
    this.directAddressDelta = 5,
    this.challengeDelta = -5,
    this.agreementDelta = 4,
    this.silenceStreakDelta = -3,
    this.silenceThreshold = 6,
  });

  // -------------------------------------------------------------------------
  // Per-character defaults
  // -------------------------------------------------------------------------

  /// WATSON — The Analyst — stable, low sensitivity.
  static const watson = MoodConfig(sensitivity: 0.5);

  /// DEEP — The Strategist — stable, low sensitivity.
  static const deep = MoodConfig(sensitivity: 0.5);

  /// NOVA — The Visionary — reactive, high sensitivity.
  static const nova = MoodConfig(sensitivity: 1.5);

  /// SAGE — The Challenger — very reactive; enjoys challenges (+8 instead of -5).
  static const sage = MoodConfig(
    sensitivity: 2.0,
    challengeDelta: 8, // SAGE finds challenge stimulating
  );

  /// Returns the default config for [characterName].
  static MoodConfig forCharacter(String characterName) {
    switch (characterName.toUpperCase()) {
      case 'WATSON':
        return watson;
      case 'DEEP':
        return deep;
      case 'NOVA':
        return nova;
      case 'SAGE':
        return sage;
      default:
        return const MoodConfig(sensitivity: 1.0);
    }
  }
}
