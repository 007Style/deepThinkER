/// SettingsScreen — tabbed settings UI for deepThinkER.
library settings_screen;

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------

/// Full-screen settings panel with five tabs:
/// Network, Tools, Safety, Display, Advanced.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
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
          _NetworkTab(settings: _settings, onChanged: _save),
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

  const _NetworkTab({required this.settings, required this.onChanged});

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
          title: const Text('Enable proactive web injection'),
          value: settings.proactiveInjectionEnabled,
          onChanged: (v) =>
              onChanged(settings.copyWith(proactiveInjectionEnabled: v)),
        ),
      ],
    );
  }
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
          title: const Text('Enable content filter'),
          value: settings.contentFilterEnabled,
          onChanged: (v) =>
              onChanged(settings.copyWith(contentFilterEnabled: v)),
        ),
        const _SectionHeader('Active Categories'),
        ...cats.map((cat) {
          final active = settings.activeFilterCategories.contains(cat);
          return CheckboxListTile(
            title: Text(cat[0].toUpperCase() + cat.substring(1)),
            value: active,
            onChanged: (v) {
              final updated = List<String>.from(settings.activeFilterCategories);
              if (v == true) {
                updated.add(cat);
              } else {
                updated.remove(cat);
              }
              onChanged(settings.copyWith(activeFilterCategories: updated));
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
          items: scales
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(settings.copyWith(fontSizeScale: v));
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('High contrast mode'),
          value: settings.highContrastMode,
          onChanged: (v) =>
              onChanged(settings.copyWith(highContrastMode: v)),
        ),
        SwitchListTile(
          title: const Text('Reduced motion mode'),
          value: settings.reducedMotionMode,
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
          title: const Text('Sound cues'),
          value: settings.soundEnabled,
          onChanged: (v) => onChanged(settings.copyWith(soundEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Desktop notifications'),
          value: settings.notificationsEnabled,
          onChanged: (v) =>
              onChanged(settings.copyWith(notificationsEnabled: v)),
        ),
        const _SectionHeader('Schema'),
        ListTile(
          title: const Text('Settings schema version'),
          trailing: Text('v${settings.schemaVersion}'),
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
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.bold),
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
            child: Text(label),
          ),
          child,
        ],
      ),
    );
  }
}
