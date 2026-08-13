import 'package:test/test.dart';
import 'package:deep_think_er/core/mood/mood_score.dart';

void main() {
  group('MoodState', () {
    group('fromScore', () {
      test('0 → withdrawn', () =>
          expect(MoodState.fromScore(0), MoodState.withdrawn));
      test('19 → withdrawn', () =>
          expect(MoodState.fromScore(19), MoodState.withdrawn));
      test('20 → neutral', () =>
          expect(MoodState.fromScore(20), MoodState.neutral));
      test('50 → neutral', () =>
          expect(MoodState.fromScore(50), MoodState.neutral));
      test('60 → neutral', () =>
          expect(MoodState.fromScore(60), MoodState.neutral));
      test('61 → engaged', () =>
          expect(MoodState.fromScore(61), MoodState.engaged));
      test('79 → engaged', () =>
          expect(MoodState.fromScore(79), MoodState.engaged));
      test('80 → excited', () =>
          expect(MoodState.fromScore(80), MoodState.excited));
      test('100 → excited', () =>
          expect(MoodState.fromScore(100), MoodState.excited));
    });

    test('neutral descriptor is empty string', () {
      expect(MoodState.neutral.descriptor, isEmpty);
    });

    test('withdrawn descriptor mentions withdrawn', () {
      expect(MoodState.withdrawn.descriptor.toLowerCase(), contains('withdrawn'));
    });

    test('engaged descriptor mentions engaged', () {
      expect(MoodState.engaged.descriptor.toLowerCase(), contains('engaged'));
    });

    test('excited descriptor mentions excited', () {
      expect(MoodState.excited.descriptor.toLowerCase(), contains('excited'));
    });

    test('agitated descriptor mentions agitated', () {
      expect(MoodState.agitated.descriptor.toLowerCase(), contains('agitated'));
    });
  });

  group('MoodScore', () {
    test('defaultFor creates score=50 neutral not agitated', () {
      final ms = MoodScore.defaultFor('WATSON');
      expect(ms.characterName, 'WATSON');
      expect(ms.score, 50);
      expect(ms.moodState, MoodState.neutral);
      expect(ms.isAgitated, isFalse);
    });

    group('copyWith', () {
      test('updates score and re-derives moodState', () {
        final ms = MoodScore.defaultFor('DEEP').copyWith(score: 70);
        expect(ms.score, 70);
        expect(ms.moodState, MoodState.engaged);
      });

      test('agitated override sets moodState to agitated', () {
        final ms = MoodScore.defaultFor('NOVA').copyWith(isAgitated: true);
        expect(ms.moodState, MoodState.agitated);
        expect(ms.isAgitated, isTrue);
      });

      test('clamps score below 0 to 0', () {
        final ms = MoodScore.defaultFor('SAGE').copyWith(score: -5);
        expect(ms.score, 0);
      });

      test('clamps score above 100 to 100', () {
        final ms = MoodScore.defaultFor('SAGE').copyWith(score: 120);
        expect(ms.score, 100);
      });

      test('preserves characterName', () {
        final ms = MoodScore.defaultFor('WATSON').copyWith(score: 80);
        expect(ms.characterName, 'WATSON');
      });

      test('isAgitated false after clearing agitated state', () {
        final agitated = MoodScore.defaultFor('DEEP').copyWith(isAgitated: true);
        final calmed = agitated.copyWith(isAgitated: false, score: 50);
        expect(calmed.isAgitated, isFalse);
        expect(calmed.moodState, MoodState.neutral);
      });
    });
  });
}
