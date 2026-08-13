/// AuditLog — singleton append-only log of all tool invocations.
///
/// This file has zero Flutter imports — pure Dart only.
library audit_log;

import 'dart:async';

import 'audit_entry.dart';
import 'audit_persistence.dart';

export 'audit_entry.dart';

// ---------------------------------------------------------------------------
// AuditLog
// ---------------------------------------------------------------------------

/// Singleton audit log. Records every tool call attempt.
class AuditLog {
  AuditLog._();

  static final AuditLog instance = AuditLog._();

  final List<AuditEntry> _entries = [];

  final StreamController<AuditEntry> _streamController =
      StreamController<AuditEntry>.broadcast();

  bool _loaded = false;

  /// Broadcast stream of newly appended [AuditEntry] objects.
  Stream<AuditEntry> get entryStream => _streamController.stream;

  /// All entries currently in memory.
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Loads existing entries from disk (call once on startup).
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    final persisted = await AuditPersistence.loadAll();
    _entries.addAll(persisted);
  }

  /// Records [entry] to memory and persists it.
  Future<void> record(AuditEntry entry) async {
    _entries.add(entry);
    if (!_streamController.isClosed) _streamController.add(entry);
    await AuditPersistence.append(entry);
  }

  /// Returns all entries for [characterName].
  List<AuditEntry> queryByCharacter(String characterName) =>
      _entries.where((e) => e.characterName == characterName).toList();

  /// Returns all entries for [sessionName].
  List<AuditEntry> queryBySession(String sessionName) =>
      _entries.where((e) => e.sessionName == sessionName).toList();

  /// Returns all entries for [toolTag].
  List<AuditEntry> queryByTool(String toolTag) =>
      _entries.where((e) => e.toolTag == toolTag).toList();

  /// Clears all entries from memory and disk.
  Future<void> clearAll() async {
    _entries.clear();
    await AuditPersistence.clear();
  }
}
