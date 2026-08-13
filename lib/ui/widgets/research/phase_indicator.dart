import 'package:flutter/material.dart';

import '../../../core/research/research_session.dart';

// ---------------------------------------------------------------------------
// PhaseIndicator
// ---------------------------------------------------------------------------

/// Displays the current research phase as an animated banner.
///
/// Transitions smoothly between phases using an [AnimatedContainer] color
/// change and a fading phase label.
class PhaseIndicator extends StatefulWidget {
  /// Stream of phase transitions from [ResearchEngine].
  final Stream<ResearchPhase> phaseStream;

  /// Initial phase to display.
  final ResearchPhase initialPhase;

  const PhaseIndicator({
    super.key,
    required this.phaseStream,
    this.initialPhase = ResearchPhase.gathering,
  });

  @override
  State<PhaseIndicator> createState() => _PhaseIndicatorState();
}

class _PhaseIndicatorState extends State<PhaseIndicator>
    with SingleTickerProviderStateMixin {
  late ResearchPhase _phase;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _phase = widget.initialPhase;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    widget.phaseStream.listen((newPhase) {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _phase = newPhase);
        _fadeController.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Phase styling
  // -------------------------------------------------------------------------

  static const _phaseData = {
    ResearchPhase.gathering: (
      emoji: '🔍',
      label: 'Gathering',
      color: Color(0xFF1565C0), // deep blue
    ),
    ResearchPhase.debating: (
      emoji: '💬',
      label: 'Debating',
      color: Color(0xFF6A1B9A), // deep purple
    ),
    ResearchPhase.synthesising: (
      emoji: '📝',
      label: 'Synthesising',
      color: Color(0xFF00695C), // deep teal
    ),
    ResearchPhase.complete: (
      emoji: '✅',
      label: 'Complete',
      color: Color(0xFF2E7D32), // deep green
    ),
  };

  @override
  Widget build(BuildContext context) {
    final data = _phaseData[_phase]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: data.color.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Phase: ${data.label}',
              style: TextStyle(
                color: data.color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
