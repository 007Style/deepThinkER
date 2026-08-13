/// OllamaStatusIndicator — small colored dot showing Ollama health.
library ollama_status_indicator;

import 'package:flutter/material.dart';

import '../../core/ollama/ollama_health_monitor.dart';

// ---------------------------------------------------------------------------
// OllamaStatusIndicator
// ---------------------------------------------------------------------------

/// A small colored circle that reflects the current [OllamaHealthStatus]:
/// - green  → healthy
/// - amber  → restarting
/// - red    → failed
class OllamaStatusIndicator extends StatelessWidget {
  /// The current health status to display.
  final OllamaHealthStatus status;

  /// Diameter of the dot.  Defaults to 10.
  final double size;

  const OllamaStatusIndicator({
    super.key,
    required this.status,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OllamaHealthStatus.healthy => Colors.green,
      OllamaHealthStatus.restarting => Colors.amber,
      OllamaHealthStatus.failed => Colors.red,
    };

    return Tooltip(
      message: switch (status) {
        OllamaHealthStatus.healthy => 'Ollama: healthy',
        OllamaHealthStatus.restarting => 'Ollama: restarting…',
        OllamaHealthStatus.failed => 'Ollama: failed',
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
