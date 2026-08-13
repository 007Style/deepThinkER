// Manual model installation help screen for deepThink.
//
// Shows per-model download links, step-by-step fallback instructions,
// and model storage locations for macOS and Windows.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ollama/model_registry.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// ModelHelpScreen
// ---------------------------------------------------------------------------

/// Full-screen scrollable help page explaining how to install models manually.
class ModelHelpScreen extends StatelessWidget {
  const ModelHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Manual Model Installation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Models grid ───────────────────────────────────────────────
                _SectionHeader(title: 'Available Models'),
                const SizedBox(height: 12),
                ...ModelRegistry.all.map((m) => _ModelCard(model: m)),

                const SizedBox(height: 32),

                // ── Fallback steps ────────────────────────────────────────────
                _SectionHeader(title: 'If Automatic Download Failed'),
                const SizedBox(height: 12),
                const _FallbackSteps(),

                const SizedBox(height: 32),

                // ── Storage locations ─────────────────────────────────────────
                _SectionHeader(title: 'Model Storage Locations'),
                const SizedBox(height: 12),
                const _StorageLocations(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionHeader
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ModelCard
// ---------------------------------------------------------------------------

class _ModelCard extends StatelessWidget {
  final ModelInfo model;

  const _ModelCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final libraryUrl =
        'https://ollama.com/library/${model.id.split(':').first}';
    final tagName = model.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: display name + RAM badge
          Row(
            children: [
              Expanded(
                child: Text(
                  model.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _RamBadge(gb: model.ramGb),
            ],
          ),
          const SizedBox(height: 4),
          // Ollama tag
          _CodeChip(text: tagName),
          const SizedBox(height: 8),
          // Description
          Text(
            model.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // Library link
          GestureDetector(
            onTap: () => _launch(libraryUrl),
            child: Text(
              libraryUrl,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// _RamBadge
// ---------------------------------------------------------------------------

class _RamBadge extends StatelessWidget {
  final double gb;

  const _RamBadge({required this.gb});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '${gb.toStringAsFixed(1)} GB',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CodeChip
// ---------------------------------------------------------------------------

class _CodeChip extends StatelessWidget {
  final String text;

  const _CodeChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FallbackSteps
// ---------------------------------------------------------------------------

class _FallbackSteps extends StatelessWidget {
  const _FallbackSteps();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        'Download and install Ollama',
        'Visit https://ollama.com/download and install Ollama for your platform.',
        'https://ollama.com/download',
      ),
      (
        'Open a terminal',
        Platform.isMacOS
            ? 'Open Terminal (Applications → Utilities → Terminal).'
            : 'Open Command Prompt or PowerShell (search "cmd" or "PowerShell" in Start).',
        null,
      ),
      (
        'Pull each model',
        'Run the following command for each missing model:',
        null,
      ),
      (
        'Verify installation',
        'Run the following command to list all installed models:',
        null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepRow(
            number: i + 1,
            title: steps[i].$1,
            description: steps[i].$2,
            linkUrl: steps[i].$3,
          ),
          // Extra content for steps 3 and 4
          if (i == 2) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ModelRegistry.all
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _CodeBlock(text: 'ollama pull ${m.id}'),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (i == 3) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 36),
              child: _CodeBlock(text: 'ollama list'),
            ),
          ],
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final String? linkUrl;

  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
    this.linkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (linkUrl != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(linkUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    linkUrl!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;

  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StorageLocations
// ---------------------------------------------------------------------------

class _StorageLocations extends StatelessWidget {
  const _StorageLocations();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StorageRow(
          platform: 'macOS',
          path: r'~/.ollama/models/',
        ),
        const SizedBox(height: 8),
        _StorageRow(
          platform: 'Windows',
          path: r'%USERPROFILE%\.ollama\models\',
        ),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String platform;
  final String path;

  const _StorageRow({required this.platform, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              platform,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            path,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
