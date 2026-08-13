/// FileToolConfig — configuration for the file read/write tools.
///
/// This file has zero Flutter imports — pure Dart only.
library file_tool_config;

import 'dart:io';

// ---------------------------------------------------------------------------
// FileToolConfig
// ---------------------------------------------------------------------------

/// Configures the workspace directory for file tools.
class FileToolConfig {
  static FileToolConfig? _instance;

  /// Singleton accessor.
  static FileToolConfig get instance =>
      _instance ??= FileToolConfig._default();

  /// The workspace directory path.
  String workspacePath;

  FileToolConfig._default()
      : workspacePath = _defaultPath();

  FileToolConfig({required this.workspacePath});

  static String _defaultPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/Documents/deepThinkER/workspace';
  }

  /// Resolves [relativePath] against [workspacePath] and returns the absolute path.
  ///
  /// Returns `null` if the resolved path escapes the workspace (path traversal).
  String? resolveSafe(String relativePath) {
    // Normalise without resolving symlinks (file may not exist yet).
    final rawPath = '$workspacePath/$relativePath';
    // Use Uri to normalise (collapses ../ etc.) without filesystem access.
    final uri = Uri.file(rawPath).normalizePath();
    final resolved = uri.toFilePath();
    final wsNorm = workspacePath.replaceAll(RegExp(r'[/\\]+$'), '');
    if (!resolved.startsWith(wsNorm)) return null;
    return resolved;
  }

  /// Ensures the workspace directory exists.
  Future<void> ensureWorkspaceExists() async {
    final dir = Directory(workspacePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
