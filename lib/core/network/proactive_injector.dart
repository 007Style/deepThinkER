/// ProactiveInjector — injects relevant web context into conversation without
/// a character explicitly requesting it.
///
/// Runs a per-character timer keyed to trust tier.  On each tick, it:
/// 1. Extracts topics from the last 3 messages.
/// 2. Picks the top topic.
/// 3. Calls RateLimiter.request(); if allowed, fetches via NetworkFetcher.
/// 4. Appends an ephemeral system message to the ConversationLog.
/// 5. Emits a ProactiveInjectionEvent.
///
/// This file has zero Flutter imports — pure Dart only.
library proactive_injector;

import 'dart:async';

import '../conversation/conversation_log.dart';
import '../conversation/message.dart';
import '../trust/trust_manager.dart';
import 'network_fetcher.dart';
import 'rate_limit_config.dart';
import 'rate_limiter.dart';
import 'topic_extractor.dart';

// ---------------------------------------------------------------------------
// ProactiveInjectionEvent
// ---------------------------------------------------------------------------

/// Emitted when the proactive injector fires a web search.
class ProactiveInjectionEvent {
  final String characterName;
  final String topic;
  final String url;
  final bool rateLimited;
  final DateTime timestamp;

  ProactiveInjectionEvent({
    required this.characterName,
    required this.topic,
    required this.url,
    required this.rateLimited,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'ProactiveInjectionEvent($characterName, topic="$topic", '
      'rateLimited=$rateLimited)';
}

// ---------------------------------------------------------------------------
// ProactiveInjector
// ---------------------------------------------------------------------------

/// Monitors conversation activity and injects proactive web context.
///
/// Start with [start] at session begin; call [stop] when the session ends.
class ProactiveInjector {
  final ConversationLog log;
  final NetworkFetcher fetcher;
  final RateLimiter rateLimiter;
  final TrustManager trustManager;
  final RateLimitConfig config;

  final Map<String, Timer?> _timers = {};
  final StreamController<ProactiveInjectionEvent> _eventController =
      StreamController<ProactiveInjectionEvent>.broadcast();

  ProactiveInjector({
    required this.log,
    required this.fetcher,
    required this.rateLimiter,
    required this.trustManager,
    required this.config,
  });

  /// Broadcast stream of [ProactiveInjectionEvent]s.
  Stream<ProactiveInjectionEvent> get eventStream => _eventController.stream;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Starts per-character proactive injection timers.
  ///
  /// [characterNames] must include all four AI characters.
  void start(List<String> characterNames) {
    if (!config.proactiveInjectionEnabled) return;

    for (final name in characterNames) {
      _scheduleFor(name);
    }

    // Re-schedule whenever a character's tier changes.
    trustManager.trustStream.listen((event) {
      if (characterNames.contains(event.characterName) && event.tierChanged) {
        _cancelFor(event.characterName);
        _scheduleFor(event.characterName);
      }
    });
  }

  /// Cancels all timers.
  void stop() {
    for (final name in _timers.keys.toList()) {
      _cancelFor(name);
    }
    _timers.clear();
  }

  /// Releases the event stream controller.
  Future<void> dispose() async {
    stop();
    await _eventController.close();
  }

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  void _scheduleFor(String characterName) {
    final tier = rateLimiter.currentTier(characterName);
    final interval = config.proactiveIntervalFor(tier);
    if (interval == null) return; // Low tier — proactive injection disabled.

    _timers[characterName] = Timer.periodic(interval, (_) {
      _onTick(characterName);
    });
  }

  void _cancelFor(String characterName) {
    _timers[characterName]?.cancel();
    _timers[characterName] = null;
  }

  Future<void> _onTick(String characterName) async {
    // Get last 3 messages from the log.
    final recent = log.getLastN(3);
    final topics = TopicExtractor.extract(recent, maxTopics: 3);
    if (topics.isEmpty) return;

    final topic = topics.first;
    final tier = rateLimiter.currentTier(characterName);

    // Check rate limit.
    final rateResult = rateLimiter.request(characterName, tier);
    if (!rateResult.allowed) {
      _emit(ProactiveInjectionEvent(
        characterName: characterName,
        topic: topic,
        url: 'https://html.duckduckgo.com/html/?q=${Uri.encodeQueryComponent(topic)}',
        rateLimited: true,
      ));
      return;
    }

    // Fetch.
    final fetchResult = await fetcher.search(topic, characterName);
    final content = fetchResult.isSuccess
        ? fetchResult.rawHtml
        : '[FETCH_ERROR: ${fetchResult.errorMessage}]';

    // Inject as ephemeral system message.
    final injection = Message(
      participantName: 'System',
      content: '[PROACTIVE_WEB_RESULT for $characterName]:\n$content',
      isUser: false,
      roundIndex: log.currentRoundIndex,
      isEphemeral: true,
    );
    log.append(injection);

    _emit(ProactiveInjectionEvent(
      characterName: characterName,
      topic: topic,
      url: fetchResult.url,
      rateLimited: false,
    ));
  }

  void _emit(ProactiveInjectionEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}
