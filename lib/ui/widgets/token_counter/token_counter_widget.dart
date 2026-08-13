// TokenCounterWidget — shows current token usage vs context window capacity.
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TokenCounterWidget
// ---------------------------------------------------------------------------

/// Compact display showing `currentTokens / maxTokens`.
///
/// Color shifts: green (<60%), amber (60–85%), red (>85%).
class TokenCounterWidget extends StatelessWidget {
  /// Current estimated token count.
  final int tokenCount;

  /// Maximum context window size in tokens.
  final int maxTokens;

  const TokenCounterWidget({
    required this.tokenCount,
    required this.maxTokens,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxTokens > 0 ? tokenCount / maxTokens : 0.0;
    final color = ratio > 0.85
        ? const Color(0xFFEF5350) // red
        : ratio > 0.60
            ? const Color(0xFFFFB300) // amber
            : const Color(0xFF66BB6A); // green

    final display = '${_fmt(tokenCount)} / ${_fmt(maxTokens)}';

    return Text(
      display,
      style: TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w500,
        fontFamily: 'monospace',
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}
