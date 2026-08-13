/// Immutable value object representing a single character's trust state.
///
/// This file has zero Flutter imports — pure Dart only.
library trust_score;

// ---------------------------------------------------------------------------
// TrustTier
// ---------------------------------------------------------------------------

/// The three trust tiers that gate network rate limits.
///
/// | Tier | Score range | Searches / min |
/// |------|-------------|----------------|
/// | low  | 0 – 33      | 1              |
/// | mid  | 34 – 66     | 3              |
/// | high | 67 – 100    | 5              |
enum TrustTier {
  low,
  mid,
  high;

  /// Derives the tier from a raw [score] value.
  static TrustTier fromScore(double score) {
    if (score <= 33.0) return TrustTier.low;
    if (score <= 66.0) return TrustTier.mid;
    return TrustTier.high;
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case TrustTier.low:
        return 'Low';
      case TrustTier.mid:
        return 'Mid';
      case TrustTier.high:
        return 'High';
    }
  }

  /// Searches allowed per minute for this tier.
  int get searchesPerMinute {
    switch (this) {
      case TrustTier.low:
        return 1;
      case TrustTier.mid:
        return 3;
      case TrustTier.high:
        return 5;
    }
  }
}

// ---------------------------------------------------------------------------
// TrustScore
// ---------------------------------------------------------------------------

/// Immutable snapshot of a character's trust state at a point in time.
class TrustScore {
  /// Name of the character this score belongs to (e.g. "WATSON").
  final String characterName;

  /// Current trust score, clamped to [0.0, 100.0].
  final double score;

  /// Derived tier from [score].
  final TrustTier tier;

  /// Whether this character's network access is currently enabled.
  final bool networkEnabled;

  /// When this snapshot was created.
  final DateTime timestamp;

  const TrustScore({
    required this.characterName,
    required this.score,
    required this.tier,
    required this.networkEnabled,
    required this.timestamp,
  });

  /// Creates a default starting score (50 / mid / network ON).
  factory TrustScore.defaultFor(String characterName) {
    const defaultScore = 50.0;
    return TrustScore(
      characterName: characterName,
      score: defaultScore,
      tier: TrustTier.fromScore(defaultScore),
      networkEnabled: true,
      timestamp: DateTime.now(),
    );
  }

  /// Returns a copy with the given fields replaced.
  TrustScore copyWith({
    double? score,
    bool? networkEnabled,
    DateTime? timestamp,
  }) {
    final newScore = (score ?? this.score).clamp(0.0, 100.0);
    return TrustScore(
      characterName: characterName,
      score: newScore,
      tier: TrustTier.fromScore(newScore),
      networkEnabled: networkEnabled ?? this.networkEnabled,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'characterName': characterName,
        'score': score,
        'networkEnabled': networkEnabled,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Deserialises from a JSON-compatible map.
  factory TrustScore.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num).toDouble().clamp(0.0, 100.0);
    return TrustScore(
      characterName: json['characterName'] as String,
      score: score,
      tier: TrustTier.fromScore(score),
      networkEnabled: json['networkEnabled'] as bool? ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'TrustScore($characterName: ${score.toStringAsFixed(1)} [${tier.label}] '
      'network=${networkEnabled ? "ON" : "OFF"})';
}
