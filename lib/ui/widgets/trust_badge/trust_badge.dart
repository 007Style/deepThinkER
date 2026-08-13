// TrustBadge — compact trust score + tier indicator for AI quadrant headers.
//
// Displays the numeric score and tier label with a tier-derived color.
// Animates opacity when the score changes.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/trust/trust_score.dart';

// ---------------------------------------------------------------------------
// TrustBadge
// ---------------------------------------------------------------------------

/// Compact badge showing a character's current trust score and tier.
///
/// [scoreStream] should be a filtered stream of [TrustScore] objects for the
/// single character this badge represents.
///
/// Animates to a brief white flash then returns to the tier color whenever
/// the score changes.
class TrustBadge extends StatefulWidget {
  final Stream<TrustScore> scoreStream;
  final TrustScore initialScore;

  const TrustBadge({
    required this.scoreStream,
    required this.initialScore,
    super.key,
  });

  @override
  State<TrustBadge> createState() => _TrustBadgeState();
}

class _TrustBadgeState extends State<TrustBadge>
    with SingleTickerProviderStateMixin {
  late TrustScore _current;
  StreamSubscription<TrustScore>? _sub;

  late final AnimationController _flashCtrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _current = widget.initialScore;

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );

    _sub = widget.scoreStream.listen((score) {
      if (!mounted) return;
      setState(() => _current = score);
      _flashCtrl.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flashCtrl.dispose();
    super.dispose();
  }

  Color get _tierColor {
    switch (_current.tier) {
      case TrustTier.low:
        return Colors.red[700]!;
      case TrustTier.mid:
        return Colors.amber[700]!;
      case TrustTier.high:
        return Colors.green[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor;

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _current.score.round().toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              _current.tier.label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
