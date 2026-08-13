import 'package:test/test.dart';
import 'package:deep_think/core/ollama/ollama_client.dart';

void main() {
  group('ModelPullProgress', () {
    group('percent', () {
      test('returns correct fraction when total > 0', () {
        final p = ModelPullProgress(
          modelTag: 'mistral:7b',
          completed: 500,
          total: 1000,
          status: 'pulling',
          isDone: false,
        );
        expect(p.percent, closeTo(0.5, 0.0001));
      });

      test('returns 0.0 when total is 0 (unknown size)', () {
        final p = ModelPullProgress(
          modelTag: 'llama3:8b',
          completed: 0,
          total: 0,
          status: 'pulling manifest',
          isDone: false,
        );
        expect(p.percent, 0.0);
      });

      test('clamps to 1.0 when completed > total', () {
        final p = ModelPullProgress(
          modelTag: 'gemma2:9b',
          completed: 1100,
          total: 1000,
          status: 'success',
          isDone: true,
        );
        expect(p.percent, 1.0);
      });

      test('returns 1.0 when fully downloaded', () {
        final p = ModelPullProgress(
          modelTag: 'phi3:14b',
          completed: 8200000000,
          total: 8200000000,
          status: 'success',
          isDone: true,
        );
        expect(p.percent, 1.0);
      });
    });

    group('toString', () {
      test('includes model tag and percent', () {
        final p = ModelPullProgress(
          modelTag: 'mistral:7b',
          completed: 250,
          total: 1000,
          status: 'pulling',
          isDone: false,
        );
        expect(p.toString(), contains('mistral:7b'));
        expect(p.toString(), contains('25.0%'));
      });
    });
  });
}
