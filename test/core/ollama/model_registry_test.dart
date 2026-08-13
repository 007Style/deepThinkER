import 'package:test/test.dart';
import 'package:deep_think_er/core/ollama/model_registry.dart';

void main() {
  group('ModelRegistry', () {
    group('all', () {
      test('contains exactly 5 models (4 character + llava vision)', () {
        expect(ModelRegistry.all.length, 5);
      });

      test('contains all expected model ids', () {
        final ids = ModelRegistry.all.map((m) => m.id).toSet();
        expect(ids, containsAll([
          'mistral:7b', 'llama3:8b', 'gemma2:9b', 'phi3:14b', 'llava:7b',
        ]));
      });

      test('all models have non-empty display names', () {
        for (final m in ModelRegistry.all) {
          expect(m.displayName, isNotEmpty,
              reason: '${m.id} has empty displayName');
        }
      });

      test('all models have positive RAM values', () {
        for (final m in ModelRegistry.all) {
          expect(m.ramGb, greaterThan(0),
              reason: '${m.id} has non-positive ramGb');
        }
      });

      test('all models have non-empty descriptions', () {
        for (final m in ModelRegistry.all) {
          expect(m.description, isNotEmpty,
              reason: '${m.id} has empty description');
        }
      });
    });

    group('isHighContext', () {
      test('only phi3:14b has isHighContext=true', () {
        final highCtx = ModelRegistry.all.where((m) => m.isHighContext).toList();
        expect(highCtx.length, 1);
        expect(highCtx.first.id, 'phi3:14b');
      });

      test('all other models have isHighContext=false', () {
        for (final m in ModelRegistry.all) {
          if (m.id != 'phi3:14b') {
            expect(m.isHighContext, isFalse,
                reason: '${m.id} should not be high context');
          }
        }
      });
    });

    group('findById', () {
      test('returns correct model for known id', () {
        final m = ModelRegistry.findById('mistral:7b');
        expect(m, isNotNull);
        expect(m!.displayName, 'Mistral 7B');
        expect(m.ramGb, 4.1);
      });

      test('returns null for unknown id', () {
        expect(ModelRegistry.findById('unknown:99b'), isNull);
      });

      test('returns null for empty string', () {
        expect(ModelRegistry.findById(''), isNull);
      });

      test('is case-sensitive', () {
        expect(ModelRegistry.findById('MISTRAL:7B'), isNull);
      });
    });

    group('ModelInfo.toString', () {
      test('includes id and RAM', () {
        final s = ModelRegistry.mistral7b.toString();
        expect(s, contains('mistral:7b'));
        expect(s, contains('4.1GB'));
      });
    });
  });
}
