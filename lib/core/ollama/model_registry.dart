// Model registry for deepThink.
//
// Defines the four available Ollama models with their metadata.
// This file has zero Flutter imports — pure Dart only.

/// Metadata describing a single available model.
class ModelInfo {
  /// The Ollama model tag used in all API calls (e.g. `mistral:7b`).
  final String id;

  /// The human-readable display name shown in the UI (e.g. `Mistral 7B`).
  final String displayName;

  /// Approximate disk / RAM footprint in gigabytes (e.g. `4.1`).
  final double ramGb;

  /// Short user-facing description shown in model selectors.
  final String description;

  /// Whether this model receives the largest available context window tier.
  ///
  /// Currently only `phi3:14b` sets this flag to `true`.
  final bool isHighContext;

  /// Creates a [ModelInfo] entry.
  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.ramGb,
    required this.description,
    required this.isHighContext,
  });

  @override
  String toString() => 'ModelInfo($id, ${ramGb}GB)';
}

/// Registry of all four models available in deepThink.
///
/// Use [ModelRegistry.all] to get the full list, or [ModelRegistry.findById]
/// to look up a specific model by its Ollama tag.
class ModelRegistry {
  ModelRegistry._();

  /// The all-rounder — fast, sharp, great at debate and structured thinking.
  static const ModelInfo mistral7b = ModelInfo(
    id: 'mistral:7b',
    displayName: 'Mistral 7B',
    ramGb: 4.1,
    description:
        'The all-rounder — fast, sharp, great at debate and structured thinking.',
    isHighContext: false,
  );

  /// Natural and expressive — great for free-flowing creative discussion.
  static const ModelInfo llama3_8b = ModelInfo(
    id: 'llama3:8b',
    displayName: 'Llama 3 8B',
    ramGb: 4.7,
    description:
        'Natural and expressive — great for free-flowing creative discussion.',
    isHighContext: false,
  );

  /// Precise and clear — excellent at breaking down complex ideas cleanly.
  static const ModelInfo gemma2_9b = ModelInfo(
    id: 'gemma2:9b',
    displayName: 'Gemma 2 9B',
    ramGb: 5.5,
    description:
        'Precise and clear — excellent at breaking down complex ideas cleanly.',
    isHighContext: false,
  );

  /// Deep reasoning — punches above its size, best for philosophical depth.
  static const ModelInfo phi3_14b = ModelInfo(
    id: 'phi3:14b',
    displayName: 'Phi-3 14B',
    ramGb: 8.2,
    description:
        'Deep reasoning — punches above its size, best for philosophical depth.',
    isHighContext: true,
  );

  /// Vision — image analysis model (loaded on demand).
  static const ModelInfo llava7b = ModelInfo(
    id: 'llava:7b',
    displayName: 'LLaVA 7B',
    ramGb: 4.7,
    description: 'Vision — image analysis (loaded on demand).',
    isHighContext: false,
  );

  /// All registered models in display order.
  static const List<ModelInfo> all = [
    mistral7b,
    llama3_8b,
    gemma2_9b,
    phi3_14b,
    llava7b,
  ];

  /// Returns the [ModelInfo] whose [ModelInfo.id] equals [id], or `null` if
  /// no matching model is found.
  static ModelInfo? findById(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return null;
  }
}
