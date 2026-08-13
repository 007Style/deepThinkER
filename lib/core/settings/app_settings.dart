/// AppSettings — unified settings model for deepThinkER.
///
/// This file has zero Flutter imports — pure Dart only.
library app_settings;

import 'dart:convert';

// ---------------------------------------------------------------------------
// AppSettings
// ---------------------------------------------------------------------------

/// All configurable application settings in one place.
class AppSettings {
  /// Max tool calls per minute across all characters.
  final int globalRateLimitPerMin;

  /// Path to the user's workspace / data directory.
  final String workspacePath;

  /// Default persona text applied to all characters unless overridden.
  final String personaText;

  /// Whether the proactive web-injection feature is enabled.
  final bool proactiveInjectionEnabled;

  /// Ollama model tag to use for vision tasks.
  final String visionModelName;

  /// Whether the content safety filter is active.
  final bool contentFilterEnabled;

  /// Categories currently enabled in the content filter.
  final List<String> activeFilterCategories;

  /// Whether audio sound cues are played.
  final bool soundEnabled;

  /// Whether desktop notifications are shown.
  final bool notificationsEnabled;

  /// UI font size scale: `'small'`, `'medium'`, `'large'`, or `'xl'`.
  final String fontSizeScale;

  /// Whether the high-contrast visual theme is active.
  final bool highContrastMode;

  /// Whether reduced-motion mode is active.
  final bool reducedMotionMode;

  /// Persisted settings schema version for forward-compat migrations.
  final int schemaVersion;

  const AppSettings({
    this.globalRateLimitPerMin = 10,
    this.workspacePath = '',
    this.personaText = '',
    this.proactiveInjectionEnabled = false,
    this.visionModelName = 'llava:7b',
    this.contentFilterEnabled = false,
    this.activeFilterCategories = const ['adult', 'violence', 'hate'],
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.fontSizeScale = 'medium',
    this.highContrastMode = false,
    this.reducedMotionMode = false,
    this.schemaVersion = 1,
  });

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  AppSettings copyWith({
    int? globalRateLimitPerMin,
    String? workspacePath,
    String? personaText,
    bool? proactiveInjectionEnabled,
    String? visionModelName,
    bool? contentFilterEnabled,
    List<String>? activeFilterCategories,
    bool? soundEnabled,
    bool? notificationsEnabled,
    String? fontSizeScale,
    bool? highContrastMode,
    bool? reducedMotionMode,
    int? schemaVersion,
  }) {
    return AppSettings(
      globalRateLimitPerMin:
          globalRateLimitPerMin ?? this.globalRateLimitPerMin,
      workspacePath: workspacePath ?? this.workspacePath,
      personaText: personaText ?? this.personaText,
      proactiveInjectionEnabled:
          proactiveInjectionEnabled ?? this.proactiveInjectionEnabled,
      visionModelName: visionModelName ?? this.visionModelName,
      contentFilterEnabled: contentFilterEnabled ?? this.contentFilterEnabled,
      activeFilterCategories:
          activeFilterCategories ?? this.activeFilterCategories,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      reducedMotionMode: reducedMotionMode ?? this.reducedMotionMode,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'globalRateLimitPerMin': globalRateLimitPerMin,
        'workspacePath': workspacePath,
        'personaText': personaText,
        'proactiveInjectionEnabled': proactiveInjectionEnabled,
        'visionModelName': visionModelName,
        'contentFilterEnabled': contentFilterEnabled,
        'activeFilterCategories': activeFilterCategories,
        'soundEnabled': soundEnabled,
        'notificationsEnabled': notificationsEnabled,
        'fontSizeScale': fontSizeScale,
        'highContrastMode': highContrastMode,
        'reducedMotionMode': reducedMotionMode,
        'schemaVersion': schemaVersion,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      globalRateLimitPerMin:
          json['globalRateLimitPerMin'] as int? ?? 10,
      workspacePath: json['workspacePath'] as String? ?? '',
      personaText: json['personaText'] as String? ?? '',
      proactiveInjectionEnabled:
          json['proactiveInjectionEnabled'] as bool? ?? false,
      visionModelName:
          json['visionModelName'] as String? ?? 'llava:7b',
      contentFilterEnabled:
          json['contentFilterEnabled'] as bool? ?? false,
      activeFilterCategories:
          (json['activeFilterCategories'] as List<dynamic>?)
                  ?.cast<String>() ??
              const ['adult', 'violence', 'hate'],
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ?? true,
      fontSizeScale: json['fontSizeScale'] as String? ?? 'medium',
      highContrastMode: json['highContrastMode'] as bool? ?? false,
      reducedMotionMode: json['reducedMotionMode'] as bool? ?? false,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory AppSettings.fromJsonString(String raw) =>
      AppSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
}
