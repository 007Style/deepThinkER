import 'package:test/test.dart';
import 'package:deep_think_er/core/export/markdown_exporter.dart';

void main() {
  group('MarkdownExporter', () {
    const exporter = MarkdownExporter();

    test('starts with session name as h1', () {
      final result = exporter.export(
        sessionName: 'My Session',
        messages: [],
      );
      expect(result, startsWith('# My Session'));
    });

    test('includes a Conversation h2 section', () {
      final result = exporter.export(sessionName: 'S', messages: []);
      expect(result, contains('## Conversation'));
    });

    test('formats a message with bold sender and italic timestamp', () {
      final result = exporter.export(
        sessionName: 'Test',
        messages: [
          {
            'sender': 'WATSON',
            'content': 'Hello world',
            'timestamp': '2024-01-15T10:00:00Z',
          }
        ],
      );
      expect(result, contains('**WATSON**'));
      expect(result, contains('_2024-01-15T10:00:00Z_'));
      expect(result, contains('Hello world'));
    });

    test('skips empty messages', () {
      final result = exporter.export(
        sessionName: 'S',
        messages: [
          {'sender': 'WATSON', 'content': '', 'timestamp': '10:00'},
        ],
      );
      expect(result, isNot(contains('WATSON')));
    });

    test('includes horizontal rules between messages', () {
      final result = exporter.export(
        sessionName: 'S',
        messages: [
          {'sender': 'A', 'content': 'Hello', 'timestamp': '10:00'},
          {'sender': 'B', 'content': 'Hi', 'timestamp': '10:01'},
        ],
      );
      expect(result, contains('---'));
    });

    test('includes Search Activity section when provided', () {
      final result = exporter.export(
        sessionName: 'S',
        messages: [],
        searchActivity: [
          {
            'query': 'dart language',
            'timestamp': '10:05',
            'result': 'Found 10 results',
          }
        ],
      );
      expect(result, contains('## Search Activity'));
      expect(result, contains('**dart language**'));
      expect(result, contains('Found 10 results'));
    });

    test('omits Search Activity section when not provided', () {
      final result = exporter.export(sessionName: 'S', messages: []);
      expect(result, isNot(contains('## Search Activity')));
    });

    test('formats search query as bold in blockquote', () {
      final result = exporter.export(
        sessionName: 'S',
        messages: [],
        searchActivity: [
          {'query': 'flutter testing', 'timestamp': '10:00'},
        ],
      );
      expect(result, contains('> '));
      expect(result, contains('**flutter testing**'));
    });
  });
}
