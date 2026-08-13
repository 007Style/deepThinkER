// AuditLogScreen — sortable, filterable view of all tool invocations.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/audit/audit_log.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// AuditLogScreen
// ---------------------------------------------------------------------------

/// Displays all audit log entries in a sortable DataTable.
/// Supports filtering by character and tool tag, CSV export, and clear-all.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const _characters = ['', 'WATSON', 'DEEP', 'NOVA', 'SAGE'];

  List<AuditEntry> _entries = [];
  StreamSubscription<AuditEntry>? _sub;

  // Filter state
  String _charFilter = '';
  String _toolFilter = '';

  // Sort state
  int _sortColumnIndex = 4; // timestamp
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _sub = AuditLog.instance.entryStream.listen((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _entries = List.from(AuditLog.instance.entries);
    });
  }

  List<AuditEntry> _filtered() {
    return _entries.where((e) {
      if (_charFilter.isNotEmpty && e.characterName != _charFilter) {
        return false;
      }
      if (_toolFilter.isNotEmpty && e.toolTag != _toolFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort(_comparator());
  }

  Comparator<AuditEntry> _comparator() {
    switch (_sortColumnIndex) {
      case 0:
        return _sortAscending
            ? (a, b) => a.characterName.compareTo(b.characterName)
            : (a, b) => b.characterName.compareTo(a.characterName);
      case 1:
        return _sortAscending
            ? (a, b) => a.toolTag.compareTo(b.toolTag)
            : (a, b) => b.toolTag.compareTo(a.toolTag);
      case 2:
        return _sortAscending
            ? (a, b) => a.sessionName.compareTo(b.sessionName)
            : (a, b) => b.sessionName.compareTo(a.sessionName);
      case 3:
        return _sortAscending
            ? (a, b) => a.argument.compareTo(b.argument)
            : (a, b) => b.argument.compareTo(a.argument);
      default: // 4 = timestamp
        return _sortAscending
            ? (a, b) => a.timestamp.compareTo(b.timestamp)
            : (a, b) => b.timestamp.compareTo(a.timestamp);
    }
  }

  Set<String> _distinctTools() =>
      _entries.map((e) => e.toolTag).toSet();

  Future<void> _exportCsv() async {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      final path = '$home/Downloads/deepThinkER_audit.csv';
      final buf = StringBuffer(
          'id,sessionName,characterName,toolTag,argument,timestamp,'
          'wasRateLimited,wasDisabled,responseBytes\n');
      for (final e in _filtered()) {
        final arg = e.argument.replaceAll('"', '""');
        buf.writeln(
            '"${e.id}","${e.sessionName}","${e.characterName}",'
            '"${e.toolTag}","$arg",'
            '"${e.timestamp.toIso8601String()}",'
            '${e.wasRateLimited},${e.wasDisabled},${e.responseBytes}');
      }
      await File(path).writeAsString(buf.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Audit Log?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will permanently delete all audit entries.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All',
                style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuditLog.instance.clearAll();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final tools = ['', ..._distinctTools().toList()..sort()];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Audit Log',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Export CSV'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text('Clear All'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF5350),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter row
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Dropdown(
                  label: 'Character',
                  value: _charFilter,
                  items: _characters,
                  onChanged: (v) =>
                      setState(() => _charFilter = v ?? ''),
                ),
                const SizedBox(width: 12),
                _Dropdown(
                  label: 'Tool',
                  value: _toolFilter,
                  items: tools,
                  onChanged: (v) =>
                      setState(() => _toolFilter = v ?? ''),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} entries',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Table
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No audit entries.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingRowHeight: 32,
                        dataRowMinHeight: 28,
                        dataRowMaxHeight: 28,
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.surface),
                        columns: [
                          _col('Character', 0),
                          _col('Tool', 1),
                          _col('Session', 2),
                          _col('Argument', 3),
                          _col('Time', 4),
                        ],
                        rows: filtered.map((e) {
                          final ts = e.timestamp.toLocal();
                          final time =
                              '${_p(ts.hour)}:${_p(ts.minute)}:${_p(ts.second)}';
                          final arg = e.argument.length > 40
                              ? '${e.argument.substring(0, 37)}...'
                              : e.argument;
                          return DataRow(
                            color: WidgetStateProperty.resolveWith((s) {
                              if (e.wasRateLimited) {
                                return const Color(0xFF2A1A1A);
                              }
                              if (e.wasDisabled) {
                                return const Color(0xFF1A1A1A);
                              }
                              return AppColors.card;
                            }),
                            cells: [
                              DataCell(Text(e.characterName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textPrimary))),
                              DataCell(Text(e.toolTag,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent))),
                              DataCell(Text(e.sessionName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))),
                              DataCell(
                                Tooltip(
                                  message: e.argument,
                                  child: Text(arg,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ),
                              ),
                              DataCell(Text(time,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataColumn _col(String label, int index) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
      onSort: (i, asc) => setState(() {
        _sortColumnIndex = i;
        _sortAscending = asc;
      }),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// _Dropdown
// ---------------------------------------------------------------------------

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:  ',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textPrimary),
          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(e.isEmpty ? 'All' : e),
            );
          }).toList(),
          onChanged: onChanged,
          underline: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
