import 'package:test/test.dart';
import 'package:deep_think_er/core/trust/trust_score.dart';

void main() {
  group('TrustTier', () {
    group('fromScore', () {
      test('0 → low', () => expect(TrustTier.fromScore(0), TrustTier.low));
      test('33 → low', () => expect(TrustTier.fromScore(33), TrustTier.low));
      test('34 → mid', () => expect(TrustTier.fromScore(34), TrustTier.mid));
      test('66 → mid', () => expect(TrustTier.fromScore(66), TrustTier.mid));
      test('67 → high', () => expect(TrustTier.fromScore(67), TrustTier.high));
      test('100 → high', () => expect(TrustTier.fromScore(100), TrustTier.high));
    });

    group('searchesPerMinute', () {
      test('low = 1', () => expect(TrustTier.low.searchesPerMinute, 1));
      test('mid = 3', () => expect(TrustTier.mid.searchesPerMinute, 3));
      test('high = 5', () => expect(TrustTier.high.searchesPerMinute, 5));
    });

    group('label', () {
      test('low label', () => expect(TrustTier.low.label, 'Low'));
      test('mid label', () => expect(TrustTier.mid.label, 'Mid'));
      test('high label', () => expect(TrustTier.high.label, 'High'));
    });
  });

  group('TrustScore', () {
    test('defaultFor produces score=50, mid tier, networkEnabled=true', () {
      final ts = TrustScore.defaultFor('WATSON');
      expect(ts.characterName, 'WATSON');
      expect(ts.score, 50.0);
      expect(ts.tier, TrustTier.mid);
      expect(ts.networkEnabled, isTrue);
    });

    group('copyWith', () {
      test('updates score and re-derives tier', () {
        final ts = TrustScore.defaultFor('DEEP');
        final updated = ts.copyWith(score: 80.0);
        expect(updated.score, 80.0);
        expect(updated.tier, TrustTier.high);
      });

      test('clamps score below 0 to 0', () {
        final ts = TrustScore.defaultFor('NOVA');
        final updated = ts.copyWith(score: -10.0);
        expect(updated.score, 0.0);
      });

      test('clamps score above 100 to 100', () {
        final ts = TrustScore.defaultFor('SAGE');
        final updated = ts.copyWith(score: 150.0);
        expect(updated.score, 100.0);
      });

      test('toggles networkEnabled', () {
        final ts = TrustScore.defaultFor('WATSON');
        final off = ts.copyWith(networkEnabled: false);
        expect(off.networkEnabled, isFalse);
        expect(off.score, ts.score); // score unchanged
      });

      test('preserves characterName', () {
        final ts = TrustScore.defaultFor('DEEP');
        final updated = ts.copyWith(score: 70.0);
        expect(updated.characterName, 'DEEP');
      });
    });

    group('JSON serialisation', () {
      test('round-trips through toJson/fromJson', () {
        final original = TrustScore.defaultFor('WATSON').copyWith(score: 72.5);
        final json = original.toJson();
        final restored = TrustScore.fromJson(json);
        expect(restored.characterName, original.characterName);
        expect(restored.score, original.score);
        expect(restored.tier, original.tier);
        expect(restored.networkEnabled, original.networkEnabled);
      });

      test('fromJson defaults networkEnabled to true when missing', () {
        final json = {
          'characterName': 'SAGE',
          'score': 50.0,
          'timestamp': DateTime.now().toIso8601String(),
        };
        final ts = TrustScore.fromJson(json);
        expect(ts.networkEnabled, isTrue);
      });

      test('fromJson clamps out-of-range score', () {
        final json = {
          'characterName': 'NOVA',
          'score': 999.0,
          'networkEnabled': true,
          'timestamp': DateTime.now().toIso8601String(),
        };
        final ts = TrustScore.fromJson(json);
        expect(ts.score, 100.0);
      });
    });

    test('toString contains character name and tier label', () {
      final ts = TrustScore.defaultFor('WATSON');
      expect(ts.toString(), contains('WATSON'));
      expect(ts.toString(), contains('Mid'));
    });
  });
}
