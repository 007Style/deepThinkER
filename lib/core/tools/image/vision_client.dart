/// VisionClient — calls Ollama /api/generate with an image payload.
///
/// This file has zero Flutter imports — pure Dart only.
library vision_client;

import 'dart:convert';
import 'dart:io';

import 'image_tool_config.dart';

// ---------------------------------------------------------------------------
// VisionClient
// ---------------------------------------------------------------------------

/// Sends an image to Ollama's vision endpoint and returns a text description.
class VisionClient {
  static const _ollamaUrl = 'http://127.0.0.1:11434/api/generate';
  static const _timeout = Duration(seconds: 30);

  final ImageToolConfig config;

  VisionClient({ImageToolConfig? config})
      : config = config ?? ImageToolConfig.instance;

  /// Reads [imagePath], base64-encodes it, and calls Ollama's vision model.
  ///
  /// Returns the model's description text, or an error string on failure.
  Future<String> describe(String imagePath, String prompt) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final client = HttpClient();
      client.connectionTimeout = _timeout;

      final uri = Uri.parse(_ollamaUrl);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = json.encode({
        'model': config.visionModelName,
        'prompt': prompt,
        'images': [base64Image],
        'stream': false,
      });

      request.add(utf8.encode(body));
      final response = await request.close().timeout(_timeout);

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final decoded = json.decode(responseBody) as Map<String, dynamic>;
      return (decoded['response'] as String? ?? '').trim();
    } catch (e) {
      return '[VISION_ERROR: $e]';
    }
  }
}
