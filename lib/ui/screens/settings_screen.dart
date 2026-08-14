/// SettingsScreen — tabbed settings UI for deepThinkER.
library settings_screen;

import 'package:flutter/material.dart';

import '../../core/network/network_request_record.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------

/// Full-screen settings panel with five tabs:
/// Network, Tools, Safety, Display, Advanced.
class SettingsScreen extends StatefulWidget {
  /// Optional network request log from the current session.
  /// Passed in from MainScreen so the Network tab can display live history.
  final List<NetworkRequestRecord> networkLog;

  const SettingsScreen({
    this.networkLog = const [],
    super.key,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _settings = SettingsProvider.instance.current;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _save(AppSettings updated) {
    setState(() => _settings = updated);
    SettingsProvider.instance.update(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Network'),
            Tab(text: 'Tools'),
            Tab(text: 'Safety'),
            Tab(text: 'Display'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NetworkTab(
            settings: _settings,
            onChanged: _save,
            networkLog: widget.networkLog,
          ),
          _ToolsTab(settings: _settings, onChanged: _save),
          _SafetyTab(settings: _settings, onChanged: _save),
          _DisplayTab(settings: _settings, onChanged: _save),
          _AdvancedTab(settings: _settings, onChanged: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Network tab
// ---------------------------------------------------------------------------

class _NetworkTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;
  final List<NetworkRequestRecord> networkLog;

  const _NetworkTab({
    required this.settings,
    required this.onChanged,
    required this.networkLog,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Rate Limiting'),
        _LabeledRow(
          label: 'Global rate limit (calls/min)',
          child: SizedBox(
            width: 200,
            child: Slider(
              min: 1,
              max: 60,
              divisions: 59,
              value: settings.globalRateLimitPerMin.toDouble(),
              label: '${settings.globalRateLimitPerMin}',
              onChanged: (v) => onChanged(
                settings.copyWith(globalRateLimitPerMin: v.round()),
              ),
            ),
          ),
        ),
        const _SectionHeader('Workspace'),
        _LabeledRow(
          label: 'Workspace path',
          child: Expanded(
            child: Text(
              settings.workspacePath.isEmpty
                  ? '(default)'
                  : settings.workspacePath,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const _SectionHeader('Proactive Injection'),
        SwitchListTile(
          title: const Text(
            'Enable proactive web injection',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.proactiveInjectionEnabled,
          activeColor: AppColors.accent,
          onChanged: (v) =>
              onChanged(settings.copyWith(proactiveInjectionEnabled: v)),
        ),
        // ── Network request log ───────────────────────────────────────────────
        const _SectionHeader('Network Request Log'),
        _NetworkLogSection(log: networkLog),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkLogSection
// ---------------------------------------------------------------------------

/// Lists all network requests made in the current session.
/// Each row is tappable and opens a detail dialog with the full response.
class _NetworkLogSection extends StatelessWidget {
  final List<NetworkRequestRecord> log;

  const _NetworkLogSection({required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No network requests yet this session.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Show newest-first.
    final reversed = log.reversed.toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 68,
                  child: Text(
                    'CHARACTER',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 44,
                  child: Text(
                    'TYPE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'QUERY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 76,
                  child: Text(
                    'STATUS',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Request rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reversed.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (ctx, i) =>
                _NetworkLogRow(record: reversed[i]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkLogRow
// ---------------------------------------------------------------------------

/// One row in the network log list. Tappable to show the full response.
class _NetworkLogRow extends StatelessWidget {
  final NetworkRequestRecord record;

  const _NetworkLogRow({required this.record});

  Color get _statusColor {
    switch (record.status) {
      case NetworkRequestStatus.success:
        return const Color(0xFF66BB6A); // green
      case NetworkRequestStatus.rateLimited:
        return const Color(0xFFFFCA28); // amber
      case NetworkRequestStatus.blocked:
        return const Color(0xFFEF5350); // red
    }
  }

  String get _timeLabel {
    final t = record.timestamp.toLocal();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _charColor {
    switch (record.characterName) {
      case 'WATSON':
        return 'WA';
      case 'DEEP':
        return 'DE';
      case 'NOVA':
        return 'NO';
      case 'SAGE':
        return 'SA';
      default:
        return record.characterName.substring(0, 2);
    }
  }

  Color get _charAccent {
    switch (record.characterName) {
      case 'WATSON':
        return const Color(0xFF4FC3F7);
      case 'DEEP':
        return const Color(0xFFAB47BC);
      case 'NOVA':
        return const Color(0xFF66BB6A);
      case 'SAGE':
        return const Color(0xFFFFCA28);
      default:
        return AppColors.accent;
    }
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _NetworkDetailDialog(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Character chip
            Container(
              width: 68,
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _charAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: _charAccent.withValues(alpha: 0.35)),
              ),
              child: Text(
                record.characterName,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _charAccent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Tag chip
            SizedBox(
              width: 44,
              child: Text(
                record.tag,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Query — expands
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.query,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _timeLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status chip + bytes
            SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      record.statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  if (record.status == NetworkRequestStatus.success) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${(record.responseBytes / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Chevron hint
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkDetailDialog
// ---------------------------------------------------------------------------

/// Full-response popout dialog, scrollable.
class _NetworkDetailDialog extends StatelessWidget {
  final NetworkRequestRecord record;

  const _NetworkDetailDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    final ts = record.timestamp.toLocal();
    final timeStr =
        '${ts.year}-${_p(ts.month)}-${_p(ts.day)}  '
        '${_p(ts.hour)}:${_p(ts.minute)}:${_p(ts.second)}';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 560,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record.tag}: ${record.query}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.characterName}  ·  $timeStr  ·  '
                          '${record.statusLabel}'
                          '${record.status == NetworkRequestStatus.success ? "  ·  ${(record.responseBytes / 1024).toStringAsFixed(1)} KB" : ""}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
            // ── Response body ─────────────────────────────────────────────────
            Expanded(
              child: record.responseText.isEmpty
                  ? const Center(
                      child: Text(
                        'No response body.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: SelectableText(
                          record.responseText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// Tools tab
// ---------------------------------------------------------------------------

class _ToolsTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _ToolsTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Vision Model'),
        _LabeledRow(
          label: 'Vision model name',
          child: SizedBox(
            width: 200,
            child: TextFormField(
              initialValue: settings.visionModelName,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) =>
                  onChanged(settings.copyWith(visionModelName: v)),
            ),
          ),
        ),
        const _SectionHeader('Persona'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            initialValue: settings.personaText,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Global persona text',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => onChanged(settings.copyWith(personaText: v)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Safety tab
// ---------------------------------------------------------------------------

class _SafetyTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _SafetyTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cats = ['adult', 'violence', 'hate'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text(
            'Enable content filter',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.contentFilterEnabled,
          activeColor: AppColors.accent,
          onChanged: (v) =>
              onChanged(settings.copyWith(contentFilterEnabled: v)),
        ),
        const _SectionHeader('Active Categories'),
        ...cats.map((cat) {
          final active = settings.activeFilterCategories.contains(cat);
          return CheckboxListTile(
            title: Text(
              cat[0].toUpperCase() + cat.substring(1),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
            ),
            value: active,
            activeColor: AppColors.accent,
            checkColor: Colors.white,
            onChanged: (v) {
              final updated =
                  List<String>.from(settings.activeFilterCategories);
              if (v == true) {
                updated.add(cat);
              } else {
                updated.remove(cat);
              }
              onChanged(
                  settings.copyWith(activeFilterCategories: updated));
            },
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Display tab
// ---------------------------------------------------------------------------

class _DisplayTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _DisplayTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const scales = ['small', 'medium', 'large', 'xl'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Font Size'),
        DropdownButtonFormField<String>(
          value: settings.fontSizeScale,
          dropdownColor: AppColors.surface,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13),
          items: scales
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(settings.copyWith(fontSizeScale: v));
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'High contrast mode',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.highContrastMode,
          activeColor: AppColors.accent,
          onChanged: (v) =>
              onChanged(settings.copyWith(highContrastMode: v)),
        ),
        SwitchListTile(
          title: const Text(
            'Reduced motion mode',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.reducedMotionMode,
          activeColor: AppColors.accent,
          onChanged: (v) =>
              onChanged(settings.copyWith(reducedMotionMode: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced tab
// ---------------------------------------------------------------------------

class _AdvancedTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _AdvancedTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text(
            'Sound cues',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.soundEnabled,
          activeColor: AppColors.accent,
          onChanged: (v) => onChanged(settings.copyWith(soundEnabled: v)),
        ),
        SwitchListTile(
          title: const Text(
            'Desktop notifications',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          value: settings.notificationsEnabled,
          activeColor: AppColors.accent,
          onChanged: (v) =>
              onChanged(settings.copyWith(notificationsEnabled: v)),
        ),
        const _SectionHeader('Schema'),
        ListTile(
          title: const Text(
            'Settings schema version',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          trailing: Text(
            'v${settings.schemaVersion}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
