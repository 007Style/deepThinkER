// Rate limiter for deepThinkER network access.
//
// Enforces per-character sliding-window limits (derived from trust tier) and
// a global cap across all characters combined.  Calls back to [TrustManager]
// on denial so a trust penalty is applied.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';

import '../trust/trust_manager.dart';
import 'rate_limit_config.dart';

export 'rate_limit_config.dart';

// ---------------------------------------------------------------------------
// RateRequest
// ---------------------------------------------------------------------------

/// Result of a [RateLimiter.request] call.
class RateRequest {
  /// Whether the request is allowed.
  final bool allowed;

  /// Human-readable explanation when [allowed] is `false`.
  final String reason;

  const RateRequest({required this.allowed, required this.reason});

  @override
  String toString() => 'RateRequest(allowed=$allowed, reason=$reason)';
}

// ---------------------------------------------------------------------------
// _SlidingWindow
// ---------------------------------------------------------------------------

/// Internal sliding-window counter for a single character (or global).
///
/// Keeps a list of timestamps.  On each [record] or [count] call it first
/// evicts timestamps older than 60 seconds, so the count always represents
/// requests in the last rolling minute.
class _SlidingWindow {
  final List<DateTime> _timestamps = [];

  static const _windowDuration = Duration(seconds: 60);

  /// Current count of requests within the rolling window.
  int get count {
    _evict();
    return _timestamps.length;
  }

  /// Records a new request at [now] (or [DateTime.now] if omitted).
  void record([DateTime? now]) {
    _evict(now);
    _timestamps.add(now ?? DateTime.now());
  }

  void _evict([DateTime? now]) {
    final cutoff = (now ?? DateTime.now()).subtract(_windowDuration);
    _timestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

// ---------------------------------------------------------------------------
// RateLimiter
// ---------------------------------------------------------------------------

/// Enforces per-character and global network rate limits.
///
/// Per-character limits are derived from the character's current [TrustTier].
/// The limiter subscribes to [TrustManager.trustStream] so it keeps an
/// up-to-date tier cache without polling.
///
/// ### Usage
/// ```dart
/// final limiter = RateLimiter(config: RateLimitConfig(), trustManager: mgr);
/// limiter.init();
/// final r = limiter.request('WATSON', TrustTier.mid);
/// if (!r.allowed) print(r.reason);
/// ```
class RateLimiter {
  final RateLimitConfig config;
  final TrustManager trustManager;

  // Per-character sliding windows, keyed by character name.
  final Map<String, _SlidingWindow> _characterWindows = {};

  // Global sliding window across all characters.
  final _SlidingWindow _globalWindow = _SlidingWindow();

  // Cached tier per character — updated via trustStream subscription.
  final Map<String, TrustTier> _tierCache = {};

  StreamSubscription<TrustEvent>? _trustSub;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  RateLimiter({required this.config, required this.trustManager});

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Subscribes to [TrustManager.trustStream] and seeds the tier cache
  /// from current scores.
  ///
  /// Call once after [TrustManager.init].
  void init() {
    // Seed tier cache from existing scores.
    for (final entry in trustManager.allScores.entries) {
      _tierCache[entry.key] = entry.value.tier;
      _characterWindows.putIfAbsent(entry.key, () => _SlidingWindow());
    }

    // Keep tier cache up to date.
    _trustSub = trustManager.trustStream.listen((event) {
      _tierCache[event.characterName] = event.newTier;
    });
  }

  /// Cancels the trust stream subscription.
  void dispose() {
    _trustSub?.cancel();
    _trustSub = null;
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Requests permission for [characterName] to make a network call.
  ///
  /// Uses the [tier] parameter (or falls back to the cached tier if the
  /// caller passes the cached value) to determine the per-character limit.
  ///
  /// Returns [RateRequest.allowed] == `false` if:
  /// - the per-character limit is exceeded, or
  /// - the global cap is exceeded.
  ///
  /// On denial, [TrustManager.recordRateLimitViolation] is called.
  RateRequest request(String characterName, TrustTier tier) {
    final now = DateTime.now();

    // Update tier cache.
    _tierCache[characterName] = tier;

    // Ensure a window exists for this character.
    final window =
        _characterWindows.putIfAbsent(characterName, () => _SlidingWindow());

    // Check global cap first.
    if (_globalWindow.count >= config.globalCap) {
      trustManager.recordRateLimitViolation(characterName);
      return RateRequest(
        allowed: false,
        reason: 'Global rate limit reached '
            '(${config.globalCap} searches/min across all characters).',
      );
    }

    // Check per-character limit.
    final perCharLimit = config.limitFor(tier);
    if (window.count >= perCharLimit) {
      trustManager.recordRateLimitViolation(characterName);
      return RateRequest(
        allowed: false,
        reason: 'Rate limit reached for $characterName '
            '($perCharLimit searches/min at ${tier.label} trust tier).',
      );
    }

    // Allowed — record the request.
    window.record(now);
    _globalWindow.record(now);

    return const RateRequest(allowed: true, reason: '');
  }

  /// Returns the current tier for [characterName] from the cache,
  /// or [TrustTier.low] if not yet cached.
  TrustTier currentTier(String characterName) =>
      _tierCache[characterName] ?? TrustTier.low;
}
