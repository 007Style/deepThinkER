/// MockOllamaClient — streams scripted responses for offline simulation mode.
///
/// Implements the same [generateStream] interface as [OllamaClient] so it can
/// be swapped in transparently during development / testing.
///
/// This file has zero Flutter imports — pure Dart only.
library mock_ollama_client;

import 'dart:async';

import 'mock_response_fixture.dart';

// ---------------------------------------------------------------------------
// MockOllamaClient
// ---------------------------------------------------------------------------

/// Drop-in replacement for [OllamaClient] that streams tokens from a list of
/// [MockResponseFixture] objects instead of hitting a real Ollama server.
///
/// Fixtures are matched by [MockResponseFixture.characterName].  If no
/// matching fixture is found, a default "no fixture" message is streamed.
class MockOllamaClient {
  /// The pool of scripted fixtures to draw from.
  final List<MockResponseFixture> fixtures;

  /// Default per-token delay when no fixture matches.
  final int defaultDelayMs;

  MockOllamaClient({
    required this.fixtures,
    this.defaultDelayMs = 40,
  });

  // ---------------------------------------------------------------------------
  // generateStream — same signature as OllamaClient.generateStream
  // ---------------------------------------------------------------------------

  /// Streams a scripted response matching [model] as the character name,
  /// or falls back to the first fixture in the list.
  ///
  /// Tokens are the individual words of the response text, separated by spaces.
  /// [toolCallsToEmit] from the fixture are injected at the midpoint.
  Future<void> generateStream({
    required String model,
    required List<Map<String, String>> messages,
    required int numCtx,
    required void Function(String token) onToken,
    required void Function() onDone,
    void Function(Object error)? onError,
  }) async {
    try {
      final fixture = _fixtureFor(model);
      final words = fixture.responseText.split(' ');
      final midpoint = words.length ~/ 2;
      final delay = Duration(milliseconds: fixture.delayMs);

      for (var i = 0; i < words.length; i++) {
        await Future<void>.delayed(delay);
        onToken('${words[i]} ');

        // Emit tool calls at midpoint.
        if (i == midpoint) {
          for (final tag in fixture.toolCallsToEmit) {
            await Future<void>.delayed(delay);
            onToken(tag);
          }
        }
      }
      onDone();
    } catch (error) {
      if (onError != null) {
        onError(error);
      } else {
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers — mimic OllamaClient surface used by ModelManager / health checks
  // ---------------------------------------------------------------------------

  Future<List<String>> listModels() async =>
      fixtures.map((f) => f.characterName).toSet().toList();

  Future<bool> isHealthy() async => true;

  void close() {}
  void abortInFlight() {}

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  MockResponseFixture _fixtureFor(String characterName) {
    return fixtures.firstWhere(
      (f) => f.characterName.toLowerCase() == characterName.toLowerCase(),
      orElse: () => fixtures.isNotEmpty
          ? fixtures.first
          : const MockResponseFixture(
              characterName: 'default',
              responseText: '[MockOllamaClient] No fixture configured.',
            ),
    );
  }
}
