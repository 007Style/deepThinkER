import 'package:test/test.dart';
import 'package:deep_think/core/session/app_stats.dart';

void main() {
  group('AppStats', () {
    group('empty()', () {
      test('all counters are zero', () {
        final stats = AppStats.empty();
        expect(stats.totalSessionsRun, 0);
        expect(stats.totalMessagesGenerated, 0);
        expect(stats.totalTokensProcessed, 0);
      });

      test('date fields are null', () {
        final stats = AppStats.empty();
        expect(stats.firstSessionDate, isNull);
        expect(stats.lastSessionDate, isNull);
      });
    });

    group('toJson / fromJson round-trip', () {
      test('round-trips all fields without dates', () {
        final original = AppStats(
          totalSessionsRun: 5,
          totalMessagesGenerated: 123,
          totalTokensProcessed: 45678,
        );
        final restored = AppStats.fromJson(original.toJson());
        expect(restored.totalSessionsRun, 5);
        expect(restored.totalMessagesGenerated, 123);
        expect(restored.totalTokensProcessed, 45678);
        expect(restored.firstSessionDate, isNull);
        expect(restored.lastSessionDate, isNull);
      });

      test('round-trips date fields', () {
        final first = DateTime(2024, 1, 1).toUtc();
        final last = DateTime(2024, 6, 15, 10, 30).toUtc();
        final original = AppStats(
          totalSessionsRun: 10,
          totalMessagesGenerated: 500,
          totalTokensProcessed: 99999,
          firstSessionDate: first,
          lastSessionDate: last,
        );
        final restored = AppStats.fromJson(original.toJson());
        expect(restored.firstSessionDate, first);
        expect(restored.lastSessionDate, last);
      });

      test('toJson omits null date fields', () {
        final json = AppStats.empty().toJson();
        expect(json.containsKey('firstSessionDate'), isFalse);
        expect(json.containsKey('lastSessionDate'), isFalse);
      });

      test('fromJson handles missing optional fields gracefully', () {
        final stats = AppStats.fromJson({});
        expect(stats.totalSessionsRun, 0);
        expect(stats.totalMessagesGenerated, 0);
        expect(stats.totalTokensProcessed, 0);
        expect(stats.firstSessionDate, isNull);
        expect(stats.lastSessionDate, isNull);
      });
    });

    group('mutability', () {
      test('counters can be incremented', () {
        final stats = AppStats.empty();
        stats.totalSessionsRun++;
        stats.totalMessagesGenerated += 42;
        stats.totalTokensProcessed += 1000;
        expect(stats.totalSessionsRun, 1);
        expect(stats.totalMessagesGenerated, 42);
        expect(stats.totalTokensProcessed, 1000);
      });

      test('date fields can be assigned', () {
        final stats = AppStats.empty();
        final now = DateTime.now().toUtc();
        stats.firstSessionDate = now;
        stats.lastSessionDate = now;
        expect(stats.firstSessionDate, now);
        expect(stats.lastSessionDate, now);
      });
    });

    group('toString', () {
      test('includes key stats', () {
        final stats = AppStats(
          totalSessionsRun: 3,
          totalMessagesGenerated: 77,
          totalTokensProcessed: 12345,
        );
        final s = stats.toString();
        expect(s, contains('3'));
        expect(s, contains('77'));
        expect(s, contains('12345'));
      });
    });
  });
}
