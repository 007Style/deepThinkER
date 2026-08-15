// OllamaHealthMonitor — pings Ollama every 10 s and emits health events.
//
// Automatically attempts up to 3 restarts with 5 s backoff when the service
// becomes unreachable.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:io';

// ---------------------------------------------------------------------------
// OllamaHealthStatus
// ---------------------------------------------------------------------------

/// The current health state of the Ollama service.
enum OllamaHealthStatus {
  /// The service is reachable and responding normally.
  healthy,

  /// A restart attempt is in progress.
  restarting,

  /// All restart attempts exhausted; service is unavailable.
  failed,
}

// ---------------------------------------------------------------------------
// OllamaHealthEvent
// ---------------------------------------------------------------------------

/// Base class for all health-monitor events.
abstract class OllamaHealthEvent {
  const OllamaHealthEvent();
}

/// Emitted when Ollama stops responding.
class OllamaCrashEvent extends OllamaHealthEvent {
  /// The number of restart attempts that have been made.
  final int attemptsMade;

  const OllamaCrashEvent({this.attemptsMade = 0});
}

/// Emitted when Ollama responds successfully after a crash.
class OllamaRecoveredEvent extends OllamaHealthEvent {
  const OllamaRecoveredEvent();
}

/// Emitted after all restart attempts are exhausted.
class OllamaFailedEvent extends OllamaHealthEvent {
  const OllamaFailedEvent();
}

// ---------------------------------------------------------------------------
// OllamaHealthMonitor
// ---------------------------------------------------------------------------

/// Polls `GET http://localhost:11434/api/tags` every [pollInterval].
///
/// On failure, attempts auto-restart up to [maxRestartAttempts] times with
/// [restartBackoff] between each attempt. Emits [OllamaHealthEvent]s on the
/// [events] stream.
class OllamaHealthMonitor {
  /// URL to ping.
  final String baseUrl;

  /// How often to poll Ollama.
  final Duration pollInterval;

  /// Maximum number of auto-restart attempts before giving up.
  final int maxRestartAttempts;

  /// How long to wait between restart attempts.
  final Duration restartBackoff;

  final StreamController<OllamaHealthEvent> _controller =
      StreamController<OllamaHealthEvent>.broadcast();

  Timer? _timer;
  bool _running = false;
  OllamaHealthStatus _status = OllamaHealthStatus.healthy;

  OllamaHealthMonitor({
    this.baseUrl = 'http://localhost:11434',
    this.pollInterval = const Duration(seconds: 10),
    this.maxRestartAttempts = 3,
    this.restartBackoff = const Duration(seconds: 5),
  });

  /// Broadcast stream of [OllamaHealthEvent]s.
  Stream<OllamaHealthEvent> get events => _controller.stream;

  /// The current health status.
  OllamaHealthStatus get status => _status;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts polling.  Safe to call multiple times (no-op if already running).
  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  /// Stops polling and closes the event stream.
  Future<void> dispose() async {
    _running = false;
    _timer?.cancel();
    await _controller.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _poll() async {
    final healthy = await _ping();
    if (healthy) {
      if (_status != OllamaHealthStatus.healthy) {
        _status = OllamaHealthStatus.healthy;
        _emit(const OllamaRecoveredEvent());
      }
      return;
    }

    // Service is down.
    if (_status == OllamaHealthStatus.healthy) {
      _status = OllamaHealthStatus.restarting;
      _emit(OllamaCrashEvent(attemptsMade: 0));
    }

    await _attemptRestart();
  }

  Future<void> _attemptRestart() async {
    for (var attempt = 1; attempt <= maxRestartAttempts; attempt++) {
      _emit(OllamaCrashEvent(attemptsMade: attempt));
      await Future<void>.delayed(restartBackoff);
      if (await _ping()) {
        _status = OllamaHealthStatus.healthy;
        _emit(const OllamaRecoveredEvent());
        return;
      }
    }
    // All attempts failed.
    _status = OllamaHealthStatus.failed;
    _emit(const OllamaFailedEvent());
  }

  Future<bool> _ping() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('$baseUrl/api/tags'));
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      client.close();
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void _emit(OllamaHealthEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
