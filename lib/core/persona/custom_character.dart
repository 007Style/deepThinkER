/// CustomCharacter — a user-defined AI character profile.
///
/// Persisted to ~/Documents/deepThinkER/custom_characters.json as a list.
///
/// This file has zero Flutter imports — pure Dart only.
library custom_character;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// CustomCharacter
// ---------------------------------------------------------------------------

/// A user-defined AI character with a custom personality and master prompt.
class CustomCharacter {
  /// Unique identifier (used as internal key).
  final String id;

  /// Display name shown in the UI.
  final String name;

  /// Short description of the character's personality (shown in picker).
  final String personalityDescription;

  /// Full master prompt injected as the system message for this character.
  final String masterPrompt;

  /// Ollama model ID to use (e.g. `'llama3.2:3b'`).
  final String modelId;

  const CustomCharacter({
    required this.id,
    required this.name,
    required this.personalityDescription,
    required this.masterPrompt,
    required this.modelId,
  });

  // -------------------------------------------------------------------------
  // JSON
  // -------------------------------------------------------------------------

  factory CustomCharacter.fromJson(Map<String, dynamic> json) =>
      CustomCharacter(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        personalityDescription:
            json['personalityDescription'] as String? ?? '',
        masterPrompt: json['masterPrompt'] as String? ?? '',
        modelId: json['modelId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'personalityDescription': personalityDescription,
        'masterPrompt': masterPrompt,
        'modelId': modelId,
      };

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  static String get _filePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Documents/deepThinkER/custom_characters.json';
  }

  /// Loads all custom characters from disk.  Returns empty list on error.
  static Future<List<CustomCharacter>> loadAll() async {
    final file = File(_filePath);
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CustomCharacter.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the full list of custom characters to disk.
  static Future<void> saveAll(List<CustomCharacter> characters) async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    final json = jsonEncode(characters.map((c) => c.toJson()).toList());
    await file.writeAsString(json);
  }
}
