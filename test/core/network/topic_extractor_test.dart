import 'package:test/test.dart';
import 'package:deep_think_er/core/network/topic_extractor.dart';
import 'package:deep_think_er/core/conversation/message.dart';

Message _msg(String content) =>
    Message(participantName: 'WATSON', content: content, isUser: false);

void main() {
  group('TopicExtractor', () {
    test('returns empty list for empty message list', () {
      expect(TopicExtractor.extract([]), isEmpty);
    });

    test('returns empty list when all messages are passes', () {
      expect(TopicExtractor.extract([_msg('')]), isEmpty);
    });

    test('extracts most frequent non-stopword words', () {
      final msgs = [
        _msg('climate change climate change research'),
        _msg('climate change is important research topic'),
      ];
      final topics = TopicExtractor.extract(msgs, maxTopics: 2);
      expect(topics, contains('climate'));
      expect(topics, contains('change'));
    });

    test('respects maxTopics limit', () {
      final msgs = [_msg('artificial intelligence machine learning neural networks deep learning')];
      final topics = TopicExtractor.extract(msgs, maxTopics: 2);
      expect(topics.length, lessThanOrEqualTo(2));
    });

    test('filters out short words (≤4 chars)', () {
      final msgs = [_msg('the cat sat on mat')];
      final topics = TopicExtractor.extract(msgs);
      // All words ≤4 chars — should return empty
      expect(topics, isEmpty);
    });

    test('filters common stopwords', () {
      final msgs = [_msg('about above after although because before')];
      final topics = TopicExtractor.extract(msgs);
      expect(topics, isEmpty);
    });

    test('is case-insensitive', () {
      final msgs = [
        _msg('Quantum physics quantum mechanics QUANTUM entanglement'),
      ];
      final topics = TopicExtractor.extract(msgs, maxTopics: 1);
      expect(topics.first, 'quantum');
    });
  });
}
