/// Typed notification event classes for deepThinkER.
///
/// This file has zero Flutter imports — pure Dart only.
library notification_event;

// ---------------------------------------------------------------------------
// NotificationEvent
// ---------------------------------------------------------------------------

/// Base class for all notification events.
abstract class NotificationEvent {
  /// Unique notification ID (used to update/replace existing notifications).
  int get id;

  /// Short title shown in the notification banner.
  String get title;

  /// Body text of the notification.
  String get body;

  const NotificationEvent();
}

// ---------------------------------------------------------------------------
// Concrete event types
// ---------------------------------------------------------------------------

/// Fired when the autonomous research phase changes.
class ResearchPhaseChangedNotification extends NotificationEvent {
  @override
  final int id = 1001;

  /// The new phase name (e.g. `'Gathering'`, `'Analysing'`, `'Reporting'`).
  final String newPhase;

  const ResearchPhaseChangedNotification({required this.newPhase});

  @override
  String get title => 'Research phase changed';

  @override
  String get body => 'Entering phase: $newPhase';
}

/// Fired when a character has hit consecutive rate-limit violations.
class RateLimitStreakNotification extends NotificationEvent {
  @override
  final int id = 1002;

  final String characterName;
  final int streak;

  const RateLimitStreakNotification({
    required this.characterName,
    required this.streak,
  });

  @override
  String get title => 'Rate limit streak';

  @override
  String get body => '$characterName has been rate-limited $streak times in a row.';
}

/// Fired when a character's trust tier drops.
class TrustTierDroppedNotification extends NotificationEvent {
  @override
  final int id = 1003;

  final String characterName;
  final String newTier;

  const TrustTierDroppedNotification({
    required this.characterName,
    required this.newTier,
  });

  @override
  String get title => 'Trust tier dropped';

  @override
  String get body => '$characterName is now $newTier trust.';
}

/// Fired when an image has been analysed by the vision model.
class ImageAnalysedNotification extends NotificationEvent {
  @override
  final int id = 1004;

  final String characterName;

  const ImageAnalysedNotification({required this.characterName});

  @override
  String get title => 'Image analysed';

  @override
  String get body => '$characterName completed image analysis.';
}

/// Fired when Ollama has crashed.
class OllamaCrashedNotification extends NotificationEvent {
  @override
  final int id = 1005;

  const OllamaCrashedNotification();

  @override
  String get title => 'Ollama has stopped';

  @override
  String get body => 'deepThinkER cannot generate responses. Check Ollama.';
}

/// Fired when Ollama has recovered after a crash.
class OllamaRecoveredNotification extends NotificationEvent {
  @override
  final int id = 1006;

  const OllamaRecoveredNotification();

  @override
  String get title => 'Ollama recovered';

  @override
  String get body => 'Ollama is running again. Resuming normally.';
}
