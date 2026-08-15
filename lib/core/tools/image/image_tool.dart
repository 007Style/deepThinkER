// ImageTool — AgentTool that analyses images from the workspace.
//
// Tag: [IMAGE: filename]
//
// This file has zero Flutter imports — pure Dart only.

import '../../tools/file/file_tool_config.dart';
import '../agent_tool.dart';
import '../../trust/trust_score.dart';
import 'vision_client.dart';

// ---------------------------------------------------------------------------
// ImageTool
// ---------------------------------------------------------------------------

/// Analyses an image file from the workspace using the vision model.
class ImageTool implements AgentTool {
  final VisionClient _vision;

  ImageTool({VisionClient? vision})
      : _vision = vision ?? VisionClient();

  @override
  String get tag => 'IMAGE';

  @override
  bool get enabled => true;

  @override
  String get disabledMessage => 'Image analysis is not available.';

  @override
  bool get requiresTrust => false;

  @override
  TrustTier get minimumTrust => TrustTier.low;

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    final filename = argument.trim();
    final config = FileToolConfig.instance;
    await config.ensureWorkspaceExists();

    final safePath = config.resolveSafe(filename);
    if (safePath == null) {
      return ToolResult.success(
        tag: tag,
        output: '[IMAGE_ERROR: path escapes workspace]',
        characterName: characterName,
      );
    }

    final description = await _vision.describe(
      safePath,
      'Describe this image in detail.',
    );

    return ToolResult.success(
      tag: tag,
      output: '[IMAGE_RESULT]: $description',
      characterName: characterName,
    );
  }
}
