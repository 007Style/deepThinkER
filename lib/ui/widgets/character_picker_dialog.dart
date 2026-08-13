// CharacterPickerDialog — shows a list of built-in + custom characters to swap to.
import 'package:flutter/material.dart';

import '../../core/conversation/participant.dart';
import '../../core/persona/custom_character.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// CharacterPickerDialog
// ---------------------------------------------------------------------------

/// Shows a modal dialog to pick a replacement character for hot-swap.
///
/// Returns via [onSelected] with the chosen [Participant].
/// Call [showCharacterPickerDialog] rather than using this widget directly.
Future<void> showCharacterPickerDialog({
  required BuildContext context,
  required String currentCharacter,
  required void Function(Participant) onSelected,
}) async {
  final customs = await CustomCharacter.loadAll();

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _CharacterPickerDialog(
      currentCharacter: currentCharacter,
      customCharacters: customs,
      onSelected: (p) {
        Navigator.of(ctx).pop();
        onSelected(p);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// _CharacterPickerDialog (private widget)
// ---------------------------------------------------------------------------

class _CharacterPickerDialog extends StatelessWidget {
  final String currentCharacter;
  final List<CustomCharacter> customCharacters;
  final void Function(Participant) onSelected;

  const _CharacterPickerDialog({
    required this.currentCharacter,
    required this.customCharacters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final builtIns = Participant.defaults();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Swap Character',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Built-in characters',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...builtIns.map((p) => _CharacterTile(
                  name: p.name,
                  description: p.personality,
                  isCurrent: p.name == currentCharacter,
                  onTap: () => onSelected(p),
                )),
            if (customCharacters.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Custom characters',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ...customCharacters.map((c) => _CharacterTile(
                    name: c.name,
                    description: c.personalityDescription,
                    isCurrent: c.name == currentCharacter,
                    onTap: () => onSelected(Participant(
                      name: c.name,
                      ibmReference: 'Custom',
                      personality: c.personalityDescription,
                      role: c.personalityDescription,
                      assignedModelId: c.modelId,
                      masterPrompt: c.masterPrompt,
                    )),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterTile
// ---------------------------------------------------------------------------

class _CharacterTile extends StatelessWidget {
  final String name;
  final String description;
  final bool isCurrent;
  final VoidCallback onTap;

  const _CharacterTile({
    required this.name,
    required this.description,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: isCurrent ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCurrent
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.7),
            ),
            borderRadius: BorderRadius.circular(6),
            color: isCurrent
                ? AppColors.border.withValues(alpha: 0.25)
                : null,
          ),
          child: Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCurrent ? '$description (current)' : description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
