// Main application screen for deepThink.
//
// Assembles: top header bar, 2×2 quadrant grid, user input bar, status band.
// Manages ConversationEngine lifecycle, routes InferenceEvents to quadrants,
// and tracks user-name easter-egg updates.
//
// Key design points:
//   • Each AI quadrant shows ONLY its own messages + user messages.
//   • User can type and queue messages BEFORE pressing Start.
//   • Queued messages are injected into the engine in order once Start fires.
//   • Messages carry a roundIndex for color-banding in the quadrant panels.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics/session_analytics.dart';
import '../../core/conversation/conversation_engine.dart';
import '../../core/conversation/conversation_log.dart';
import '../../core/conversation/inference_worker.dart';
import '../../core/conversation/message.dart';
import '../../core/conversation/whisper_message.dart';
import '../../core/conversation/participant.dart';
import '../../core/conversation/user_name_detector.dart';
import '../../core/mood/mood_engine.dart';
import '../../core/network/rate_limiter.dart';
import '../../core/ollama/hardware_detector.dart';
import '../../core/ollama/ollama_client.dart';
import '../../core/relationships/relationship_matrix.dart';
import '../../core/security/content_filter.dart';
import '../../core/session/session.dart';
import '../../core/session/session_manager.dart';
import '../../core/steering/steering_engine.dart';
import '../../core/tools/tool_call_interceptor.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/trust/trust_manager.dart';

import '../../core/session/replay_mode.dart';
import '../../core/tools/file/file_tool_config.dart';
import '../../core/tools/image/image_watcher.dart';
import 'analytics_screen.dart';
import 'research_mode_screen.dart';
import 'settings_screen.dart';
import '../avatars/avatar_widget.dart';
import '../debug/state_simulator_panel.dart';
import '../quadrants/quadrant_grid.dart';
import '../widgets/app_theme.dart';
import '../widgets/help_menu.dart';
import '../widgets/network_indicator/rate_limit_flash.dart';
import '../widgets/relationship_matrix_widget.dart';
import '../widgets/replay_banner.dart';
import '../widgets/start_stop_button.dart';
import '../widgets/status_band.dart';
import '../widgets/steering_input_bar.dart';

import '../widgets/user_input_bar.dart';
import 'startup_config_screen.dart';

// ---------------------------------------------------------------------------
// MainScreen
// ---------------------------------------------------------------------------

/// The primary application window, shown once startup configuration is done.
///
/// Accepts:
/// - [participants]       — the four configured [Participant] objects.
/// - [hardware]           — detected [HardwareInfo] for display and context sizing.
/// - [replayLog]          — optional pre-loaded [ConversationLog] for replay mode.
/// - [replayMode]         — the [ReplayMode] to use when [replayLog] is provided.
/// - [replaySessionName]  — display name of the replayed session.
class MainScreen extends StatefulWidget {
  /// The four AI participants to display.
  final List<Participant> participants;

  /// Detected hardware info (RAM tier, backend).
  final HardwareInfo hardware;

  /// Optional pre-loaded conversation log for session replay.
  final ConversationLog? replayLog;

  /// The replay mode — required when [replayLog] is provided.
  final ReplayMode? replayMode;

  /// Display name of the replayed session.
  final String? replaySessionName;

