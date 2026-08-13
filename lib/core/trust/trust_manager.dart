/// TrustManager — tracks per-character trust scores, drives decay/gain,
/// handles network toggle events, and persists state to disk.
///
/// This file has zero Flutter imports — pure Dart only.
library trust_manager;

import 'dart:async';

import 'trust_event.dart';
import 'trust_persistence.dart';
import 'trust_score.dart';

export 'trust_event.dart';
export 'trust_score.dart';

// ---------------------------------------------------------------------------
// TrustManager
// ---------------------------------------------------------------------------

/// Manages the trust lifecycle for all four AI characters.
///
/// ### Trust rules
/// - Starting score: 50.0 (mid tier)
/// - **Decay:** −0.5 per minute while network is ON
/// - **Gain:** +1.0 per minute while network is ON **and** no rate-limit
///   violation occurred in the preceding minute
/// - Net change when well-behaved: +0.5 / minute
/// - **Toggle OFF:** −15 immediate penalty
/// - **Toggle ON:**  +5 immediate bonus
/// - **Rate-limit violation:** −2 per event (called by [RateLimiter])
/// - All scores clamped to [0.0, 100.0]
///
/// ### Usage
/// ```dart
/// final manager = TrustManager(characterNames: Participant.defaultNames);
/// await manager.init();
/// manager.trustStream.listen((event) { /* update UI */ });
/// manager.setNetworkEnabled('WATSON', false);
/// ```
class TrustManager {
  /// Names of the characters being managed.
  final List<String> characterNames;

  /// Interval between decay/gain ticks. Defaults to 60 seconds.
  /// Override in tests for faster cycles.
  final Duration tickInterval;

  // Current scores, keyed by character name.
  final Map<String, TrustScore> _scores = {};

  // Tracks whether a rate-limit violation fired in the current tick window,
  // per character — suppresses the gain portion of that tick.
  final Map<String, bool> _violatedThisTick = {};

  final StreamController<TrustEvent> _streamController =
      StreamController<TrustEvent>.broadcast();

  Timer? _ticker;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  TrustManager({
    required this.characterNames,
    this.tickInterval = const Duration(minutes: 1),
  });

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Initialises the manager: loads persisted scores (falling back to defaults)
  /// and starts the periodic decay/gain ticker.
  Future<void> init() async {
    final persisted = await TrustPersistence.load();

    for (final name in characterNames) {
      final loaded = persisted[name];
      if (loaded != null) {
        _scores[name] = loaded;
        _emit(TrustEvent(
          characterName: name,
          oldScore: loaded.score,
          newScore: loaded.score,
          oldTier: loaded.tier,
          newTier: loaded.tier,
          reason: TrustEventReason.loaded,
          networkEnabled: loaded.networkEnabled,
        ));
      } else {
        _scores[name] = TrustScore.defaultFor(name);
      }
      _violatedThisTick[name] = false;
    }

    _startTicker();
  }

