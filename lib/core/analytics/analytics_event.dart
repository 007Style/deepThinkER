/// AnalyticsEvent — event model for session analytics.
///
/// This file has zero Flutter imports — pure Dart only.
library analytics_event;

// ---------------------------------------------------------------------------
// AnalyticsEventType
// ---------------------------------------------------------------------------

/// The type of analytics event.
enum AnalyticsEventType {
  message,
  trustSnapshot,
  toolCall,
  moodChange,
  rateLimited,
  researchPhaseChange,
}

// ---------------------------------------------------------------------------
// AnalyticsEvent
// ---------------------------------------------------------------------------

/// A single analytics event recorded during a session.
class AnalyticsEvent {
  final AnalyticsEventType type;
  final DateTime timestamp;

  /// Character involved, or null for global events.
  final String? characterName;

  /// Additional data about the event.
  final Map<String, dynamic> payload;

  AnalyticsEvent({
    required this.type,
    required this.characterName,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Serialises to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'characterName': characterName,
        'payload': payload,
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      type: AnalyticsEventType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => AnalyticsEventType.message,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      characterName: json['characterName'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}
