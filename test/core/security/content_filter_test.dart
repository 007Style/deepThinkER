import 'package:test/test.dart';
import 'package:deep_think_er/core/security/content_filter.dart';
import 'package:deep_think_er/core/security/filter_config.dart';

ContentFilter _buildFilter({bool enabled = true}) {
  return ContentFilter.fromMap(
    FilterConfig(
      enabled: enabled,
      activeCategories: const ['adult', 'violence'],
    ),
    {
      'adult': 'explicit\nxxxxx\nnaked',
      'violence': 'kill\nstab\nblood',
    },
  );
}

void main() {
  group('ContentFilter', () {
    group('scan — filter disabled', () {
      test('returns empty list regardless of content', () {
        final f = _buildFilter(enabled: false);
        expect(f.scan('kill explicit naked'), isEmpty);
      });
    });

    group('scan — filter enabled', () {
      test('returns empty list for clean text', () {
        final f = _buildFilter();
        expect(f.scan('the weather is lovely'), isEmpty);
      });

      test('detects adult category', () {
        final f = _buildFilter();
        expect(f.scan('explicit content here'), contains('adult'));
      });

      test('detects violence category', () {
        final f = _buildFilter();
        expect(f.scan('there was blood on the floor'), contains('violence'));
      });

      test('can detect multiple categories', () {
        final f = _buildFilter();
        final results = f.scan('explicit kill');
        expect(results, contains('adult'));
        expect(results, contains('violence'));
      });

      test('is case-insensitive', () {
        final f = _buildFilter();
        expect(f.scan('EXPLICIT material'), contains('adult'));
      });

      test('returns no duplicate categories for multiple keyword hits', () {
        final f = _buildFilter();
        final results = f.scan('kill stab blood');
        expect(results.where((c) => c == 'violence').length, 1);
      });
    });

    group('sanitise — filter disabled', () {
      test('returns text unchanged', () {
        final f = _buildFilter(enabled: false);
        const text = 'kill explicit naked';
        expect(f.sanitise(text), text);
      });
    });

    group('sanitise — filter enabled', () {
      test('replaces adult keyword with placeholder', () {
        final f = _buildFilter();
        final result = f.sanitise('explicit content');
        expect(result, contains('[CONTENT_FILTERED: adult]'));
        expect(result, isNot(contains('explicit')));
      });

      test('replaces violence keyword with placeholder', () {
        final f = _buildFilter();
        final result = f.sanitise('blood everywhere');
        expect(result, contains('[CONTENT_FILTERED: violence]'));
      });

      test('does not modify clean text', () {
        final f = _buildFilter();
        expect(f.sanitise('the sky is blue'), 'the sky is blue');
      });
    });

    group('fromMap — custom keywords', () {
      test('merges custom keywords from config', () {
        final f = ContentFilter.fromMap(
          FilterConfig(
            enabled: true,
            activeCategories: const ['adult'],
            customKeywords: const {'adult': ['custom_word']},
          ),
          {'adult': 'original'},
        );
        expect(f.scan('custom_word in text'), contains('adult'));
        expect(f.scan('original in text'), contains('adult'));
      });
    });

    group('empty factory', () {
      test('scan always returns empty', () {
        expect(ContentFilter.empty().scan('kill explicit'), isEmpty);
      });
    });
  });
}
