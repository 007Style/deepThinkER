// External Ollama Screen for deepThink.
//
// Shown at startup when port 11434 is already held by a foreign Ollama
// process that is not responding to HTTP.  Lets the user kill it and retry.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ollama/ollama_launcher.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// ExternalOllamaScreen
// ---------------------------------------------------------------------------

class ExternalOllamaScreen extends StatefulWidget {
  final ExternalOllamaException error;

  /// Called after the blocker is killed and our Ollama is confirmed running.
  final VoidCallback onRetry;

  const ExternalOllamaScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  @override
  State<ExternalOllamaScreen> createState() => _ExternalOllamaScreenState();
}

class _ExternalOllamaScreenState extends State<ExternalOllamaScreen> {
  _Phase _phase = _Phase.idle;
  String _detail = '';

  Future<void> _kill() async {
    setState(() {
      _phase = _Phase.killing;
      _detail = 'Sending SIGKILL to pid ${widget.error.pid}…';
    });

    final ok = await killExternalOllama(widget.error.pid);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _phase = _Phase.failed;
        _detail =
            'Could not kill pid ${widget.error.pid}. '
            'Try running:\n  kill -9 ${widget.error.pid}\nin Terminal, then press Retry.';
      });
      return;
    }

    // Give the OS a moment to release the port.
    setState(() => _detail = 'Waiting for port to be released…');
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _phase = _Phase.done;
      _detail = 'Done — restarting deepThink engine…';
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final pid = widget.error.pid;
    final proc = widget.error.processPath;
    final isWorking = _phase == _Phase.killing || _phase == _Phase.done;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a1a00),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6b3a00)),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF9800),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Another Ollama is running',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Explanation ─────────────────────────────────────────────
                const Text(
                  'deepThink bundles its own Ollama engine, but port 11434 is '
                  'already occupied by a separate process that isn\'t responding. '
                  'This is usually a leftover Ollama instance from a previous run '
                  'or another AI tool.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Process info card ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1400),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4a3800)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'PID', value: '$pid'),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'Process',
                        value: proc == 'unknown' ? '(could not resolve)' : proc,
                      ),
                      const SizedBox(height: 6),
                      const _InfoRow(label: 'Port', value: '11434 (TCP, LISTEN)'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Status / detail line ────────────────────────────────────
                if (_detail.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWorking)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      else if (_phase == _Phase.failed)
                        const Icon(Icons.error_outline,
                            size: 14, color: Color(0xFFF44336))
                      else
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _detail,
                          style: TextStyle(
                            fontSize: 12,
                            color: _phase == _Phase.failed
                                ? const Color(0xFFF44336)
                                : AppColors.textSecondary,
                            height: 1.5,
                            fontFamily:
                                _phase == _Phase.failed ? 'monospace' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Action buttons ──────────────────────────────────────────
                Row(
                  children: [
                    // Kill & Retry button
                    ElevatedButton.icon(
                      onPressed: isWorking ? null : _kill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            const Color(0xFFFF9800).withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: isWorking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black54),
                            )
                          : const Icon(Icons.power_settings_new_rounded,
                              size: 16),
                      label: Text(
                        _phase == _Phase.failed ? 'Retry' : 'Kill & Retry',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Manual instructions toggle
                    TextButton(
                      onPressed: isWorking
                          ? null
                          : () => setState(() {
                                _phase = _Phase.failed;
                                _detail =
                                    'To kill manually, open Terminal and run:\n'
                                    '  kill -9 $pid\n'
                                    'Then press "Kill & Retry" to continue.';
                              }),
                      child: const Text(
                        'Do it manually',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

enum _Phase { idle, killing, done, failed }

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
