import 'package:test/test.dart';
import 'package:deep_think_er/core/settings/app_settings.dart';

void main() {
  group('AppSettings', () {
    group('defaults', () {
      const s = AppSettings();
      test('globalRateLimitPerMin = 10', () => expect(s.globalRateLimitPerMin, 10));
      test('visionModelName = llava:7b', () => expect(s.visionModelName, 'llava:7b'));
      test('soundEnabled = true', () => expect(s.soundEnabled, isTrue));
      test('notificationsEnabled = true', () => expect(s.notificationsEnabled, isTrue));
      test('fontSizeScale = medium', () => expect(s.fontSizeScale, 'medium'));
      test('highContrastMode = false', () => expect(s.highContrastMode, isFalse));
      test('reducedMotionMode = false', () => expect(s.reducedMotionMode, isFalse));
      test('contentFilterEnabled = false', () => expect(s.contentFilterEnabled, isFalse));
      test('proactiveInjectionEnabled = false', () => expect(s.proactiveInjectionEnabled, isFalse));
      test('schemaVersion = 1', () => expect(s.schemaVersion, 1));
      test('activeFilterCategories has 3 defaults', () =>
          expect(s.activeFilterCategories, hasLength(3)));
    });

    group('copyWith', () {
      test('changes only specified fields', () {
        const original = AppSettings();
        final modified = original.copyWith(
          globalRateLimitPerMin: 20,
          soundEnabled: false,
        );
        expect(modified.globalRateLimitPerMin, 20);
        expect(modified.soundEnabled, isFalse);
        // unchanged
        expect(modified.visionModelName, original.visionModelName);
        expect(modified.fontSizeScale, original.fontSizeScale);
        expect(modified.schemaVersion, original.schemaVersion);
      });

      test('copyWith with no args returns equivalent settings', () {
        const original = AppSettings(personaText: 'I am an expert');
        final copy = original.copyWith();
        expect(copy.personaText, original.personaText);
        expect(copy.globalRateLimitPerMin, original.globalRateLimitPerMin);
      });
    });

    group('JSON round-trip', () {
      test('toJson/fromJson round-trips all fields', () {
        const original = AppSettings(
          globalRateLimitPerMin: 15,
          personaText: 'Expert user',
          proactiveInjectionEnabled: true,
          visionModelName: 'llava:13b',
          contentFilterEnabled: true,
          activeFilterCategories: ['adult'],
          soundEnabled: false,
          notificationsEnabled: false,
          fontSizeScale: 'large',
          highContrastMode: true,
          reducedMotionMode: true,
          schemaVersion: 2,
        );
        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.globalRateLimitPerMin, original.globalRateLimitPerMin);
        expect(restored.personaText, original.personaText);
        expect(restored.proactiveInjectionEnabled, original.proactiveInjectionEnabled);
        expect(restored.visionModelName, original.visionModelName);
        expect(restored.contentFilterEnabled, original.contentFilterEnabled);
        expect(restored.activeFilterCategories, original.activeFilterCategories);
        expect(restored.soundEnabled, original.soundEnabled);
        expect(restored.notificationsEnabled, original.notificationsEnabled);
        expect(restored.fontSizeScale, original.fontSizeScale);
        expect(restored.highContrastMode, original.highContrastMode);
        expect(restored.reducedMotionMode, original.reducedMotionMode);
        expect(restored.schemaVersion, original.schemaVersion);
      });

      test('fromJson with missing fields uses defaults', () {
        final settings = AppSettings.fromJson({});
        expect(settings.globalRateLimitPerMin, 10);
        expect(settings.soundEnabled, isTrue);
        expect(settings.fontSizeScale, 'medium');
      });

      test('toJsonString / fromJsonString round-trip', () {
        const s = AppSettings(personaText: 'Hello');
        final raw = s.toJsonString();
        final restored = AppSettings.fromJsonString(raw);
        expect(restored.personaText, 'Hello');
      });
    });
  });
}
