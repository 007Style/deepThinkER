// NetworkRequestRecord — lightweight value object for one network tool call.
//
// Collected in-memory by MainScreen and passed to SettingsScreen for display.
// Not persisted — lives only for the duration of the session view.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// NetworkRequestStatus
// ---------------------------------------------------------------------------

/// The outcome of a single network tool invocation.
enum NetworkRequestStatus {
  /// The request completed and returned content.
  success,

  /// The request was rejected by the rate limiter.
  rateLimited,

  /// The tool was disabled (network OFF or trust tier too low).
  blocked,
}

// ---------------------------------------------------------------------------
// NetworkRequestRecord
// ---------------------------------------------------------------------------

/// One network tool invocation captured from a [ToolCallEvent].
class NetworkRequestRecord {
  /// Character that issued the request (e.g. `'WATSON'`).
  final String characterName;

  /// Tool tag (`'SEARCH'` or `'FETCH'`).
  final String tag;

  /// The query string or URL passed to the tool.
  final String query;

  /// Outcome of the call.
  final NetworkRequestStatus status;

  /// Full response text injected into the LLM context.
  /// Empty string for blocked / rate-limited calls.
  final String responseText;

  /// Approximate byte count of [responseText].
  final int responseBytes;

  /// When the call was processed.
  final DateTime timestamp;

  const NetworkRequestRecord({
    required this.characterName,
    required this.tag,
    required this.query,
    required this.status,
    required this.responseText,
    required this.responseBytes,
    required this.timestamp,
  });

  /// Short human-readable status label.
  String get statusLabel {
    switch (status) {
      case NetworkRequestStatus.success:
        return 'OK';
      case NetworkRequestStatus.rateLimited:
        return 'Rate limited';
      case NetworkRequestStatus.blocked:
        return 'Blocked';
    }
  }
}
