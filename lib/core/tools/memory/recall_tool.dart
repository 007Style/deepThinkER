/// RecallTool — AgentTool that queries the character's MemoryStore.
///
/// Tag: [RECALL: topic]
///
/// This file has zero Flutter imports — pure Dart only.
library recall_tool;

import '../agent_tool.dart';
import '../tool_result.dart';
import '../../memory/memory_store.dart';
import '../../trust/trust_score.dart';

// ---------------------------------------------------------------------------
// RecallTool
// ---------------------------------------------------------------------------

/// Queries a character's memory store and returns matching entries.
///
/// The LLM emits `[RECALL: topic]`.
/// Up to 5 matching entries are returned as a bullet list.
class RecallTool implements AgentTool {
  @override
  String get tag => 'RECALL';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Memory recall is not available.';

  @override
  bool get requiresTrust => false;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final topic = argument.trim();
    final store = MemoryStoreRegistry.storeFor(characterName);
    final matches = topic.isEmpty
        ? store.entries.reversed.take(5).toList()
        : store.queryByTopic(topic).take(5).toList();

    if (matches.isEmpty) {
      return ToolResult.success(
        tag: tag,
        output: '[RECALL: no memories found for "$topic"]',
        characterName: characterName,
      );
    }

    final buf = StringBuffer('[RECALLED MEMORIES for $characterName]:\n');
    for (final m in matches) {
      buf.writeln('• ${m.content}');
    }

    return ToolResult.success(
      tag: tag,
      output: buf.toString().trimRight(),
      characterName: characterName,
    );
  }
}
