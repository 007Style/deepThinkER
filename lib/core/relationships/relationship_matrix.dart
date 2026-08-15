// RelationshipMatrix — holds and manages all 6 character-pair scores.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';

import 'relationship_score.dart';

export 'relationship_score.dart';

// ---------------------------------------------------------------------------
// RelationshipChangeEvent
// ---------------------------------------------------------------------------

/// Emitted by [RelationshipMatrix] when any pair score changes.
class RelationshipChangeEvent {
  final RelationshipScore oldScore;
  final RelationshipScore newScore;
  final DateTime timestamp;

  RelationshipChangeEvent({
    required this.oldScore,
    required this.newScore,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// RelationshipMatrix
// ---------------------------------------------------------------------------

/// Manages all 6 inter-character relationship scores.
///
/// The default characters are WATSON, DEEP, NOVA, SAGE — all 6 pair
/// combinations are pre-initialised to neutral (score 0).
class RelationshipMatrix {
  static const _defaultCharacters = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];

  final Map<String, RelationshipScore> _scores = {};

  final StreamController<RelationshipChangeEvent> _controller =
      StreamController<RelationshipChangeEvent>.broadcast();

  RelationshipMatrix() {
    // Initialise all 6 pairs.
    for (var i = 0; i < _defaultCharacters.length; i++) {
      for (var j = i + 1; j < _defaultCharacters.length; j++) {
        final pair = RelationshipPair(
          _defaultCharacters[i],
          _defaultCharacters[j],
        );
        _scores[pair.key] = RelationshipScore.neutral(pair);
      }
    }
  }

  /// Broadcast stream of [RelationshipChangeEvent]s.
  Stream<RelationshipChangeEvent> get changeStream => _controller.stream;

  /// Returns the [RelationshipScore] for the pair of [a] and [b].
  RelationshipScore disposition(String a, String b) {
    final pair = RelationshipPair(a, b);
    return _scores[pair.key] ?? RelationshipScore.neutral(pair);
  }

  /// Applies [delta] to the score for the pair ([a], [b]).
  void applyDelta(String a, String b, int delta) {
    final pair = RelationshipPair(a, b);
    final current = _scores[pair.key] ?? RelationshipScore.neutral(pair);
    final newScore = (current.score + delta).clamp(-100, 100);
    final updated = current.copyWith(score: newScore);
    _scores[pair.key] = updated;

    if (updated.disposition != current.disposition ||
        updated.score != current.score) {
      _emit(RelationshipChangeEvent(
        oldScore: current,
        newScore: updated,
      ));
    }
  }

  /// Loads scores from a list (used by persistence layer).
  void loadAll(List<RelationshipScore> scores) {
    for (final s in scores) {
      _scores[s.pair.key] = s;
    }
  }

  /// All current scores.
  List<RelationshipScore> get allScores =>
      List.unmodifiable(_scores.values.toList());

  /// Returns a system-prompt descriptor for [character] listing only
  /// non-neutral relationships (score outside [-19, +19]).
  String descriptorFor(String character) {
    final lines = <String>[];
    for (final score in _scores.values) {
      if (score.pair.characterA != character &&
          score.pair.characterB != character) {
        continue;
      }
      if (score.disposition == Disposition.neutral) continue;

      final other = score.pair.characterA == character
          ? score.pair.characterB
          : score.pair.characterA;

      switch (score.disposition) {
        case Disposition.allied:
          lines.add('You are allied with $other.');
        case Disposition.respectful:
          lines.add('You respect $other.');
        case Disposition.sceptical:
          lines.add('You are sceptical of $other.');
        case Disposition.hostile:
          lines.add('You find $other reckless and oppose their views.');
        case Disposition.neutral:
          break; // already filtered above
      }
    }
    return lines.join(' ');
  }

  Future<void> dispose() => _controller.close();

  void _emit(RelationshipChangeEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
