/// AppPaths — single source of truth for all on-disk paths used by deepThinkER.
///
/// On macOS  : ~/Library/Application Support/deepThinkER/
/// On Windows: %APPDATA%\deepThinkER\
///
/// Using ~/Library/Application Support avoids the macOS TCC privacy prompt
/// that fires when any app first touches ~/Documents.
///
/// This file has zero Flutter imports — pure Dart only.
library app_paths;

import 'dart:io';

// ---------------------------------------------------------------------------
// AppPaths
// ---------------------------------------------------------------------------

/// Returns platform-appropriate paths for all deepThinkER data files.
class AppPaths {
  AppPaths._();

  /// The root data directory for deepThinkER.
  ///
  /// macOS  : ~/Library/Application Support/deepThinkER
  /// Windows: %APPDATA%\deepThinkER
  static String get base {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      return '$home/Library/Application Support/deepThinkER';
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '.';
      return '$appData\\deepThinkER';
    }
    // Linux / fallback
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.local/share/deepThinkER';
  }

  static String get sessions    => '$base/sessions';
  static String get memory      => '$base/memory';
  static String get analytics   => '$base/analytics';
  static String get reports     => '$base/reports';
  static String get exports     => '$base/exports';
  static String get workspace   => '$base/workspace';

  static String get settings    => '$base/settings.json';
  static String get stats       => '$base/stats.json';
  static String get participantPrefs => '$base/participant_prefs.json';
  static String get persona     => '$base/persona.json';
  static String get customCharacters => '$base/custom_characters.json';
  static String get relationships    => '$base/relationships.json';
  static String get trust       => '$base/trust.json';
  static String get whitelist   => '$base/whitelist.json';
  static String get audit       => '$base/audit.ndjson';
}
