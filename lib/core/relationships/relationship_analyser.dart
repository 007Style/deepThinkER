// RelationshipAnalyser — monitors conversation messages and updates scores.
//
// This file has zero Flutter imports — pure Dart only.

import '../conversation/message.dart';
import 'relationship_matrix.dart';

// ---------------------------------------------------------------------------
// RelationshipAnalyser
// ---------------------------------------------------------------------------

/// Analyses each new [Message] and applies relationship score deltas based on
/// signals detected in the message content.
///
/// Signals:
/// - Character A's message mentions Character B + agreement keyword → +3
/// - Character A's message mentions Character B + challenge keyword → -2
/// - (Prolonged ignoring handled externally via timer — not implemented here
///   to keep this class simple and testable.)
class RelationshipAnalyser {
  final RelationshipMatrix matrix;

  static const _challengeKeywords = [
    'wrong',
    'disagree',
    'incorrect',
    'no,',
    'actually',
    'but',
    'however',
  ];

  static const _agreementKeywords = [
    'agree',
    'exactly',
    'right',
    'good point',
    'yes',
    'correct',
  ];

  static const _allCharacters = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];

  RelationshipAnalyser({required this.matrix});

  /// Processes [message] and applies any relationship deltas.
  void onMessage(Message message) {
    if (message.isEphemeral || message.isUser) return;

    final speaker = message.participantName.toUpperCase();
    if (!_allCharacters.contains(speaker)) return;

    final content = message.content.toLowerCase();
    final hasAgreement = _containsAny(content, _agreementKeywords);
    final hasChallenge = _containsAny(content, _challengeKeywords);

    for (final other in _allCharacters) {
      if (other == speaker) continue;
      final otherLower = other.toLowerCase();

      // Check if this message mentions the other character by name.
      if (!content.contains(otherLower)) continue;

      if (hasAgreement) {
        matrix.applyDelta(speaker, other, 3);
      }
      if (hasChallenge) {
        matrix.applyDelta(speaker, other, -2);
      }
    }
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);
}
