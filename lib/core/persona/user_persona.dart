/// UserPersona — persistent user description injected into all system prompts.
///
/// This file has zero Flutter imports — pure Dart only.
library user_persona;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// UserPersona
// ---------------------------------------------------------------------------

/// Represents the user's persona description.
///
/// Persisted to `~/Documents/deepThinkER/persona.json`.
/// Text capped at 200 characters.
class UserPersona {
  static const int maxLength = 200;

  String _text;

  UserPersona({String text = ''}) : _text = _cap(text);

  /// The persona text (max 200 chars).
  String get text => _text;

  set text(String value) {
    _text = _cap(value);
  }

  bool get isEmpty => _text.isEmpty;

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  static String _path() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/Documents/deepThinkER/persona.json';
  }

  /// Loads the persona from disk.  Returns an empty persona if none saved.
  static Future<UserPersona> load() async {
    final file = File(_path());
    if (!await file.exists()) return UserPersona();
    try {
      final raw = await file.readAsString();
      final map = json.decode(raw) as Map<String, dynamic>;
      return UserPersona(text: map['text'] as String? ?? '');
    } catch (_) {
      return UserPersona();
    }
  }

  /// Saves this persona to disk.
  Future<void> save() async {
    final dir = File(_path()).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await File(_path()).writeAsString(json.encode({'text': _text}));
  }

  static String _cap(String s) =>
      s.length > maxLength ? s.substring(0, maxLength) : s;
}
