// SessionExporter — assembles session artefacts into a zip archive in memory.
//
// This file has zero Flutter imports — pure Dart only.

import 'package:archive/archive.dart';

// ---------------------------------------------------------------------------
// SessionExporter
// ---------------------------------------------------------------------------

/// Builds a zip archive in memory containing all session export artefacts.
///
/// Returns the zip bytes as `List<int>`.  The caller is responsible for
/// writing them to disk or sharing them.
class SessionExporter {
  const SessionExporter();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Assembles the archive and returns the zip bytes.
  ///
  /// Parameters:
  /// - [sessionName]        — used as the top-level folder name inside the zip.
  /// - [conversationText]   — plain-text transcript (from ConversationFormatter).
  /// - [analyticsJson]      — optional JSON analytics snapshot.
  /// - [researchReportMd]   — optional Markdown research report.
  /// - [auditCsv]           — optional CSV audit log.
  List<int> export({
    required String sessionName,
    required String conversationText,
    String? analyticsJson,
    String? researchReportMd,
    String? auditCsv,
  }) {
    final archive = Archive();
    final folder = _sanitiseName(sessionName);

    _addText(archive, '$folder/conversation.txt', conversationText);

    if (analyticsJson != null && analyticsJson.isNotEmpty) {
      _addText(archive, '$folder/analytics.json', analyticsJson);
    }
    if (researchReportMd != null && researchReportMd.isNotEmpty) {
      _addText(archive, '$folder/research_report.md', researchReportMd);
    }
    if (auditCsv != null && auditCsv.isNotEmpty) {
      _addText(archive, '$folder/audit.csv', auditCsv);
    }

    return ZipEncoder().encode(archive) ?? [];
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _addText(Archive archive, String path, String content) {
    final bytes = _toBytes(content);
    archive.addFile(
      ArchiveFile(path, bytes.length, bytes),
    );
  }

  static List<int> _toBytes(String text) {
    return text.codeUnits;
  }

  static String _sanitiseName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-]'), '_');
  }
}
