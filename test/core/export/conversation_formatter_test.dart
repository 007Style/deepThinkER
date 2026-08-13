import 'package:test/test.dart';
import 'package:deep_think_er/core/export/conversation_formatter.dart';

void main() {
  group('ConversationFormatter', () {
    const fmt = ConversationFormatter();

    List<Map<String, String>> _msgs(List<(String, String, String)> data) => [
          for (final (sender, content, ts) in data)
            {'sender': sender, 'content': content, 'timestamp': ts},
        ];

    test('formats a simple message', () {
      final result = fmt.format([
        {'sender': 'WATSON', 'content': 'Hello!', 'timestamp': '10:00:00'},
      ]);
      expect(result, contains('[10:00:00] WATSON: Hello!'));
    });

    test('strips WEB_RESULT lines', () {
      final result = fmt.format([
        {
          'sender': 'WATSON',
          'content': 'Here is my answer.\n[WEB_RESULT for WATSON]: html\nThe end.',
          'timestamp': '10:00:00',
        }
      ]);
      expect(result, isNot(contains('[WEB_RESULT')));
      expect(result, contains('Here is my answer.'));
      expect(result, contains('The end.'));
    });

    test('strips SYSTEM_STEER lines', () {
      final result = fmt.format([
        {
          'sender': 'DEEP',
          'content': 'Good point.\n[SYSTEM_STEER: be more concise]',
          'timestamp': '10:01:00',
        }
      ]);
      expect(result, isNot(contains('[SYSTEM_STEER')));
      expect(result, contains('Good point.'));
    });

    test('strips PROACTIVE_WEB_RESULT lines', () {
      final result = fmt.format([
        {
          'sender': 'NOVA',
          'content': 'I found this.\n[PROACTIVE_WEB_RESULT for NOVA]: data',
          'timestamp': '10:02:00',
        }
      ]);
      expect(result, isNot(contains('[PROACTIVE_WEB_RESULT')));
    });

    test('skips messages with empty content after cleaning', () {
      final result = fmt.format([
        {
          'sender': 'SAGE',
          'content': '[WEB_RESULT for SAGE]: only system content',
          'timestamp': '10:03:00',
        }
      ]);
      expect(result, isEmpty);
    });

    test('formats multiple messages in order', () {
      final result = fmt.format([
        {'sender': 'WATSON', 'content': 'First', 'timestamp': '09:00'},
        {'sender': 'DEEP', 'content': 'Second', 'timestamp': '09:01'},
      ]);
      final watson = result.indexOf('WATSON');
      final deep = result.indexOf('DEEP');
      expect(watson, lessThan(deep));
    });

    test('uses Unknown for missing sender', () {
      final result = fmt.format([
        {'content': 'hello', 'timestamp': '10:00'},
      ]);
      expect(result, contains('Unknown'));
    });
  });
}
