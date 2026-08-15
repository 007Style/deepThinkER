// FetchResult — value object for an HTTP fetch response.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// FetchResult
// ---------------------------------------------------------------------------

/// The outcome of a [NetworkFetcher.search] or [NetworkFetcher.fetch] call.
///
/// On success:  [rawHtml] contains the (possibly truncated) response body.
/// On failure:  [errorMessage] contains a human-readable description.
class FetchResult {
  /// The URL that was fetched.
  final String url;

  /// The raw HTML body, truncated to the configured limit.
  ///
  /// Empty string on error.
  final String rawHtml;

  /// Whether [rawHtml] was truncated from the original response body.
  final bool truncated;

  /// Error description, or `null` if the fetch succeeded.
  final String? errorMessage;

  /// When this result was produced.
  final DateTime fetchedAt;

  /// Total bytes received (before truncation).
  final int responseBytes;

  /// The character on whose behalf this fetch was performed.
  final String characterName;

  const FetchResult._({
    required this.url,
    required this.rawHtml,
    required this.truncated,
    this.errorMessage,
    required this.fetchedAt,
    required this.responseBytes,
    required this.characterName,
  });

  /// Creates a successful fetch result.
  factory FetchResult.success({
    required String url,
    required String rawHtml,
    required bool truncated,
    required DateTime fetchedAt,
    required int responseBytes,
    required String characterName,
  }) {
    return FetchResult._(
      url: url,
      rawHtml: rawHtml,
      truncated: truncated,
      fetchedAt: fetchedAt,
      responseBytes: responseBytes,
      characterName: characterName,
    );
  }

  /// Creates a failed fetch result.
  factory FetchResult.error({
    required String url,
    required String errorMessage,
    required String characterName,
    DateTime? fetchedAt,
  }) {
    return FetchResult._(
      url: url,
      rawHtml: '',
      truncated: false,
      errorMessage: errorMessage,
      fetchedAt: fetchedAt ?? DateTime.now(),
      responseBytes: 0,
      characterName: characterName,
    );
  }

  /// Whether this result represents a successful fetch.
  bool get isSuccess => errorMessage == null;

  @override
  String toString() => isSuccess
      ? 'FetchResult.success(url=$url, bytes=$responseBytes, truncated=$truncated)'
      : 'FetchResult.error(url=$url, error=$errorMessage)';
}