  /// Stops the ticker and closes the stream. Call on app dispose.
  Future<void> dispose() async {
    _ticker?.cancel();
    await _streamController.close();
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Broadcast stream of [TrustEvent]s. UI and [RateLimiter] subscribe here.
  Stream<TrustEvent> get trustStream => _streamController.stream;

  /// Returns the current [TrustScore] for [characterName].
  ///
  /// Throws [ArgumentError] if the character is unknown.
  TrustScore scoreFor(String characterName) {
    final score = _scores[characterName];
    if (score == null) {
      throw ArgumentError.value(
          characterName, 'characterName', 'Unknown character');
    }
    return score;
  }

  /// Returns all current scores as an unmodifiable map.
  Map<String, TrustScore> get allScores => Map.unmodifiable(_scores);

  /// Enables or disables network access for [characterName].
  ///
  /// - Toggle OFF: −15 immediate, emits [TrustEventReason.toggleOff]
  /// - Toggle ON:  +5 immediate, emits [TrustEventReason.toggleOn]
  Future<void> setNetworkEnabled(String characterName, bool enabled) async {
    final current = _requireScore(characterName);
    if (current.networkEnabled == enabled) return; // no-op

    final delta = enabled ? 5.0 : -15.0;
    final reason =
        enabled ? TrustEventReason.toggleOn : TrustEventReason.toggleOff;

    await _applyDelta(characterName, delta, reason,
        networkEnabled: enabled);
  }

  /// Records a rate-limit violation for [characterName].
  ///
  /// Applies −2 trust points and suppresses the gain portion of the
  /// current tick window for this character.
  ///
  /// Called by [RateLimiter] when a request is denied.
  Future<void> recordRateLimitViolation(String characterName) async {
    _violatedThisTick[characterName] = true;
    await _applyDelta(
        characterName, -2.0, TrustEventReason.rateLimitViolation);
  }

  /// Resets [characterName] to the default score (50, mid, network ON).
  ///
  /// Intended for debug/test use only.
  Future<void> reset(String characterName) async {
    final current = _requireScore(characterName);
    const defaultScore = 50.0;
    final newScore = TrustScore.defaultFor(characterName);
    _scores[characterName] = newScore;
    _violatedThisTick[characterName] = false;

    _emit(TrustEvent(
      characterName: characterName,
      oldScore: current.score,
      newScore: defaultScore,
      oldTier: current.tier,
      newTier: TrustTier.fromScore(defaultScore),
      reason: TrustEventReason.reset,
      networkEnabled: true,
    ));

    await _persist();
  }

  // -------------------------------------------------------------------------
  // Private: tick logic
  // -------------------------------------------------------------------------

  void _startTicker() {
    _ticker = Timer.periodic(tickInterval, (_) => _onTick());
  }

  Future<void> _onTick() async {
    for (final name in characterNames) {
      final score = _scores[name]!;

      // Only apply decay/gain when network is enabled.
      if (!score.networkEnabled) {
        _violatedThisTick[name] = false;
        continue;
      }

      // Decay always applies.
      const decayAmount = 0.5;
      await _applyDelta(name, -decayAmount, TrustEventReason.decay);

      // Gain only applies if no violation occurred this tick.
      if (!(_violatedThisTick[name] ?? false)) {
        const gainAmount = 1.0;
        await _applyDelta(name, gainAmount, TrustEventReason.gain);
      }

      // Reset violation flag for next tick.
      _violatedThisTick[name] = false;
    }
  }

  // -------------------------------------------------------------------------
  // Private: helpers
  // -------------------------------------------------------------------------

  /// Applies [delta] to [characterName]'s score, emits an event, and persists.
  Future<void> _applyDelta(
    String characterName,
    double delta,
    TrustEventReason reason, {
    bool? networkEnabled,
  }) async {
    final current = _requireScore(characterName);
    final rawNew = current.score + delta;
    final newScore = rawNew.clamp(0.0, 100.0);
    final newNetworkEnabled = networkEnabled ?? current.networkEnabled;

    final updated = current.copyWith(
      score: newScore,
      networkEnabled: newNetworkEnabled,
    );
    _scores[characterName] = updated;

    _emit(TrustEvent(
      characterName: characterName,
      oldScore: current.score,
      newScore: newScore,
      oldTier: current.tier,
      newTier: updated.tier,
      reason: reason,
      networkEnabled: newNetworkEnabled,
    ));

    await _persist();
  }

  void _emit(TrustEvent event) {
    if (!_streamController.isClosed) {
      _streamController.add(event);
    }
  }

  Future<void> _persist() => TrustPersistence.save(_scores);

  TrustScore _requireScore(String characterName) {
    final score = _scores[characterName];
    if (score == null) {
      throw ArgumentError.value(
          characterName, 'characterName', 'Unknown character');
    }
    return score;
  }
}
