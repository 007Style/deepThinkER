/// StateSimulatorPanel — debug overlay for manipulating app state.
///
/// Only rendered when [kDebugMode] is true.
library state_simulator_panel;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/debug/debug_controller.dart';

// ---------------------------------------------------------------------------
// StateSimulatorPanel
// ---------------------------------------------------------------------------

/// A floating debug overlay panel guarded by [kDebugMode].
///
/// Exposes sliders, dropdowns, and action buttons to manipulate deepThinkER
/// state at runtime without a real conversation.
///
/// Usage: embed in a [Stack] over the main content.
class StateSimulatorPanel extends StatefulWidget {
  /// Character names to include in the trust/mood controls.
  final List<String> characterNames;

  /// Called when the user taps the close button.
  final VoidCallback? onClose;

  const StateSimulatorPanel({
    super.key,
    this.characterNames = const ['WATSON', 'DEEP', 'NOVA', 'SAGE'],
    this.onClose,
  });

  @override
  State<StateSimulatorPanel> createState() => _StateSimulatorPanelState();
}

class _StateSimulatorPanelState extends State<StateSimulatorPanel> {
  bool _expanded = false;

  // Per-character state
  late final Map<String, double> _trustValues;
  late final Map<String, String> _moodValues;

  static const List<String> _moodOptions = [
    'neutral',
    'happy',
    'frustrated',
    'curious',
    'suspicious',
    'excited',
  ];

  @override
  void initState() {
    super.initState();
    _trustValues = {for (final c in widget.characterNames) c: 0.7};
    _moodValues = {for (final c in widget.characterNames) c: 'neutral'};
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      right: 8,
      bottom: 80,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade900.withAlpha(230),
        child: _expanded ? _buildExpanded() : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    return IconButton(
      icon: const Icon(Icons.bug_report, color: Colors.orange),
      tooltip: 'State Simulator',
      onPressed: () => setState(() => _expanded = true),
    );
  }

  Widget _buildExpanded() {
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'State Simulator',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.minimize, color: Colors.white70, size: 16),
                  tooltip: 'Collapse',
                  onPressed: () => setState(() => _expanded = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  tooltip: 'Close panel',
                  onPressed: () {
                    setState(() => _expanded = false);
                    widget.onClose?.call();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: Colors.white24),

            // Per-character controls
            ...widget.characterNames.map((char) => _buildCharacterTile(char)),

            const Divider(color: Colors.white24),

            // Action buttons
            _actionButton(
              'Fire Rate Limit Violation',
              Colors.amber,
              () => DebugController.instance
                  .fireRateLimitViolation(widget.characterNames.first),
            ),
            const SizedBox(height: 4),
            _actionButton(
              'Trigger Research Phase',
              Colors.blue.shade300,
              () => DebugController.instance.setMood(
                widget.characterNames.first,
                'research_phase',
              ),
            ),
            const SizedBox(height: 4),
            _actionButton(
              'Simulate Ollama Crash',
              Colors.red.shade300,
              () => DebugController.instance.simulateOllamaCrash(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterTile(String char) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            char,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              const Text('Trust', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 1,
                  value: _trustValues[char]!,
                  activeColor: Colors.orange,
                  onChanged: (v) {
                    setState(() => _trustValues[char] = v);
                    DebugController.instance.setTrust(char, v);
                  },
                ),
              ),
              Text(
                (_trustValues[char]! * 100).round().toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Mood  ', style: TextStyle(color: Colors.white54, fontSize: 10)),
              DropdownButton<String>(
                value: _moodValues[char],
                dropdownColor: Colors.grey.shade800,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                underline: const SizedBox(),
                items: _moodOptions
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _moodValues[char] = v);
                  DebugController.instance.setMood(char, v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 6),
          textStyle: const TextStyle(fontSize: 11),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
