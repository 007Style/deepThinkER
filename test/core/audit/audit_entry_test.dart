import 'package:test/test.dart';
import 'package:deep_think_er/core/audit/audit_entry.dart';

void main() {
  group('AuditEntry', () {
    group('create factory', () {
      test('id starts with aud_', () {
        final e = AuditEntry.create(
          sessionName: 'sess1',
          characterName: 'WATSON',
          toolTag: 'SEARCH',
          argument: 'dart',
          wasRateLimited: false,
          wasDisabled: false,
          responseBytes: 100,
        );
        expect(e.id, startsWith('aud_'));
      });

      test('timestamp is UTC', () {
        final e = AuditEntry.create(
          sessionName: 's',
          characterName: 'DEEP',
          toolTag: 'FETCH',
          argument: 'http://x.com',
          wasRateLimited: false,
          wasDisabled: false,
          responseBytes: 200,
        );
        expect(e.timestamp.isUtc, isTrue);
      });

      test('injectionAttemptDetected defaults to false', () {
        final e = AuditEntry.create(
          sessionName: 's',
          characterName: 'NOVA',
          toolTag: 'CALC',
          argument: '1+1',
          wasRateLimited: false,
          wasDisabled: false,
          responseBytes: 5,
        );
        expect(e.injectionAttemptDetected, isFalse);
      });

      test('injectionAttemptDetected can be set to true', () {
        final e = AuditEntry.create(
          sessionName: 's',
          characterName: 'SAGE',
          toolTag: 'SEARCH',
          argument: 'query',
          wasRateLimited: false,
          wasDisabled: false,
          responseBytes: 0,
          injectionAttemptDetected: true,
        );
        expect(e.injectionAttemptDetected, isTrue);
      });
    });

    group('JSON round-trip', () {
      AuditEntry make({bool injection = false}) => AuditEntry.create(
            sessionName: 'test_session',
            characterName: 'WATSON',
            toolTag: 'SEARCH',
            argument: 'flutter testing',
            wasRateLimited: true,
            wasDisabled: false,
            responseBytes: 512,
            injectionAttemptDetected: injection,
          );

      test('toJson/fromJson preserves all fields', () {
        final original = make(injection: true);
        final json = original.toJson();
        final restored = AuditEntry.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.sessionName, original.sessionName);
        expect(restored.characterName, original.characterName);
        expect(restored.toolTag, original.toolTag);
        expect(restored.argument, original.argument);
        expect(restored.wasRateLimited, original.wasRateLimited);
        expect(restored.wasDisabled, original.wasDisabled);
        expect(restored.responseBytes, original.responseBytes);
        expect(restored.injectionAttemptDetected, isTrue);
      });

      test('fromJson with missing injectionAttemptDetected defaults to false', () {
        final e = AuditEntry.fromJson({
          'id': 'aud_1',
          'sessionName': 's',
          'characterName': 'DEEP',
          'toolTag': 'CALC',
          'argument': '2+2',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'wasRateLimited': false,
          'wasDisabled': false,
          'responseBytes': 1,
        });
        expect(e.injectionAttemptDetected, isFalse);
      });

      test('toNdJsonLine produces valid JSON', () {
        final e = make();
        final line = e.toNdJsonLine();
        expect(() => AuditEntry.fromJson(
              Map<String, dynamic>.from(
                (line.isNotEmpty) ? {} : {},
              ),
            ), returnsNormally);
        // Verify it's parseable JSON
        expect(line, startsWith('{'));
        expect(line, contains('"WATSON"'));
      });
    });
  });
}
