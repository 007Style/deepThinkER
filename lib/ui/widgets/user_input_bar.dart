// User text input bar — sits above the status band.
//
// The bar is ALWAYS active — users can type and submit messages even before
// the conversation starts.  When not running, submitted messages are queued
// (shown via [pendingCount] badge) and injected into the engine on Start.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'whisper_selector.dart';

// ---------------------------------------------------------------------------
// UserInputBar
// ---------------------------------------------------------------------------

/// Bottom input bar for the human user to send or queue messages.
///
/// - [userName]     : displayed label (updates dynamically via easter egg).
/// - [isRunning]    : whether a conversation is actively running.
/// - [pendingCount] : number of messages queued before Start.
/// - [onSubmit]     : called with the trimmed text when the user sends.
class UserInputBar extends StatefulWidget {
  /// Dynamic display name for the user label.
  final String userName;

  /// Whether the conversation engine is running.
  final bool isRunning;

  /// Number of messages queued for injection at Start.
  final int pendingCount;

  /// Called with the non-empty trimmed text when the user submits.
  final void Function(String) onSubmit;

  /// Optional callback to toggle the steering bar.
  final VoidCallback? onToggleSteering;

  /// Called with (text, targetCharacter) for whispers, or null for normal.
  final void Function(String, String)? onWhisper;

  const UserInputBar({
    required this.userName,
    required this.isRunning,
    required this.pendingCount,
    required this.onSubmit,
    this.onToggleSteering,
    this.onWhisper,
    super.key,
  });

  @override
  State<UserInputBar> createState() => _UserInputBarState();
}

class _UserInputBarState extends State<UserInputBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Non-null when whisper mode is active.
  String? _whisperTarget;

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (_whisperTarget != null && widget.onWhisper != null) {
      widget.onWhisper!(text, _whisperTarget!);
    } else {
      widget.onSubmit(text);
    }
    _ctrl.clear();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool preStart = !widget.isRunning;

    // Border color is muted when pre-start (queue mode), accent when live.
    final Color borderColor = preStart
        ? AppColors.border
        : AppColors.accent.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User name label + optional "queued" pill
          SizedBox(
            width: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: preStart
                        ? AppColors.textSecondary
                        : AppColors.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (preStart && widget.pendingCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${widget.pendingCount} queued',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Text field — always enabled
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                // Send on Enter, new-line on Shift+Enter
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  final shift = HardwareKeyboard.instance.isShiftPressed;
                  if (!shift) _submit();
                }
              },
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                enabled: true,
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: preStart
                      ? 'Queue a message for when the conversation starts…'
                      : 'Interject…',
                  isDense: true,
                ),
              ),
            ),
          ),
          // Whisper selector (only shown when onWhisper is set)
          if (widget.onWhisper != null) ...[
            const SizedBox(width: 6),
            WhisperSelector(
              onWhisperChanged: (target) =>
                  setState(() => _whisperTarget = target),
            ),
          ],
          const SizedBox(width: 8),
          // Steer toggle button (optional)
          if (widget.onToggleSteering != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Toggle steering input',
                child: InkWell(
                  onTap: widget.onToggleSteering,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '🎯',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          // Send button — always enabled
          SizedBox(
            width: 64,
            height: 34,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    preStart ? AppColors.border : AppColors.accent,
                foregroundColor: preStart
                    ? AppColors.textSecondary
                    : Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                _whisperTarget != null
                    ? '🤫 Whisper'
                    : preStart
                        ? 'Queue'
                        : 'Send',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
