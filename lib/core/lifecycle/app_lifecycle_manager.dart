// AppLifecycleManager — listens for OS shutdown signals and triggers a
// graceful app shutdown callback.
//
// Handles SIGTERM and SIGINT on POSIX platforms. On Windows, only SIGINT
// (Ctrl-C) is trapped; SIGTERM is a no-op.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:io';

// ---------------------------------------------------------------------------
// AppLifecycleManager
// ---------------------------------------------------------------------------

/// Hooks OS signals and invokes [onShutdown] for graceful teardown.
///
/// ```dart
/// final lifecycle = AppLifecycleManager(
///   onShutdown: () async {
///     await sessionManager.endSession();
///   },
/// );
/// lifecycle.start();
/// // ...
/// await lifecycle.dispose();
/// ```
class AppLifecycleManager {
  /// Async callback invoked on SIGTERM or SIGINT.
  ///
  /// The app should perform all cleanup (flush logs, end session, etc.) inside
  /// this callback before the process exits.
  final Future<void> Function() onShutdown;

  final List<StreamSubscription<ProcessSignal>> _subs = [];
  bool _disposed = false;

  AppLifecycleManager({required this.onShutdown});

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts listening for SIGTERM and SIGINT.
  ///
  /// On Windows, SIGTERM is not delivered — only SIGINT (Ctrl-C) is trapped.
  void start() {
    if (_disposed) return;

    _listen(ProcessSignal.sigint);

    // SIGTERM is only available on POSIX platforms.
    if (!Platform.isWindows) {
      _listen(ProcessSignal.sigterm);
    }
  }

  /// Cancels all signal subscriptions.
  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _listen(ProcessSignal signal) {
    final sub = signal.watch().listen((_) async {
      await onShutdown();
      await dispose();
      exit(0);
    });
    _subs.add(sub);
  }
}
