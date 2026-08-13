/// ShortcutEditor — Flutter screen displaying current keyboard shortcut bindings.
library shortcut_editor;

import 'package:flutter/material.dart';

import '../../core/settings/keyboard_shortcut_map.dart';
import '../input/shortcut_handler.dart';

// ---------------------------------------------------------------------------
// ShortcutEditor
// ---------------------------------------------------------------------------

/// A scrollable list view showing the current keyboard shortcut bindings.
///
/// Displays each action name alongside its current key combo.  Actual
/// re-binding is not implemented yet — this is a read-only display.
class ShortcutEditor extends StatefulWidget {
  const ShortcutEditor({super.key});

  @override
  State<ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<ShortcutEditor> {
  final _map = KeyboardShortcutMap();

  @override
  Widget build(BuildContext context) {
    final actions = _map.actions;

    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard Shortcuts')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final action = actions[index];
          final binding = _map.binding(action) ?? '';
          return ListTile(
            title: Text(_actionLabel(action)),
            trailing: Chip(
              label: Text(shortcutLabel(binding)),
              labelStyle: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a camelCase action name to a readable label.
  String _actionLabel(String action) {
    final spaced = action.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m[0]}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
