import 'package:test/test.dart';
import 'package:deep_think/core/session/session.dart';
import 'package:deep_think/core/conversation/participant.dart';

void main() {
  group('Session', () {
    final participants = Participant.defaults();
    final startTime = DateTime(2024, 5, 10, 8, 0, 0).toUtc();

    Session _make({String? name, DateTime? start}) => Session(
          id: 'session-123',
          name: name ?? 'quantumFalcon',
          participants: participants,
          logFilePath: '/tmp/quantumFalcon_123.txt',
          startTime: start ?? startTime,
        );

    group('constructor defaults', () {
      test('isActive defaults to false', () {
        expect(_make().isActive, isFalse);
      });

      test('totalMessages defaults to 0', () {
        expect(_make().totalMessages, 0);
      });

      test('totalTokens defaults to 0', () {
        expect(_make().totalTokens, 0);
      });

      test('totalUserMessages defaults to 0', () {
        expect(_make().totalUserMessages, 0);
      });

      test('endTime defaults to null', () {
        expect(_make().endTime, isNull);
      });

      test('startTime defaults to now when not supplied', () {
        final before = DateTime.now().toUtc();
        final s = Session(
          id: 'x',
          name: 'test',
          participants: [],
          logFilePath: '/tmp/x.txt',
        );
        final after = DateTime.now().toUtc();
        expect(s.startTime.isAfter(before) || s.startTime == before, isTrue);
        expect(s.startTime.isBefore(after) || s.startTime == after, isTrue);
      });
    });

    group('toJson / fromJson round-trip', () {
      test('round-trips all scalar fields', () {
        final s = _make();
        s.endTime = DateTime(2024, 5, 10, 9, 0, 0).toUtc();
        s.isActive = true;
        s.totalMessages = 42;
        s.totalTokens = 9999;
        s.totalUserMessages = 7;

        final restored = Session.fromJson(s.toJson());
        expect(restored.id, s.id);
        expect(restored.name, s.name);
        expect(restored.startTime, s.startTime);
        expect(restored.endTime, s.endTime);
        expect(restored.logFilePath, s.logFilePath);
        expect(restored.isActive, s.isActive);
        expect(restored.totalMessages, s.totalMessages);
        expect(restored.totalTokens, s.totalTokens);
        expect(restored.totalUserMessages, s.totalUserMessages);
      });

      test('toJson encodes participant names, not full objects', () {
        final json = _make().toJson();
        final pNames = json['participants'] as List;
        expect(pNames, containsAll(['WATSON', 'DEEP', 'NOVA', 'SAGE']));
        // Ensure it's strings, not nested maps
        expect(pNames.first, isA<String>());
      });

      test('endTime is omitted from JSON when null', () {
        final json = _make().toJson();
        expect(json.containsKey('endTime'), isFalse);
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'id': 'session-abc',
          'name': 'testSession',
          'startTime': startTime.toIso8601String(),
          'logFilePath': '/tmp/test.txt',
        };
        final s = Session.fromJson(json);
        expect(s.id, 'session-abc');
        expect(s.totalMessages, 0);
        expect(s.isActive, isFalse);
        expect(s.endTime, isNull);
        expect(s.participants, isEmpty);
      });
    });

    group('toString', () {
      test('includes id, name, active, and messages', () {
        final s = _make();
        s.totalMessages = 5;
        final str = s.toString();
        expect(str, contains('session-123'));
        expect(str, contains('quantumFalcon'));
        expect(str, contains('5'));
      });
    });
  });
}
