// User-name detector for deepThink.
//
// Scans AI responses for natural-language signals that the user has given
// (or been given) a name, and extracts that name so the UI can update the
// user's display label dynamically.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// UserNameDetector
// ---------------------------------------------------------------------------

/// Detects when an AI response contains a user-rename signal.
///
/// The easter egg works purely through conversation content — there is no UI
/// setting. When an AI says something like "I'll call you Alex" or "OK, Max,
/// that's a great point", this detector picks up the new name so the UI can
/// update the user's label dynamically.
///
/// ```dart
/// final newName = UserNameDetector.detectRename(
///   'Sure, I\'ll call you Alex from now on.',
///   'User',
/// );
/// print(newName); // "Alex"
/// ```
class UserNameDetector {
  UserNameDetector._();

  /// Maximum character length for an accepted user name.
  static const int maxNameLength = 20;

  // Compiled patterns for common rename phrasings.
  static final List<RegExp> _patterns = [
    // "I'll call you X", "I'll call you X from now on"
    RegExp(
      r"i[''']?ll\s+call\s+you\s+([A-Za-z][A-Za-z0-9_\-]{0,19})",
      caseSensitive: false,
    ),
    // "I will call you X"
    RegExp(
      r'i\s+will\s+call\s+you\s+([A-Za-z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
    // "you mentioned your name is X", "your name is X"
    RegExp(
      r'your\s+name\s+is\s+([A-Za-z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
    // "you said your name is X"
    RegExp(
      r'you\s+said\s+your\s+name\s+is\s+([A-Za-z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
    // "you introduced yourself as X"
    RegExp(
      r'introduced\s+yourself\s+as\s+([A-Za-z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
    // "nice to meet you, X" / "nice to meet you X"
    RegExp(
      r'nice\s+to\s+meet\s+you[,\s]+([A-Z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
    // "welcome, X" at sentence start
    RegExp(
      r'welcome[,\s]+([A-Z][A-Za-z]{1,19})\b',
      caseSensitive: false,
    ),
    // "OK X," or "Okay X," or "Sure X," — greeting by name
    RegExp(
      r'(?:^|[.!?]\s+)(?:ok(?:ay)?|sure|right|alright|great)[,\s]+([A-Z][A-Za-z]{1,19})[,\s]',
      caseSensitive: false,
    ),
    // "so X," at sentence/turn start — addressing by name
    RegExp(
      r'(?:^|[.!?]\s+)so[,\s]+([A-Z][A-Za-z]{1,19})[,\s]',
      caseSensitive: false,
    ),
    // "that's a great point, X" / "good point, X"
    RegExp(
      r'(?:great|good|excellent|fair|interesting)\s+point[,\s]+([A-Z][A-Za-z]{1,19})\b',
      caseSensitive: false,
    ),
    // "tell me, X" / "tell me more, X"
    RegExp(
      r'tell\s+me(?:\s+more)?[,\s]+([A-Z][A-Za-z]{1,19})\b',
      caseSensitive: false,
    ),
    // "my name for you is X"
    RegExp(
      r'my\s+name\s+for\s+you\s+is\s+([A-Za-z][A-Za-z0-9_\-]{0,19})',
      caseSensitive: false,
    ),
  ];

  // Words that should never be accepted as user names (common false-positive triggers).
  static const Set<String> _blocklist = {
    'the', 'a', 'an', 'you', 'your', 'user', 'they', 'them', 'that',
    'this', 'here', 'there', 'what', 'who', 'how', 'why', 'when',
    'me', 'my', 'i', 'we', 'us', 'our', 'it', 'its', 'him', 'his',
    'her', 'she', 'he', 'now', 'then', 'just', 'so', 'no', 'yes',
    'not', 'all', 'more', 'some', 'any', 'sure', 'right', 'good',
    'great', 'ok', 'okay', 'well', 'true', 'false',
  };

  /// Scans [aiResponse] for a user-rename signal.
  ///
  /// Returns the detected name (trimmed, stripped of trailing punctuation,
  /// max [maxNameLength] characters) if a pattern matches and the candidate
  /// passes validation. Returns `null` otherwise.
  ///
  /// [currentUserName] is used to avoid re-returning the name that is already
  /// set (prevents spurious updates).
  static String? detectRename(String aiResponse, String currentUserName) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(aiResponse);
      if (match == null) continue;

      final candidate = _sanitise(match.group(1) ?? '');
      if (candidate.isEmpty) continue;
      if (_isInvalid(candidate, currentUserName)) continue;

      return candidate;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Strips leading/trailing whitespace and trailing punctuation, then
  /// truncates to [maxNameLength].
  static String _sanitise(String raw) {
    // Remove trailing punctuation (period, comma, exclamation, etc.)
    var clean = raw.trim().replaceAll(RegExp(r'[^\w\-]+$'), '');
    if (clean.length > maxNameLength) {
      clean = clean.substring(0, maxNameLength);
    }
    return clean;
  }

  /// Returns `true` if the candidate should be rejected.
  static bool _isInvalid(String candidate, String currentUserName) {
    if (candidate.isEmpty) return true;
    if (candidate.length > maxNameLength) return true;
    if (_blocklist.contains(candidate.toLowerCase())) return true;
    if (candidate.toLowerCase() == currentUserName.toLowerCase()) return true;
    // Must start with a letter.
    if (!RegExp(r'^[A-Za-z]').hasMatch(candidate)) return true;
    return false;
  }
}
