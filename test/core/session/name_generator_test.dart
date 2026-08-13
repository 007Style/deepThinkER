import 'dart:math';
import 'package:test/test.dart';
import 'package:deep_think_er/core/session/name_generator.dart';

void main() {
  group('NameGenerator', () {
    group('generate()', () {
      test('returns a non-empty string', () {
        final gen = NameGenerator();
        expect(gen.generate(), isNotEmpty);
      });

      test('result is lowerCamelCase: starts lowercase, contains an uppercase letter', () {
        final gen = NameGenerator();
        for (var i = 0; i < 20; i++) {
          final name = gen.generate();
          expect(name[0], equals(name[0].toLowerCase()),
              reason: 'First char should be lowercase: $name');
          expect(name, matches(RegExp(r'[A-Z]')),
              reason: 'Should contain at least one uppercase letter: $name');
        }
      });

      test('result contains only alphanumeric characters', () {
        final gen = NameGenerator();
        for (var i = 0; i < 20; i++) {
          final name = gen.generate();
          expect(name, matches(RegExp(r'^[a-zA-Z]+$')),
              reason: 'Should be all letters: $name');
        }
      });

      test('uses seeded Random for deterministic output', () {
        // Same seed → same sequence
        final gen1 = NameGenerator(random: Random(42));
        final gen2 = NameGenerator(random: Random(42));
        expect(gen1.generate(), gen2.generate());
      });

      test('different seeds produce different output (usually)', () {
        final gen1 = NameGenerator(random: Random(1));
        final gen2 = NameGenerator(random: Random(999));
        // Generate several names and expect at least one difference
        final names1 = List.generate(10, (_) => gen1.generate());
        final names2 = List.generate(10, (_) => gen2.generate());
        expect(names1, isNot(equals(names2)));
      });
    });

    group('generateUnique()', () {
      test('returns a name not in existingNames', () {
        final gen = NameGenerator(random: Random(0));
        // Pre-populate with the first generated name
        final first = gen.generate();
        final gen2 = NameGenerator(random: Random(0));
        final unique = gen2.generateUnique({first});
        expect(unique, isNot(first));
      });

      test('returns any name when existingNames is empty', () {
        final gen = NameGenerator();
        final name = gen.generateUnique({});
        expect(name, isNotEmpty);
      });

      test('returns a unique name even with large existing set', () {
        final gen = NameGenerator(random: Random(7));
        // Generate a large set of existing names
        final existing = <String>{};
        for (var i = 0; i < 500; i++) {
          existing.add(gen.generate());
        }
        // A fresh generator should still find something unique
        final gen2 = NameGenerator();
        final unique = gen2.generateUnique(existing);
        expect(unique, isNotEmpty);
      });
    });
  });
}
