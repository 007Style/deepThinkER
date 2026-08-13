// WhisperSelector — character dropdown + whisper toggle for user input bar.
import 'package:flutter/material.dart';

import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// WhisperSelector
// ---------------------------------------------------------------------------

/// A compact row with a character dropdown and a whisper toggle button.
///
/// When whisper mode is active, the send button text should reflect it.
/// [onWhisperChanged] is called when the whisper target changes
/// (null = normal mode, a name = whisper to that character).
class WhisperSelector extends StatefulWidget {
  /// Called when the whisper target changes. Null = normal mode.
  final void Function(String? targetCharacter) onWhisperChanged;

  const WhisperSelector({
    required this.onWhisperChanged,
    super.key,
  });

  @override
  State<WhisperSelector> createState() => _WhisperSelectorState();
}

class _WhisperSelectorState extends State<WhisperSelector> {
  static const _characters = ['WATSON', 'DEEP', 'NOVA', 'SAGE'];

  bool _whisperMode = false;
  String _selectedChar = 'WATSON';

  void _toggle() {
    setState(() {
      _whisperMode = !_whisperMode;
    });
    widget.onWhisperChanged(_whisperMode ? _selectedChar : null);
  }

  void _onCharChanged(String? value) {
    if (value == null) return;
    setState(() => _selectedChar = value);
    if (_whisperMode) {
      widget.onWhisperChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Whisper toggle icon
        Tooltip(
          message: _whisperMode ? 'Disable whisper mode' : 'Enable whisper mode',
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _whisperMode
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : null,
                borderRadius: BorderRadius.circular(4),
                border: _whisperMode
                    ? Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4))
                    : null,
              ),
              child: Text(
                '🤫',
                style: TextStyle(
                  fontSize: 14,
                  color: _whisperMode ? null : Colors.grey,
                ),
              ),
            ),
          ),
        ),
        // Character dropdown (only shown in whisper mode)
        if (_whisperMode) ...[
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: _selectedChar,
            dropdownColor: AppColors.surface,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textPrimary,
            ),
            underline: const SizedBox.shrink(),
            isDense: true,
            items: _characters
                .map((c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            onChanged: _onCharChanged,
          ),
        ],
      ],
    );
  }
}
