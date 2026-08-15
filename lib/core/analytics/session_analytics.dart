// SessionAnalytics — accumulates and persists session analytics events.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../paths/app_paths.dart';
import 'analytics_event.dart';

export 'analytics_event.dart';

// ---------------------------------------------------------------------------
// SessionAnalytics
// ---------------------------------------------------------------------------

/// Accumulates analytics events for one session and persists them periodically.
///
/// Call [flush] on session end to ensure all events are written.
class SessionAnalytics {
  final String sessionName;

  final List<AnalyticsEvent> _events = [];

  /// Per-character message counts.
  final Map<String, int> messageCountByCharacter = {};

  /// Per-character trust history samples (sampled every 60 s).
  final Map<String, List<double>> trustHistory = {};

  Timer? _flushTimer;

  SessionAnalytics({required this.sessionName}) {
    // Flush every 60 seconds.
    _flushTimer = Timer.periodic(const Duration(seconds: 60), (_) => flush());
  }

  // -------------------------------------------------------------------------
  // Recording methods
  // -------------------------------------------------------------------------

  void recordMessage(String characterName) {
    messageCountByCharacter[characterName] =
        (messageCountByCharacter[characterName] ?? 0) + 1;
    _add(AnalyticsEvent(
      type: AnalyticsEventType.message,
      characterName: characterName,
      payload: {},
    ));
  }

  void recordTrustSnapshot(String characterName, double score) {
    trustHistory
        .putIfAbsent(characterName, () => [])
        .add(score);
    _add(AnalyticsEvent(
      type: AnalyticsEventType.trustSnapshot,
      characterName: characterName,
      payload: {'score': score},
    ));
  }

  void recordToolCall(String characterName, String tag, bool rateLimited) {
    _add(AnalyticsEvent(
      type: AnalyticsEventType.toolCall,
      characterName: characterName,
      payload: {'tag': tag, 'rateLimited': rateLimited},
    ));
  }

  void recordMoodChange(String characterName, String newState) {
    _add(AnalyticsEvent(
      type: AnalyticsEventType.moodChange,
      characterName: characterName,
      payload: {'newState': newState},
    ));
  }

  void recordRateLimited(String characterName) {
    _add(AnalyticsEvent(
      type: AnalyticsEventType.rateLimited,
      characterName: characterName,
      payload: {},
    ));
  }

  /// All recorded events (unmodifiable).
  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  /// Flushes all events to disk.
  Future<void> flush() async {
    try {
      final dir = _analyticsDir();
      await Directory(dir).create(recursive: true);
      final path = '$dir/$sessionName.json';
      final data = {
        'sessionName': sessionName,
        'messageCountByCharacter': messageCountByCharacter,
        'trustHistory': trustHistory,
        'events': _events.map((e) => e.toJson()).toList(),
      };
      await File(path).writeAsString(json.encode(data));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Stops the flush timer. Call on session end (followed by [flush]).
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _add(AnalyticsEvent event) {
    _events.add(event);
  }

  static String _analyticsDir() => AppPaths.analytics;
}
