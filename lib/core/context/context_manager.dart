// Context manager for deepThink.
//
// Tracks estimated token usage per participant and triggers context-window
// resets when a participant approaches its limit. Also builds the seed
// message list used to prime a fresh context window.
//
// This file has zero Flutter imports — pure Dart only.

import '../conversation/conversation_log.dart';
import '../conversation/message.dart';
import '../memory/memory_store.dart';

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

  /// Builds the context-reset seed: the last 2 non-pass, non-ephemeral
  /// messages from each participant in [participantNames], sorted
  /// chronologically, capped at [_seedMaxMessages] messages total.
  ///
  /// Ephemeral messages (tool-result injections) are excluded so they do not
  /// burn tokens in the fresh context window.
  ///
  /// This seed is prepended to a fresh context window so the AI has minimal
  /// but meaningful history after a reset.
  List<Message> buildResetSeed(
    ConversationLog log,
    List<String> participantNames,
  ) {
    final seed = log
        .getLastNPerParticipant(participantNames, 2)
        .where((m) => !m.isEphemeral)
        .toList();

    // Append per-character memory summaries as ephemeral system messages so
    // each worker has a brief memory recap after a context reset.
    for (final name in participantNames) {
      // Skip pseudo-participants like 'User' or 'System'.
      if (name == 'User' || name == 'System') continue;
      final store = MemoryStoreRegistry.storeFor(name);
      final summary = store.recentSummary(n: 5);
      if (summary.isNotEmpty) {
        seed.add(Message(
          participantName: 'System',
          content: '[MEMORY_SUMMARY for $name]:\n$summary',
          isUser: false,
          isEphemeral: true,
        ));
      }
    }

    // Cap at the maximum seed size.
    if (seed.length <= _seedMaxMessages) return seed;
    return seed.sublist(seed.length - _seedMaxMessages);
  }
}
