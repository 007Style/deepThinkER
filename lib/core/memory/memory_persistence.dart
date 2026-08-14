/// MemoryPersistence — read/write per-character memory JSON files.
///
/// This file has zero Flutter imports — pure Dart only.
library memory_persistence;

import 'dart:convert';
import 'dart:io';

import '../paths/app_paths.dart';
import 'memory_entry.dart';
import 'memory_store.dart';

// ---------------------------------------------------------------------------
// MemoryPersistence
// ---------------------------------------------------------------------------

/// Handles reading and writing per-character memory files.
class MemoryPersistence {
  MemoryPersistence._();

  static String _dir() => AppPaths.memory;

  static String _filePath(String characterName) =>
      '${_dir()}/${characterName.toUpperCase()}.json';

  /// Loads all entries for [characterName] from disk.
  ///
  /// Returns an empty list if the file does not exist or cannot be parsed.
  static Future<List<MemoryEntry>> load(String characterName) async {
    final file = File(_filePath(characterName));
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => MemoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Writes all entries from [store] to disk for [characterName].
  static Future<void> save(String characterName, MemoryStore store) async {
    final dir = Directory(_dir());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(_filePath(characterName));
    final list = store.entries.map((e) => e.toJson()).toList();
    await file.writeAsString(json.encode(list));
  }
}
