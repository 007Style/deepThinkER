import 'package:test/test.dart';
import 'package:deep_think_er/core/network/domain_whitelist.dart';

void main() {
  group('DomainWhitelist', () {
    late DomainWhitelist wl;

    setUp(() {
      wl = DomainWhitelist.instance;
      wl.allowedDomains = []; // reset between tests
    });

    group('enabled', () {
      test('false when empty', () => expect(wl.enabled, isFalse));
      test('true when non-empty', () {
        wl.allowedDomains = ['example.com'];
        expect(wl.enabled, isTrue);
      });
    });

    group('isAllowed — whitelist disabled', () {
      test('any URL is allowed when list is empty', () {
        expect(wl.isAllowed('https://evil.com/path'), isTrue);
      });
    });

    group('isAllowed — whitelist active', () {
      setUp(() {
        wl.allowedDomains = ['en.wikipedia.org', 'example.com'];
      });

      test('exact hostname match is allowed', () {
        expect(wl.isAllowed('https://en.wikipedia.org/wiki/Dart'), isTrue);
      });

      test('different hostname is blocked', () {
        expect(wl.isAllowed('https://evil.com/payload'), isFalse);
      });

      test('subdomain not in list is blocked', () {
        expect(wl.isAllowed('https://sub.example.com/page'), isFalse);
      });

      test('URL without scheme is parsed correctly', () {
        expect(wl.isAllowed('example.com/page'), isTrue);
      });

      test('malformed URL returns false when whitelist active', () {
        expect(wl.isAllowed('not a url at all :::'), isFalse);
      });
    });

    group('hostnameOf', () {
      test('extracts hostname from full URL', () {
        expect(wl.hostnameOf('https://example.com/path?q=1'), 'example.com');
      });

      test('returns original for unparseable input', () {
        final raw = ':::bad';
        final result = wl.hostnameOf(raw);
        // Should not throw; returns some non-empty string
        expect(result, isNotEmpty);
      });
    });
  });
}
