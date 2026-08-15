// Event emitted by [TrustManager] whenever a character's trust state changes.
//
// This file has zero Flutter imports — pure Dart only.

import 'trust_score.dart';

// ---------------------------------------------------------------------------
// TrustEventReason
// ---------------------------------------------------------------------------

/// Why a trust score changed.
enum TrustEventReason {
  /// Periodic decay tick (−0.5 per minute while network is ON).
  decay,

  /// Periodic gain tick (+1.0 per minute while network is ON, no violations).
  gain,

  /// User toggled network access OFF for this character (−15 immediate).
  toggleOff,

  /// User toggled network access ON for this character (+5 immediate).
  toggleOn,

  /// A rate-limit violation was recorded for this character (−2 per violation).
  rateLimitViolation,

  /// Score loaded from persisted storage at startup.
  loaded,

  /// Score was manually reset to default (debug / test use).
  reset,
}

// ---------------------------------------------------------------------------
// TrustEvent
// ---------------------------------------------------------------------------

/// Fired by [TrustManager] on every trust-state change.
///
/// Consumers (UI, rate limiter) listen to [TrustManager.trustStream] and
/// receive these events to update badges, adjust rate-limit buckets, and
/// decide when to notify the LLM about access changes.
class TrustEvent {
  /// Character whose trust changed.
  final String characterName;

  /// Score before this event.
  final double oldScore;

  /// Score after this event (already clamped to [0, 100]).
  final double newScore;

  /// Tier before this event.
  final TrustTier oldTier;

  /// Tier after this event.
  final TrustTier newTier;

  /// Why the change happened.
  final TrustEventReason reason;

  /// Whether network access is enabled after this event.
  final bool networkEnabled;

  /// When the event was created.
  final DateTime timestamp;

  TrustEvent({
    required this.characterName,
    required this.oldScore,
    required this.newScore,
    required this.oldTier,
    required this.newTier,
    required this.reason,
    required this.networkEnabled,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// True when this event represents a tier boundary crossing.
  bool get tierChanged => oldTier != newTier;

  /// True when network access state flipped (ON→OFF or OFF→ON).
  bool get networkToggled =>
      reason == TrustEventReason.toggleOn ||
      reason == TrustEventReason.toggleOff;

  /// The score delta (positive = gain, negative = loss).
  double get delta => newScore - oldScore;

  @override
  String toString() =>
      'TrustEvent($characterName: ${oldScore.toStringAsFixed(1)}'
      ' → ${newScore.toStringAsFixed(1)} [${reason.name}]'
      '${tierChanged ? " TIER: ${oldTier.label}→${newTier.label}" : ""})';
}
