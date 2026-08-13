/// Per-AI inference worker for deepThinkER.
///
/// Each [InferenceWorker] monitors the shared [ConversationLog], applies a
/// random jitter before responding, calls [OllamaClient.generateStream], and
/// streams [InferenceEvent] tokens back to the [ConversationEngine].
///
/// Context-window resets are handled transparently via [ContextManager].
///
/// Tool-call interception: if a [ToolCallInterceptor] is attached, the
/// response buffer is scanned after streaming completes.  When a tag is found
/// the interceptor executes the tool and injects the result as a system
/// message into the conversation log.
///
/// This file has zero Flutter imports — pure Dart only.
library inference_worker;

import 'dart:async';
import 'dart:math';

import '../context/context_manager.dart';
import '../ollama/hardware_detector.dart';
import '../ollama/ollama_client.dart';
import '../tools/tool_call_interceptor.dart';
import 'conversation_log.dart';
import 'message.dart';
import 'participant.dart';
import 'whisper_message.dart';
import 'system_prompt_builder.dart';

// ---------------------------------------------------------------------------
// InferenceEvent
// ---------------------------------------------------------------------------

/// A single event emitted by an [InferenceWorker].
///
/// Consumers should check:
/// - [token] is non-null → append it to the participant's current response.
/// - [token] is null and [isDone] is `true` → generation for this turn is complete.
/// - [isThinking] is `true` → the worker is deciding whether to respond (jitter phase).
class InferenceEvent {
  /// Name of the participant producing this event.
  final String participantName;

  /// Incremental text token, or `null` when [isDone] is `true`.
  final String? token;

  /// `true` once the worker has finished streaming a full response (or pass).
  final bool isDone;

  /// `true` during the jitter window before inference begins.
  final bool isThinking;

  /// `true` when the participant decided to pass (empty response).
  final bool isPass;

  /// The complete response text, populated only when [isDone] is `true`.
  final String? fullResponse;

  /// The tool call event fired during this inference turn, if any.
  final ToolCallEvent? toolCallEvent;

  /// Creates an [InferenceEvent].
  const InferenceEvent({
    required this.participantName,
    this.token,
    this.isDone = false,
    this.isThinking = false,
    this.isPass = false,
    this.fullResponse,
    this.toolCallEvent,
  });

  @override
  String toString() =>
      'InferenceEvent($participantName, token=$token, done=$isDone, '
      'thinking=$isThinking, pass=$isPass)';
}

// ---------------------------------------------------------------------------
// InferenceWorker
// ---------------------------------------------------------------------------

/// Drives inference for a single AI [Participant].
///
/// The worker subscribes to [ConversationLog.messageStream] and reacts to
/// every new message. It waits a random jitter (200–800 ms) before calling
/// Ollama, which prevents all four AIs from responding simultaneously.
///
/// Start the worker with [start] and stop it cleanly with [stop].
/// All events are available on [eventStream].
///
/// ```dart
/// final worker = InferenceWorker(
///   participant: participants[0],
///   log: conversationLog,
///   client: ollamaClient,
///   hardware: hardwareInfo,
///   contextManager: ctxManager,
/// );
/// worker.start(allParticipants);
/// worker.eventStream.listen((e) { ... });
/// ```
class InferenceWorker {
  /// The AI character this worker drives.
  final Participant participant;

  /// The shared conversation log.
  final ConversationLog log;

  /// Ollama REST API client.
  final OllamaClient client;

  /// Detected hardware — used for context window selection.
  final HardwareInfo hardware;

  /// Shared context manager — tracks token usage across all workers.
  final ContextManager contextManager;

  /// Optional tool-call interceptor.  When set, the response buffer is scanned
  /// after every token and tool calls are processed inline.
  ToolCallInterceptor? interceptor;

  final StreamController<InferenceEvent> _eventController =
      StreamController<InferenceEvent>.broadcast();

  final Random _rng = Random();

  StreamSubscription<Message>? _logSubscription;
  bool _running = false;
  bool _inferencing = false;

  // Queue: when a new message arrives during active inference we set a flag
  // rather than nesting calls.
  bool _pendingResponse = false;

  // True when the pending response is specifically triggered by a user message.
  // Passed through to _runInference so the model cannot pass on user input.
  bool _pendingIsUserMessage = false;

