import 'package:test/test.dart';
import 'package:deep_think_er/core/debug/debug_controller.dart';

void main() {
  group('DebugController', () {
    final dc = DebugController.instance;

    setUp(() {
      // Clear all callbacks before each test
      dc.onSetTrust = null;
      dc.onSetMood = null;
      dc.onSetRelationship = null;
      dc.onFireRateLimitViolation = null;
      dc.onSimulateOllamaCrash = null;
    });

    test('singleton returns same instance', () {
      expect(DebugController.instance, same(DebugController.instance));
    });

    test('setTrust calls onSetTrust with clamped value', () {
      double? received;
      dc.onSetTrust = (_, score) => received = score;
      dc.setTrust('WATSON', 1.5);  // should clamp to 1.0
      expect(received, 1.0);
    });

    test('setTrust clamps negative values to 0.0', () {
      double? received;
      dc.onSetTrust = (_, score) => received = score;
      dc.setTrust('DEEP', -0.5);
      expect(received, 0.0);
    });

    test('setTrust passes character name correctly', () {
      String? receivedChar;
      dc.onSetTrust = (char, _) => receivedChar = char;
      dc.setTrust('NOVA', 0.7);
      expect(receivedChar, 'NOVA');
    });

    test('setMood calls onSetMood', () {
      String? receivedMood;
      dc.onSetMood = (_, mood) => receivedMood = mood;
      dc.setMood('SAGE', 'excited');
      expect(receivedMood, 'excited');
    });

    test('setRelationship clamps score above 100', () {
      int? received;
      dc.onSetRelationship = (_, __, score) => received = score;
      dc.setRelationship('WATSON', 'DEEP', 200);
      expect(received, 100);
    });

    test('setRelationship clamps score below -100', () {
      int? received;
      dc.onSetRelationship = (_, __, score) => received = score;
      dc.setRelationship('WATSON', 'DEEP', -200);
      expect(received, -100);
    });

    test('fireRateLimitViolation calls callback with character name', () {
      String? received;
      dc.onFireRateLimitViolation = (char) => received = char;
      dc.fireRateLimitViolation('WATSON');
      expect(received, 'WATSON');
    });

    test('simulateOllamaCrash calls callback', () {
      var called = false;
      dc.onSimulateOllamaCrash = () => called = true;
      dc.simulateOllamaCrash();
      expect(called, isTrue);
    });

    test('no-op when callbacks are null', () {
      // Should not throw with null callbacks
      expect(() {
        dc.setTrust('WATSON', 0.5);
        dc.setMood('WATSON', 'neutral');
        dc.setRelationship('A', 'B', 10);
        dc.fireRateLimitViolation('WATSON');
        dc.simulateOllamaCrash();
      }, returnsNormally);
    });
  });
}
