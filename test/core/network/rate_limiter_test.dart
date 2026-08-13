import 'package:test/test.dart';
import 'package:deep_think_er/core/network/rate_limiter.dart';
import 'package:deep_think_er/core/trust/trust_score.dart';
import 'package:deep_think_er/core/trust/trust_manager.dart';

// All tests use only characters registered in the TrustManager.
const _chars = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];

TrustManager _mgr() => TrustManager(characterNames: _chars);

// Config with 0 violation penalty so recordRateLimitViolation doesn't throw.
RateLimitConfig _cfg({int globalCap = 10}) => RateLimitConfig(
      globalCap: globalCap,
      violationPenalty: 0,
    );

void main() {
  group('RateLimitConfig', () {
    test('limitFor returns correct limits per tier', () {
      const cfg = RateLimitConfig();
      expect(cfg.limitFor(TrustTier.low), 1);
      expect(cfg.limitFor(TrustTier.mid), 3);
      expect(cfg.limitFor(TrustTier.high), 5);
    });

    test('globalCap default is 10', () {
      expect(const RateLimitConfig().globalCap, 10);
    });

    test('proactiveIntervalFor low = null', () {
      expect(const RateLimitConfig().proactiveIntervalFor(TrustTier.low), isNull);
    });

    test('proactiveIntervalFor mid = 5 min', () {
      expect(const RateLimitConfig().proactiveIntervalFor(TrustTier.mid),
          const Duration(minutes: 5));
    });
  });

  group('RateLimiter', () {
    late TrustManager mgr;
    late RateLimiter limiter;

    setUp(() async {
      mgr = _mgr();
      await mgr.init();  // seeds default scores so violation recording works
      limiter = RateLimiter(config: _cfg(), trustManager: mgr);
      limiter.init();
    });

    tearDown(() => limiter.dispose());

    test('first request on fresh window is allowed', () {
      final r = limiter.request('WATSON', TrustTier.high);
      expect(r.allowed, isTrue);
    });

    test('low-tier character limited after 1 request per minute', () {
      limiter.request('WATSON', TrustTier.low);
      final second = limiter.request('WATSON', TrustTier.low);
      expect(second.allowed, isFalse);
      expect(second.reason, contains('Rate limit reached'));
    });

    test('mid-tier allows 3 requests then blocks', () {
      for (var i = 0; i < 3; i++) {
        expect(limiter.request('DEEP', TrustTier.mid).allowed, isTrue);
      }
      expect(limiter.request('DEEP', TrustTier.mid).allowed, isFalse);
    });

    test('high-tier allows 5 requests then blocks', () {
      for (var i = 0; i < 5; i++) {
        expect(limiter.request('NOVA', TrustTier.high).allowed, isTrue);
      }
      expect(limiter.request('NOVA', TrustTier.high).allowed, isFalse);
    });

    test('denial reason mentions character name', () {
      limiter.request('WATSON', TrustTier.low);
      final r = limiter.request('WATSON', TrustTier.low);
      expect(r.reason, contains('WATSON'));
    });

    test('global cap enforced across characters', () {
      // Cap of 3; per-char limit high so global triggers first.
      final l = RateLimiter(
        config: RateLimitConfig(
          globalCap: 3,
          violationPenalty: 0,
          perTierLimits: {
            TrustTier.low: 10,
            TrustTier.mid: 10,
            TrustTier.high: 10,
          },
        ),
        trustManager: mgr,
      )..init();

      expect(l.request('WATSON', TrustTier.high).allowed, isTrue);
      expect(l.request('DEEP', TrustTier.high).allowed, isTrue);
      expect(l.request('NOVA', TrustTier.high).allowed, isTrue);
      // 4th request hits global cap
      final r = l.request('SAGE', TrustTier.high);
      expect(r.allowed, isFalse);
      expect(r.reason, contains('Global'));
      l.dispose();
    });

    test('currentTier returns low for unknown character', () {
      expect(limiter.currentTier('UNKNOWN'), TrustTier.low);
    });

    test('currentTier updates after request', () {
      limiter.request('WATSON', TrustTier.high);
      expect(limiter.currentTier('WATSON'), TrustTier.high);
    });
  });
}