  const MainScreen({
    required this.participants,
    required this.hardware,
    this.replayLog,
    this.replayMode,
    this.replaySessionName,
    super.key,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// ---------------------------------------------------------------------------
// _QuadrantState — per-participant mutable state
// ---------------------------------------------------------------------------

class _QuadrantState {
  /// Only this participant's own messages + user messages (chronological).
  final List<Message> messages = [];
  AvatarState avatarState = AvatarState.idle;
  bool isThinking = false;

  // Each quadrant gets its own broadcast StreamController for live tokens.
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();

  Stream<String> get tokenStream => tokenController.stream;

  void dispose() {
    tokenController.close();
  }
}

// ---------------------------------------------------------------------------
// _MainScreenState
// ---------------------------------------------------------------------------

class _MainScreenState extends State<MainScreen> {
  // Core — engine is recreated on every Start so it can be restarted cleanly.
  ConversationEngine? _engine;
  late final SessionManager _sessionManager;
  Session? _session;
  StreamSubscription<InferenceEvent>? _engineSub;
  StreamSubscription<Message>? _logMessageSub;
  StreamSubscription<Message>? _logSub;

  // GlobalKey to call warpToHead on the QuadrantGrid.
  final GlobalKey<QuadrantGridState> _gridKey = GlobalKey<QuadrantGridState>();

  // UI state
  bool _isRunning = false;
  bool _isPaused = false;
  /// True while a stop-and-unload or start sequence is in progress.
  /// Blocks the Start button to prevent double-presses.
  bool _isBusy = false;
  String _userName = 'User';
  String _sessionName = '';

  // Replay state
  bool _showReplayBanner = false;

  /// Whether the relationship matrix panel is visible.
  bool _showRelationships = false;

  /// Shared relationship matrix (session-scoped, instantiated in _start).
  final RelationshipMatrix _relationshipMatrix = RelationshipMatrix();

  /// Image watcher — monitors workspace for dropped images.
  ImageWatcher? _imageWatcher;

  /// Broadcast stream controller for image drop events.
  final StreamController<ImageDroppedEvent> _imageEventController =
      StreamController<ImageDroppedEvent>.broadcast();

  StreamSubscription<ImageDroppedEvent>? _imageWatcherSub;

  /// Session analytics (created on Start, disposed on Stop).
  SessionAnalytics? _sessionAnalytics;

  /// Whether the steering bar is visible.
  bool _showSteering = false;

  /// Whether the debug state simulator panel is visible (debug builds only).
  bool _showDebugPanel = false;

  /// Steering engine (created after engine starts).
  SteeringEngine? _steeringEngine;

  // Messages typed before Start — injected in order when engine starts.
  final List<String> _pendingUserMessages = [];

  // One _QuadrantState per participant (keyed by participant name).
  final Map<String, _QuadrantState> _quadrantStates = {};

  // ── Trust / mood / network ───────────────────────────────────────────────

  /// Session-scoped trust manager (created on Start, disposed on Stop).
  TrustManager? _trustManager;

  /// Session-scoped rate limiter (created on Start, disposed on Stop).
  RateLimiter? _rateLimiter;

  /// Session-scoped mood engine (created on Start, disposed on Stop).
  MoodEngine? _moodEngine;

  /// Per-character rate-limit flash controllers (created on Start, cleared on Stop).
  final Map<String, RateLimitFlashController> _rateLimitControllers = {};

  /// Per-character broadcast stream controllers for live TrustScore updates.
  final Map<String, StreamController<TrustScore>> _trustStreamControllers = {};

  /// Per-character broadcast stream controllers for live MoodScore updates.
  final Map<String, StreamController<MoodScore>> _moodStreamControllers = {};

  /// Subscription to the TrustManager event stream.
  StreamSubscription<TrustEvent>? _trustSub;

  /// Subscription to the MoodEngine mood stream.
  StreamSubscription<MoodChangeEvent>? _moodSub;

  /// Subscription to the ToolCallInterceptor event stream.
  StreamSubscription<ToolCallEvent>? _toolEventSub;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    for (final p in widget.participants) {
      _quadrantStates[p.name] = _QuadrantState();
    }
    _startImageWatcher();
    // If a replay log was passed, schedule the loadReplay after first frame.
    if (widget.replayLog != null) {
      _showReplayBanner = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _initReplay());
    }
  }

  Future<void> _initReplay() async {
    final log = widget.replayLog;
    final mode = widget.replayMode;
    if (log == null || mode == null) return;

    // Create engine, load replay, then start normally.
    _engine = ConversationEngine(client: OllamaClient());
    await _engine!.loadReplay(log, mode);
    // loadReplay only seeds the log; the engine still needs start() called
    // to create workers — _start() handles that.
  }

  void _startImageWatcher() async {
    final watchPath = FileToolConfig.instance.workspacePath;
    _imageWatcher = ImageWatcher(watchPath: watchPath);
    await _imageWatcher!.start();
    _imageWatcherSub = _imageWatcher!.events.listen((event) {
      if (!_imageEventController.isClosed) {
        _imageEventController.add(event);
      }
    });
  }

  @override
  void dispose() {
    _stop();
    _imageWatcherSub?.cancel();
    _imageWatcher?.stop();
    _imageEventController.close();
    for (final qs in _quadrantStates.values) {
      qs.dispose();
    }
    // Dispose trust/mood stream controllers.
    for (final sc in _trustStreamControllers.values) {
      sc.close();
    }
    for (final sc in _moodStreamControllers.values) {
      sc.close();
    }
    for (final ctrl in _rateLimitControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Start / Stop
  // -------------------------------------------------------------------------

  Future<void> _start() async {
    if (_isRunning || _isBusy) return;
    setState(() => _isBusy = true);

    final names = widget.participants.map((p) => p.name).toList();

    // ── Trust / mood / network setup ────────────────────────────────────────

    // Create per-character stream controllers (reuse existing if already
    // created; create fresh ones on first start).
    for (final name in names) {
      _trustStreamControllers.putIfAbsent(
          name, () => StreamController<TrustScore>.broadcast());
      _moodStreamControllers.putIfAbsent(
          name, () => StreamController<MoodScore>.broadcast());
      _rateLimitControllers.putIfAbsent(
          name, () => RateLimitFlashController());
    }

    // TrustManager — fresh per session so scores accumulate correctly.
    _trustManager = TrustManager(characterNames: names);
    await _trustManager!.init();

    // RateLimiter wired to the TrustManager.
    _rateLimiter = RateLimiter(
      config: const RateLimitConfig(),
      trustManager: _trustManager!,
    );
    _rateLimiter!.init();

    // MoodEngine — fresh per session.
    _moodEngine = MoodEngine(characterNames: names);

    // Subscribe to trust events → fan-out per-character TrustScore streams.
    // event.newScore is a double; we fetch the full TrustScore from the manager.
    // Also trigger the rate-limit flash when a violation is recorded.
    _trustSub = _trustManager!.trustStream.listen((event) {
      final sc = _trustStreamControllers[event.characterName];
      if (sc != null && !sc.isClosed) {
        sc.add(_trustManager!.scoreFor(event.characterName));
      }
      if (event.reason == TrustEventReason.rateLimitViolation) {
        _rateLimitControllers[event.characterName]?.trigger();
      }
    });

    // Subscribe to mood events → fan-out per-character MoodScore streams.
    // event.newScore is an int; we fetch the full MoodScore from the engine.
    _moodSub = _moodEngine!.moodStream.listen((event) {
      final sc = _moodStreamControllers[event.characterName];
      if (sc != null && !sc.isClosed) {
        sc.add(_moodEngine!.scoreFor(event.characterName));
      }
    });

    // ── Always create a fresh engine — ConversationEngine is single-use ─────

    _engine = ConversationEngine(client: OllamaClient());

    // Create session.
    final session = await _sessionManager.createSession(
      participants: widget.participants,
    );
    _session = session;

    // Start analytics tracking.
    _sessionAnalytics = SessionAnalytics(sessionName: session.name);

    // Create steering engine after engine is created.
    _steeringEngine = SteeringEngine(engine: _engine!);

    // Wire up ALL subscriptions BEFORE starting the engine so no messages
    // are missed on the broadcast stream.  Order matters:
    //   1. File logging — every message must land on disk.
    //   2. UI display subscription.
    //   3. Engine start (emits kickoff) + pending message injection.
    _logSub = await _sessionManager.startLogging(
      session,
      _engine!.log.messageStream,
    );

    _engineSub = _engine!.eventStream.listen(_handleEvent);
    _logMessageSub = _engine!.log.messageStream.listen(_handleLogMessage);

    // Start the engine (appends kickoff message — workers see it immediately).
    await _engine!.start(widget.participants, widget.hardware);

    // ── Wire interceptor (must be after engine.start so workers exist) ──────
    final interceptor = ToolCallInterceptor(
      registry: ToolRegistry.instance,
      rateLimiter: _rateLimiter!,
      trustManager: _trustManager!,
      sessionName: session.name,
      contentFilter: ContentFilter.empty(),
    );
    _engine!.setInterceptorOnAllWorkers(interceptor);

    // Subscribe to tool-call events → show search activity inline.
    _toolEventSub = interceptor.eventStream.listen(_handleToolCallEvent);

    // Feed mood engine from the log message stream.
    _engine!.log.messageStream.listen((msg) => _moodEngine?.onMessage(msg));

    // Clear the local preview messages that were shown while the engine was
    // stopped — the real messages will arrive via _handleLogMessage as the
    // engine re-injects them into the shared log, so without this clear they
    // would appear twice.
    for (final qs in _quadrantStates.values) {
      qs.messages.clear();
    }

    // Inject any messages the user queued before pressing Start.
    for (final text in _pendingUserMessages) {
      _engine!.injectUserMessage(_userName, text);
    }
    _pendingUserMessages.clear();

    setState(() {
      _isRunning = true;
      _isBusy = false;
      _sessionName = session.name;
    });
  }

  // -------------------------------------------------------------------------
  // Reconfigure — stop session and return to config screen
  // -------------------------------------------------------------------------

  Future<void> _reconfigure() async {
    if (_isBusy) return;

    // If a session is running, ask for confirmation before tearing it down.
    if (_isRunning) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'End session?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'The current session will be stopped and all models will be '
            'unloaded. You can reconfigure and start a new session.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('End & Reconfigure',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _stop();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => StartupConfigScreen(hardware: widget.hardware),
      ),
    );
  }

  Future<void> _stop() async {
    if (!_isRunning || _isBusy) return;
    setState(() => _isBusy = true);

    // Abort any in-flight HTTP streams immediately — prevents unloadModel
    // from queuing behind an active inference.
    _engine?.pause();

    // Cancel the UI event subscription first so no more state updates fire.
    await _engineSub?.cancel();
    _engineSub = null;

    // Cancel the log-message subscription so no more messages hit the display.
    await _logMessageSub?.cancel();
    _logMessageSub = null;

    // Cancel trust / mood / tool-call subscriptions.
    await _trustSub?.cancel();
    _trustSub = null;
    await _moodSub?.cancel();
    _moodSub = null;
    await _toolEventSub?.cancel();
    _toolEventSub = null;

    // Stop the engine (stops workers, unloads models, disposes log stream).
    await _engine?.stop();
    _engine = null;

    // End the session BEFORE cancelling _logSub — endSession flushes and
    // closes the IOSink; cancelling _logSub afterward is safe because the
    // sink is already gone and won't be double-closed.
    if (_session != null) {
      await _sessionManager.endSession(_session!);
      _session = null;
    }

    // Flush and dispose analytics.
    await _sessionAnalytics?.dispose();
    _sessionAnalytics = null;
    _steeringEngine = null;

    // Dispose trust + mood engines.
    await _trustManager?.dispose();
    _trustManager = null;
    _rateLimiter = null;
    _moodEngine = null;

    await _logSub?.cancel();
    _logSub = null;

    // Reset quadrant states (clear messages too so the next session is fresh).
    for (final qs in _quadrantStates.values) {
      qs.avatarState = AvatarState.idle;
      qs.isThinking = false;
      qs.messages.clear();
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isPaused = false;
        _isBusy = false;
        _sessionName = '';
      });
    }
  }

  void _pause() {
    _engine?.pause();
    if (mounted) setState(() => _isPaused = true);
  }

  void _resume() {
    _engine?.resume();
    if (mounted) setState(() => _isPaused = false);
  }

  // -------------------------------------------------------------------------
  // Event routing
  // -------------------------------------------------------------------------

  void _handleEvent(InferenceEvent event) {
    final qs = _quadrantStates[event.participantName];
    if (qs == null) return;

    if (event.isThinking) {
      setState(() {
        qs.avatarState = AvatarState.thinking;
        qs.isThinking = true;
      });
      return;
    }

    if (event.token != null) {
      qs.tokenController.add(event.token!);
      if (qs.avatarState != AvatarState.speaking) {
        setState(() => qs.avatarState = AvatarState.speaking);
      }

      // Run user-name detection on every token batch.
      final newName = UserNameDetector.detectRename(event.token!, _userName);
      if (newName != null && mounted) {
        setState(() => _userName = newName);
      }
      return;
    }

    if (event.isDone) {
      setState(() {
        qs.avatarState = AvatarState.idle;
        qs.isThinking = false;
      });
    }
  }

  void _handleLogMessage(Message msg) {
    if (!mounted) return;
    if (msg.isPass) return;

    setState(() {
      if (msg.isWhisper) {
        // Whisper: only appears in the target character's quadrant.
        final target = (msg as WhisperMessage).targetCharacter;
        final qs = _quadrantStates[target];
        qs?.messages.add(msg);
      } else if (msg.isUser) {
        // Normal user messages appear in ALL quadrant panels.
        for (final qs in _quadrantStates.values) {
          qs.messages.add(msg);
        }
      } else {
        // AI message: only the owner's quadrant panel.
        final qs = _quadrantStates[msg.participantName];
        qs?.messages.add(msg);
      }
    });
  }

  /// Handles a [ToolCallEvent] from the interceptor.
  ///
  /// For network tools (SEARCH / FETCH) the call is surfaced as an inline
  /// activity notice in the owning character's quadrant message list.
  void _handleToolCallEvent(ToolCallEvent event) {
    if (!mounted) return;
    final qs = _quadrantStates[event.characterName];
    if (qs == null) return;

    final isSearch = event.tag == 'SEARCH';
    final isFetch = event.tag == 'FETCH';
    if (!isSearch && !isFetch) return; // Only surface network tool calls.

    // Build a synthetic ephemeral message so the quadrant panel can render it
    // as a SearchActivityEntry.  We use isEphemeral=true so it never appears
    // in exports or session logs.
    final label = event.result.wasRateLimited
        ? '🚫 ${event.tag} rate-limited: ${event.argument}'
        : event.result.wasDisabled
            ? '⛔ ${event.tag} disabled: ${event.argument}'
            : '🔍 ${event.tag}: ${event.argument}';

    final activityMsg = Message(
      participantName: event.characterName,
      content: label,
      isUser: false,
      isEphemeral: true,
      roundIndex: 0,
    );

    setState(() {
      qs.messages.add(activityMsg);
    });
  }

  // -------------------------------------------------------------------------
  // User input
  // -------------------------------------------------------------------------

  void _warpToHead() => QuadrantGrid.warpToHead(_gridKey);

  void _onUserSubmit(String text) {
    // Check if the user is telling us their name ("my name is X").
    final detectedName = _detectUserSelfIntroduction(text);
    if (detectedName != null && mounted) {
      setState(() => _userName = detectedName);
    }

    if (_isRunning) {
      final name = detectedName ?? _userName;
      // Inject the message — if paused, also resume so AIs respond.
      _engine!.injectUserMessage(name, text);
      if (_isPaused) _resume();
    } else {
      // Pre-start — queue for when Start is pressed, and show in all panels.
      setState(() {
        _pendingUserMessages.add(text);
        // Use a local round placeholder (roundIndex 0) for display purposes.
        // The real round will be assigned by the engine after Start.
        final preview = Message(
          participantName: _userName,
          content: text,
          isUser: true,
          roundIndex: 0,
        );
        for (final qs in _quadrantStates.values) {
          qs.messages.add(preview);
        }
      });
    }
  }

  /// Detects "my name is X" / "I'm X" / "call me X" directly from the
  /// user's own typed text, so the label updates without waiting for an AI
  /// to acknowledge it.  Returns the trimmed name (max 20 chars) or null.
  static String? _detectUserSelfIntroduction(String text) {
    final patterns = [
      RegExp(r"my name is ([A-Za-z][A-Za-z0-9_\-]{0,19})", caseSensitive: false),
      RegExp(r"i'?m ([A-Za-z][A-Za-z0-9_\-]{1,19})\b", caseSensitive: false),
      RegExp(r"call me ([A-Za-z][A-Za-z0-9_\-]{0,19})\b", caseSensitive: false),
      RegExp(r"my name'?s ([A-Za-z][A-Za-z0-9_\-]{0,19})\b", caseSensitive: false),
    ];
    const blocklist = {'a', 'an', 'the', 'here', 'there', 'sorry', 'not',
        'sure', 'ok', 'okay', 'just', 'going', 'doing', 'trying', 'happy'};

    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      final raw = (m.group(1) ?? '').trim();
      if (raw.isEmpty || blocklist.contains(raw.toLowerCase())) continue;
      // Truncate to 20 chars for UI safety.
      return raw.length > 20 ? raw.substring(0, 20) : raw;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final quadrantDataList = List.generate(widget.participants.length, (i) {
      final p = widget.participants[i];
      final qs = _quadrantStates[p.name]!;
      return QuadrantData(
        participant: p,
        messages: List.unmodifiable(qs.messages),
        avatarState: qs.avatarState,
        isThinking: qs.isThinking,
        tokenStream: qs.tokenStream,
        imageEventStream: _imageEventController.stream,
        onSwap: _isRunning
            ? (newP) => _engine?.swapCharacter(i, newP)
            : null,
        // ── Trust / network / mood ─────────────────────────────────────────
        trustManager: _trustManager,
        initialTrustScore: _trustManager?.scoreFor(p.name),
        trustScoreStream: _trustStreamControllers[p.name]?.stream,
        rateLimitFlashController: _rateLimitControllers[p.name],
        initialMoodScore: _moodEngine?.scoreFor(p.name),
        moodScoreStream: _moodStreamControllers[p.name]?.stream,
      );
    });

    // Keyboard shortcuts: Cmd+, → Settings, Cmd+Shift+D → Debug panel
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            const _OpenSettingsIntent(),
        if (kDebugMode)
          const SingleActivator(LogicalKeyboardKey.keyD,
              meta: true, shift: true): const _ToggleDebugPanelIntent(),
      },
      child: Actions(
        actions: {
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ));
              return null;
            },
          ),
          if (kDebugMode)
            _ToggleDebugPanelIntent: CallbackAction<_ToggleDebugPanelIntent>(
              onInvoke: (_) {
                setState(() => _showDebugPanel = !_showDebugPanel);
                return null;
              },
            ),
        },
        child: Focus(
          autofocus: true,
          child: _buildBody(context, quadrantDataList),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<QuadrantData> quadrantDataList) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
        children: [
          // ── Replay banner (shown when in replay mode) ─────────────────────
          if (_showReplayBanner && widget.replaySessionName != null)
            ReplayBanner(
              sessionName: widget.replaySessionName!,
              mode: widget.replayMode ?? ReplayMode.continueSession,
              onDismiss: () => setState(() => _showReplayBanner = false),
            ),
          // ── Top header bar ────────────────────────────────────────────────
          _TopBar(
            isRunning: _isRunning,
            isPaused: _isPaused,
            isBusy: _isBusy,
            sessionName: _sessionName,
            pendingCount: _pendingUserMessages.length,
            onStart: _start,
            onStop: _stop,
            onPause: _pause,
            onResume: _resume,
            onWarpToHead: _warpToHead,
            onReconfigure: _reconfigure,
            hardware: widget.hardware,
            showRelationships: _showRelationships,
            onToggleRelationships: () =>
                setState(() => _showRelationships = !_showRelationships),
            onShowAnalytics: _sessionAnalytics != null
                ? () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AnalyticsScreen(
                          analytics: _sessionAnalytics!),
                    ));
                  }
                : null,
            onShowResearch: _isRunning && _engine != null
                ? () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ResearchModeScreen(
                        engine: _engine!,
                        characterNames: widget.participants
                            .map((p) => p.name)
                            .toList(),
                        ollamaClient: _engine!.client,
                      ),
                    ));
                  }
                : null,
          ),
          // ── Relationship matrix panel (collapsible) ───────────────────────
          if (_showRelationships)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: RelationshipMatrixWidget(
                  matrix: _relationshipMatrix),
            ),
          // ── Quadrant grid ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: QuadrantGrid(
                key: _gridKey,
                quadrants: quadrantDataList,
              ),
            ),
          ),
          // ── User input bar ────────────────────────────────────────────────
          UserInputBar(
            userName: _userName,
            isRunning: _isRunning,
            pendingCount: _pendingUserMessages.length,
            onSubmit: _onUserSubmit,
            onToggleSteering: () =>
                setState(() => _showSteering = !_showSteering),
            onWhisper: _isRunning
                ? (text, target) =>
                    _engine?.sendWhisper(_userName, text, target)
                : null,
          ),
          // ── Steering input bar ────────────────────────────────────────────
          SteeringInputBar(
            visible: _showSteering,
            onSteer: (text) => _steeringEngine?.steer(text),
          ),
            // ── Status band ─────────────────────────────────────────────────
            StatusBand(
              hardware: widget.hardware,
              sessionName: _sessionName,
            ),
          ],
        ),
        // ── Debug state simulator overlay (debug builds only) ─────────────
        if (kDebugMode && _showDebugPanel)
          StateSimulatorPanel(
            onClose: () => setState(() => _showDebugPanel = false),
          ),
        // ── Settings FAB ───────────────────────────────────────────────────
        Positioned(
          bottom: 52,  // above status band
          right: 12,
          child: Tooltip(
            message: 'Settings  (⌘,)',
            child: FloatingActionButton.small(
              heroTag: 'settings_fab',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textSecondary,
              elevation: 2,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
              child: const Icon(Icons.settings_outlined, size: 18),
            ),
          ),
        ),
      ],
    ),
  );
  }
}

