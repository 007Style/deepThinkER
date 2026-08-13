/// Network fetcher for deepThinkER.
///
/// Executes [SEARCH:] and [FETCH:] tool calls: fetches raw HTML via HTTP,
/// truncates to the configured character limit, and returns a [FetchResult].
///
/// This file has zero Flutter imports — pure Dart only.
library network_fetcher;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fetch_result.dart';
import 'rate_limit_config.dart';

// ---------------------------------------------------------------------------
// NetworkFetcher
// ---------------------------------------------------------------------------

/// Fetches web pages for deepThinkER's tool-call pipeline.
///
/// Both [search] and [fetch] share the same underlying HTTP logic:
///  - 10-second request timeout
///  - Browser-like User-Agent header
///  - Response body truncated to [config.htmlTruncationChars]
///
/// Thread-safety: all public methods are async and safe to call concurrently.
class NetworkFetcher {
  final RateLimitConfig config;

  /// Cumulative number of successful search/fetch calls.
  int _totalSearches = 0;

  /// Cumulative bytes received across all successful fetches.
  int _totalBytesReceived = 0;

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  static const Duration _timeout = Duration(seconds: 10);

  /// Creates a [NetworkFetcher] with the given [config].
  NetworkFetcher({RateLimitConfig? config})
      : config = config ?? const RateLimitConfig();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Current cumulative search/fetch count.
  int get totalSearches => _totalSearches;

  /// Current cumulative received bytes (before truncation).
  int get totalBytesReceived => _totalBytesReceived;

  /// Searches DuckDuckGo HTML endpoint for [query] on behalf of [characterName].
  ///
  /// Builds URL: `https://html.duckduckgo.com/html/?q=<encoded>`.
  Future<FetchResult> search(String query, String characterName) {
    final encoded = Uri.encodeQueryComponent(query);
    final url = 'https://html.duckduckgo.com/html/?q=$encoded';
    return fetch(url, characterName);
  }

  /// Fetches [url] directly on behalf of [characterName].
  Future<FetchResult> fetch(String url, String characterName) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return FetchResult.error(
        url: url,
        errorMessage: 'Invalid URL: $url',
        characterName: characterName,
      );
    }

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      final rawBytes = response.bodyBytes;
      final rawString = utf8.decode(rawBytes, allowMalformed: true);
      final limit = config.htmlTruncationChars;
      final truncated = rawString.length > limit;
      final html = truncated ? rawString.substring(0, limit) : rawString;

      _totalSearches++;
      _totalBytesReceived += rawBytes.length;

      if (response.statusCode >= 400) {
        return FetchResult.error(
          url: url,
          errorMessage: 'HTTP ${response.statusCode} error fetching $url',
          characterName: characterName,
          fetchedAt: DateTime.now(),
        );
      }

      return FetchResult.success(
        url: url,
        rawHtml: html,
        truncated: truncated,
        fetchedAt: DateTime.now(),
        responseBytes: rawBytes.length,
        characterName: characterName,
      );
    } on http.ClientException catch (e) {
      return FetchResult.error(
        url: url,
        errorMessage: 'Network error fetching $url: ${e.message}',
        characterName: characterName,
      );
    } catch (e) {
      return FetchResult.error(
        url: url,
        errorMessage: 'Error fetching $url: $e',
        characterName: characterName,
      );
    }
  }
}
