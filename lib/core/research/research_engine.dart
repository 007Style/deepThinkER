/// Orchestrates Autonomous Research Mode.
///
/// Injects a task directive into all four characters, manages phase
/// transitions on timers, collects synthesis statements, and generates
/// the final Markdown report.
///
/// This file has zero Flutter imports — pure Dart only.
library research_engine;

import 'dart:async';

import '../conversation/conversation_engine.dart';
import '../conversation/inference_worker.dart';
import '../conversation/message.dart';
import 'report_generator.dart';
import 'research_config.dart';
import 'research_session.dart';

export 'research_session.dart' show ResearchPhase;

// ---------------------------------------------------------------------------
// ResearchPhaseEvent
// ---------------------------------------------------------------------------

/// Emitted whenever the research session transitions to a new phase or
/// a synthesis statement is collected.
class ResearchPhaseEvent {
  /// The new phase.
  final ResearchPhase phase;

  /// Name of the research session.
  final String sessionName;

  /// If the event is a synthesis arrival, the character who submitted it.
  final String? synthesisByCharacter;

  /// Path to the saved report file when [phase] == [ResearchPhase.complete].
  final String? reportPath;

  /// When the event occurred.
  final DateTime timestamp;

  ResearchPhaseEvent({
    required this.phase,
    required this.sessionName,
    this.synthesisByCharacter,
    this.reportPath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// ResearchEngine
// ---------------------------------------------------------------------------

/// Manages the full lifecycle of an autonomous research session.
///
/// ### Phases
/// 1. **Gathering** — task directive injected; characters independently
///    research via tool calls. Lasts [ResearchConfig.gatherPhaseDuration].
/// 2. **Debating** — debate prompt injected; characters discuss findings.
///    Lasts [ResearchConfig.debatePhaseDuration].
/// 3. **Synthesising** — synthesis prompt injected; engine monitors for
///    characters producing short non-tool-call responses as synthesis signals.
///    Ends when all 4 synthesise or [ResearchConfig.synthesisTimeout] elapses.
/// 4. **Complete** — report generated and saved.
///
/// The user can interject at any time (normal message input remains active).
/// The engine does not block the [ConversationEngine] in any way.
class ResearchEngine {
  final ConversationEngine _engine;
  final ResearchConfig _config;
  final List<String> _characterNames;

  ResearchSession? _session;
  Timer? _phaseTimer;
  StreamSubscription<InferenceEvent>? _eventSub;

  // Accumulates tool call argument strings for source URL extraction.
  final List<String> _sourceUrls = [];

  final StreamController<ResearchPhaseEvent> _phaseController =
      StreamController<ResearchPhaseEvent>.broadcast();

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  ResearchEngine({
    required ConversationEngine engine,
    required List<String> characterNames,
    ResearchConfig? config,
  })  : _engine = engine,
        _characterNames = characterNames,
        _config = config ?? const ResearchConfig();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Stream of phase transition events. UI subscribes here.
  Stream<ResearchPhaseEvent> get phaseStream => _phaseController.stream;

  /// The active research session, or null if not running.
  ResearchSession? get currentSession => _session;

  /// Whether a research session is currently active.
  bool get isActive => _session != null && _session!.phase != ResearchPhase.complete;

  /// Starts a new research session on [topic].
  ///
  /// If a session is already running it is stopped first.
  Future<void> startResearch(String topic) async {
    if (isActive) await stopResearch();

    final session = ResearchSession.create(topic);
    _session = session;
    _sourceUrls.clear();

    // Listen to the engine event stream to detect synthesis signals and
    // track source URLs from tool calls.
    _eventSub = _engine.eventStream.listen(_onInferenceEvent);

    // Inject gathering directive to all characters.
    _injectSystemToAll(
      'RESEARCH_TASK',
      'Your task for this session: thoroughly research the following topic. '
      'Use [SEARCH:], [FETCH:], and [RECALL:] freely to gather information. '
      'Share your findings actively with the group as you discover them.\n\n'
      'Topic: $topic',
    );

    // Emit gathering phase event.
    _emitPhase(ResearchPhase.gathering);

    // Schedule transition to debating phase.
    _phaseTimer = Timer(_config.gatherPhaseDuration, _transitionToDebating);
  }

  /// Pauses an active session (stops the phase timer).
  void pause() {
    _session?.isPaused = true;
    _phaseTimer?.cancel();
  }

  /// Resumes a paused session.
  void resume() {
    if (_session == null || !(_session!.isPaused)) return;
    _session!.isPaused = false;

    // Reschedule the current phase timer with the remaining time.
    // Simple approach: restart with full phase duration from now.
    switch (_session!.phase) {
      case ResearchPhase.gathering:
        _phaseTimer = Timer(_config.gatherPhaseDuration, _transitionToDebating);
        break;
      case ResearchPhase.debating:
        _phaseTimer = Timer(_config.debatePhaseDuration, _transitionToSynthesising);
        break;
      case ResearchPhase.synthesising:
        _phaseTimer = Timer(_config.synthesisTimeout, _completeResearch);
        break;
      case ResearchPhase.complete:
        break;
    }
  }

  /// Stops and cleans up the current session.
  Future<void> stopResearch() async {
    _phaseTimer?.cancel();
    _phaseTimer = null;
    await _eventSub?.cancel();
    _eventSub = null;
    _session = null;
  }

  /// Disposes the engine — call on app shutdown.
  Future<void> dispose() async {
    await stopResearch();
    await _phaseController.close();
  }

  // -------------------------------------------------------------------------
  // Private: Phase transitions
  // -------------------------------------------------------------------------

  void _transitionToDebating() {
    if (_session == null) return;
    _session!.transitionTo(ResearchPhase.debating);
    _emitPhase(ResearchPhase.debating);

    _injectSystemToAll(
      'RESEARCH_DEBATE',
      'Gathering phase complete. Now debate and discuss your findings with the '
      'other characters. Challenge assumptions, highlight disagreements, and '
      'build on each other\'s insights. The topic: ${_session!.topic}',
    );

    _phaseTimer = Timer(_config.debatePhaseDuration, _transitionToSynthesising);
  }

  void _transitionToSynthesising() {
    if (_session == null) return;
    _session!.transitionTo(ResearchPhase.synthesising);
    _emitPhase(ResearchPhase.synthesising);

    _injectSystemToAll(
      'RESEARCH_SYNTHESISE',
      'Debate phase complete. Please provide your individual synthesis: '
      'a concise summary of your key findings and conclusions on the topic: '
      '${_session!.topic}. Keep it to 3–5 sentences.',
    );

    _phaseTimer = Timer(_config.synthesisTimeout, _completeResearch);
  }

  Future<void> _completeResearch() async {
    if (_session == null) return;
    _phaseTimer?.cancel();

    _session!.transitionTo(ResearchPhase.complete);

    // Generate the report.
    String reportPath;
    try {
      reportPath = await ReportGenerator.generate(
        session: _session!,
        characterNames: _characterNames,
        sourceUrls: List.from(_sourceUrls),
      );
    } catch (e) {
      reportPath = '';
    }

    _emitPhase(ResearchPhase.complete, reportPath: reportPath);

    await _eventSub?.cancel();
    _eventSub = null;
  }

  // -------------------------------------------------------------------------
  // Private: Event monitoring
  // -------------------------------------------------------------------------

  void _onInferenceEvent(InferenceEvent event) {
    final session = _session;
    if (session == null) return;

    // Track source URLs from SEARCH/FETCH tool call arguments.
    if (event.toolCallEvent != null) {
      final tcEvent = event.toolCallEvent!;
      final tag = tcEvent.tag.toUpperCase();
      if (tag == 'FETCH') {
        _sourceUrls.add(tcEvent.argument);
      } else if (tag == 'SEARCH') {
        // Record DDG search URL for attribution.
        _sourceUrls.add(
            'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(tcEvent.argument)}');
      }
      session.recordToolCall(event.participantName);
    }

    // During synthesising phase: detect synthesis candidates.
    // A synthesis candidate = a non-empty, non-tool-call message that is
    // the full response (isDone=true) and hasn't been recorded yet.
    if (session.phase == ResearchPhase.synthesising &&
        event.isDone == true &&
        event.fullResponse != null &&
        event.fullResponse!.trim().isNotEmpty &&
        !session.synthesisStatements.containsKey(event.participantName)) {
      final text = event.fullResponse!.trim();
      // Only treat as synthesis if it doesn't contain another tool-call tag.
      if (!RegExp(r'\[[A-Z_]+:').hasMatch(text)) {
        session.recordSynthesis(event.participantName, text);
        _emitPhase(
          ResearchPhase.synthesising,
          synthesisByCharacter: event.participantName,
        );

        // If all characters have synthesised, complete early.
        if (session.synthesisStatements.length >= _characterNames.length) {
          _completeResearch();
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Private: helpers
  // -------------------------------------------------------------------------

  void _injectSystemToAll(String tag, String content) {
    final msg = Message(
      participantName: 'SYSTEM',
      content: '[$tag]: $content',
      isUser: false,
      isEphemeral: true,
    );
    _engine.injectSystemMessage(msg);
  }

  void _emitPhase(
    ResearchPhase phase, {
    String? synthesisByCharacter,
    String? reportPath,
  }) {
    if (!_phaseController.isClosed && _session != null) {
      _phaseController.add(ResearchPhaseEvent(
        phase: phase,
        sessionName: _session!.sessionName,
        synthesisByCharacter: synthesisByCharacter,
        reportPath: reportPath,
      ));
    }
  }
}
