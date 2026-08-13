/// RelationshipScore — value object for a character pair relationship.
///
/// This file has zero Flutter imports — pure Dart only.
library relationship_score;

// ---------------------------------------------------------------------------
// Disposition
// ---------------------------------------------------------------------------

/// The disposition label derived from a relationship score.
enum Disposition {
  /// Score -100 to -60.
  hostile,

  /// Score -59 to -20.
  sceptical,

  /// Score -19 to +19.
  neutral,

  /// Score +20 to +59.
  respectful,

  /// Score +60 to +100.
  allied;

  /// Derives the disposition from [score].
  static Disposition fromScore(int score) {
    if (score <= -60) return Disposition.hostile;
    if (score <= -20) return Disposition.sceptical;
    if (score <= 19) return Disposition.neutral;
    if (score <= 59) return Disposition.respectful;
    return Disposition.allied;
  }
}

// ---------------------------------------------------------------------------
// RelationshipPair
// ---------------------------------------------------------------------------

/// A canonical, alphabetically-sorted pair of two character names.
///
/// `RelationshipPair('NOVA', 'DEEP')` == `RelationshipPair('DEEP', 'NOVA')`.
class RelationshipPair {
  final String characterA;
  final String characterB;

  RelationshipPair(String a, String b)
      : characterA = a.compareTo(b) <= 0 ? a : b,
        characterB = a.compareTo(b) <= 0 ? b : a;

  String get key => '$characterA|$characterB';

  @override
  bool operator ==(Object other) =>
      other is RelationshipPair &&
      characterA == other.characterA &&
      characterB == other.characterB;

  @override
  int get hashCode => Object.hash(characterA, characterB);

  @override
  String toString() => 'RelationshipPair($characterA ↔ $characterB)';
}

// ---------------------------------------------------------------------------
// RelationshipScore
// ---------------------------------------------------------------------------

/// Immutable snapshot of a character pair's relationship.
class RelationshipScore {
  final RelationshipPair pair;

  /// Score clamped to [-100, 100]. 0 = neutral.
  final int score;

  /// Derived disposition from [score].
  final Disposition disposition;

  const RelationshipScore._({
    required this.pair,
    required this.score,
    required this.disposition,
  });

  factory RelationshipScore({
    required RelationshipPair pair,
    required int score,
  }) {
    final clamped = score.clamp(-100, 100);
    return RelationshipScore._(
      pair: pair,
      score: clamped,
      disposition: Disposition.fromScore(clamped),
    );
  }

  /// Returns a default neutral score for [pair].
  factory RelationshipScore.neutral(RelationshipPair pair) =>
      RelationshipScore(pair: pair, score: 0);

  /// Returns a copy with an updated score.
  RelationshipScore copyWith({required int score}) =>
      RelationshipScore(pair: pair, score: score);

  /// Serialises to JSON.
  Map<String, dynamic> toJson() => {
        'characterA': pair.characterA,
        'characterB': pair.characterB,
        'score': score,
      };

  factory RelationshipScore.fromJson(Map<String, dynamic> json) {
    return RelationshipScore(
      pair: RelationshipPair(
        json['characterA'] as String,
        json['characterB'] as String,
      ),
      score: (json['score'] as num).toInt(),
    );
  }
}
