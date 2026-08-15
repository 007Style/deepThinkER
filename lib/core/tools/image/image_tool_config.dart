// ImageToolConfig — configuration for the image analysis tool.
//
// This file has zero Flutter imports — pure Dart only.

// ---------------------------------------------------------------------------
// ImageToolConfig
// ---------------------------------------------------------------------------

/// Configuration for the vision/image tool.
class ImageToolConfig {
  static ImageToolConfig? _instance;

  /// Singleton accessor.
  static ImageToolConfig get instance =>
      _instance ??= ImageToolConfig._default();

  /// Ollama model used for vision inference.
  String visionModelName;

  /// File extensions that are treated as images.
  List<String> supportedExtensions;

  /// When true, images dropped into the workspace are automatically analysed
  /// and injected into all characters' contexts.
  bool autoInjectOnDrop;

  ImageToolConfig._default()
      : visionModelName = 'llava:7b',
        supportedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
        autoInjectOnDrop = true;

  ImageToolConfig({
    required this.visionModelName,
    required this.supportedExtensions,
    required this.autoInjectOnDrop,
  });

  /// Returns `true` if [filename] has a supported image extension.
  bool isImageFile(String filename) {
    final lower = filename.toLowerCase();
    return supportedExtensions.any(lower.endsWith);
  }
}
