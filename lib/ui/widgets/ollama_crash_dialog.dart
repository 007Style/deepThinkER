/// OllamaCrashDialog — shows when the Ollama process has crashed.
library ollama_crash_dialog;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// OllamaCrashDialog
// ---------------------------------------------------------------------------

/// An [AlertDialog] informing the user that Ollama has crashed and
/// providing manual restart instructions.
class OllamaCrashDialog extends StatelessWidget {
  /// Optional crash message from the health monitor.
  final String? message;

  const OllamaCrashDialog({super.key, this.message});

  /// Convenience helper to show the dialog.
  static Future<void> show(BuildContext context, {String? message}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OllamaCrashDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Ollama has stopped'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message!.isNotEmpty) ...[
            Text(message!),
            const SizedBox(height: 12),
          ],
          const Text(
            'deepThinkER cannot generate responses without Ollama running.\n\n'
            'To restart Ollama manually:',
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Open a Terminal\n'
            '2. Run: ollama serve\n'
            '3. Return here and press "Retry"',
            style: TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
