/// Conversation engine for deepThink.
///
/// Top-level orchestrator that owns the four [InferenceWorker] instances,
/// manages start/stop lifecycle, injects user messages, and exposes a
/// merged [eventStream] for the UI layer.
///
/// This file has zero Flutter imports — pure Dart only.
library conversation_engine;

import 'dart:async';

import '../context/context_manager.dart';
import '../ollama/hardware_detector.dart';
import '../ollama/model_registry.dart';
import '../ollama/ollama_client.dart';
import '../session/replay_mode.dart';
import '../tools/tool_call_interceptor.dart';
import 'character_swap_event.dart';
import 'conversation_log.dart';
import 'inference_worker.dart';
import 'message.dart';
import 'participant.dart';
import 'whisper_message.dart';

// ---------------------------------------------------------------------------
// ConversationEngine
// ---------------------------------------------------------------------------

/// Orchestrates all four AI [InferenceWorker] instances.
///
/// The engine:
/// - Owns the shared [ConversationLog] that all workers read from and write to.
/// - Creates one [InferenceWorker] per [Participant] on [start].
/// - Merges all four worker event streams into a single [eventStream].
/// - Provides [injectUserMessage] so the UI can push user utterances into
///   the conversation.
/// - Shuts everything down cleanly on [stop].
///
/// ```dart
/// final engine = ConversationEngine(client: ollamaClient);
/// final hardware = await HardwareDetector.detect();
/// await engine.start(Participant.defaults(), hardware);
///
/// engine.eventStream.listen((event) {
///   if (event.token != null) print('${event.participantName}: ${event.token}');
/// });
///
/// engine.injectUserMessage('User', 'What do you all think about AI?');
/// // ... later ...
/// await engine.stop();
/// ```
class ConversationEngine {
  /// The Ollama REST API client shared by all workers.
  final OllamaClient client;

  final ConversationLog _log = ConversationLog();
  final ContextManager _contextManager = ContextManager();

  List<InferenceWorker> _workers = [];
  List<Participant> _participants = [];
  StreamSubscription<InferenceEvent>? _mergedSubscription;

  // Initialised eagerly so eventStream can be subscribed to before start() is
  // called — this is the safe pattern in both debug and release builds.
  final StreamController<InferenceEvent> _eventController =
      StreamController<InferenceEvent>.broadcast();

  final StreamController<CharacterSwapEvent> _swapController =
      StreamController<CharacterSwapEvent>.broadcast();

  bool _started = false;
  bool _paused = false;

  HardwareInfo? _hardware;

  /// Creates a [ConversationEngine].
  ConversationEngine({required this.client});

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// The shared conversation log.
  ConversationLog get log => _log;

  /// Broadcast stream of [CharacterSwapEvent]s.
  Stream<CharacterSwapEvent> get swapStream => _swapController.stream;

  /// Merged broadcast stream of [InferenceEvent]s from all four workers.
  ///
  /// Subscribe to this before or after calling [start] — it is safe either way
  /// because the controller is created eagerly in the constructor.
  /// Consumers can filter by [InferenceEvent.participantName].
  Stream<InferenceEvent> get eventStream => _eventController.stream;

  /// Initialises all workers and begins the conversation.
  ///
  /// [participants] must contain exactly the four AI participants.
  /// [hardware] is used by each worker for context window sizing.
  ///
  /// This method is idempotent — calling it when already started is a no-op.
  /// Whether the engine is currently paused.
  bool get isPaused => _paused;

  /// Pauses all workers — new inference turns are blocked until [resume].
  /// Any response currently streaming is allowed to complete.
  void pause() {
    if (!_started || _paused) return;
    _paused = true;
    for (final w in _workers) {
      w.pause();
    }
  }

  /// Resumes all workers.  Any pending responses fire immediately.
  void resume() {
    if (!_paused) return;
    _paused = false;
    for (final w in _workers) {
      w.resume(_participants);
    }
  }

