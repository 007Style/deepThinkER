import 'package:test/test.dart';
import 'package:deep_think_er/core/memory/memory_entry.dart';
import 'package:deep_think_er/core/memory/memory_store.dart';

MemoryEntry _entry(String content, {List<String> tags = const []}) =>
    MemoryEntry.create(
      characterName: 'WATSON',
      content: content,
      topicTags: tags,
    );

void main() {
  group('MemoryEntry', () {
    group('create factory', () {
      test('generates a non-empty id', () {
        expect(_entry('hello').id, isNotEmpty);
      });

      test('id starts with mem_', () {
        expect(_entry('hello').id, startsWith('mem_'));
      });

      test('sets characterName correctly', () {
        expect(_entry('hello').characterName, 'WATSON');
      });

      test('timestamp is UTC', () {
        expect(_entry('hello').timestamp.isUtc, isTrue);
      });

      test('defaults source to explicit', () {
        expect(_entry('hello').source, MemorySource.explicit);
      });
    });

    group('JSON round-trip', () {
      test('toJson/fromJson preserves all fields', () {
        final original = MemoryEntry.create(
          characterName: 'DEEP',
          content: 'Interesting fact',
          topicTags: ['ai', 'research'],
          source: MemorySource.observed,
        );
        final json = original.toJson();
        final restored = MemoryEntry.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.characterName, original.characterName);
        expect(restored.content, original.content);
        expect(restored.topicTags, original.topicTags);
        expect(restored.source, original.source);
      });

      test('fromJson with unknown source falls back to explicit', () {
        final entry = MemoryEntry.fromJson({
          'id': 'mem_1',
          'characterName': 'NOVA',
          'content': 'test',
          'topicTags': [],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'source': 'totally_unknown',
        });
        expect(entry.source, MemorySource.explicit);
      });
    });
  });

  group('MemoryStore', () {
    late MemoryStore store;

    setUp(() => store = MemoryStore('WATSON'));
    tearDown(() => store.dispose());

    test('starts empty', () {
      expect(store.length, 0);
      expect(store.entries, isEmpty);
    });

    test('add increases length', () {
      store.add(_entry('fact 1'));
      expect(store.length, 1);
    });

    test('entries are stored in insertion order', () {
      store.add(_entry('first'));
      store.add(_entry('second'));
      expect(store.entries[0].content, 'first');
      expect(store.entries[1].content, 'second');
    });

    test('remove by id returns true and removes entry', () {
      final e = _entry('to remove');
      store.add(e);
      expect(store.remove(e.id), isTrue);
      expect(store.length, 0);
    });

    test('remove non-existent id returns false', () {
      expect(store.remove('nonexistent'), isFalse);
    });

    test('cap at 200 evicts oldest', () {
      for (var i = 0; i < 201; i++) {
        store.add(_entry('entry $i'));
      }
      expect(store.length, 200);
      expect(store.entries.first.content, 'entry 1'); // entry 0 evicted
    });

    test('addStream emits on each add', () async {
      final events = <MemoryEntry>[];
      store.addStream.listen(events.add);
      store.add(_entry('a'));
      store.add(_entry('b'));
      await Future.delayed(Duration.zero);
      expect(events, hasLength(2));
    });

    group('queryByTopic', () {
      test('returns matching entries', () {
        store.add(_entry('I love machine learning', tags: ['ml']));
        store.add(_entry('Weather today is nice'));
        final results = store.queryByTopic('machine');
        expect(results, hasLength(1));
        expect(results[0].content, contains('machine'));
      });

      test('matches by topicTags', () {
        store.add(_entry('Something', tags: ['ml', 'ai']));
        store.add(_entry('Unrelated'));
        final results = store.queryByTopic('ai');
        expect(results, hasLength(1));
      });

      test('returns newest first', () async {
        store.add(_entry('older neural', tags: []));
        await Future.delayed(const Duration(milliseconds: 2));
        store.add(_entry('newer neural', tags: []));
        final results = store.queryByTopic('neural');
        expect(results[0].content, contains('newer'));
      });

      test('returns all reversed when query is blank', () {
        store.add(_entry('a'));
        store.add(_entry('b'));
        final results = store.queryByTopic('');
        expect(results.length, 2);
      });
    });

    group('recentSummary', () {
      test('returns empty string when store is empty', () {
        expect(store.recentSummary(), isEmpty);
      });

      test('returns bullet points for recent entries', () {
        store.add(_entry('fact one'));
        store.add(_entry('fact two'));
        final summary = store.recentSummary(n: 5);
        expect(summary, contains('• fact one'));
        expect(summary, contains('• fact two'));
      });

      test('respects n limit', () {
        for (var i = 0; i < 10; i++) {
          store.add(_entry('fact $i'));
        }
        final summary = store.recentSummary(n: 3);
        final lines = summary.split('\n').where((l) => l.isNotEmpty).toList();
        expect(lines.length, 3);
      });
    });

    group('loadAll', () {
      test('loads entries replacing existing', () {
        store.add(_entry('old'));
        final newEntries = [_entry('new1'), _entry('new2')];
        store.loadAll(newEntries);
        expect(store.length, 2);
        expect(store.entries[0].content, 'new1');
      });

      test('loadAll respects cap when loading more than 200', () {
        final many = List.generate(210, (i) => _entry('e$i'));
        store.loadAll(many);
        expect(store.length, 200);
      });
    });
  });
}
