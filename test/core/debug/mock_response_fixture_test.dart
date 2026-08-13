import 'package:test/test.dart';
import 'package:deep_think_er/core/debug/mock_response_fixture.dart';

void main() {
  group('MockResponseFixture', () {
    group('construction', () {
      test('stores all fields', () {
        const f = MockResponseFixture(
          characterName: 'WATSON',
          responseText: 'Hello world',
          delayMs: 75,
          toolCallsToEmit: ['[SEARCH: test]'],
        );
        expect(f.characterName, 'WATSON');
        expect(f.responseText, 'Hello world');
        expect(f.delayMs, 75);
        expect(f.toolCallsToEmit, ['[SEARCH: test]']);
      });

      test('defaults delayMs to 50', () {
        const f = MockResponseFixture(
          characterName: 'DEEP',
          responseText: 'Hi',
        );
        expect(f.delayMs, 50);
      });

      test('defaults toolCallsToEmit to empty', () {
        const f = MockResponseFixture(
          characterName: 'NOVA',
          responseText: 'Hi',
        );
        expect(f.toolCallsToEmit, isEmpty);
      });
    });

    group('JSON round-trip', () {
      test('toJson/fromJson preserves all fields', () {
        const original = MockResponseFixture(
          characterName: 'SAGE',
          responseText: 'Interesting perspective.',
          delayMs: 100,
          toolCallsToEmit: ['[SEARCH: dart]', '[CALC: 2+2]'],
        );
        final json = original.toJson();
        final restored = MockResponseFixture.fromJson(json);

        expect(restored.characterName, original.characterName);
        expect(restored.responseText, original.responseText);
        expect(restored.delayMs, original.delayMs);
        expect(restored.toolCallsToEmit, original.toolCallsToEmit);
      });

      test('fromJson with missing fields uses defaults', () {
        final f = MockResponseFixture.fromJson({'characterName': 'WATSON'});
        expect(f.responseText, '');
        expect(f.delayMs, 50);
        expect(f.toolCallsToEmit, isEmpty);
      });
    });

    group('listFromJson', () {
      test('parses a JSON array of fixtures', () {
        const raw = '''
[
  {"characterName":"WATSON","responseText":"Hello","delayMs":50,"toolCallsToEmit":[]},
  {"characterName":"DEEP","responseText":"Hi","delayMs":80,"toolCallsToEmit":["[SEARCH: test]"]}
]
''';
        final fixtures = MockResponseFixture.listFromJson(raw);
        expect(fixtures, hasLength(2));
        expect(fixtures[0].characterName, 'WATSON');
        expect(fixtures[1].toolCallsToEmit, ['[SEARCH: test]']);
      });

      test('returns empty list for empty JSON array', () {
        expect(MockResponseFixture.listFromJson('[]'), isEmpty);
      });
    });
  });
}
