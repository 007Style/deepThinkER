/// FileReadTool — AgentTool that reads files from the workspace.
///
/// Tag: [FILE_READ: path]
///
/// This file has zero Flutter imports — pure Dart only.
library file_read_tool;

import 'dart:io';

import '../agent_tool.dart';
import '../tool_result.dart';
import '../../trust/trust_score.dart';
import 'file_tool_config.dart';

// ---------------------------------------------------------------------------
// FileReadTool
// ---------------------------------------------------------------------------

/// Reads a file from the configured workspace directory.
///
/// Path must stay within the workspace — path traversal is rejected.
/// Content is truncated to 8,000 characters.
class FileReadTool implements AgentTool {
  static const _maxChars = 8000;

  @override
  String get tag => 'FILE_READ';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'File read access is not available.';

  @override
  bool get requiresTrust => true;

  @override
  TrustTier get minimumTrust => TrustTier.mid;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final config = FileToolConfig.instance;
    await config.ensureWorkspaceExists();

    final safePath = config.resolveSafe(argument.trim());
    if (safePath == null) {
      return ToolResult.success(
        tag: tag,
        output: '[FILE_READ_ERROR: path escapes workspace]',
        characterName: characterName,
      );
    }

    try {
      final file = File(safePath);
      if (!await file.exists()) {
        return ToolResult.success(
          tag: tag,
          output: '[FILE_READ_ERROR: file not found: ${argument.trim()}]',
          characterName: characterName,
        );
      }
      final raw = await file.readAsString();
      final content = raw.length > _maxChars
          ? raw.substring(0, _maxChars) + '\n[...truncated]'
          : raw;
      return ToolResult.success(
        tag: tag,
        output: content,
        characterName: characterName,
      );
    } catch (e) {
      return ToolResult.success(
        tag: tag,
        output: '[FILE_READ_ERROR: $e]',
        characterName: characterName,
      );
    }
  }
}
