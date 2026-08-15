// MemoryStore — per-character in-memory store with cap and stream.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';

import 'memory_entry.dart';

export 'memory_entry.dart';

// ---------------------------------------------------------------------------
// MemoryStoreRegistry
// ---------------------------------------------------------------------------

/// Singleton registry of per-character [MemoryStore] instances.
///
/// Use [MemoryStoreRegistry.storeFor] to get or create the store for a
/// character.
class MemoryStoreRegistry {
  MemoryStoreRegistry._();

  static final Map<String, MemoryStore> _stores = {};

  /// Returns the [MemoryStore] for [characterName], creating it if needed.
  static MemoryStore storeFor(String characterName) {
    return _stores.putIfAbsent(characterName, () => MemoryStore(characterName));
  }

  /// Returns all registered stores.
  static Map<String, MemoryStore> get all => Map.unmodifiable(_stores);
}

// ---------------------------------------------------------------------------
// MemoryStore
// ---------------------------------------------------------------------------

/// Holds up to 200 [MemoryEntry] objects for one AI character.
///
/// When the cap is reached the oldest entry is evicted on each new [add].
/// A broadcast stream [addStream] emits each newly added entry.
class MemoryStore {
  /// The character who owns this store.
  final String characterName;

  /// Maximum number of entries before eviction begins.
  static const int _cap = 200;

  final List<MemoryEntry> _entries = [];

  final StreamController<MemoryEntry> _addController =
      StreamController<MemoryEntry>.broadcast();

  MemoryStore(this.characterName);

  /// Broadcast stream of newly added [MemoryEntry] objects.
  Stream<MemoryEntry> get addStream => _addController.stream;

  /// All current entries, oldest first.
  List<MemoryEntry> get entries => List.unmodifiable(_entries);

  /// Number of entries currently stored.
  int get length => _entries.length;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Adds [entry] to the store.
  ///
  /// If the store is at capacity the oldest entry is removed first.
  void add(MemoryEntry entry) {
    if (_entries.length >= _cap) {
      _entries.removeAt(0); // evict oldest
    }
    _entries.add(entry);
    if (!_addController.isClosed) {
      _addController.add(entry);
    }
  }

  /// Loads a list of entries directly (used by persistence layer on startup).
  void loadAll(List<MemoryEntry> entries) {
    _entries.clear();
    // Respect cap even when loading.
    final toLoad = entries.length > _cap
        ? entries.sublist(entries.length - _cap)
        : entries;
    _entries.addAll(toLoad);
  }

  /// Removes the entry with [id]. Returns `true` if found and removed.
  bool remove(String id) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return false;
    _entries.removeAt(idx);
    return true;
  }

  /// Queries entries whose [content] or [topicTags] contain [topic].
  ///
  /// Delegates to [MemoryQuery.match] and returns results sorted by recency
  /// (most recent first).
  List<MemoryEntry> queryByTopic(String topic) {
    final results = MemoryQuery.match(topic, _entries);
    return results;
  }

  /// Returns a bullet-list string of the [n] most recent entries.
  ///
  /// Used when building the context-reset seed.
  String recentSummary({int n = 5}) {
    if (_entries.isEmpty) return '';
    final recent = _entries.reversed.take(n).toList();
    final buf = StringBuffer();
    for (final e in recent) {
      buf.writeln('• ${e.content}');
    }
    return buf.toString().trimRight();
  }

  /// Closes the add stream controller. Call when the store is no longer needed.
  void dispose() {
    _addController.close();
  }
}

// ---------------------------------------------------------------------------
// MemoryQuery (defined here to keep memory_query.dart thin)
// ---------------------------------------------------------------------------

// ignore: avoid_classes_with_only_static_members
/// Simple keyword matcher for memory entries.
class MemoryQuery {
  MemoryQuery._();

  /// Returns entries from [entries] whose content or tags contain any word
  /// from [topic] (case-insensitive). Results are sorted newest-first.
  static List<MemoryEntry> match(String topic, List<MemoryEntry> entries) {
    final words = topic
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 1)
        .toSet();

    if (words.isEmpty) return List.from(entries.reversed);

    final matched = entries.where((e) {
      final contentLower = e.content.toLowerCase();
      final tagsLower = e.topicTags.map((t) => t.toLowerCase()).toList();
      return words.any(
        (w) =>
            contentLower.contains(w) || tagsLower.any((t) => t.contains(w)),
      );
    }).toList();

    // Sort newest-first.
    matched.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matched;
  }
}
