/// FileWriteTool — AgentTool that writes files to the workspace.
///
/// Tag: [FILE_WRITE: path | content]
/// Argument format: "relative/path | content to write"
///
/// Does NOT overwrite existing files — returns an error if file exists.
///
/// This file has zero Flutter imports — pure Dart only.
library file_write_tool;

import 'dart:io';

import '../agent_tool.dart';
import '../tool_result.dart';
import '../../trust/trust_score.dart';
import 'file_tool_config.dart';

// ---------------------------------------------------------------------------
// FileWriteTool
// ---------------------------------------------------------------------------

/// Writes content to a new file in the configured workspace directory.
///
/// Will not overwrite an existing file.
class FileWriteTool implements AgentTool {
  @override
  String get tag => 'FILE_WRITE';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'File write access is not available.';

  @override
  bool get requiresTrust => true;

  @override
  TrustTier get minimumTrust => TrustTier.high;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final config = FileToolConfig.instance;
    await config.ensureWorkspaceExists();

    // Split argument on the first " | ".
    final separatorIndex = argument.indexOf(' | ');
    if (separatorIndex == -1) {
      return ToolResult.success(
        tag: tag,
        output: '[FILE_WRITE_ERROR: invalid format — use "path | content"]',
        characterName: characterName,
      );
    }

    final relativePath = argument.substring(0, separatorIndex).trim();
    final content = argument.substring(separatorIndex + 3);

    final safePath = config.resolveSafe(relativePath);
    if (safePath == null) {
      return ToolResult.success(
        tag: tag,
        output: '[FILE_WRITE_ERROR: path escapes workspace]',
        characterName: characterName,
      );
    }

    try {
      final file = File(safePath);
      if (await file.exists()) {
        return ToolResult.success(
          tag: tag,
          output: '[FILE_WRITE_ERROR: file already exists: $relativePath]',
          characterName: characterName,
        );
      }
      // Ensure parent directories exist.
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return ToolResult.success(
        tag: tag,
        output: 'File written: $relativePath',
        characterName: characterName,
      );
    } catch (e) {
      return ToolResult.success(
        tag: tag,
        output: '[FILE_WRITE_ERROR: $e]',
        characterName: characterName,
      );
    }
  }
}
