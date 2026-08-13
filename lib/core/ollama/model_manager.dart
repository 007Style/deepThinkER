/// Model lifecycle manager for deepThink.
///
/// Checks which of the four registry models are installed in Ollama, downloads
/// missing models with progress reporting, and exposes a convenience method
/// to download all missing models sequentially.
///
/// This file has zero Flutter imports — pure Dart only.
library model_manager;

import 'ollama_client.dart';
import 'model_registry.dart';

// ---------------------------------------------------------------------------
// ModelStatus
// ---------------------------------------------------------------------------

/// The installation status of a single registry model.
class ModelStatus {
  /// Metadata from [ModelRegistry] for this model.
  final ModelInfo model;

  /// Whether this model is currently installed in the local Ollama instance.
  final bool isInstalled;

  /// Creates a [ModelStatus].
  const ModelStatus({
    required this.model,
    required this.isInstalled,
  });

  @override
  String toString() => 'ModelStatus(${model.id}, installed=$isInstalled)';
}

// ---------------------------------------------------------------------------
// ModelManager
// ---------------------------------------------------------------------------

/// High-level model lifecycle manager.
///
/// Wraps [OllamaClient] to provide install-status checks and sequential
/// download orchestration for all four deepThink models.
///
/// ### Example
/// ```dart
/// final client  = OllamaClient();
/// final manager = ModelManager(client: client);
///
/// final statuses = await manager.checkModels();
/// for (final s in statuses) {
///   print('${s.model.displayName}: ${s.isInstalled ? "ok" : "missing"}');
/// }
///
/// await manager.downloadAllMissing((tag, progress) {
///   print('$tag: ${(progress.percent * 100).toStringAsFixed(0)}%');
/// });
/// ```
class ModelManager {
  /// The Ollama REST client used for all API calls.
  final OllamaClient client;

  /// Creates a [ModelManager] backed by [client].
  const ModelManager({required this.client});

  // -------------------------------------------------------------------------
  // Status check
  // -------------------------------------------------------------------------

  /// Returns the install status for every model in [ModelRegistry.all].
  ///
  /// Calls [OllamaClient.listModels] once and cross-references the result
  /// against the registry.
  Future<List<ModelStatus>> checkModels() async {
    final installed = await client.listModels();

    // Normalize installed names: Ollama may or may not include the tag suffix.
    // For example `mistral:7b` and `mistral` should both match `mistral:7b`.
    final installedSet = <String>{
      for (final name in installed) name.toLowerCase(),
    };

    return ModelRegistry.all.map((model) {
      final id = model.id.toLowerCase();
      // Match exact tag OR base name without tag.
      final baseName = id.contains(':') ? id.split(':').first : id;
      final isInstalled =
          installedSet.contains(id) || installedSet.contains(baseName);
      return ModelStatus(model: model, isInstalled: isInstalled);
    }).toList();
  }

  // -------------------------------------------------------------------------
  // Single model download
  // -------------------------------------------------------------------------

  /// Streams download progress for a single [modelTag].
  ///
  /// Delegates directly to [OllamaClient.pullModel].
  ///
  /// ```dart
  /// await for (final p in manager.downloadModel('llama3:8b')) {
  ///   print('${p.status} — ${(p.percent * 100).toStringAsFixed(1)}%');
  /// }
  /// ```
  Stream<ModelPullProgress> downloadModel(String modelTag) {
    return client.pullModel(modelTag);
  }

  // -------------------------------------------------------------------------
  // Download all missing
  // -------------------------------------------------------------------------

  /// Downloads every model not yet installed, sequentially.
  ///
  /// [onProgress] is called for each [ModelPullProgress] event so callers can
  /// update their UI. The first argument is the model tag currently being
  /// downloaded.
  ///
  /// Models are downloaded in [ModelRegistry.all] order.
  Future<void> downloadAllMissing(
    void Function(String modelTag, ModelPullProgress progress) onProgress,
  ) async {
    final statuses = await checkModels();

    for (final status in statuses) {
      if (status.isInstalled) continue;

      await for (final progress in client.pullModel(status.model.id)) {
        onProgress(status.model.id, progress);
        if (progress.isDone) break;
      }
    }
  }
}
