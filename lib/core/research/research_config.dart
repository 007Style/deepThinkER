// Configuration for Autonomous Research Mode.
//
// All durations and limits are user-configurable.
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// ResearchConfig
// ---------------------------------------------------------------------------

/// Governs timing and limits for an autonomous research session.
class ResearchConfig {
  /// How long the gathering phase runs before transitioning to debate.
  final Duration gatherPhaseDuration;

  /// How long the debate/discussion phase runs.
  final Duration debatePhaseDuration;

  /// How long to wait for all characters to produce a synthesis before
  /// timing out and generating the report with what's available.
  final Duration synthesisTimeout;

  /// Maximum number of tool calls each character may make during research.
  /// Applies to [SEARCH:], [FETCH:], [RECALL:] combined.
  final int maxToolCallsPerCharacter;

  const ResearchConfig({
    this.gatherPhaseDuration = const Duration(minutes: 5),
    this.debatePhaseDuration = const Duration(minutes: 5),
    this.synthesisTimeout = const Duration(minutes: 2),
    this.maxToolCallsPerCharacter = 10,
  });

  /// A fast config for development/testing.
  const ResearchConfig.fast()
      : gatherPhaseDuration = const Duration(seconds: 30),
        debatePhaseDuration = const Duration(seconds: 30),
        synthesisTimeout = const Duration(seconds: 20),
        maxToolCallsPerCharacter = 3;
}
