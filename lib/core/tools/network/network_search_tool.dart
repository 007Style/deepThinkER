// NetworkSearchTool — executes [SEARCH: query] tool calls.
//
// Delegates to [NetworkFetcher.search] and returns the raw truncated HTML
// as the tool output.
//
// This file has zero Flutter imports — pure Dart only.

import '../../trust/trust_score.dart';
import '../agent_tool.dart';
import '../../network/fetch_result.dart';
import '../../network/network_fetcher.dart';

// ---------------------------------------------------------------------------
// NetworkSearchTool
// ---------------------------------------------------------------------------

/// Implements `[SEARCH: query]` — fetches DuckDuckGo HTML for a query.
class NetworkSearchTool implements AgentTool {
  final NetworkFetcher fetcher;

  NetworkSearchTool(this.fetcher);

  @override
  String get tag => 'SEARCH';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Web search is not available.';

  @override
  bool get requiresTrust => true;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final result = await fetcher.search(argument, characterName);
    return _toToolResult(result);
  }

  ToolResult _toToolResult(FetchResult fetch) {
    if (!fetch.isSuccess) {
      return ToolResult.success(
        tag: tag,
        output: '[SEARCH ERROR: ${fetch.errorMessage}]',
        characterName: fetch.characterName,
      );
    }
    final truncNote = fetch.truncated ? ' [truncated]' : '';
    return ToolResult.success(
      tag: tag,
      output: fetch.rawHtml + truncNote,
      characterName: fetch.characterName,
    );
  }
}