// ---------------------------------------------------------------------------
// Intents for keyboard shortcuts
// ---------------------------------------------------------------------------

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _ToggleDebugPanelIntent extends Intent {
  const _ToggleDebugPanelIntent();
}

// ---------------------------------------------------------------------------
// _TopBar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  // ignore_for_file: prefer_const_constructors
  final bool isRunning;
  final bool isPaused;
  final bool isBusy;
  final String sessionName;
  final int pendingCount;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onWarpToHead;
  final VoidCallback onReconfigure;
  final HardwareInfo hardware;
  final bool showRelationships;
  final VoidCallback onToggleRelationships;
  final VoidCallback? onShowAnalytics;
  final VoidCallback? onShowResearch;

  const _TopBar({
    required this.isRunning,
    required this.isPaused,
    required this.isBusy,
    required this.sessionName,
    required this.pendingCount,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    required this.onWarpToHead,
    required this.onReconfigure,
    required this.hardware,
    required this.showRelationships,
    required this.onToggleRelationships,
    this.onShowAnalytics,
    this.onShowResearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // App name — left
          const Text(
            'deepThinkER',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 1.2,
            ),
          ),
          // Warp to Head — far left, next to app name
          const SizedBox(width: 10),
          _WarpToHeadButton(onTap: onWarpToHead),
          // Start/Stop — centre
          const Spacer(),
          // Busy spinner shown while stop-and-unload is in progress
          if (isBusy) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          StartStopButton(
            isRunning: isRunning,
            disabled: isBusy,
            onStart: onStart,
            onStop: onStop,
          ),
          // Pause/Resume — only visible while running and not busy
          if (isRunning && !isBusy) ...[
            const SizedBox(width: 8),
            _PauseResumeButton(
              isPaused: isPaused,
              onPause: onPause,
              onResume: onResume,
            ),
          ],
          // Optional pending-message badge (shows when queued before start)
          if (!isRunning && pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '$pendingCount queued',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          // Session name + help button — right
          const Spacer(),
          SizedBox(
            width: 160,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                sessionName.isNotEmpty ? 'Session: $sessionName' : '',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _RelationshipsButton(
            active: showRelationships,
            onTap: onToggleRelationships,
          ),
          if (onShowAnalytics != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Session Analytics',
              child: InkWell(
                onTap: onShowAnalytics,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 13,
                          color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Analytics',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (onShowResearch != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Autonomous Research Mode',
              child: InkWell(
                onTap: onShowResearch,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔬', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 4),
                      Text('Research',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          _ReconfigureButton(onTap: onReconfigure, disabled: isBusy),
          const SizedBox(width: 4),
          HelpMenuButton(hardware: hardware),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PauseResumeButton
// ---------------------------------------------------------------------------

class _PauseResumeButton extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const _PauseResumeButton({
    required this.isPaused,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    const pauseColor = Color(0xFFFFB300); // amber
    const resumeColor = Color(0xFF00C853); // green

    final color = isPaused ? resumeColor : pauseColor;
    final icon = isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded;
    final label = isPaused ? 'Resume' : 'Pause';
    final tooltip = isPaused
        ? 'Resume — AIs continue talking'
        : 'Pause — stop new AI responses so you can interject';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isPaused ? onResume : onPause,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(6),
            color: color.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WarpToHeadButton
// ---------------------------------------------------------------------------

class _WarpToHeadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WarpToHeadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scroll all panels to the beginning',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.vertical_align_top_rounded,
                  size: 13, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'Warp to Head',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReconfigureButton
// ---------------------------------------------------------------------------

class _ReconfigureButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool disabled;

  const _ReconfigureButton({required this.onTap, required this.disabled});

  @override
  Widget build(BuildContext context) {
    final color = disabled ? AppColors.textSecondary.withValues(alpha: 0.35) : AppColors.textSecondary;
    return Tooltip(
      message: 'Stop session and return to configuration',
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.border.withValues(alpha: disabled ? 0.35 : 0.7)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                'Configure',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RelationshipsButton
// ---------------------------------------------------------------------------

class _RelationshipsButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _RelationshipsButton({
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return Tooltip(
      message: active ? 'Hide relationship matrix' : 'Show relationship matrix',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.55)
                    : AppColors.border.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(6),
            color: active ? AppColors.accent.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                'Relations',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