  // When paused, new scheduling is blocked.  Any in-flight inference is
  // allowed to finish naturally; the pending flag is still set so the
  // response fires immediately on resume.
  bool _paused = false;

  /// Creates an [InferenceWorker].
  InferenceWorker({
    required this.participant,
    required this.log,
    required this.client,
    required this.hardware,
    required this.contextManager,
  });

  /// Broadcast stream of [InferenceEvent]s produced by this worker.
  Stream<InferenceEvent> get eventStream => _eventController.stream;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Starts the worker, subscribing to [ConversationLog.messageStream].
  ///
  /// [allParticipants] must include this worker's [participant]; it is used
  /// to build the system prompt and context-reset seed participant list.
  void start(List<Participant> allParticipants) {
    if (_running) return;
    _running = true;

    _logSubscription = log.messageStream.listen((message) {
      // Ignore our own messages to avoid self-loops.
      if (message.participantName == participant.name) return;
      if (!_running) return;

      // Whisper routing: ignore whispers directed at other characters.
      if (message.isWhisper &&
          message is WhisperMessage &&
          message.targetCharacter != participant.name) {
        return;
      }

      if (_inferencing) {
        // Another inference is already in flight — flag for a follow-up.
        _pendingResponse = true;
        // If this is a user message, mark it so we don't pass on it.
        if (message.isUser) _pendingIsUserMessage = true;
      } else {
        _scheduleResponse(allParticipants, forceRespond: message.isUser);
      }
    });
  }

