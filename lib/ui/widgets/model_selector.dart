// Model selector dropdown for deepThink.
//
// Displays all four registry models as dropdown items, each showing the
// model display name, RAM footprint, and a short description.
import 'package:flutter/material.dart';

import '../../core/ollama/model_registry.dart';
import 'app_theme.dart';

// ---------------------------------------------------------------------------
// ModelSelector
// ---------------------------------------------------------------------------

/// Dropdown widget for selecting a model from [ModelRegistry.all].
///
/// Each item shows:
/// - Model display name (bold)
/// - RAM footprint (e.g. `~8.2 GB`)
/// - Short description
class ModelSelector extends StatelessWidget {
  /// The currently selected model ID (e.g. `'phi3:14b'`).
  final String selectedModelId;

  /// Called when the user selects a different model.
  final void Function(String modelId) onChanged;

  const ModelSelector({
    required this.selectedModelId,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedModelId,
      isExpanded: true,
      dropdownColor: AppColors.card,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      items: ModelRegistry.all.map(_buildItem).toList(),
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }

  DropdownMenuItem<String> _buildItem(ModelInfo model) {
    return DropdownMenuItem<String>(
      value: model.id,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Name + RAM
          Text(
            model.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '~${model.ramGb.toStringAsFixed(1)} GB',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          // Description — flex so it clips cleanly
          Flexible(
            child: Text(
              model.description,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
