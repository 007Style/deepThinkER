/// Handles reading and writing trust scores to disk.
///
/// Storage location:
/// - macOS:   `~/Documents/deepThinkER/trust.json`
/// - Windows: `%USERPROFILE%\Documents\deepThinkER\trust.json`
///
/// This file has zero Flutter imports — pure Dart only.
library trust_persistence;

import 'dart:convert';
import 'dart:io';

import 'trust_score.dart';

// ---------------------------------------------------------------------------
// TrustPersistence
// ---------------------------------------------------------------------------

/// Reads and writes the [TrustScore] map to `trust.json`.
///
/// The JSON format is a map keyed by character name:
/// ```json
/// {
///   "WATSON": { "characterName": "WATSON", "score": 72.5, ... },
///   "DEEP":   { ... },
///   ...
/// }
/// ```
class TrustPersistence {
  // -------------------------------------------------------------------------
  // Path helpers
  // -------------------------------------------------------------------------

  static String _baseDir() {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Cannot determine home directory: '
        'neither HOME nor USERPROFILE is set.',
      );
    }
    return [home, 'Documents', 'deepThinkER'].join(Platform.pathSeparator);
  }

  static String _trustPath() =>
      [_baseDir(), 'trust.json'].join(Platform.pathSeparator);

  static Future<void> _ensureDir() async {
    final dir = Directory(_baseDir());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Loads all persisted trust scores.
  ///
  /// Returns an empty map if the file doesn't exist or is malformed.
  static Future<Map<String, TrustScore>> load() async {
    final file = File(_trustPath());
    if (!await file.exists()) return {};

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map(
        (key, value) => MapEntry(
          key,
          TrustScore.fromJson(value as Map<String, dynamic>),
        ),
      );
    } on FormatException {
      // Corrupted file — start fresh rather than crashing.
      return {};
    }
  }

  /// Persists the full [scores] map to disk.
  ///
  /// Writes atomically via a temp file + rename to avoid partial writes.
  static Future<void> save(Map<String, TrustScore> scores) async {
    await _ensureDir();

    final json = scores.map((key, score) => MapEntry(key, score.toJson()));
    final encoded = const JsonEncoder.withIndent('  ').convert(json);

    final path = _trustPath();
    final tempPath = '$path.tmp';
    final tempFile = File(tempPath);

    await tempFile.writeAsString(encoded);
    await tempFile.rename(path);
  }
}
