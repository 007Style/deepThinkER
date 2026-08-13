import 'dart:async';
import 'package:test/test.dart';
import 'package:deep_think_er/core/conversation/conversation_log.dart';
import 'package:deep_think_er/core/conversation/message.dart';

Message _msg(String name, String content, {bool isUser = false}) =>
    Message(participantName: name, content: content, isUser: isUser);

void main() {
  group('ConversationLog', () {
    late ConversationLog log;

    setUp(() => log = ConversationLog());
    tearDown(() => log.dispose());

    group('append / allMessages', () {
      test('starts empty', () => expect(log.allMessages, isEmpty));

      test('appended messages appear in allMessages in order', () {
        final a = _msg('WATSON', 'Hello');
        final b = _msg('DEEP', 'Hi there');
        log.append(a);
        log.append(b);
        expect(log.allMessages, [a, b]);
      });

      test('allMessages is unmodifiable', () {
        log.append(_msg('SAGE', 'test'));
        expect(() => (log.allMessages as List).add(_msg('NOVA', 'x')),
            throwsUnsupportedError);
      });
    });

    group('messageStream', () {
      test('emits each appended message in order', () async {
        final received = <Message>[];
        final sub = log.messageStream.listen(received.add);
        final a = _msg('WATSON', 'A');
        final b = _msg('DEEP', 'B');
        log.append(a);
        log.append(b);
        await Future<void>.delayed(Duration.zero);
        expect(received, [a, b]);
        await sub.cancel();
      });
    });

    group('getLastN', () {
      setUp(() {
        for (var i = 1; i <= 5; i++) {
          log.append(_msg('WATSON', 'msg$i'));
        }
      });

      test('returns last n messages', () {
        final result = log.getLastN(3);
        expect(result.map((m) => m.content), ['msg3', 'msg4', 'msg5']);
      });

      test('returns all when n >= length', () {
        expect(log.getLastN(10).length, 5);
      });

      test('returns empty for n=0', () => expect(log.getLastN(0), isEmpty));

      test('returns empty for negative n',
          () => expect(log.getLastN(-1), isEmpty));
    });

    group('getLastNForParticipant', () {
      setUp(() {
        log.append(_msg('WATSON', 'w1'));
        log.append(_msg('DEEP', 'd1'));
        log.append(_msg('WATSON', 'w2'));
        log.append(_msg('WATSON', '')); // pass
        log.append(_msg('WATSON', 'w3'));
      });

      test('returns last n non-pass messages from specified participant', () {
        final result = log.getLastNForParticipant('WATSON', 2);
        expect(result.map((m) => m.content), ['w2', 'w3']);
      });

      test('excludes pass messages', () {
        // WATSON has w1, w2, w3 (not the empty pass)
        final result = log.getLastNForParticipant('WATSON', 10);
        expect(result.map((m) => m.content), ['w1', 'w2', 'w3']);
      });

      test('returns empty when participant has no messages', () {
        expect(log.getLastNForParticipant('NOVA', 5), isEmpty);
      });

      test('returns empty for n=0',
          () => expect(log.getLastNForParticipant('WATSON', 0), isEmpty));
    });

    group('getLastNPerParticipant', () {
      setUp(() {
        // Chronological order: w1, d1, w2, d2, n1, w3, d3
        log.append(_msg('WATSON', 'w1'));
        log.append(_msg('DEEP', 'd1'));
        log.append(_msg('WATSON', 'w2'));
        log.append(_msg('DEEP', 'd2'));
        log.append(_msg('NOVA', 'n1'));
        log.append(_msg('WATSON', 'w3'));
        log.append(_msg('DEEP', 'd3'));
      });

      test('returns last 2 from each participant in chronological order', () {
        final result = log.getLastNPerParticipant(['WATSON', 'DEEP'], 2);
        // WATSON: w2, w3 | DEEP: d2, d3 — chronological: w2, d2, w3, d3
        expect(result.map((m) => m.content), ['w2', 'd2', 'w3', 'd3']);
      });

      test('includes participant with fewer than n messages', () {
        final result = log.getLastNPerParticipant(['NOVA'], 2);
        expect(result.map((m) => m.content), ['n1']);
      });

      test('returns empty for n=0',
          () => expect(log.getLastNPerParticipant(['WATSON'], 0), isEmpty));

      test('handles missing participant gracefully', () {
        final result = log.getLastNPerParticipant(['SAGE'], 2);
        expect(result, isEmpty);
      });
    });

    group('toPlainText', () {
      test('formats non-pass messages, skips passes', () {
        final ts = DateTime.utc(2024, 1, 1, 12, 0, 0);
        log.append(Message(
            participantName: 'WATSON',
            content: 'Hello',
            isUser: false,
            timestamp: ts));
        log.append(Message(
            participantName: 'DEEP', content: '', isUser: false, timestamp: ts));
        log.append(Message(
            participantName: 'NOVA',
            content: 'World',
            isUser: false,
            timestamp: ts));

        // toPlainText reads .hour/.minute/.second directly from the UTC-stored timestamp
        final text = log.toPlainText();
        expect(text, contains('[12:00:00] WATSON: Hello'));
        expect(text, contains('[12:00:00] NOVA: World'));
        expect(text, isNot(contains('DEEP')));
      });
    });
  });
}
