// ShortcutHandler — Flutter widget that wraps a child with keyboard shortcut
// Shortcuts + Actions bindings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/keyboard_shortcut_map.dart';

// ---------------------------------------------------------------------------
// Intent classes
// ---------------------------------------------------------------------------

/// Intent to send the current user message.
class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

/// Intent to open the research mode screen.
class OpenResearchIntent extends Intent {
  const OpenResearchIntent();
}

/// Intent to open the settings screen.
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Intent to open the analytics screen.
class OpenAnalyticsIntent extends Intent {
  const OpenAnalyticsIntent();
}

/// Intent to toggle the steering input bar.
class ToggleSteeringIntent extends Intent {
  const ToggleSteeringIntent();
}

// ---------------------------------------------------------------------------
// ShortcutHandler
// ---------------------------------------------------------------------------

/// Wraps [child] with [Shortcuts] and [Actions] derived from
/// [KeyboardShortcutMap.defaults].
///
/// The [onSendMessage], [onOpenResearch], [onOpenSettings],
/// [onOpenAnalytics], and [onToggleSteering] callbacks are invoked when
/// their respective keyboard shortcuts are activated.
class ShortcutHandler extends StatelessWidget {
  final Widget child;

  final VoidCallback? onSendMessage;
  final VoidCallback? onOpenResearch;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onToggleSteering;

  const ShortcutHandler({
    super.key,
    required this.child,
    this.onSendMessage,
    this.onOpenResearch,
    this.onOpenSettings,
    this.onOpenAnalytics,
    this.onToggleSteering,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: {
          SendMessageIntent: CallbackAction<SendMessageIntent>(
            onInvoke: (_) {
              onSendMessage?.call();
              return null;
            },
          ),
          OpenResearchIntent: CallbackAction<OpenResearchIntent>(
            onInvoke: (_) {
              onOpenResearch?.call();
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              onOpenSettings?.call();
              return null;
            },
          ),
          OpenAnalyticsIntent: CallbackAction<OpenAnalyticsIntent>(
            onInvoke: (_) {
              onOpenAnalytics?.call();
              return null;
            },
          ),
          ToggleSteeringIntent: CallbackAction<ToggleSteeringIntent>(
            onInvoke: (_) {
              onToggleSteering?.call();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.enter):
          const SendMessageIntent(),
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
          const OpenResearchIntent(),
      const SingleActivator(LogicalKeyboardKey.comma, meta: true):
          const OpenSettingsIntent(),
      const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
          const OpenAnalyticsIntent(),
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
          const ToggleSteeringIntent(),
    };
  }
}

// ---------------------------------------------------------------------------
// Extension: readable label from KeyboardShortcutMap binding string
// ---------------------------------------------------------------------------

/// Returns a human-readable label for [binding].
String shortcutLabel(String binding) {
  return binding
      .replaceAll('Cmd', '⌘')
      .replaceAll('Shift', '⇧')
      .replaceAll('Alt', '⌥')
      .replaceAll('Ctrl', '⌃');
}
