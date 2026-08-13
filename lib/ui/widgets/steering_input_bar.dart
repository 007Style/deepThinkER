// SteeringInputBar — compact collapsible steering text input.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// SteeringInputBar
// ---------------------------------------------------------------------------

/// A compact steering input bar that injects silent guidance to all characters.
///
/// Calls [onSteer] when the user submits text.
/// Can be shown/hidden via the [visible] flag (AnimatedContainer).
class SteeringInputBar extends StatefulWidget {
  final bool visible;
  final void Function(String text) onSteer;

  const SteeringInputBar({
    required this.visible,
    required this.onSteer,
    super.key,
  });

  @override
  State<SteeringInputBar> createState() => _SteeringInputBarState();
}

class _SteeringInputBarState extends State<SteeringInputBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSteer(text);
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.visible ? 44 : 0,
      curve: Curves.easeInOut,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: 44,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                const Text(
                  '🎯 Steer',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        final shift =
                            HardwareKeyboard.instance.isShiftPressed;
                        if (!shift) _submit();
                      }
                    },
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Silent guidance to all characters…',
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.accent.withValues(alpha: 0.7),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Steer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
