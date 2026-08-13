/// SettingsPersistence — loads and saves AppSettings to disk.
///
/// Stores settings as JSON in `~/Documents/deepThinkER/settings.json`.
///
/// This file has zero Flutter imports — pure Dart only.
library settings_persistence;

import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';

// ---------------------------------------------------------------------------
// SettingsPersistence
// ---------------------------------------------------------------------------

/// Reads and writes [AppSettings] to `~/Documents/deepThinkER/settings.json`.
class SettingsPersistence {
  /// The directory used to store the settings file.
  static String get _dirPath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/Documents/deepThinkER';
  }

  static String get _filePath => '$_dirPath/settings.json';

  /// Loads settings from disk.
  ///
  /// Returns [AppSettings] defaults when the file does not exist or is
  /// malformed.
  Future<AppSettings> load() async {
    try {
      final file = File(_filePath);
      if (!await file.exists()) return const AppSettings();
      final raw = await file.readAsString();
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Saves [settings] to disk.
  ///
  /// Creates the parent directory if it does not exist.
  Future<void> save(AppSettings settings) async {
    final dir = Directory(_dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(_filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
