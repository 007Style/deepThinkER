// RelationshipPersistence — read/write relationship matrix to disk.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:convert';
import 'dart:io';

import '../paths/app_paths.dart';
import 'relationship_matrix.dart';

// ---------------------------------------------------------------------------
// RelationshipPersistence
// ---------------------------------------------------------------------------

/// Handles reading and writing the relationship matrix file.
class RelationshipPersistence {
  RelationshipPersistence._();

  static String _path() => AppPaths.relationships;

  /// Loads relationship scores from disk.
  ///
  /// Returns an empty list if the file does not exist or cannot be parsed.
  static Future<List<RelationshipScore>> load() async {
    final file = File(_path());
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => RelationshipScore.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves all scores from [matrix] to disk.
  static Future<void> save(RelationshipMatrix matrix) async {
    final dir = File(_path()).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final list = matrix.allScores.map((s) => s.toJson()).toList();
    await File(_path()).writeAsString(json.encode(list));
  }
}
