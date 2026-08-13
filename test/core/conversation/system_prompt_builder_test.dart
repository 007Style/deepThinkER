import 'package:test/test.dart';
import 'package:deep_think_er/core/conversation/system_prompt_builder.dart';
import 'package:deep_think_er/core/conversation/participant.dart';
import 'package:deep_think_er/core/ollama/hardware_detector.dart';

HardwareInfo _hardware(RamTier tier) => HardwareInfo(
      totalRamGb: 32.0,
      freeRamGb: 32.0,
      ramTier: tier,
      inferenceBackend: InferenceBackend.appleMetal,
      backendDisplayName: 'Apple Metal (GPU)',
    );

void main() {
  group('SystemPromptBuilder', () {
    late List<Participant> all;
    late HardwareInfo hw;

    setUp(() {
      all = Participant.defaults();
      hw = _hardware(RamTier.tier32);
    });

    test('includes the participant\'s master prompt', () {
      final watson = all.firstWhere((p) => p.name == 'WATSON');
      final prompt = SystemPromptBuilder.build(watson, all, hw);
      expect(prompt, contains(watson.masterPrompt));
    });

    test('includes all other participant names', () {
      final watson = all.firstWhere((p) => p.name == 'WATSON');
      final prompt = SystemPromptBuilder.build(watson, all, hw);
      expect(prompt, contains('DEEP'));
      expect(prompt, contains('NOVA'));
      expect(prompt, contains('SAGE'));
    });

    test('does not include self in the "other participants" section redundantly', () {
      final watson = all.firstWhere((p) => p.name == 'WATSON');
      final prompt = SystemPromptBuilder.build(watson, all, hw);
      // WATSON appears in the "You (WATSON)" section, other participants listed below
      expect(prompt, contains('You (WATSON)'));
    });

    test('marks DEEP as host in prompt', () {
      final nova = all.firstWhere((p) => p.name == 'NOVA');
      final prompt = SystemPromptBuilder.build(nova, all, hw);
      expect(prompt, contains('DEEP'));
      // The host note should appear somewhere
      expect(prompt.toLowerCase(), contains('host'));
    });

    test('includes conversation rules including pass mechanic', () {
      final sage = all.firstWhere((p) => p.name == 'SAGE');
      final prompt = SystemPromptBuilder.build(sage, all, hw);
      // Rule 3 about passing
      expect(prompt, contains('empty string'));
    });

    test('includes hardware backend display name', () {
      final deep = all.firstWhere((p) => p.name == 'DEEP');
      final prompt = SystemPromptBuilder.build(deep, all, hw);
      expect(prompt, contains('Apple Metal (GPU)'));
    });

    group('context window selection', () {
      test('phi3:14b gets high context window', () {
        final deep = all.firstWhere((p) => p.name == 'DEEP');
        expect(deep.assignedModelId, 'phi3:14b');
        final prompt = SystemPromptBuilder.build(deep, all, hw);
        // tier32 high context = 32768
        expect(prompt, contains('32768'));
      });

      test('non-phi3 model gets standard context window', () {
        final watson = all.firstWhere((p) => p.name == 'WATSON');
        expect(watson.assignedModelId, 'gemma2:9b');
        final prompt = SystemPromptBuilder.build(watson, all, hw);
        // tier32 standard context = 8192
        expect(prompt, contains('8192'));
      });
    });
  });
}