  /// Stops the worker gracefully.
  ///
  /// Any in-flight inference is abandoned; the event stream is closed.
  Future<void> stop() async {
    _running = false;
    await _logSubscription?.cancel();
    _logSubscription = null;
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  // -------------------------------------------------------------------------
  // Core inference loop
  // -------------------------------------------------------------------------

  /// Pauses all inference immediately.
  ///
  /// Aborts any in-flight HTTP stream by force-closing the underlying
  /// [HttpClient].  The aborted [generateStream] call throws, which is caught
  /// by [_runInference]'s catch block, causing it to emit a `done` event and
  /// clear [_inferencing].  New scheduling is also blocked.
  void pause() {
    _paused = true;
    if (_inferencing) {
      // Force-close the HTTP connection — this causes the awaited
      // generateStream to throw, unwinding the inference cleanly.
      client.abortInFlight();
    }
  }

  /// Resumes scheduling.  If a response was pending while paused, it fires now.
  void resume(List<Participant> allParticipants) {
    if (!_paused) return;
    _paused = false;
    if (_pendingResponse && _running && !_inferencing) {
      final wasUser = _pendingIsUserMessage;
      _pendingResponse = false;
      _pendingIsUserMessage = false;
      _scheduleResponse(allParticipants, forceRespond: wasUser);
    }
  }

  void _scheduleResponse(List<Participant> allParticipants,
      {bool forceRespond = false}) {
    if (_paused) {
      // Don't schedule — mark pending so it fires on resume.
      _pendingResponse = true;
      if (forceRespond) _pendingIsUserMessage = true;
      return;
    }

    // Random jitter: 200–800 ms to stagger AI responses naturally.
    final jitter = Duration(milliseconds: 200 + _rng.nextInt(601));

    Timer(jitter, () {
      if (!_running || _paused) return;
      _runInference(allParticipants, forceRespond: forceRespond);
    });
  }

  Future<void> _runInference(List<Participant> allParticipants,
      {bool forceRespond = false}) async {
    if (_inferencing || !_running) return;
    _inferencing = true;

    // Signal "thinking" phase.
    _emit(InferenceEvent(
      participantName: participant.name,
      isThinking: true,
    ));

    try {
      final messages = _buildMessages(allParticipants, forceRespond: forceRespond);
      final numCtx = _contextWindow();

      final responseBuffer = StringBuffer();

      await client.generateStream(
        model: participant.assignedModelId,
        messages: messages,
        numCtx: numCtx,
        onToken: (token) {
          if (!_running) return;
          responseBuffer.write(token);
          _emit(InferenceEvent(
            participantName: participant.name,
            token: token,
          ));
        },
        onDone: () {
          // handled below
        },
        onError: (error) {
          // Swallow errors silently — emit a done event so UI can recover.
        },
      );

      // After streaming completes, check for any tool-call tags in the buffer.
      // We process one tag per generation turn to keep behaviour predictable.
      String fullResponseRaw = responseBuffer.toString();
      if (interceptor != null) {
        final intercept =
            await interceptor!.process(fullResponseRaw, participant.name);
        if (intercept.event != null) {
          // Inject tool result as an ephemeral system message so the LLM can
          // read it in the next turn's context.
          final injection = Message(
            participantName: 'System',
            content: intercept.modifiedBuffer,
            isUser: false,
            roundIndex: log.currentRoundIndex,
            isEphemeral: true,
          );
          log.append(injection);
          fullResponseRaw = intercept.modifiedBuffer;
        }
      }

      final fullResponse = fullResponseRaw.trim();
      final isPass = fullResponse.isEmpty;

      // Record token usage (estimate from response length).
      contextManager.recordFromText(participant.name, fullResponse);

      // Append message to shared log — stamp with current round index so the
      // UI can group this response with others triggered by the same message.
      final message = Message(
        participantName: participant.name,
        content: fullResponse,
        isUser: false,
        roundIndex: log.currentRoundIndex,
      );
      log.append(message);

      _emit(InferenceEvent(
        participantName: participant.name,
        isDone: true,
        isPass: isPass,
        fullResponse: isPass ? null : fullResponse,
        toolCallEvent: interceptor?.lastEvent,
      ));
    } catch (_) {
      // Emit done on error so consumers do not hang.
      _emit(InferenceEvent(
        participantName: participant.name,
        isDone: true,
      ));
    } finally {
      _inferencing = false;

      // Don't re-schedule if paused or stopped — _scheduleResponse will
      // handle it on resume() or the next message respectively.
      if (_pendingResponse && _running && !_paused) {
        final wasUser = _pendingIsUserMessage;
        _pendingResponse = false;
        _pendingIsUserMessage = false;
        _scheduleResponse(allParticipants, forceRespond: wasUser);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Message construction
  // -------------------------------------------------------------------------

  /// Builds the Ollama `messages` payload for the current conversation state.
  ///
  /// If a context reset is needed, only the reset seed is included as history.
  /// [forceRespond] adds an instruction reminding the model to respond directly
  /// to the user rather than passing.
  List<Map<String, String>> _buildMessages(List<Participant> allParticipants,
      {bool forceRespond = false}) {
    final systemPrompt = SystemPromptBuilder.build(
      participant,
      allParticipants,
      hardware,
    );

    final numCtx = _contextWindow();
    final needsReset = contextManager.needsReset(participant.name, numCtx);

    List<Message> history;
    if (needsReset) {
      final names = allParticipants.map((p) => p.name).toList();
      // Include "User" as a participant name for the seed.
      if (!names.contains('User')) names.add('User');
      history = contextManager.buildResetSeed(log, names);
      contextManager.reset(participant.name);
      // Re-record the seed token cost.
      for (final m in history) {
        contextManager.recordFromText(participant.name, m.content);
      }
    } else {
      // Use the full log, filtering out passes.
      history = log.allMessages.where((m) => !m.isPass).toList();
    }

    final chatMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final m in history) {
      final role =
          m.participantName == participant.name ? 'assistant' : 'user';
      // Prefix non-user messages with the speaker's name so the model can
      // attribute them in context.
      final prefix = m.isUser ? '' : '${m.participantName}: ';
      chatMessages.add({'role': role, 'content': '$prefix${m.content}'});
    }

    // When triggered by a user message, add a reminder that passing is not
    // allowed — the human is waiting for a direct response.
    if (forceRespond) {
      chatMessages.add({
        'role': 'user',
        'content':
            '[System: The human user just sent a message above. '
            'You MUST respond directly to them. '
            'Do NOT return an empty string. Do NOT pass.]',
      });
    }

    return chatMessages;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  int _contextWindow() {
    final isHighCtx = participant.assignedModelId.startsWith('phi3');
    return isHighCtx
        ? hardware.highContextWindow
        : hardware.standardContextWindow;
  }

  void _emit(InferenceEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}
