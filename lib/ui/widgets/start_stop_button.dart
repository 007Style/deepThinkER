// Prominent start / stop control for the deepThink main header.
//
// When stopped: glowing green "▶ Start" button with a gentle pulse animation.
// When running: pulsing red "■ Stop" button.
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// StartStopButton
// ---------------------------------------------------------------------------

/// A prominent animated start / stop button.
///
/// - [isRunning] `false` → green "▶ Start" with pulse glow
/// - [isRunning] `true`  → red "■ Stop" with pulse glow
class StartStopButton extends StatefulWidget {
  /// Whether the conversation is currently running.
  final bool isRunning;

  /// When true the button is greyed out and non-interactive (busy state).
  final bool disabled;

  /// Called when the user presses Start.
  final VoidCallback onStart;

  /// Called when the user presses Stop.
  final VoidCallback onStop;

  const StartStopButton({
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    this.disabled = false,
    super.key,
  });

  @override
  State<StartStopButton> createState() => _StartStopButtonState();
}

class _StartStopButtonState extends State<StartStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFD50000);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glow = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.disabled
        ? const Color(0xFF555555)
        : widget.isRunning ? _red : _green;
    final label = widget.disabled
        ? (widget.isRunning ? 'Stopping…' : 'Starting…')
        : widget.isRunning ? '■  Stop' : '▶  Start';
    final onPressed = widget.disabled
        ? null
        : widget.isRunning ? widget.onStop : widget.onStart;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final glowRadius = 8.0 + 10.0 * _glow.value;
        final glowOpacity = 0.25 + 0.35 * _glow.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: glowOpacity),
                blurRadius: glowRadius,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: 140,
        height: 38,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isRunning ? _red : _green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PulseRing — decorative pulsing ring drawn behind the button
// ---------------------------------------------------------------------------

/// A purely decorative widget that draws a fading ring that expands outward,
/// layered behind [StartStopButton] for extra sci-fi flair.
class PulseRing extends StatefulWidget {
  final Color color;
  final double size;

  const PulseRing({required this.color, required this.size, super.key});

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RingPainter(
          progress: _ctrl.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide / 2) * (0.5 + 0.5 * progress);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
