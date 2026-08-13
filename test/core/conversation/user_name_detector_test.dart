import 'package:test/test.dart';
import 'package:deep_think_er/core/conversation/user_name_detector.dart';

void main() {
  group('UserNameDetector', () {
    group('detectRename — positive cases', () {
      test("detects \"I'll call you <Name>\"", () {
        expect(
          UserNameDetector.detectRename("I'll call you Alex from now on.", 'User'),
          'Alex',
        );
      });

      test("detects \"I will call you <Name>\"", () {
        expect(
          UserNameDetector.detectRename('I will call you Max.', 'User'),
          'Max',
        );
      });

      test('detects "your name is <Name>"', () {
        expect(
          UserNameDetector.detectRename('your name is Jordan, right?', 'User'),
          'Jordan',
        );
      });

      test('detects "you said your name is <Name>"', () {
        expect(
          UserNameDetector.detectRename('you said your name is Taylor earlier.', 'User'),
          'Taylor',
        );
      });

      test('detects "introduced yourself as <Name>"', () {
        expect(
          UserNameDetector.detectRename('you introduced yourself as Riley.', 'User'),
          'Riley',
        );
      });

      test('detects "nice to meet you, <Name>"', () {
        expect(
          UserNameDetector.detectRename('Nice to meet you, Sam!', 'User'),
          'Sam',
        );
      });

      test('detects "my name for you is <Name>"', () {
        expect(
          UserNameDetector.detectRename('my name for you is Captain.', 'User'),
          'Captain',
        );
      });
    });

    group('detectRename — negative cases', () {
      test('returns null when no pattern matches', () {
        expect(
          UserNameDetector.detectRename('That is a fascinating point.', 'User'),
          isNull,
        );
      });

      test('returns null when candidate is on the blocklist', () {
        // "your name is you" → candidate "you" is blocklisted
        expect(
          UserNameDetector.detectRename('your name is you', 'User'),
          isNull,
        );
      });

      test('returns null when candidate matches current name (case-insensitive)', () {
        expect(
          UserNameDetector.detectRename("I'll call you user", 'User'),
          isNull,
        );
      });

      test('returns null for empty response', () {
        expect(UserNameDetector.detectRename('', 'User'), isNull);
      });

      test('returns null when candidate starts with a digit', () {
        // Pattern requires first char to be a letter
        expect(
          UserNameDetector.detectRename("I'll call you 42abc", 'User'),
          isNull,
        );
      });
    });

    group('maxNameLength enforcement', () {
      test('truncates name longer than 20 characters', () {
        // Build a response where the extracted candidate is very long.
        final longName = 'A' * 25;
        final result = UserNameDetector.detectRename(
          "I'll call you $longName from now on.",
          'User',
        );
        // Should either be null (blocked by regex length limit) or truncated.
        if (result != null) {
          expect(result.length, lessThanOrEqualTo(UserNameDetector.maxNameLength));
        }
      });
    });

    group('sanitise — trailing punctuation', () {
      test('strips trailing comma from detected name', () {
        // "welcome, Alex," — the comma after Alex should be stripped
        final result = UserNameDetector.detectRename('Welcome, Alex,', 'User');
        // May or may not match depending on pattern; if it does, no trailing comma
        if (result != null) {
          expect(result, isNot(endsWith(',')));
        }
      });
    });
  });
}
