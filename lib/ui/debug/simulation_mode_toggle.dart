// SimulationModeToggle — debug-only widget to toggle offline simulation mode.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SimulationMode
// ---------------------------------------------------------------------------

/// Holds the global simulation mode flag.
///
/// When [enabled] is `true`, [MockOllamaClient] should be used instead of the
/// real [OllamaClient].
class SimulationMode {
  SimulationMode._();

  /// Whether simulation mode is currently active.
  static bool enabled = false;
}

// ---------------------------------------------------------------------------
// SimulationModeToggle
// ---------------------------------------------------------------------------

/// A [PopupMenuButton] that appears only in debug builds (`kDebugMode`).
///
/// Shows the current simulation state and lets the developer toggle it on/off.
class SimulationModeToggle extends StatefulWidget {
  const SimulationModeToggle({super.key});

  @override
  State<SimulationModeToggle> createState() => _SimulationModeToggleState();
}

class _SimulationModeToggleState extends State<SimulationModeToggle> {
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final label = SimulationMode.enabled ? 'Simulation: ON' : 'Simulation: OFF';
    final color = SimulationMode.enabled ? Colors.orange : Colors.grey;

    return PopupMenuButton<bool>(
      tooltip: 'Toggle simulation mode',
      child: Chip(
        label: Text(label, style: TextStyle(color: color, fontSize: 11)),
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      onSelected: (value) {
        setState(() => SimulationMode.enabled = value);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem<bool>(
          value: true,
          checked: SimulationMode.enabled,
          child: const Text('Simulation ON'),
        ),
        CheckedPopupMenuItem<bool>(
          value: false,
          checked: !SimulationMode.enabled,
          child: const Text('Simulation OFF'),
        ),
      ],
    );
  }
}
