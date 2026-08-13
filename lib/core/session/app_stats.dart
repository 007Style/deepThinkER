/// App-wide lifetime statistics for deepThink.
///
/// Tracks cumulative usage across all sessions ever run on this machine.
/// Persisted to `~/Documents/deepThink/stats.json` by [SessionManager].
///
/// This file has zero Flutter imports — pure Dart only.
library app_stats;

// ---------------------------------------------------------------------------
// AppStats
// ---------------------------------------------------------------------------

/// Cumulative app-wide usage statistics.
///
/// Updated by [SessionManager] at the end of each session and persisted to
/// `stats.json`. Retrieved on demand by the About screen.
///
/// ```dart
/// var stats = AppStats.empty();
/// stats.totalSessionsRun++;
/// stats.totalMessagesGenerated += session.totalMessages;
/// ```
class AppStats {
  /// Total number of sessions ever completed.
  int totalSessionsRun;

  /// Total number of non-pass messages generated across all sessions.
  int totalMessagesGenerated;

  /// Total number of tokens processed across all sessions.
  ///
  /// Sourced from Ollama `eval_count` values.
  int totalTokensProcessed;

  /// UTC timestamp of the very first session, or `null` if no session has
  /// ever been completed.
  DateTime? firstSessionDate;

  /// UTC timestamp of the most recently completed session, or `null` if no
  /// session has ever been completed.
  DateTime? lastSessionDate;

  /// Creates an [AppStats] instance with the supplied values.
  AppStats({
    required this.totalSessionsRun,
    required this.totalMessagesGenerated,
    required this.totalTokensProcessed,
    this.firstSessionDate,
    this.lastSessionDate,
  });

  /// Returns a zeroed-out [AppStats] instance representing a fresh install.
  factory AppStats.empty() => AppStats(
        totalSessionsRun: 0,
        totalMessagesGenerated: 0,
        totalTokensProcessed: 0,
      );

  // -------------------------------------------------------------------------
  // Serialisation
  // -------------------------------------------------------------------------

  /// Serialises to a JSON-compatible map for writing to `stats.json`.
  Map<String, dynamic> toJson() => {
        'totalSessionsRun': totalSessionsRun,
        'totalMessagesGenerated': totalMessagesGenerated,
        'totalTokensProcessed': totalTokensProcessed,
        if (firstSessionDate != null)
          'firstSessionDate': firstSessionDate!.toIso8601String(),
        if (lastSessionDate != null)
          'lastSessionDate': lastSessionDate!.toIso8601String(),
      };

  /// Deserialises from a JSON-compatible map read from `stats.json`.
  factory AppStats.fromJson(Map<String, dynamic> json) => AppStats(
        totalSessionsRun: json['totalSessionsRun'] as int? ?? 0,
        totalMessagesGenerated: json['totalMessagesGenerated'] as int? ?? 0,
        totalTokensProcessed: json['totalTokensProcessed'] as int? ?? 0,
        firstSessionDate: json['firstSessionDate'] != null
            ? DateTime.parse(json['firstSessionDate'] as String)
            : null,
        lastSessionDate: json['lastSessionDate'] != null
            ? DateTime.parse(json['lastSessionDate'] as String)
            : null,
      );

  @override
  String toString() =>
      'AppStats(sessions=$totalSessionsRun, messages=$totalMessagesGenerated, '
      'tokens=$totalTokensProcessed)';
}
