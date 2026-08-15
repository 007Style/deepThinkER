// NetworkFetchTool — executes [FETCH: url] tool calls.
//
// Delegates to [NetworkFetcher.fetch] and returns the raw truncated HTML
// as the tool output.
//
// This file has zero Flutter imports — pure Dart only.

import '../../network/domain_whitelist.dart';
import '../../network/fetch_result.dart';
import '../../network/network_fetcher.dart';
import '../../trust/trust_score.dart';
import '../agent_tool.dart';

// ---------------------------------------------------------------------------
// NetworkFetchTool
// ---------------------------------------------------------------------------

/// Implements `[FETCH: url]` — fetches a URL directly.
class NetworkFetchTool implements AgentTool {
  final NetworkFetcher fetcher;

  NetworkFetchTool(this.fetcher);

  @override
  String get tag => 'FETCH';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Direct URL fetching is not available.';

  @override
  bool get requiresTrust => true;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    // Check domain whitelist before fetching.
    if (!DomainWhitelist.instance.isAllowed(argument)) {
      final hostname = DomainWhitelist.instance.hostnameOf(argument);
      return ToolResult.success(
        tag: tag,
        output: '[FETCH_BLOCKED: domain $hostname is not in the whitelist]',
        characterName: characterName,
      );
    }
    final result = await fetcher.fetch(argument, characterName);
    return _toToolResult(result);
  }

  ToolResult _toToolResult(FetchResult fetch) {
    if (!fetch.isSuccess) {
      return ToolResult.success(
        tag: tag,
        output: '[FETCH ERROR: ${fetch.errorMessage}]',
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
