// RateLimitFlash — brief "🚫 rate limited" indicator.
//
// When triggered, shows a red label for 3 seconds then fades out.
// Controlled via the trigger() method or by listening to a stream.
import 'dart:async';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// RateLimitFlash
// ---------------------------------------------------------------------------

/// A brief visual indicator that appears when a character is rate-limited.
///
/// Call [RateLimitFlashController.trigger] to show the indicator.
/// The indicator automatically hides after 3 seconds.
class RateLimitFlash extends StatefulWidget {
  final RateLimitFlashController controller;

  const RateLimitFlash({required this.controller, super.key});

  @override
  State<RateLimitFlash> createState() => _RateLimitFlashState();
}

class _RateLimitFlashState extends State<RateLimitFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _opacity;
  StreamSubscription<void>? _sub;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _sub = widget.controller._stream.listen((_) => _showFlash());
  }

  void _showFlash() {
    if (!mounted) return;
    _hideTimer?.cancel();
    _animCtrl.forward(from: 0.0);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _animCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red[900]!.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red[700]!.withValues(alpha: 0.6)),
        ),
        child: Text(
          '\u{1F6AB} rate limited',
          style: TextStyle(
            fontSize: 9,
            color: Colors.red[400],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RateLimitFlashController
// ---------------------------------------------------------------------------

/// Controller that lets callers trigger the [RateLimitFlash] indicator.
class RateLimitFlashController {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get _stream => _controller.stream;

  /// Shows the rate-limit indicator on all attached [RateLimitFlash] widgets.
  void trigger() {
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Releases the underlying stream controller.
  void dispose() => _controller.close();
}
