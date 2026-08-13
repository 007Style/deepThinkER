/// Models the state of an Autonomous Research Mode session.
///
/// This file has zero Flutter imports — pure Dart only.
library research_session;

// ---------------------------------------------------------------------------
// ResearchPhase
// ---------------------------------------------------------------------------

/// The current phase of a research session.
enum ResearchPhase {
  /// Characters independently search and gather information.
  gathering,

  /// Characters discuss and challenge each other's findings.
  debating,

  /// Characters produce their individual synthesis statements.
  synthesising,

  /// All syntheses collected (or timeout reached); report generated.
  complete,
}

// ---------------------------------------------------------------------------
// ResearchSession
// ---------------------------------------------------------------------------

/// Tracks the state of a single autonomous research session.
class ResearchSession {
  /// The research topic given by the user.
  final String topic;

  /// Unique name derived from topic + timestamp.
  final String sessionName;

  /// When the session started.
  final DateTime startTime;

  /// Current phase.
  ResearchPhase phase;

  /// When the current phase started.
  DateTime phaseStartTime;

  /// Tool call counts per character during this session.
  final Map<String, int> toolCallCounts;

  /// Synthesis statements collected per character.
  /// Key = characterName, value = synthesis text.
  final Map<String, String> synthesisStatements;

  /// Whether the session is currently paused.
  bool isPaused;

  ResearchSession._({
    required this.topic,
    required this.sessionName,
    required this.startTime,
    required this.phase,
    required this.phaseStartTime,
    required this.toolCallCounts,
    required this.synthesisStatements,
  });

  /// Creates a new research session for [topic].
  factory ResearchSession.create(String topic) {
    final now = DateTime.now();
    // Sanitise topic for use as part of a filename.
    final safeTopic = topic
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    final ts =
        '${now.year}${_p(now.month)}${_p(now.day)}_${_p(now.hour)}${_p(now.minute)}';
    return ResearchSession._(
      topic: topic,
      sessionName: 'research_${safeTopic}_$ts',
      startTime: now,
      phase: ResearchPhase.gathering,
      phaseStartTime: now,
      toolCallCounts: {},
      synthesisStatements: {},
    );
  }

  /// Increments the tool call count for [characterName].
  void recordToolCall(String characterName) {
    toolCallCounts[characterName] = (toolCallCounts[characterName] ?? 0) + 1;
  }

  /// Returns true if [characterName] has reached the per-character tool call limit.
  bool isToolLimitReached(String characterName, int maxCalls) {
    return (toolCallCounts[characterName] ?? 0) >= maxCalls;
  }

  /// Records a synthesis statement from [characterName].
  void recordSynthesis(String characterName, String text) {
    synthesisStatements[characterName] = text;
  }

  /// Transitions to [newPhase] and resets the phase timer.
  void transitionTo(ResearchPhase newPhase) {
    phase = newPhase;
    phaseStartTime = DateTime.now();
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}
