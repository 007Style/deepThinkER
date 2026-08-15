import 'package:test/test.dart';
import 'package:deep_think_er/core/relationships/relationship_matrix.dart';

void main() {
  group('RelationshipPair', () {
    test('sorts alphabetically so order does not matter', () {
      final a = RelationshipPair('NOVA', 'DEEP');
      final b = RelationshipPair('DEEP', 'NOVA');
      expect(a.characterA, b.characterA);
      expect(a.characterB, b.characterB);
      expect(a.key, b.key);
    });

    test('key is A|B format', () {
      final pair = RelationshipPair('WATSON', 'DEEP');
      // alphabetically: DEEP < WATSON
      expect(pair.key, 'DEEP|WATSON');
    });

    test('equality holds for equivalent pairs', () {
      expect(
        RelationshipPair('NOVA', 'SAGE'),
        equals(RelationshipPair('SAGE', 'NOVA')),
      );
    });
  });

  group('Disposition', () {
    test('-100 → hostile', () =>
        expect(Disposition.fromScore(-100), Disposition.hostile));
    test('-60 → hostile', () =>
        expect(Disposition.fromScore(-60), Disposition.hostile));
    test('-59 → sceptical', () =>
        expect(Disposition.fromScore(-59), Disposition.sceptical));
    test('-20 → sceptical', () =>
        expect(Disposition.fromScore(-20), Disposition.sceptical));
    test('-19 → neutral', () =>
        expect(Disposition.fromScore(-19), Disposition.neutral));
    test('0 → neutral', () =>
        expect(Disposition.fromScore(0), Disposition.neutral));
    test('19 → neutral', () =>
        expect(Disposition.fromScore(19), Disposition.neutral));
    test('20 → respectful', () =>
        expect(Disposition.fromScore(20), Disposition.respectful));
    test('59 → respectful', () =>
        expect(Disposition.fromScore(59), Disposition.respectful));
    test('60 → allied', () =>
        expect(Disposition.fromScore(60), Disposition.allied));
    test('100 → allied', () =>
        expect(Disposition.fromScore(100), Disposition.allied));
  });

  group('RelationshipScore', () {
    test('clamps score above 100', () {
      final pair = RelationshipPair('WATSON', 'DEEP');
      final rs = RelationshipScore(pair: pair, score: 150);
      expect(rs.score, 100);
    });

    test('clamps score below -100', () {
      final pair = RelationshipPair('WATSON', 'DEEP');
      final rs = RelationshipScore(pair: pair, score: -200);
      expect(rs.score, -100);
    });

    test('derives disposition from score', () {
      final pair = RelationshipPair('NOVA', 'SAGE');
      expect(RelationshipScore(pair: pair, score: 75).disposition,
          Disposition.allied);
    });

    test('neutral factory produces score 0', () {
      final pair = RelationshipPair('WATSON', 'NOVA');
      final rs = RelationshipScore.neutral(pair);
      expect(rs.score, 0);
      expect(rs.disposition, Disposition.neutral);
    });

    group('JSON round-trip', () {
      test('serialises and deserialises correctly', () {
        final pair = RelationshipPair('DEEP', 'SAGE');
        final original = RelationshipScore(pair: pair, score: 45);
        final json = original.toJson();
        final restored = RelationshipScore.fromJson(json);
        expect(restored.score, 45);
        expect(restored.pair.key, pair.key);
        expect(restored.disposition, Disposition.respectful);
      });
    });
  });

  group('RelationshipMatrix', () {
    late RelationshipMatrix matrix;

    setUp(() => matrix = RelationshipMatrix());
    tearDown(() => matrix.dispose());

    test('all 6 pairs initialised to neutral', () {
      expect(matrix.allScores, hasLength(6));
      for (final s in matrix.allScores) {
        expect(s.score, 0);
        expect(s.disposition, Disposition.neutral);
      }
    });

    test('disposition returns neutral for unknown pair', () {
      final d = matrix.disposition('ALICE', 'BOB');
      expect(d.disposition, Disposition.neutral);
    });

    test('applyDelta changes score', () {
      matrix.applyDelta('WATSON', 'DEEP', 25);
      expect(matrix.disposition('WATSON', 'DEEP').score, 25);
      expect(matrix.disposition('WATSON', 'DEEP').disposition,
          Disposition.respectful);
    });

    test('applyDelta is symmetric (pair order irrelevant)', () {
      matrix.applyDelta('SAGE', 'NOVA', -30);
      expect(matrix.disposition('NOVA', 'SAGE').score, -30);
    });

    test('applyDelta clamps at +100', () {
      matrix.applyDelta('WATSON', 'DEEP', 200);
      expect(matrix.disposition('WATSON', 'DEEP').score, 100);
    });

    test('applyDelta clamps at -100', () {
      matrix.applyDelta('WATSON', 'DEEP', -200);
      expect(matrix.disposition('WATSON', 'DEEP').score, -100);
    });

    test('changeStream emits on delta', () async {
      final events = <RelationshipChangeEvent>[];
      matrix.changeStream.listen(events.add);
      matrix.applyDelta('WATSON', 'DEEP', 25);
      await Future.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events[0].newScore.score, 25);
    });

    test('descriptorFor returns empty string for all-neutral matrix', () {
      expect(matrix.descriptorFor('WATSON'), isEmpty);
    });

    test('descriptorFor includes allied relationship', () {
      matrix.applyDelta('WATSON', 'DEEP', 70);
      final desc = matrix.descriptorFor('WATSON');
      expect(desc, contains('DEEP'));
      expect(desc.toLowerCase(), contains('allied'));
    });

    test('descriptorFor does not mention neutral pairs', () {
      matrix.applyDelta('WATSON', 'DEEP', 70); // allied
      // NOVA stays neutral
      final desc = matrix.descriptorFor('WATSON');
      expect(desc, isNot(contains('NOVA')));
    });

    test('loadAll restores scores', () {
      final pair = RelationshipPair('WATSON', 'DEEP');
      final score = RelationshipScore(pair: pair, score: 55);
      matrix.loadAll([score]);
      expect(matrix.disposition('WATSON', 'DEEP').score, 55);
    });
  });
}