  Future<void> start(
      List<Participant> participants, HardwareInfo hardware) async {
    if (_started) return;
    _started = true;
    _participants = participants;
    _hardware = hardware;

    _workers = participants
        .map(
          (p) => InferenceWorker(
            participant: p,
            log: _log,
            client: client,
            hardware: hardware,
            contextManager: _contextManager,
          ),
        )
        .toList();

    // Merge all four worker streams into the single broadcast controller.
    final merged = StreamGroup.merge(
      _workers.map((w) => w.eventStream).toList(),
    );
    _mergedSubscription = merged.listen(
      (event) {
        if (!_eventController.isClosed) {
          _eventController.add(event);
        }
      },
      onError: (Object error) {
        // Swallow individual worker errors to keep the engine alive.
      },
    );

    // Start all workers.
    for (final worker in _workers) {
      worker.start(participants);
    }

    // DEEP (host) kicks off the conversation by receiving a synthetic
    // "start" message that only the host sees as a trigger.
    final kickoff = Message(
      participantName: 'System',
      content:
          'The conversation is beginning. DEEP, please open with a thought-provoking topic or question.',
      isUser: false,
    );
    _log.append(kickoff);
  }

  /// Gracefully stops all workers, unloads all models from Ollama memory,
  /// and releases resources.
  ///
  /// Unloading keeps the Ollama process alive (fast to restart) while freeing
  /// GPU/RAM so the user's machine isn't left holding loaded weights.
  ///
  /// After [stop] the engine cannot be restarted — create a new instance.
  Future<void> stop() async {
    _started = false;
    _paused = false;

    // Cancel the merged stream subscription first so no more events route up.
    await _mergedSubscription?.cancel();
    _mergedSubscription = null;

    // Stop all workers (cancels log subscriptions, closes event controllers).
    await Future.wait(_workers.map((w) => w.stop()));
    _workers.clear();

    // Unload every known model from Ollama so GPU/RAM is freed.
    // Run in parallel — each call is a fire-and-forget POST with keep_alive=0.
    await Future.wait(
      ModelRegistry.all.map((m) => client.unloadModel(m.id)),
    );

    // Do not close _eventController — it's reusable across stop/start cycles.

    await _log.dispose();
  }

  /// Sets [interceptor] on all currently-running workers and stores it so
  /// workers created later (e.g. via [swapCharacter]) inherit it too.
  ///
  /// Call this after [start] so the workers already exist.
  void setInterceptorOnAllWorkers(ToolCallInterceptor interceptor) {
    _interceptor = interceptor;
    for (final w in _workers) {
      w.interceptor = interceptor;
    }
  }

  /// Currently-active interceptor (may be null before [setInterceptorOnAllWorkers]).
  ToolCallInterceptor? _interceptor;

  /// Injects a message from the human user into the shared log.
  ///
  /// All workers will see the message on [ConversationLog.messageStream] and
  /// decide independently whether to respond.
  ///
  /// [userName] is the current display name for the user (default `"User"`).
  /// [content] must be non-empty.
  /// Injects a system [message] into the shared log.
  ///
  /// All workers will see it on the next inference turn.
  /// Typically used by [ResearchEngine] for phase directives and by
  /// [SteeringEngine] for silent steering nudges.
  void injectSystemMessage(Message message) {
    _log.append(message);
  }

  void injectUserMessage(String userName, String content) {
    if (content.trim().isEmpty) return;

    final message = Message(
      participantName: userName,
      content: content.trim(),
      isUser: true,
    );
    _log.append(message);
  }

