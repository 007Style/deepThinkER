/// ExportButton — Flutter button that triggers session export to a zip file.
library export_button;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/export/session_exporter.dart';
import '../../core/paths/app_paths.dart';

// ---------------------------------------------------------------------------
// ExportButton
// ---------------------------------------------------------------------------

/// An [ElevatedButton] that calls [SessionExporter] on press, then writes the
/// resulting zip to disk via a simple file-path prompt.
///
/// Shows a loading spinner while export is in progress.
class ExportButton extends StatefulWidget {
  /// Session name used as the zip folder and default filename.
  final String sessionName;

  /// Pre-formatted conversation text.
  final String conversationText;

  /// Optional analytics JSON string.
  final String? analyticsJson;

  /// Optional Markdown research report.
  final String? researchReportMd;

  /// Optional audit CSV.
  final String? auditCsv;

  /// Directory where the zip file will be written.
  ///
  /// Defaults to `~/Documents/deepThinkER/exports/`.
  final String? exportDirectory;

  const ExportButton({
    super.key,
    required this.sessionName,
    required this.conversationText,
    this.analyticsJson,
    this.researchReportMd,
    this.auditCsv,
    this.exportDirectory,
  });

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  bool _exporting = false;
  String? _lastPath;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
      _lastPath = null;
    });

    try {
      final bytes = const SessionExporter().export(
        sessionName: widget.sessionName,
        conversationText: widget.conversationText,
        analyticsJson: widget.analyticsJson,
        researchReportMd: widget.researchReportMd,
        auditCsv: widget.auditCsv,
      );

      final dir = widget.exportDirectory ?? AppPaths.exports;

      await Directory(dir).create(recursive: true);

      final safeName =
          widget.sessionName.replaceAll(RegExp(r'[^\w\-]'), '_');
      final path = '$dir/${safeName}_export.zip';
      await File(path).writeAsBytes(bytes);

      if (mounted) setState(() => _lastPath = path);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_exporting ? 'Exporting…' : 'Export session'),
        ),
        if (_lastPath != null) ...[
          const SizedBox(height: 4),
          Text(
            'Saved: $_lastPath',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            'Export failed: $_error',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }
}
