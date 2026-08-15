// ToolResult — value object returned by every AgentTool execution.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// ToolResult
// ---------------------------------------------------------------------------

/// The outcome of an [AgentTool.execute] call.
class ToolResult {
  /// The tool tag that produced this result (e.g. `'SEARCH'`).
  final String tag;

  /// The output text injected into the LLM context.
  final String output;

  /// The character on whose behalf the tool was invoked.
  final String characterName;

  /// Whether the tool was disabled at the time of invocation.
  final bool wasDisabled;

  /// Whether the call was rejected by the rate limiter.
  final bool wasRateLimited;

  /// When this result was produced.
  final DateTime executedAt;

  const ToolResult._({
    required this.tag,
    required this.output,
    required this.characterName,
    required this.wasDisabled,
    required this.wasRateLimited,
    required this.executedAt,
  });

  /// Creates a successful tool result.
  factory ToolResult.success({
    required String tag,
    required String output,
    required String characterName,
    DateTime? executedAt,
  }) {
    return ToolResult._(
      tag: tag,
      output: output,
      characterName: characterName,
      wasDisabled: false,
      wasRateLimited: false,
      executedAt: executedAt ?? DateTime.now(),
    );
  }

  /// Creates a result indicating the tool is disabled.
  factory ToolResult.disabled({
    required String tag,
    required String reason,
    required String characterName,
    DateTime? executedAt,
  }) {
    return ToolResult._(
      tag: tag,
      output: '[Tool $tag is disabled: $reason]',
      characterName: characterName,
      wasDisabled: true,
      wasRateLimited: false,
      executedAt: executedAt ?? DateTime.now(),
    );
  }

  /// Creates a result indicating the request was rate-limited.
  factory ToolResult.rateLimited({
    required String tag,
    required String reason,
    required String characterName,
    DateTime? executedAt,
  }) {
    return ToolResult._(
      tag: tag,
      output: '[RATE_LIMITED: $reason]',
      characterName: characterName,
      wasDisabled: false,
      wasRateLimited: true,
      executedAt: executedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'ToolResult($tag, char=$characterName, '
      'disabled=$wasDisabled, rateLimited=$wasRateLimited)';
}
