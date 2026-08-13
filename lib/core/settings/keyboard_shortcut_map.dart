/// KeyboardShortcutMap — pure Dart model of default keyboard shortcut bindings.
///
/// This file has zero Flutter imports — pure Dart only.
library keyboard_shortcut_map;

// ---------------------------------------------------------------------------
// KeyboardShortcutMap
// ---------------------------------------------------------------------------

/// Maps action names to their default key combo strings.
///
/// Key combo strings use the format `'Modifier+Key'` (e.g. `'Cmd+R'`) or a
/// bare key name (e.g. `'Enter'`).
///
/// These strings are human-readable display labels.  The actual [LogicalKeySet]
/// bindings are resolved in [ShortcutHandler] from the Flutter layer.
class KeyboardShortcutMap {
  /// Default bindings for all registered actions.
  static const Map<String, String> defaults = {
    'sendMessage': 'Enter',
    'newLine': 'Shift+Enter',
    'openResearch': 'Cmd+R',
    'openSettings': 'Cmd+,',
    'openAnalytics': 'Cmd+A',
    'toggleSteering': 'Cmd+T',
    'clearConversation': 'Cmd+Shift+K',
    'focusInput': 'Cmd+L',
    'showShortcuts': 'Cmd+/',
  };

  /// Current mutable bindings.  Starts as a copy of [defaults].
  final Map<String, String> bindings;

  KeyboardShortcutMap({Map<String, String>? bindings})
      : bindings = bindings ?? Map<String, String>.from(defaults);

  /// Returns the binding string for [action], or `null` if not registered.
  String? binding(String action) => bindings[action];

  /// All registered action names.
  List<String> get actions => bindings.keys.toList();

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(bindings);

  factory KeyboardShortcutMap.fromJson(Map<String, dynamic> json) {
    return KeyboardShortcutMap(
      bindings: {
        ...defaults,
        ...json.map((k, v) => MapEntry(k, v as String)),
      },
    );
  }
}
