// MemoryEntry — a single stored fact for one AI character.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// MemorySource
// ---------------------------------------------------------------------------

/// How a memory entry was created.
enum MemorySource {
  /// The character observed something and stored it via [REMEMBER:].
  observed,

  /// The user or character explicitly invoked [REMEMBER:].
  explicit,
}

// ---------------------------------------------------------------------------
// MemoryEntry
// ---------------------------------------------------------------------------

/// A single persisted memory for an AI character.
class MemoryEntry {
  /// Unique identifier (e.g. `'mem_1699000000000'`).
  final String id;

  /// The character who owns this memory.
  final String characterName;

  /// The fact or observation being stored.
  final String content;

  /// Keywords / topic tags associated with this memory.
  final List<String> topicTags;

  /// When the memory was recorded.
  final DateTime timestamp;

  /// How this memory was created.
  final MemorySource source;

  MemoryEntry({
    required this.id,
    required this.characterName,
    required this.content,
    required this.topicTags,
    required this.timestamp,
    required this.source,
  });

  /// Creates a new entry with an auto-generated id and current timestamp.
  factory MemoryEntry.create({
    required String characterName,
    required String content,
    List<String> topicTags = const [],
    MemorySource source = MemorySource.explicit,
  }) {
    return MemoryEntry(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      characterName: characterName,
      content: content,
      topicTags: topicTags,
      timestamp: DateTime.now().toUtc(),
      source: source,
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'characterName': characterName,
        'content': content,
        'topicTags': topicTags,
        'timestamp': timestamp.toIso8601String(),
        'source': source.name,
      };

  /// Deserialises from a JSON-compatible map.
  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] as String,
      characterName: json['characterName'] as String,
      content: json['content'] as String,
      topicTags: (json['topicTags'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: MemorySource.values.firstWhere(
        (s) => s.name == (json['source'] as String? ?? 'explicit'),
        orElse: () => MemorySource.explicit,
      ),
    );
  }

  @override
  String toString() =>
      'MemoryEntry($id, char=$characterName, tags=$topicTags)';
}
