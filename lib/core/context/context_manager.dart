/// Context manager for deepThink.
///
/// Tracks estimated token usage per participant and triggers context-window
/// resets when a participant approaches its limit. Also builds the seed
/// message list used to prime a fresh context window.
///
/// This file has zero Flutter imports — pure Dart only.
library context_manager;

import '../conversation/conversation_log.dart';
import '../conversation/message.dart';

// ---------------------------------------------------------------------------
// ContextManager
// ---------------------------------------------------------------------------

/// Tracks per-participant token usage and drives context-reset logic.
///
/// Token counts are estimated using the rule of thumb **1 token ≈ 4 characters**.
///
/// A reset is triggered when a participant's estimated token count reaches
/// **90 %** of [contextWindowSize].
///
/// ```dart
/// final ctx = ContextManager();
/// ctx.recordTokens('WATSON', 512);
/// if (ctx.needsReset('WATSON', 8192)) {
///   final seed = ctx.buildResetSeed(log, participantNames);
///   ctx.reset('WATSON');
/// }
/// ```
class ContextManager {
  final Map<String, int> _tokenCounts = {};

  /// Estimated characters-per-token ratio used for token count approximation.
  static const int _charsPerToken = 4;

  /// Fraction of the context window at which a reset is triggered.
  static const double _resetThreshold = 0.90;

  /// Maximum number of messages carried forward when building a reset seed.
  static const int _seedMaxMessages = 10;

  /// Records [tokenCount] additional tokens consumed by [participantName].
  ///
  /// Counts are accumulated across calls — call [reset] to clear.
  void recordTokens(String participantName, int tokenCount) {
    _tokenCounts[participantName] =
        (_tokenCounts[participantName] ?? 0) + tokenCount;
  }

  /// Estimates and records token usage from the character length of [text].
  ///
  /// Useful when the Ollama API does not return an exact token count.
  void recordFromText(String participantName, String text) {
    final estimated = (text.length / _charsPerToken).ceil();
    recordTokens(participantName, estimated);
  }

  /// Returns the current estimated token count for [participantName].
  int tokenCount(String participantName) =>
      _tokenCounts[participantName] ?? 0;

  /// Returns `true` when [participantName]'s token count has reached or
  /// exceeded 90 % of [contextWindowSize].
  bool needsReset(String participantName, int contextWindowSize) {
    final count = _tokenCounts[participantName] ?? 0;
    return count >= (contextWindowSize * _resetThreshold).floor();
  }

  /// Resets the token count for [participantName] to zero.
  void reset(String participantName) {
    _tokenCounts.remove(participantName);
  }

  /// Builds the context-reset seed: the last 2 non-pass messages from each
  /// participant in [participantNames], sorted chronologically, capped at
  /// [_seedMaxMessages] messages total.
  ///
  /// This seed is prepended to a fresh context window so the AI has minimal
  /// but meaningful history after a reset.
  List<Message> buildResetSeed(
    ConversationLog log,
    List<String> participantNames,
  ) {
    final seed = log.getLastNPerParticipant(participantNames, 2);
    // Cap at the maximum seed size.
    if (seed.length <= _seedMaxMessages) return seed;
    return seed.sublist(seed.length - _seedMaxMessages);
  }
}
