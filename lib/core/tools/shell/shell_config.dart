/// Shell tool configuration model.
///
/// This file has zero Flutter imports — pure Dart only.
library shell_config;

// ---------------------------------------------------------------------------
// ShellConfig
// ---------------------------------------------------------------------------

/// Configuration for the (stub) shell tool.
///
/// Shell access is **disabled** in this version of deepThinkER.
/// The config is defined here so the full interface is ready for a future
/// implementation that only needs to flip [enabled] to `true` and populate
/// [allowedCommands].
class ShellConfig {
  /// Whether shell access is enabled. Always `false` in this version.
  final bool enabled;

  /// Whitelist of allowed shell commands. Empty = none allowed.
  final List<String> allowedCommands;

  /// Working directory constraint for shell commands.
  final String workingDirectory;

  /// Timeout in seconds for shell commands.
  final int timeoutSeconds;

  /// Whether shell access requires [TrustTier.high].
  final bool requiresHighTrust;

  const ShellConfig({
    this.enabled = false,
    this.allowedCommands = const <String>[],
    this.workingDirectory = '~/Documents/deepThinkER/workspace',
    this.timeoutSeconds = 30,
    this.requiresHighTrust = true,
  });
}
