/// Persistence for per-character model and prompt preferences.
///
/// Saves and loads the user's chosen model ID and master prompt for each of
/// the four AI characters so that the startup config screen remembers the
/// last state on every launch.
///
/// File location: ~/Documents/deepThink/participant_prefs.json
/// This file has zero Flutter imports — pure Dart only.
library participant_prefs;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../conversation/participant.dart';

// ---------------------------------------------------------------------------
// ParticipantPrefs
// ---------------------------------------------------------------------------

class ParticipantPrefs {
  ParticipantPrefs._();

  // -------------------------------------------------------------------------
  // Path helper
  // -------------------------------------------------------------------------

  static String _prefsPath() {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null || home.isEmpty) return '';
    final base = [home, 'Documents', 'deepThinkER'].join(Platform.pathSeparator);
    return [base, 'participant_prefs.json'].join(Platform.pathSeparator);
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Saves the [assignedModelId] and [masterPrompt] for each participant.
  ///
  /// Keyed by participant name so the order doesn't matter.
  static Future<void> save(List<Participant> participants) async {
    final path = _prefsPath();
    if (path.isEmpty) return;

    try {
      // Ensure the directory exists.
      await Directory(File(path).parent.path).create(recursive: true);

      final map = <String, Map<String, String>>{};
      for (final p in participants) {
        map[p.name] = {
          'modelId': p.assignedModelId,
          'masterPrompt': p.masterPrompt,
        };
      }
      await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
      );
    } catch (_) {
      // Non-fatal — next launch just uses defaults.
    }
  }

  /// Loads saved preferences and applies them to [participants] in place.
  ///
  /// Only [assignedModelId] and [masterPrompt] are overwritten.
  /// If the file does not exist or is corrupt, participants keep their
  /// default values.
  static Future<void> load(List<Participant> participants) async {
    final path = _prefsPath();
    if (path.isEmpty) return;

    try {
      final file = File(path);
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;

      for (final p in participants) {
        final entry = map[p.name] as Map<String, dynamic>?;
        if (entry == null) continue;
        final modelId = entry['modelId'] as String?;
        final prompt = entry['masterPrompt'] as String?;
        if (modelId != null && modelId.isNotEmpty) p.assignedModelId = modelId;
        if (prompt != null && prompt.isNotEmpty) p.masterPrompt = prompt;
      }
    } catch (_) {
      // Corrupt file — silently fall back to defaults.
    }
  }

  /// Deletes the saved preferences file.
  ///
  /// Called by the "Reset to Defaults" button.
  static Future<void> clear() async {
    final path = _prefsPath();
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
