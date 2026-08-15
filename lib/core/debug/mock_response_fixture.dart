// MockResponseFixture — a single scripted mock response for simulation mode.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:convert';

// ---------------------------------------------------------------------------
// MockResponseFixture
// ---------------------------------------------------------------------------

/// Defines a scripted response to be streamed by [MockOllamaClient].
class MockResponseFixture {
  /// The character name this fixture is bound to.
  final String characterName;

  /// The full response text to stream (word-by-word).
  final String responseText;

  /// Delay in milliseconds between each word token.
  final int delayMs;

  /// List of tool-call tag strings to emit mid-stream (e.g. `'[SEARCH: test]'`).
  ///
  /// These are interleaved at the midpoint of the response.
  final List<String> toolCallsToEmit;

  const MockResponseFixture({
    required this.characterName,
    required this.responseText,
    this.delayMs = 50,
    this.toolCallsToEmit = const [],
  });

  Map<String, dynamic> toJson() => {
        'characterName': characterName,
        'responseText': responseText,
        'delayMs': delayMs,
        'toolCallsToEmit': toolCallsToEmit,
      };

  factory MockResponseFixture.fromJson(Map<String, dynamic> json) {
    return MockResponseFixture(
      characterName: json['characterName'] as String? ?? '',
      responseText: json['responseText'] as String? ?? '',
      delayMs: json['delayMs'] as int? ?? 50,
      toolCallsToEmit:
          (json['toolCallsToEmit'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  /// Parses a JSON array of fixture objects.
  static List<MockResponseFixture> listFromJson(String raw) {
    final list = json.decode(raw) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(MockResponseFixture.fromJson)
        .toList();
  }
}
