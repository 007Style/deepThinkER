// Memory Panel Screen — per-character memory viewer for deepThinkER.
//
// Shows each character's MemoryStore in a tab view. Entries can be deleted.
// A search bar filters entries by keyword.
import 'package:flutter/material.dart';

import '../../core/memory/memory_entry.dart';
import '../../core/memory/memory_persistence.dart';
import '../../core/memory/memory_store.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// MemoryPanelScreen
// ---------------------------------------------------------------------------

/// Screen that shows all per-character memories in tab view.
class MemoryPanelScreen extends StatefulWidget {
  const MemoryPanelScreen({super.key});

  @override
  State<MemoryPanelScreen> createState() => _MemoryPanelScreenState();
}

class _MemoryPanelScreenState extends State<MemoryPanelScreen>
    with SingleTickerProviderStateMixin {
  static const _characters = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _characters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          'Character Memories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          tabs: _characters
              .map((name) => Tab(text: name))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _characters
            .map((name) => _CharacterMemoryTab(characterName: name))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterMemoryTab
// ---------------------------------------------------------------------------

class _CharacterMemoryTab extends StatefulWidget {
  final String characterName;

  const _CharacterMemoryTab({required this.characterName});

  @override
  State<_CharacterMemoryTab> createState() => _CharacterMemoryTabState();
}

class _CharacterMemoryTabState extends State<_CharacterMemoryTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  MemoryStore get _store =>
      MemoryStoreRegistry.storeFor(widget.characterName);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MemoryEntry> _filteredEntries() {
    if (_filter.isEmpty) {
      return _store.entries.reversed.toList();
    }
    return _store.queryByTopic(_filter);
  }

  void _deleteEntry(String id) async {
    _store.remove(id);
    await MemoryPersistence.save(widget.characterName, _store);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Filter by keyword…',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: AppColors.textSecondary,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.4),
              ),
            ),
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
        ),

        // Entry count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${entries.length} memor${entries.length == 1 ? 'y' : 'ies'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${_store.length} / 200',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.border),

        // Entry list
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No memories yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _MemoryCard(
                      entry: entry,
                      onDelete: () => _deleteEntry(entry.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _MemoryCard
// ---------------------------------------------------------------------------

class _MemoryCard extends StatelessWidget {
  final MemoryEntry entry;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ts = entry.timestamp.toLocal();
    final formatted =
        '${ts.year}-${_p(ts.month)}-${_p(ts.day)} '
        '${_p(ts.hour)}:${_p(ts.minute)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _SourceChip(source: entry.source),
                    ...entry.topicTags.map(
                      (t) => _TagChip(tag: t),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.textSecondary),
            onPressed: onDelete,
            tooltip: 'Delete memory',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// _TagChip / _SourceChip
// ---------------------------------------------------------------------------

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final MemorySource source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = source == MemorySource.explicit ? 'explicit' : 'observed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
