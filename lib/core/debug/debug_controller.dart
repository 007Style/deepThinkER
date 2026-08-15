// DebugController — singleton with hooks for simulating state changes.
//
// Wires up callback hooks that the main screen can bind to its own state.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// DebugController
// ---------------------------------------------------------------------------

/// Singleton debug controller.
///
/// Methods trigger the corresponding callback hooks if wired up.  The UI
/// (main screen) binds callbacks during init.
///
/// ```dart
/// DebugController.instance.onSetTrust = (char, score) {
///   setState(() => trustScores[char] = score);
/// };
/// DebugController.instance.setTrust('Aria', 0.75);
/// ```
class DebugController {
  DebugController._();

  static final DebugController instance = DebugController._();

  // ---------------------------------------------------------------------------
  // Callback hooks (wired up by the main screen)
  // ---------------------------------------------------------------------------

  /// Called when [setTrust] is invoked.  Args: (characterName, score 0.0–1.0).
  Function(String character, double score)? onSetTrust;

  /// Called when [setMood] is invoked.  Args: (characterName, moodState).
  Function(String character, String moodState)? onSetMood;

  /// Called when [setRelationship] is invoked.  Args: (a, b, score –100..100).
  Function(String a, String b, int score)? onSetRelationship;

  /// Called when [fireRateLimitViolation] is invoked.
  Function(String character)? onFireRateLimitViolation;

  /// Called when [simulateOllamaCrash] is invoked.
  Function()? onSimulateOllamaCrash;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sets the trust score for [character] to [score] (0.0–1.0).
  void setTrust(String character, double score) {
    onSetTrust?.call(character, score.clamp(0.0, 1.0));
  }

  /// Sets the mood state of [character] to [moodState].
  void setMood(String character, String moodState) {
    onSetMood?.call(character, moodState);
  }

  /// Sets the relationship score between [a] and [b] to [score] (−100..100).
  void setRelationship(String a, String b, int score) {
    onSetRelationship?.call(a, b, score.clamp(-100, 100));
  }

  /// Fires a simulated rate-limit violation for [character].
  void fireRateLimitViolation(String character) {
    onFireRateLimitViolation?.call(character);
  }

  /// Simulates an Ollama crash event.
  void simulateOllamaCrash() {
    onSimulateOllamaCrash?.call();
  }
}
