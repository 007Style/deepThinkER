import 'package:test/test.dart';
import 'package:deep_think/core/conversation/message.dart';

void main() {
  group('Message', () {
    group('constructor', () {
      test('auto-generates a non-empty UUID id when none supplied', () {
        final msg = Message(
            participantName: 'WATSON', content: 'Hello', isUser: false);
        expect(msg.id, isNotEmpty);
        // UUID v4 format: 8-4-4-4-12 hex chars
        expect(msg.id,
            matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      });

      test('uses supplied id when provided', () {
        final msg = Message(
            participantName: 'DEEP',
            content: 'Hi',
            isUser: false,
            id: 'fixed-id-123');
        expect(msg.id, 'fixed-id-123');
      });

      test('two messages get different auto-generated ids', () {
        final a = Message(participantName: 'NOVA', content: 'A', isUser: false);
        final b = Message(participantName: 'NOVA', content: 'B', isUser: false);
        expect(a.id, isNot(equals(b.id)));
      });

      test('defaults timestamp to UTC now when not supplied', () {
        final before = DateTime.now().toUtc();
        final msg =
            Message(participantName: 'SAGE', content: 'Test', isUser: false);
        final after = DateTime.now().toUtc();
        expect(msg.timestamp.isAfter(before) || msg.timestamp == before, isTrue);
        expect(msg.timestamp.isBefore(after) || msg.timestamp == after, isTrue);
        expect(msg.timestamp.isUtc, isTrue);
      });

      test('uses supplied timestamp when provided', () {
        final ts = DateTime(2024, 1, 15, 10, 30, 0).toUtc();
        final msg = Message(
            participantName: 'WATSON',
            content: 'Hi',
            isUser: false,
            timestamp: ts);
        expect(msg.timestamp, ts);
      });
    });

    group('isPass', () {
      test('returns true for empty content', () {
        final msg =
            Message(participantName: 'DEEP', content: '', isUser: false);
        expect(msg.isPass, isTrue);
      });

      test('returns false for non-empty content', () {
        final msg =
            Message(participantName: 'DEEP', content: 'Hello', isUser: false);
        expect(msg.isPass, isFalse);
      });
    });

    group('toPlainText', () {
      test('formats message as [HH:MM:SS] NAME: content', () {
        // toPlainText uses timestamp.hour directly (UTC-stored value)
        final ts = DateTime.utc(2024, 6, 1, 9, 5, 3);
        final msg = Message(
            participantName: 'WATSON',
            content: 'Interesting point',
            isUser: false,
            timestamp: ts);
        expect(msg.toPlainText(), '[09:05:03] WATSON: Interesting point');
      });

      test('pads single-digit hours, minutes, seconds with leading zeros', () {
        // Use UTC directly — toPlainText reads .hour/.minute/.second of the stored value
        final ts = DateTime.utc(2024, 1, 1, 1, 2, 3);
        final msg = Message(
            participantName: 'NOVA',
            content: 'X',
            isUser: false,
            timestamp: ts);
        expect(msg.toPlainText(), '[01:02:03] NOVA: X');
      });
    });
  });
}
