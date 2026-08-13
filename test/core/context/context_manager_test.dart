import 'package:test/test.dart';
import 'package:deep_think_er/core/context/context_manager.dart';
import 'package:deep_think_er/core/conversation/conversation_log.dart';
import 'package:deep_think_er/core/conversation/message.dart';

Message _msg(String name, String content) =>
    Message(participantName: name, content: content, isUser: false);

void main() {
  group('ContextManager', () {
    late ContextManager ctx;

    setUp(() => ctx = ContextManager());

    group('recordTokens / tokenCount', () {
      test('starts at zero for unknown participant', () {
        expect(ctx.tokenCount('WATSON'), 0);
      });

      test('accumulates tokens across multiple calls', () {
        ctx.recordTokens('WATSON', 100);
        ctx.recordTokens('WATSON', 50);
        expect(ctx.tokenCount('WATSON'), 150);
      });

      test('tracks different participants independently', () {
        ctx.recordTokens('WATSON', 200);
        ctx.recordTokens('DEEP', 400);
        expect(ctx.tokenCount('WATSON'), 200);
        expect(ctx.tokenCount('DEEP'), 400);
      });
    });

    group('recordFromText', () {
      test('estimates tokens as ceil(length / 4)', () {
        // "Hello" = 5 chars → ceil(5/4) = 2 tokens
        ctx.recordFromText('NOVA', 'Hello');
        expect(ctx.tokenCount('NOVA'), 2);
      });

      test('accumulates with existing count', () {
        ctx.recordTokens('SAGE', 10);
        ctx.recordFromText('SAGE', '1234'); // 4 chars = 1 token
        expect(ctx.tokenCount('SAGE'), 11);
      });
    });

    group('needsReset', () {
      test('returns false when below 90% threshold', () {
        ctx.recordTokens('WATSON', 7000);
        // 7000 / 8192 = 85.4% < 90%
        expect(ctx.needsReset('WATSON', 8192), isFalse);
      });

      test('returns true at exactly 90%', () {
        // floor(8192 * 0.90) = 7372
        ctx.recordTokens('WATSON', 7372);
        expect(ctx.needsReset('WATSON', 8192), isTrue);
      });

      test('returns true above 90%', () {
        ctx.recordTokens('WATSON', 8000);
        expect(ctx.needsReset('WATSON', 8192), isTrue);
      });

      test('returns false for unknown participant', () {
        expect(ctx.needsReset('NOBODY', 8192), isFalse);
      });
    });

    group('reset', () {
      test('clears token count to zero', () {
        ctx.recordTokens('DEEP', 5000);
        ctx.reset('DEEP');
        expect(ctx.tokenCount('DEEP'), 0);
      });

      test('only resets specified participant', () {
        ctx.recordTokens('WATSON', 1000);
        ctx.recordTokens('DEEP', 2000);
        ctx.reset('WATSON');
        expect(ctx.tokenCount('WATSON'), 0);
        expect(ctx.tokenCount('DEEP'), 2000);
      });

      test('reset of unknown participant is a no-op', () {
        expect(() => ctx.reset('NOBODY'), returnsNormally);
      });
    });

    group('buildResetSeed', () {
      late ConversationLog log;

      setUp(() {
        log = ConversationLog();
        // Add 3 messages each for WATSON and DEEP, plus a pass and a user msg
        log.append(_msg('WATSON', 'w1'));
        log.append(_msg('DEEP', 'd1'));
        log.append(_msg('WATSON', 'w2'));
        log.append(_msg('DEEP', 'd2'));
        log.append(Message(participantName: 'WATSON', content: '', isUser: false)); // pass
        log.append(_msg('WATSON', 'w3'));
        log.append(_msg('DEEP', 'd3'));
      });

      tearDown(() => log.dispose());

      test('returns last 2 non-pass messages per participant in chron order', () {
        final seed = ctx.buildResetSeed(log, ['WATSON', 'DEEP']);
        final contents = seed.map((m) => m.content).toList();
        // WATSON last 2: w2, w3 | DEEP last 2: d2, d3
        // Chronological: w2, d2, w3, d3
        expect(contents, ['w2', 'd2', 'w3', 'd3']);
      });

      test('caps seed at 10 messages max', () {
        // Add enough messages to go over 10
        for (var i = 0; i < 10; i++) {
          log.append(_msg('NOVA', 'n$i'));
        }
        final seed = ctx.buildResetSeed(log, ['WATSON', 'DEEP', 'NOVA', 'SAGE']);
        expect(seed.length, lessThanOrEqualTo(10));
      });
    });
  });
}
