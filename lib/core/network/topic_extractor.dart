/// TopicExtractor — derives key topics from recent conversation messages.
///
/// Simple approach: split content to words, lowercase, filter stopwords,
/// keep words >4 chars, deduplicate, return top N by frequency.
/// No ML or external dependencies.
///
/// This file has zero Flutter imports — pure Dart only.
library topic_extractor;

import '../conversation/message.dart';

// ---------------------------------------------------------------------------
// TopicExtractor
// ---------------------------------------------------------------------------

/// Extracts the most prominent topics from a set of recent messages.
///
/// The algorithm:
/// 1. Concatenate all message content.
/// 2. Lowercase and split on non-word characters.
/// 3. Filter out short words (≤4 chars) and stopwords.
/// 4. Count word frequency.
/// 5. Return the top [maxTopics] by frequency.
class TopicExtractor {
  TopicExtractor._();

  // ── Stopword list ──────────────────────────────────────────────────────────

  static const _stopwords = {
    'about', 'above', 'after', 'again', 'against', 'also', 'although',
    'always', 'among', 'and', 'another', 'around', 'because', 'before',
    'being', 'below', 'between', 'could', 'does', 'doing', 'done',
    'during', 'each', 'either', 'enough', 'every', 'found', 'from',
    'given', 'going', 'have', 'having', 'here', 'however', 'into',
    'just', 'know', 'like', 'made', 'make', 'might', 'more', 'most',
    'much', 'need', 'never', 'next', 'only', 'other', 'our', 'over',
    'really', 'right', 'same', 'since', 'some', 'still', 'such',
    'than', 'that', 'their', 'them', 'then', 'there', 'these', 'they',
    'thing', 'think', 'this', 'those', 'though', 'through', 'time',
    'today', 'under', 'until', 'upon', 'very', 'want', 'were', 'what',
    'when', 'where', 'which', 'while', 'will', 'with', 'within',
    'would', 'your',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Extracts the top [maxTopics] topics from [recentMessages].
  ///
  /// Returns an empty list if no meaningful topics are found.
  static List<String> extract(
    List<Message> recentMessages, {
    int maxTopics = 3,
  }) {
    if (recentMessages.isEmpty) return [];

    // Concatenate all non-pass message content.
    final allText = recentMessages
        .where((m) => !m.isPass && !m.isEphemeral)
        .map((m) => m.content)
        .join(' ');

    // Tokenise: split on non-alphabetic characters, lowercase.
    final words = allText
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.length > 4 && !_stopwords.contains(w))
        .toList();

    if (words.isEmpty) return [];

    // Count word frequency.
    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }

    // Sort by frequency descending, deduplicated.
    final sorted = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

    return sorted.take(maxTopics).toList();
  }
}
