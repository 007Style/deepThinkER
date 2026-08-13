/// MoodEngine — analyses conversation messages and tracks per-character mood.
///
/// This file has zero Flutter imports — pure Dart only.
library mood_engine;

import 'dart:async';

import '../conversation/message.dart';
import 'mood_config.dart';
import 'mood_score.dart';

export 'mood_score.dart';
export 'mood_config.dart';

// ---------------------------------------------------------------------------
// MoodEngine
// ---------------------------------------------------------------------------

/// Session-scoped engine that shifts each character's mood score as the
/// conversation evolves.
///
/// Call [onMessage] each time a new [Message] is added to the conversation log.
/// Subscribe to [moodStream] to receive [MoodChangeEvent]s.
///
/// Mood resets to neutral (score=50) on construction — not persisted.
class MoodEngine {
  static const _challengeKeywords = [
    'wrong',
    'disagree',
    'incorrect',
    'no,',
    'actually',
    'but',
    'however',
  ];

  static const _agreementKeywords = [
    'agree',
    'exactly',
    'right',
    'good point',
    'yes',
    'correct',
  ];

  final List<String> characterNames;

  /// Current scores keyed by character name.
  final Map<String, MoodScore> _scores = {};

  /// Messages-since-last-response counter per character (silence tracking).
  final Map<String, int> _silenceCounter = {};

  final StreamController<MoodChangeEvent> _controller =
      StreamController<MoodChangeEvent>.broadcast();

  MoodEngine({required this.characterNames}) {
    for (final name in characterNames) {
      _scores[name] = MoodScore.defaultFor(name);
      _silenceCounter[name] = 0;
    }
  }

  /// Broadcast stream of [MoodChangeEvent]s.
  Stream<MoodChangeEvent> get moodStream => _controller.stream;

  /// Returns the current [MoodScore] for [characterName].
  MoodScore scoreFor(String characterName) =>
      _scores[characterName] ?? MoodScore.defaultFor(characterName);

  /// All current scores as an unmodifiable map.
  Map<String, MoodScore> get allScores => Map.unmodifiable(_scores);

  /// Process a new [Message] and update mood scores accordingly.
  void onMessage(Message message) {
    if (message.isEphemeral) return; // ignore tool results

    final content = message.content.toLowerCase();
    final speaker = message.participantName.toUpperCase();

    for (final name in characterNames) {
      final config = MoodConfig.forCharacter(name);
      final current = _scores[name]!;
      int delta = 0;
      bool triggerAgitated = false;

      if (speaker == name) {
        // This character just spoke — reset their silence counter.
        _silenceCounter[name] = 0;
      } else {
        // Increment silence counter for characters that didn't speak.
        final newCount = (_silenceCounter[name] ?? 0) + 1;
        _silenceCounter[name] = newCount;

        // Silence streak penalty.
        if (newCount >= config.silenceThreshold) {
          delta +=
              (config.silenceStreakDelta * config.sensitivity).round();
          _silenceCounter[name] = 0; // reset after applying
        }

        // Check if this message directly addresses this character.
        final nameLower = name.toLowerCase();
        if (content.contains(nameLower)) {
          delta +=
              (config.directAddressDelta * config.sensitivity).round();
        }

        // Challenge signal.
        if (_containsAny(content, _challengeKeywords)) {
          final challengeEffect = config.challengeDelta;
          delta += (challengeEffect * config.sensitivity).round();
          if (challengeEffect < 0) {
            // Negative challenge delta (non-SAGE) can trigger agitation.
            triggerAgitated = true;
          }
        }

        // Agreement signal.
        if (_containsAny(content, _agreementKeywords)) {
          delta +=
              (config.agreementDelta * config.sensitivity).round();
        }
      }

      if (delta == 0 && !triggerAgitated) continue;

      final newScore = (current.score + delta).clamp(0, 100);
      final newAgitated = triggerAgitated && delta < 0;
      final updated = current.copyWith(
        score: newScore,
        isAgitated: newAgitated,
      );
      _scores[name] = updated;

      if (updated.moodState != current.moodState) {
        _emit(MoodChangeEvent(
          characterName: name,
          oldState: current.moodState,
          newState: updated.moodState,
          oldScore: current.score,
          newScore: newScore,
        ));
      }
    }
  }

  /// Closes the stream controller.
  Future<void> dispose() => _controller.close();

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _emit(MoodChangeEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}
