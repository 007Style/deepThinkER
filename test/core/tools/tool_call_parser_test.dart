import 'package:test/test.dart';
import 'package:deep_think_er/core/tools/tool_call_parser.dart';

void main() {
  group('ToolCallParser', () {
    group('parse — basic matching', () {
      test('returns empty list for plain text', () {
        expect(ToolCallParser.parse('Hello, how are you?'), isEmpty);
      });

      test('detects a single SEARCH tag', () {
        final result = ToolCallParser.parse('[SEARCH: dart language]');
        expect(result, hasLength(1));
        expect(result[0].tag, 'SEARCH');
        expect(result[0].argument, 'dart language');
      });

      test('detects a FETCH tag', () {
        final result = ToolCallParser.parse('[FETCH: https://example.com]');
        expect(result, hasLength(1));
        expect(result[0].tag, 'FETCH');
        expect(result[0].argument, 'https://example.com');
      });

      test('detects multiple tags in order', () {
        final result = ToolCallParser.parse(
            'Some text [SEARCH: query] more text [FETCH: url]');
        expect(result, hasLength(2));
        expect(result[0].tag, 'SEARCH');
        expect(result[1].tag, 'FETCH');
      });

      test('tag names are always uppercased', () {
        // Regex only matches uppercase A-Z_, so mixed-case won't parse
        // but registered uppercase tags should be found
        final result = ToolCallParser.parse('[CALC: 2+2]');
        expect(result[0].tag, 'CALC');
      });

      test('trims whitespace from argument', () {
        final result = ToolCallParser.parse('[SEARCH:   spaces around   ]');
        expect(result[0].argument, 'spaces around');
      });

      test('records correct start and end indices', () {
        const text = 'prefix [SEARCH: q] suffix';
        final result = ToolCallParser.parse(text);
        expect(result[0].startIndex, 7);
        expect(result[0].endIndex, 18);
        expect(text.substring(result[0].startIndex, result[0].endIndex),
            '[SEARCH: q]');
      });

      test('handles multi-word tags with underscore', () {
        final result = ToolCallParser.parse('[FILE_READ: /path/to/file]');
        expect(result, hasLength(1));
        expect(result[0].tag, 'FILE_READ');
      });

      test('unknown lowercase tag not matched', () {
        // Only uppercase A-Z_ is matched
        final result = ToolCallParser.parse('[search: query]');
        expect(result, isEmpty);
      });

      test('handles tag with empty argument', () {
        final result = ToolCallParser.parse('[RECALL:]');
        expect(result, hasLength(1));
        expect(result[0].argument, isEmpty);
      });

      test('handles multi-line argument (dotAll)', () {
        final result = ToolCallParser.parse('[SEARCH: line1\nline2]');
        expect(result, hasLength(1));
        expect(result[0].argument, contains('line1'));
      });
    });

    test('toString includes tag and argument', () {
      const call = ParsedToolCall(
          tag: 'SEARCH', argument: 'test', startIndex: 0, endIndex: 15);
      expect(call.toString(), contains('SEARCH'));
      expect(call.toString(), contains('test'));
    });
  });
}