  /// Swaps the character at [slot] (0-based index in [_participants]) with
  /// [newParticipant] mid-session.
  ///
  /// Stops the outgoing worker, starts a new worker for [newParticipant],
  /// injects the last 10 messages as a catch-up context, and emits a
  /// [CharacterSwapEvent].
  Future<void> swapCharacter(int slot, Participant newParticipant) async {
    if (!_started || slot < 0 || slot >= _workers.length) return;

    final outgoing = _participants[slot];

    // Stop the old worker.
    await _workers[slot].stop();

    // Update participants list.
    _participants = List<Participant>.from(_participants)..[slot] = newParticipant;

    // Build catch-up context from last 10 messages.
    final recent = _log.allMessages
        .where((m) => !m.isPass && !m.isEphemeral)
        .toList();
    final catchUp = recent.length > 10 ? recent.sublist(recent.length - 10) : recent;
    final catchUpText = catchUp
        .map((m) => '[${m.participantName}]: ${m.content}')
        .join('\n');
    final catchUpMsg = Message(
      participantName: 'System',
      content: 'You are joining an ongoing conversation. '
          'Recent context:\n$catchUpText',
      isUser: false,
      isEphemeral: true,
    );
    _log.append(catchUpMsg);

    // Create and start the new worker.
    final newWorker = InferenceWorker(
      participant: newParticipant,
      log: _log,
      client: client,
      hardware: _hardware!,
      contextManager: _contextManager,
    );

    // Inherit the active interceptor (if any).
    if (_interceptor != null) {
      newWorker.interceptor = _interceptor;
    }

    // Wire the new worker into the event controller.
    newWorker.eventStream.listen(
      (event) {
        if (!_eventController.isClosed) _eventController.add(event);
      },
      onError: (_) {},
    );
    newWorker.start(_participants);
    _workers[slot] = newWorker;

    // Log swap as a system message.
    final swapNote = Message(
      participantName: 'System',
      content: '[SYSTEM: ${outgoing.name} replaced by ${newParticipant.name} '
          'at ${DateTime.now().hour.toString().padLeft(2,'0')}:'
          '${DateTime.now().minute.toString().padLeft(2,'0')}]',
      isUser: false,
    );
    _log.append(swapNote);

    final event = CharacterSwapEvent(
      outgoingCharacter: outgoing.name,
      incomingCharacter: newParticipant.name,
      timestamp: DateTime.now(),
      catchUpMessageCount: catchUp.length,
    );
    if (!_swapController.isClosed) _swapController.add(event);
  }

  /// Loads [replayLog] into this engine so characters can continue or reflect
  /// on a past session.
  ///
  /// If the engine is currently running, [stop] is called first.
  ///
  /// In [ReplayMode.reflection] a system message is prepended to the log so
  /// all four workers understand the loaded messages are historical context.
  Future<void> loadReplay(ConversationLog replayLog, ReplayMode mode) async {
    if (_started) await stop();

    final messages = List<Message>.from(replayLog.allMessages);

    if (mode == ReplayMode.reflection) {
      final framingMsg = Message(
        participantName: 'SYSTEM',
        content: 'The following conversation occurred in a past session. '
            'Read it carefully, then continue the discussion or reflect on '
            'it when prompted.',
        isUser: false,
      );
      _log.seedFrom([framingMsg, ...messages]);
    } else {
      _log.seedFrom(messages);
    }
  }

  /// Sends a whisper message visible only to [targetCharacter].
  ///
  /// The [WhisperMessage] is appended to the log; [InferenceWorker] instances
  /// for other characters ignore it based on the `isWhisper` + `targetCharacter`
  /// check.
  void sendWhisper(String userName, String content, String targetCharacter) {
    if (content.trim().isEmpty) return;
    final msg = WhisperMessage(
      participantName: userName,
      content: content.trim(),
      targetCharacter: targetCharacter,
    );
    _log.append(msg);
  }
}

// ---------------------------------------------------------------------------
// StreamGroup helper (avoids the async package dependency)
// ---------------------------------------------------------------------------

/// Merges multiple streams into a single broadcast stream.
///
/// This is a minimal internal utility so that `package:async` is not required
/// in a pure-Dart core file.
class StreamGroup {
  /// Returns a broadcast [Stream] that emits events from all [streams].
  ///
  /// The combined stream closes when all source streams have closed.
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    int openCount = streams.length;

    void onDone() {
      openCount--;
      if (openCount == 0) {
        controller.close();
      }
    }

    final subscriptions = <StreamSubscription<T>>[];

    controller = StreamController<T>.broadcast(
      onListen: () {
        for (final stream in streams) {
          final sub = stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: onDone,
          );
          subscriptions.add(sub);
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }
}
