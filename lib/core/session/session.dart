// Session model for deepThink.
//
// Represents a single conversation session: its identity, name, timing,
// participant snapshot, log file location, and running message/token stats.
//
// This file has zero Flutter imports — pure Dart only.

import '../conversation/participant.dart';

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

/// A deepThink conversation session.
///
/// Created by [SessionManager.createSession] and updated as messages flow
/// through the conversation. [logFilePath] is the absolute path to the
/// on-disk plain-text transcript.
///
/// ```dart
/// final session = Session(
///   id: 'session-1697000000000',
///   name: 'quantumFalcon',
///   participants: Participant.defaults(),
///   logFilePath: '/Users/alice/Documents/deepThink/sessions/quantumFalcon_1697000000000.txt',
/// );
/// ```
class Session {
  /// Timestamp-based unique identifier (`session-<millisecondsSinceEpoch>`).
  final String id;

  /// Human-readable display name for this session.
  ///
  /// Mutable — the user may rename the session at any point.
  String name;

  /// UTC time when the session was created.
  final DateTime startTime;

  /// UTC time when the session ended, or `null` if still active.
  DateTime? endTime;

  /// Snapshot of the participant configuration at session-start time.
  ///
  /// Stored so the log footer can record which models were in use even if
  /// participants are later reconfigured for a new session.
  final List<Participant> participants;

  /// Absolute path to the plain-text transcript file on disk.
  final String logFilePath;

  /// Whether the session is currently active (i.e. [endTime] is null and
  /// logging is still in progress).
  bool isActive;

  // -------------------------------------------------------------------------
  // Running stats (updated by SessionManager as messages arrive)
  // -------------------------------------------------------------------------

  /// Total number of non-pass messages appended to this session so far.
  int totalMessages;

  /// Cumulative token estimate for this session.
  ///
  /// Populated from Ollama `eval_count` values returned in generate responses.
  int totalTokens;

  /// Number of messages originating from the human user in this session.
  int totalUserMessages;

  /// Creates a [Session].
  ///
  /// [startTime] defaults to the current UTC time when omitted.
  Session({
    required this.id,
    required this.name,
    required this.participants,
    required this.logFilePath,
    DateTime? startTime,
    this.endTime,
    this.isActive = false,
    this.totalMessages = 0,
    this.totalTokens = 0,
    this.totalUserMessages = 0,
  }) : startTime = startTime ?? DateTime.now().toUtc();

  // -------------------------------------------------------------------------
  // Serialisation helpers (used by session index)
  // -------------------------------------------------------------------------

  /// Serialises this session to a JSON-compatible map.
  ///
  /// Only metadata fields are serialised; the full [participants] list is
  /// stored as names only (the full config is inside the log file itself).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'participants': participants.map((p) => p.name).toList(),
        'logFilePath': logFilePath,
        'isActive': isActive,
        'totalMessages': totalMessages,
        'totalTokens': totalTokens,
        'totalUserMessages': totalUserMessages,
      };

  /// Creates a [Session] from a JSON-compatible map.
  ///
  /// [participants] is not restored from the index (only names are stored);
  /// pass [Participant.defaults()] when loading historical sessions for display.
  factory Session.fromJson(
    Map<String, dynamic> json, {
    List<Participant>? participants,
  }) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      participants: participants ?? [],
      logFilePath: json['logFilePath'] as String,
      isActive: json['isActive'] as bool? ?? false,
      totalMessages: json['totalMessages'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
      totalUserMessages: json['totalUserMessages'] as int? ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Marks this session as incomplete (e.g. terminated unexpectedly).
  ///
  /// Sets [isActive] to `false` without setting a normal [endTime], leaving
  /// [endTime] as `null` so callers can distinguish a clean end from a crash.
  void markIncomplete() {
    isActive = false;
  }

  @override
  String toString() =>
      'Session(id=$id, name=$name, active=$isActive, messages=$totalMessages)';
}
