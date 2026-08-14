/// AuditPersistence — append-only NDJSON audit log file.
///
/// This file has zero Flutter imports — pure Dart only.
library audit_persistence;

import 'dart:convert';
import 'dart:io';

import '../paths/app_paths.dart';
import 'audit_entry.dart';

// ---------------------------------------------------------------------------
// AuditPersistence
// ---------------------------------------------------------------------------

/// Handles NDJSON append/read for the audit log.
class AuditPersistence {
  AuditPersistence._();

  static String _path() => AppPaths.audit;

  /// Appends [entry] as a single JSON line to the audit file.
  static Future<void> append(AuditEntry entry) async {
    try {
      final file = File(_path());
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString('${entry.toNdJsonLine()}\n',
          mode: FileMode.append);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Reads all entries from the audit file.
  ///
  /// Lines that fail to parse are skipped.
  static Future<List<AuditEntry>> loadAll() async {
    final file = File(_path());
    if (!await file.exists()) return [];
    try {
      final lines = await file.readAsLines();
      final entries = <AuditEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          entries.add(
            AuditEntry.fromJson(json.decode(line) as Map<String, dynamic>),
          );
        } catch (_) {
          // Skip malformed lines.
        }
      }
      return entries;
    } catch (_) {
      return [];
    }
  }

  /// Deletes the audit file.
  static Future<void> clear() async {
    final file = File(_path());
    if (await file.exists()) {
      await file.delete();
    }
  }
}
