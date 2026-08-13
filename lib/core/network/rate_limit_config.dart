/// Configuration model for the deepThinkER rate limiter.
///
/// This file has zero Flutter imports — pure Dart only.
library rate_limit_config;

import '../trust/trust_score.dart';

// ---------------------------------------------------------------------------
// RateLimitConfig
// ---------------------------------------------------------------------------

/// Immutable configuration for per-character and global search rate limits.
///
/// Default values match the DESIGN.md specification:
/// - low tier: 1 search / minute
/// - mid tier: 3 searches / minute
/// - high tier: 5 searches / minute
/// - global cap: 10 searches / minute across all characters combined
/// - violation penalty: 2.0 trust points (applied by TrustManager)
/// - HTML truncation: 12,000 characters before injection
/// - Proactive injection: enabled
/// - Proactive intervals: low = disabled, mid = 5 min, high = 2 min
class RateLimitConfig {
  /// Per-tier search limits (searches per 60-second window).
  final Map<TrustTier, int> perTierLimits;

  /// Maximum combined searches per minute across all characters.
  final int globalCap;

  /// Trust points deducted from a character on a rate-limit violation.
  final double violationPenalty;

  /// Maximum characters of raw HTML injected per fetch result.
  final int htmlTruncationChars;

  /// Whether proactive context injection is enabled.
  final bool proactiveInjectionEnabled;

  /// Per-tier interval for proactive injection.
  ///
  /// `null` means proactive injection is disabled for that tier.
  final Map<TrustTier, Duration?> proactiveIntervals;

  const RateLimitConfig({
    this.perTierLimits = const {
      TrustTier.low: 1,
      TrustTier.mid: 3,
      TrustTier.high: 5,
    },
    this.globalCap = 10,
    this.violationPenalty = 2.0,
    this.htmlTruncationChars = 12000,
    this.proactiveInjectionEnabled = true,
    this.proactiveIntervals = const {
      TrustTier.low: null,
      TrustTier.mid: Duration(minutes: 5),
      TrustTier.high: Duration(minutes: 2),
    },
  });

  /// Returns the search limit per minute for [tier].
  int limitFor(TrustTier tier) => perTierLimits[tier] ?? 1;

  /// Returns the proactive injection interval for [tier], or null if disabled.
  Duration? proactiveIntervalFor(TrustTier tier) =>
      proactiveIntervals[tier];
}
