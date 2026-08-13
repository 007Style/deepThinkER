/// RememberTool — AgentTool that stores a fact in the character's MemoryStore.
///
/// Tag: [REMEMBER: fact]
///
/// This file has zero Flutter imports — pure Dart only.
library remember_tool;

import '../agent_tool.dart';
import '../tool_result.dart';
import '../../memory/memory_entry.dart';
import '../../memory/memory_persistence.dart';
import '../../memory/memory_store.dart';
import '../../trust/trust_score.dart';

// ---------------------------------------------------------------------------
// RememberTool
// ---------------------------------------------------------------------------

/// Stores a new memory for the invoking character.
///
/// The LLM emits `[REMEMBER: some fact to remember]`.
/// The tool creates a [MemoryEntry] and persists it.
class RememberTool implements AgentTool {
  @override
  String get tag => 'REMEMBER';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Memory storage is not available.';

  @override
  bool get requiresTrust => false;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final content = argument.trim();
    if (content.isEmpty) {
      return ToolResult.success(
        tag: tag,
        output: '[REMEMBER: empty content — nothing stored]',
        characterName: characterName,
      );
    }

    final entry = MemoryEntry.create(
      characterName: characterName,
      content: content,
      source: MemorySource.explicit,
    );

    final store = MemoryStoreRegistry.storeFor(characterName);
    store.add(entry);

    // Persist asynchronously — don't await to keep inference latency low.
    MemoryPersistence.save(characterName, store).ignore();

    return ToolResult.success(
      tag: tag,
      output: 'Memory stored.',
      characterName: characterName,
    );
  }
}
