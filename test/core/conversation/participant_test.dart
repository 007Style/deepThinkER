import 'package:test/test.dart';
import 'package:deep_think/core/conversation/participant.dart';

void main() {
  group('Participant', () {
    group('defaults()', () {
      late List<Participant> defaults;
      setUp(() => defaults = Participant.defaults());

      test('returns exactly 4 participants', () {
        expect(defaults.length, 4);
      });

      test('participants are in order: WATSON, DEEP, NOVA, SAGE', () {
        expect(defaults.map((p) => p.name), ['WATSON', 'DEEP', 'NOVA', 'SAGE']);
      });

      test('only DEEP has isHost=true', () {
        final hosts = defaults.where((p) => p.isHost).toList();
        expect(hosts.length, 1);
        expect(hosts.first.name, 'DEEP');
      });

      test('each participant has a non-empty IBM reference', () {
        for (final p in defaults) {
          expect(p.ibmReference, isNotEmpty,
              reason: '${p.name} has empty ibmReference');
        }
      });

      test('each participant has a non-empty personality', () {
        for (final p in defaults) {
          expect(p.personality, isNotEmpty,
              reason: '${p.name} has empty personality');
        }
      });

      test('each participant has a non-empty master prompt', () {
        for (final p in defaults) {
          expect(p.masterPrompt, isNotEmpty,
              reason: '${p.name} has empty masterPrompt');
        }
      });

      test('each participant has a non-empty assigned model id', () {
        for (final p in defaults) {
          expect(p.assignedModelId, isNotEmpty,
              reason: '${p.name} has empty assignedModelId');
        }
      });

      test('default model assignments match spec', () {
        final map = {for (final p in defaults) p.name: p.assignedModelId};
        expect(map['WATSON'], 'gemma2:9b');
        expect(map['DEEP'], 'phi3:14b');
        expect(map['NOVA'], 'llama3:8b');
        expect(map['SAGE'], 'mistral:7b');
      });
    });

    group('mutability', () {
      test('assignedModelId can be changed', () {
        final p = Participant.defaults().first;
        p.assignedModelId = 'mistral:7b';
        expect(p.assignedModelId, 'mistral:7b');
      });

      test('masterPrompt can be changed', () {
        final p = Participant.defaults().first;
        p.masterPrompt = 'Custom prompt';
        expect(p.masterPrompt, 'Custom prompt');
      });
    });

    group('toString', () {
      test('includes name, model, and host flag', () {
        final p = Participant.defaults().firstWhere((p) => p.name == 'DEEP');
        final s = p.toString();
        expect(s, contains('DEEP'));
        expect(s, contains('phi3:14b'));
        expect(s, contains('host=true'));
      });
    });
  });
}
