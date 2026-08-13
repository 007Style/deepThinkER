// Animated Energy Orb avatar widget for deepThink.
//
// Extends [AvatarWidget] and manages two [AnimationController]s whose
// speeds are adjusted whenever [widget.state] changes:
//
//   idle      → primary 3.0 s  / secondary 4.0 s
//   thinking  → primary 1.5 s  / secondary 0.8 s
//   speaking  → primary 0.8 s  / secondary 0.4 s
//   waiting   → primary 5.0 s  / secondary 12.0 s (near-stopped)
//
// The [OrbPainter] is rebuilt on every animation tick via [AnimatedBuilder].
import 'package:flutter/widgets.dart';

import '../avatar_widget.dart';
import 'orb_config.dart';
import 'orb_painter.dart';

// ---------------------------------------------------------------------------
// EnergyOrbAvatar
// ---------------------------------------------------------------------------

/// An Energy Orb avatar that visualises a participant's activity state through
/// rich particle motion, glowing gradients, and a pulsing central orb.
///
/// Pass [characterName] to pick the correct [OrbConfig] from
/// [OrbConfig.forCharacter]. If [characterName] is omitted the WATSON
/// colour palette is used as the fallback.
class EnergyOrbAvatar extends AvatarWidget {
  /// The participant name used to look up [OrbConfig] (e.g. `"NOVA"`).
  final String characterName;

  /// Creates an [EnergyOrbAvatar].
  const EnergyOrbAvatar({
    required super.state,
    this.characterName = 'WATSON',
    super.size,
    super.key,
  });

  @override
  State<EnergyOrbAvatar> createState() => _EnergyOrbAvatarState();
}

// ---------------------------------------------------------------------------
// _EnergyOrbAvatarState
// ---------------------------------------------------------------------------

class _EnergyOrbAvatarState extends State<EnergyOrbAvatar>
    with TickerProviderStateMixin {
  late AnimationController _primary;
  late AnimationController _secondary;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final durations = _durationsFor(widget.state);
    _primary = AnimationController(vsync: this, duration: durations.$1)
      ..repeat();
    _secondary = AnimationController(vsync: this, duration: durations.$2)
      ..repeat();
  }

  @override
  void didUpdateWidget(EnergyOrbAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _applyState(widget.state);
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // State → animation speed mapping
  // -------------------------------------------------------------------------

  /// Returns (primaryDuration, secondaryDuration) for the given [state].
  (Duration, Duration) _durationsFor(AvatarState state) => switch (state) {
        AvatarState.idle => (
            const Duration(milliseconds: 3000),
            const Duration(milliseconds: 4000),
          ),
        AvatarState.thinking => (
            const Duration(milliseconds: 1500),
            const Duration(milliseconds: 800),
          ),
        AvatarState.speaking => (
            const Duration(milliseconds: 800),
            const Duration(milliseconds: 400),
          ),
        AvatarState.waiting => (
            const Duration(milliseconds: 5000),
            const Duration(milliseconds: 12000),
          ),
      };

  /// Adjusts both controllers to the durations appropriate for [state].
  ///
  /// The current fractional position is preserved so the animation
  /// transitions smoothly rather than snapping to zero.
  void _applyState(AvatarState state) {
    final durations = _durationsFor(state);

    // Preserve the current fractional position to avoid a visual jump.
    final primaryValue = _primary.value;
    final secondaryValue = _secondary.value;

    _primary.stop();
    _secondary.stop();

    _primary.duration = durations.$1;
    _secondary.duration = durations.$2;

    _primary.forward(from: primaryValue);
    _primary.addStatusListener(_repeatPrimary);

    _secondary.forward(from: secondaryValue);
    _secondary.addStatusListener(_repeatSecondary);
  }

  void _repeatPrimary(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _primary.removeStatusListener(_repeatPrimary);
      _primary.repeat();
    }
  }

  void _repeatSecondary(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _secondary.removeStatusListener(_repeatSecondary);
      _secondary.repeat();
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final config = OrbConfig.forCharacter(widget.characterName);

    return AnimatedBuilder(
      animation: Listenable.merge([_primary, _secondary]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: OrbPainter(
            config: config,
            animationValue: _primary.value,
            secondaryAnimValue: _secondary.value,
            state: widget.state,
          ),
        );
      },
    );
  }
}
