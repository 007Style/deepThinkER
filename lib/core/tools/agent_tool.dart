// Abstract interface for all deepThinkER agent tools.
//
// Every tool — network, shell, or future capability — implements this
// interface and is registered in [ToolRegistry] at startup.
//
// This file has zero Flutter imports — pure Dart only.

import '../trust/trust_score.dart';
import 'tool_result.dart';

export 'tool_result.dart';

// ---------------------------------------------------------------------------
// AgentTool
// ---------------------------------------------------------------------------

/// An executable capability that an AI character can invoke via tag syntax.
///
/// The LLM emits `[TAG: argument]` in its response stream.  The
/// [ToolCallInterceptor] detects this, resolves the tool via [ToolRegistry],
/// checks eligibility, and calls [execute].
///
/// ### Implementing a tool
/// ```dart
/// class MyTool implements AgentTool {
///   @override String get tag => 'MY_TOOL';
///   @override bool get enabled => true;
///   @override String get disabledMessage => 'My tool is disabled.';
///   @override bool get requiresTrust => false;
///   @override TrustTier get minimumTrust => TrustTier.low;
///   @override Future<ToolResult> execute(String argument, String characterName) async {
///     return ToolResult.success(tag: tag, output: 'done', characterName: characterName);
///   }
/// }
/// ```
abstract class AgentTool {
  /// The tag name the LLM emits — e.g. `'SEARCH'`.
  ///
  /// Must be all-uppercase with no whitespace.
  String get tag;

  /// Whether this tool is currently active.
  ///
  /// Disabled tools return [ToolResult.disabled] without executing.
  bool get enabled;

  /// Message returned to the LLM when the tool is disabled.
  String get disabledMessage;

  /// Whether [RateLimiter] checks apply before this tool executes.
  bool get requiresTrust;

  /// The minimum [TrustTier] a character must have to use this tool.
  TrustTier get minimumTrust;

  /// Executes the tool with [argument] on behalf of [characterName].
  Future<ToolResult> execute(String argument, String characterName);
}
