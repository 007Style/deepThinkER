// SettingsProvider — singleton that holds the current AppSettings and
// broadcasts changes to subscribers.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';

import 'app_settings.dart';
import 'settings_persistence.dart';

// ---------------------------------------------------------------------------
// SettingsProvider
// ---------------------------------------------------------------------------

/// Singleton settings provider.
///
/// Call [init] once at startup to load persisted settings, then call [update]
/// to mutate settings. Subscribe to [stream] to react to changes.
///
/// ```dart
/// await SettingsProvider.instance.init();
/// SettingsProvider.instance.update(
///   SettingsProvider.instance.current.copyWith(soundEnabled: false),
/// );
/// ```
class SettingsProvider {
  SettingsProvider._();

  static final SettingsProvider instance = SettingsProvider._();

  final SettingsPersistence _persistence = SettingsPersistence();
  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  AppSettings _current = const AppSettings();

  /// The current settings snapshot.
  AppSettings get current => _current;

  /// Broadcast stream that emits each time settings are updated.
  Stream<AppSettings> get stream => _controller.stream;

  /// Loads settings from disk and populates [current].
  ///
  /// Must be called once before accessing settings.
  Future<void> init() async {
    _current = await _persistence.load();
  }

  /// Replaces the current settings with [settings], persists them, and
  /// notifies all stream listeners.
  Future<void> update(AppSettings settings) async {
    _current = settings;
    await _persistence.save(settings);
    if (!_controller.isClosed) {
      _controller.add(_current);
    }
  }

  /// Closes the stream controller.  Call on app shutdown.
  Future<void> dispose() => _controller.close();
}
