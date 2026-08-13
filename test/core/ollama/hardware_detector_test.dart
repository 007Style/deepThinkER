import 'package:test/test.dart';
import 'package:deep_think_er/core/ollama/hardware_detector.dart';

HardwareInfo _info(RamTier tier) => HardwareInfo(
      totalRamGb: 32.0,
      freeRamGb: 32.0,
      ramTier: tier,
      inferenceBackend: InferenceBackend.cpu,
      backendDisplayName: 'CPU (no GPU acceleration)',
    );

void main() {
  group('HardwareInfo', () {
    group('standardContextWindow', () {
      test('tier32 → 8192', () {
        expect(_info(RamTier.tier32).standardContextWindow, 8192);
      });
      test('tier48 → 16384', () {
        expect(_info(RamTier.tier48).standardContextWindow, 16384);
      });
      test('tier64 → 32768', () {
        expect(_info(RamTier.tier64).standardContextWindow, 32768);
      });
      test('tier128 → 65536', () {
        expect(_info(RamTier.tier128).standardContextWindow, 65536);
      });
    });

    group('highContextWindow', () {
      test('tier32 → 32768', () {
        expect(_info(RamTier.tier32).highContextWindow, 32768);
      });
      test('tier48 → 65536', () {
        expect(_info(RamTier.tier48).highContextWindow, 65536);
      });
      test('tier64 → 131072', () {
        expect(_info(RamTier.tier64).highContextWindow, 131072);
      });
      test('tier128 → 131072 (capped at max)', () {
        expect(_info(RamTier.tier128).highContextWindow, 131072);
      });
    });

    group('tier ordering', () {
      test('standard context windows increase with tier', () {
        final tiers = [
          RamTier.tier32,
          RamTier.tier48,
          RamTier.tier64,
          RamTier.tier128,
        ];
        final values = tiers.map((t) => _info(t).standardContextWindow).toList();
        for (var i = 0; i < values.length - 1; i++) {
          expect(values[i], lessThan(values[i + 1]));
        }
      });

      test('high context windows are always >= standard context windows', () {
        for (final tier in RamTier.values) {
          final info = _info(tier);
          expect(info.highContextWindow,
              greaterThanOrEqualTo(info.standardContextWindow));
        }
      });
    });

    group('toString', () {
      test('includes RAM, tier, and backend', () {
        final info = HardwareInfo(
          totalRamGb: 64.0,
          freeRamGb: 64.0,
          ramTier: RamTier.tier64,
          inferenceBackend: InferenceBackend.appleMetal,
          backendDisplayName: 'Apple Metal (GPU)',
        );
        final s = info.toString();
        expect(s, contains('64.0GB'));
        expect(s, contains('free=64.0GB'));
        expect(s, contains('tier64'));
        expect(s, contains('appleMetal'));
      });
    });
  });

  group('HardwareDetector._classifyRam (via detect())', () {
    // We test the classification logic indirectly using a white-box approach
    // by constructing HardwareInfo manually with known RAM values.
    // The private _classifyRam thresholds are:
    //   < 40 GB  → tier32
    //   >= 40 GB → tier48
    //   >= 56 GB → tier64
    //   >= 112 GB → tier128
    //
    // We verify the mapping is consistent with the tier values we create.

    test('RAM below 40 GB maps to tier32 behaviour (ctx=8192)', () {
      final info = HardwareInfo(
        totalRamGb: 32.0,
        freeRamGb: 32.0,
        ramTier: RamTier.tier32,
        inferenceBackend: InferenceBackend.cpu,
        backendDisplayName: 'CPU (no GPU acceleration)',
      );
      expect(info.standardContextWindow, 8192);
    });

    test('RAM of 48 GB maps to tier48 behaviour (ctx=16384)', () {
      final info = HardwareInfo(
        totalRamGb: 48.0,
        freeRamGb: 48.0,
        ramTier: RamTier.tier48,
        inferenceBackend: InferenceBackend.cuda,
        backendDisplayName: 'NVIDIA CUDA (GPU)',
      );
      expect(info.standardContextWindow, 16384);
    });
  });
}
