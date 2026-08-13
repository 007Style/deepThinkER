// Per-character configuration card for deepThink startup config screen.
//
// Shows: avatar (idle, 56px), character name + personality + IBM reference,
// model selector, and an expandable system prompt editor.
import 'package:flutter/material.dart';

import '../../core/conversation/participant.dart';
import '../../core/ollama/model_registry.dart';
import '../avatars/avatar_registry.dart';
import '../avatars/avatar_widget.dart';
import 'app_theme.dart';
import 'model_selector.dart';

// ---------------------------------------------------------------------------
// CharacterConfigCard
// ---------------------------------------------------------------------------

/// Configuration card for a single AI participant.
///
/// Displays the character's avatar, identity labels, a [ModelSelector], and
/// an expandable panel for editing the master system prompt.
class CharacterConfigCard extends StatefulWidget {
  /// The participant whose config is being displayed.
  final Participant participant;

  /// Called when the user selects a different model.
  final void Function(String modelId) onModelChanged;

  /// Called when the user edits the master system prompt.
  final void Function(String prompt) onPromptChanged;

  const CharacterConfigCard({
    required this.participant,
    required this.onModelChanged,
    required this.onPromptChanged,
    super.key,
  });

  @override
  State<CharacterConfigCard> createState() => _CharacterConfigCardState();
}

class _CharacterConfigCardState extends State<CharacterConfigCard> {
  bool _promptExpanded = false;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: widget.participant.masterPrompt,
    );
    _promptController.addListener(() {
      widget.onPromptChanged(_promptController.text);
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Color _borderColor(String name) {
    switch (name.toUpperCase()) {
      case 'WATSON':
        return AppColors.watsonBlue;
      case 'DEEP':
        return AppColors.deepPurple;
      case 'NOVA':
        return AppColors.novaOrange;
      case 'SAGE':
        return AppColors.sageRed;
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(widget.participant.name);
    final model = ModelRegistry.findById(widget.participant.assignedModelId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar — idle state, 56px
                AvatarRegistry.build(
                  'energyOrb',
                  state: AvatarState.idle,
                  characterName: widget.participant.name,
                  size: 56,
                ),
                const SizedBox(width: 12),
                // Identity labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.participant.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: borderColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.participant.personality,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.participant.ibmReference,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Host badge
                if (widget.participant.isHost)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'HOST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: borderColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Model selector ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MODEL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                ModelSelector(
                  selectedModelId: widget.participant.assignedModelId,
                  onChanged: widget.onModelChanged,
                ),
                if (model != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    model.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Expandable system prompt editor ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expand toggle
                InkWell(
                  onTap: () =>
                      setState(() => _promptExpanded = !_promptExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _promptExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Edit System Prompt',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Prompt field (shown when expanded)
                if (_promptExpanded) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    maxLines: 12,
                    minLines: 6,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: borderColor.withValues(alpha: 0.7),
                          width: 1.4,
                        ),
                      ),
                      hintText: 'Enter system prompt…',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
