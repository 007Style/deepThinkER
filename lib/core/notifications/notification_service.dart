/// NotificationService — wraps flutter_local_notifications to deliver
/// typed [NotificationEvent]s as desktop/system notifications.
///
/// NOTE: This file is in lib/core/ but imports flutter_local_notifications,
/// which transitively depends on Flutter. This is intentional — the package
/// only supports Flutter apps, and deepThinkER is a Flutter app.
library notification_service;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_event.dart';

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Singleton wrapper around [FlutterLocalNotificationsPlugin].
///
/// Call [init] once at app startup, then call [notify] to deliver events.
/// The [enabled] flag can be toggled at runtime to silence all notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  /// Master on/off switch.  Set from [AppSettings.notificationsEnabled].
  bool enabled = true;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises the notification plugin.
  ///
  /// Must be called once before [notify]. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;

    const initSettings = InitializationSettings(
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _plugin.initialize(initSettings);
    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Shows a notification for [event] if [enabled] is `true`.
  Future<void> notify(NotificationEvent event) async {
    if (!enabled || !_initialised) return;

    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );

    await _plugin.show(
      event.id,
      event.title,
      event.body,
      details,
    );
  }
}
