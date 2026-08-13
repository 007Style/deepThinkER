/// ShellTool — registered stub for [SHELL: command] tool calls.
///
/// Shell access is disabled in this version.  The tool is fully registered
/// in [ToolRegistry] so the interceptor and UI can acknowledge the tag, but
/// [execute] always returns [ToolResult.disabled].
///
/// To enable shell access in a future version: set [ShellConfig.enabled] to
/// `true`, populate [ShellConfig.allowedCommands], and implement the actual
/// process-spawn logic in [execute].
///
/// This file has zero Flutter imports — pure Dart only.
library shell_tool;

import '../../trust/trust_score.dart';
import '../agent_tool.dart';
import '../tool_result.dart';
import 'shell_config.dart';

// ---------------------------------------------------------------------------
// ShellTool
// ---------------------------------------------------------------------------

/// Implements `[SHELL: command]` — currently always returns disabled.
class ShellTool implements AgentTool {
  final ShellConfig config;

  ShellTool({ShellConfig? config}) : config = config ?? const ShellConfig();

  @override
  String get tag => 'SHELL';

  @override
  bool get enabled => config.enabled; // false in this version

  @override
  String get disabledMessage =>
      'Shell access is not yet enabled in this version.';

  @override
  bool get requiresTrust => config.requiresHighTrust;

  @override
  TrustTier get minimumTrust => TrustTier.high;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    // Always disabled — future implementation replaces this body.
    return ToolResult.disabled(
      tag: tag,
      reason: disabledMessage,
      characterName: characterName,
    );
  }
}
