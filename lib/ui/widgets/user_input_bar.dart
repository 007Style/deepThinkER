// User text input bar — sits above the status band.
//
// The bar is ALWAYS active — users can type and submit messages even before
// the conversation starts.  When not running, submitted messages are queued
// (shown via [pendingCount] badge) and injected into the engine on Start.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

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

  const UserInputBar({
    required this.userName,
    required this.isRunning,
    required this.pendingCount,
    required this.onSubmit,
    super.key,
  });

  @override
  State<UserInputBar> createState() => _UserInputBarState();
}

class _UserInputBarState extends State<UserInputBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
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
          const SizedBox(width: 8),
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
              child: Text(preStart ? 'Queue' : 'Send'),
            ),
          ),
        ],
      ),
    );
  }
}
