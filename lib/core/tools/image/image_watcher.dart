// ImageWatcher — monitors the workspace for new image files.
//
// Emits [ImageDroppedEvent] when an image file is detected.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:io';

import 'image_tool_config.dart';

// ---------------------------------------------------------------------------
// ImageDroppedEvent
// ---------------------------------------------------------------------------

/// Emitted when a new image file appears in the watched directory.
class ImageDroppedEvent {
  final String filePath;
  final String fileName;

  ImageDroppedEvent({required this.filePath, required this.fileName});
}

// ---------------------------------------------------------------------------
// ImageWatcher
// ---------------------------------------------------------------------------

/// Watches a directory for new image files using [Directory.watch].
///
/// Debounces events by 500 ms to avoid duplicate firing.
class ImageWatcher {
  final String watchPath;
  final ImageToolConfig config;

  StreamSubscription<FileSystemEvent>? _watchSub;
  final StreamController<ImageDroppedEvent> _controller =
      StreamController<ImageDroppedEvent>.broadcast();

  Timer? _debounce;
  final Set<String> _pending = {};

  ImageWatcher({
    required this.watchPath,
    ImageToolConfig? config,
  }) : config = config ?? ImageToolConfig.instance;

  /// Broadcast stream of [ImageDroppedEvent]s.
  Stream<ImageDroppedEvent> get events => _controller.stream;

  /// Starts watching the directory.
  Future<void> start() async {
    final dir = Directory(watchPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _watchSub = dir.watch(events: FileSystemEvent.create).listen((event) {
      final path = event.path;
      final name = path.split(Platform.pathSeparator).last;
      if (!config.isImageFile(name)) return;

      // Debounce: collect pending paths and flush after 500 ms.
      _pending.add(path);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _flush);
    });
  }

  void _flush() {
    for (final path in _pending) {
      final name = path.split(Platform.pathSeparator).last;
      if (!_controller.isClosed) {
        _controller.add(ImageDroppedEvent(filePath: path, fileName: name));
      }
    }
    _pending.clear();
  }

  /// Stops watching and closes the event stream.
  Future<void> stop() async {
    _debounce?.cancel();
    await _watchSub?.cancel();
    await _controller.close();
  }
}
