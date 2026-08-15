// Ollama REST API client for deepThink.
//
// Provides streaming chat generation, model listing, model pulling with
// progress, and a health check — all using only [dart:io] and [dart:convert].
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// ModelPullProgress
// ---------------------------------------------------------------------------

/// Progress event emitted during a model pull ([OllamaClient.pullModel]).
class ModelPullProgress {
  /// The Ollama model tag being pulled (e.g. `mistral:7b`).
  final String modelTag;

  /// Bytes downloaded so far.
  final int completed;

  /// Total bytes to download (may be 0 if unknown).
  final int total;

  /// Download progress as a fraction in the range `[0.0, 1.0]`.
  ///
  /// Returns `0.0` when [total] is zero (size not yet known).
  double get percent => (total > 0) ? (completed / total).clamp(0.0, 1.0) : 0.0;

  /// Human-readable status string from the Ollama API (e.g. `"pulling manifest"`).
  final String status;

  /// Whether the pull has completed successfully.
  final bool isDone;

  /// Creates a [ModelPullProgress] event.
  const ModelPullProgress({
    required this.modelTag,
    required this.completed,
    required this.total,
    required this.status,
    required this.isDone,
  });

  @override
  String toString() =>
      'ModelPullProgress($modelTag, ${(percent * 100).toStringAsFixed(1)}%, '
      'status="$status", done=$isDone)';
}

// ---------------------------------------------------------------------------
// OllamaClient
// ---------------------------------------------------------------------------

/// Low-level HTTP client for the Ollama REST API.
///
/// All calls are directed at [baseUrl] (default `http://localhost:11434`).
///
/// ### Example — streaming a chat response
/// ```dart
/// final client = OllamaClient();
/// await client.generateStream(
///   model: 'mistral:7b',
///   messages: [
///     {'role': 'system', 'content': 'You are a helpful assistant.'},
///     {'role': 'user', 'content': 'Hello!'},
///   ],
///   numCtx: 8192,
///   onToken: (token) => stdout.write(token),
///   onDone: () => print('\n[done]'),
/// );
/// ```
class OllamaClient {
  /// Base URL for the Ollama REST API.
  final String baseUrl;

  /// HTTP request timeout for non-streaming calls.
  final Duration timeout;

  HttpClient _http;

  /// Creates an [OllamaClient].
  ///
  /// [baseUrl] defaults to `http://localhost:11434`.
  /// [timeout] defaults to 30 seconds for non-streaming endpoints.
  OllamaClient({
    this.baseUrl = 'http://localhost:11434',
    this.timeout = const Duration(seconds: 30),
  }) : _http = HttpClient()
            ..connectionTimeout = const Duration(seconds: 10);

  /// Immediately aborts all in-flight HTTP connections on this client.
  ///
  /// Used by [InferenceWorker.pause] to hard-stop any streaming inference
  /// mid-response. A new [HttpClient] is created so the client stays usable.
  void abortInFlight() {
    _http.close(force: true);
    _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  }

  // -------------------------------------------------------------------------
  // Health check
  // -------------------------------------------------------------------------

  /// Returns `true` when the Ollama server is reachable and responding.
  Future<bool> isHealthy() async {
    try {
      final response = await _get('/');
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Chat streaming
  // -------------------------------------------------------------------------

  /// Streams a chat completion from the `POST /api/chat` endpoint.
  ///
  /// [model]    — Ollama model tag (e.g. `mistral:7b`).
  /// [messages] — Ordered list of `{role, content}` maps.
  /// [numCtx]   — Context window size in tokens.
  /// [onToken]  — Called with each incremental text token as it arrives.
  /// [onDone]   — Called once when generation is complete.
  /// [onError]  — Optional error handler; if omitted, errors are rethrown.
  Future<void> generateStream({
    required String model,
    required List<Map<String, String>> messages,
    required int numCtx,
    required void Function(String token) onToken,
    required void Function() onDone,
    void Function(Object error)? onError,
  }) async {
    try {
      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
        'options': {'num_ctx': numCtx},
      });

      final request = await _postRequest('/api/chat');
      request.add(utf8.encode(body));
      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await _readBody(response);
        throw HttpException(
          'POST /api/chat returned ${response.statusCode}: $errorBody',
        );
      }

      await for (final chunk in response.transform(utf8.decoder)) {
        // Each chunk may contain one or more newline-delimited JSON objects.
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          final Map<String, dynamic> json;
          try {
            json = jsonDecode(trimmed) as Map<String, dynamic>;
          } catch (_) {
            continue; // Skip malformed lines.
          }

          final message = json['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            onToken(content);
          }

          final done = json['done'] as bool? ?? false;
          if (done) {
            onDone();
            return;
          }
        }
      }

      // Stream ended without a `done: true` frame — still call onDone.
      onDone();
    } catch (error) {
      if (onError != null) {
        onError(error);
      } else {
        rethrow;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Model listing
  // -------------------------------------------------------------------------

  /// Returns the list of model names currently installed in Ollama.
  ///
  /// Calls `GET /api/tags` and extracts the `name` field from each entry.
  Future<List<String>> listModels() async {
    final response = await _get('/api/tags');
    final body = await _readBody(response);

    if (response.statusCode != 200) {
      throw HttpException(
        'GET /api/tags returned ${response.statusCode}: $body',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final models = json['models'] as List<dynamic>? ?? [];
    return models
        .cast<Map<String, dynamic>>()
        .map((m) => m['name'] as String)
        .toList();
  }

  // -------------------------------------------------------------------------
  // Model pulling
  // -------------------------------------------------------------------------

  /// Streams download progress for [modelTag] from `POST /api/pull`.
  ///
  /// Yields [ModelPullProgress] events until the model is fully downloaded or
  /// an error occurs.
  ///
  /// ```dart
  /// await for (final progress in client.pullModel('mistral:7b')) {
  ///   print('${(progress.percent * 100).toStringAsFixed(0)}%');
  /// }
  /// ```
  Stream<ModelPullProgress> pullModel(String modelTag) async* {
    final body = jsonEncode({'name': modelTag, 'stream': true});

    final request = await _postRequest('/api/pull');
    request.add(utf8.encode(body));
    final response = await request.close();

    if (response.statusCode != 200) {
      final errorBody = await _readBody(response);
      throw HttpException(
        'POST /api/pull returned ${response.statusCode}: $errorBody',
      );
    }

    // Buffer partial lines across chunks — Ollama streams newline-delimited JSON
    // but a single chunk may arrive mid-line.
    final lineBuffer = StringBuffer();

    await for (final chunk in response.transform(utf8.decoder)) {
      lineBuffer.write(chunk);
      final raw = lineBuffer.toString();
      final lines = raw.split('\n');

      // Keep the last element in the buffer — it may be an incomplete line.
      lineBuffer.clear();
      lineBuffer.write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final Map<String, dynamic> json;
        try {
          json = jsonDecode(trimmed) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        // Ollama sends {"error":"..."} for failures (e.g. network loss,
        // partial download state mismatch). Surface it as an exception.
        final error = json['error'] as String?;
        if (error != null && error.isNotEmpty) {
          throw HttpException('Ollama pull error for $modelTag: $error');
        }

        final status = json['status'] as String? ?? '';
        final completed = (json['completed'] as num?)?.toInt() ?? 0;
        final total = (json['total'] as num?)?.toInt() ?? 0;

        // Ollama signals completion with status == 'success'.
        // It also sends a series of intermediate statuses:
        //   "pulling manifest" → "pulling layer" → "verifying sha256 digest"
        //   → "writing manifest" → "removing any unused layers" → "success"
        final isDone = status == 'success';

        yield ModelPullProgress(
          modelTag: modelTag,
          completed: completed,
          total: total,
          status: status,
          isDone: isDone,
        );

        if (isDone) return;
      }
    }

    // Flush any remaining buffered line (stream closed mid-line is unusual
    // but handle it gracefully — if it parses as success, we're done).
    final remaining = lineBuffer.toString().trim();
    if (remaining.isNotEmpty) {
      try {
        final json = jsonDecode(remaining) as Map<String, dynamic>;
        final error = json['error'] as String?;
        if (error != null && error.isNotEmpty) {
          throw HttpException('Ollama pull error for $modelTag: $error');
        }
        final status = json['status'] as String? ?? '';
        if (status == 'success') {
          yield ModelPullProgress(
            modelTag: modelTag,
            completed: 0,
            total: 0,
            status: status,
            isDone: true,
          );
        }
      } catch (_) {
        // Malformed trailing data — ignore.
      }
    }
  }

  // -------------------------------------------------------------------------
  // Model management
  // -------------------------------------------------------------------------

  /// Asks Ollama to unload [modelTag] from GPU/RAM immediately.
  ///
  /// Sends `POST /api/generate` with `keep_alive: 0`.  Ollama evicts the
  /// model from memory on the next idle cycle.  Errors are silently swallowed
  /// — if the model wasn't loaded this is a no-op.
  Future<void> unloadModel(String modelTag) async {
    try {
      await Future<void>(() async {
        final body = jsonEncode({'model': modelTag, 'keep_alive': 0});
        final request = await _postRequest('/api/generate');
        request.add(utf8.encode(body));
        final response = await request.close();
        await response.drain<void>();
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Not loaded, already gone, or timed out — that's fine.
    }
  }

  /// Deletes [modelTag] from the local Ollama instance via `DELETE /api/delete`.
  ///
  /// Returns `true` if the model was deleted, `false` if it wasn't found.
  /// Throws on other HTTP errors.
  Future<bool> deleteModel(String modelTag) async {
    final uri = Uri.parse('$baseUrl/api/delete');
    final request = await _http.deleteUrl(uri);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({'name': modelTag})));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    throw HttpException(
      'DELETE /api/delete returned ${response.statusCode} for $modelTag',
    );
  }

  // -------------------------------------------------------------------------
  // HTTP helpers
  // -------------------------------------------------------------------------

  Future<HttpClientResponse> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _http.getUrl(uri);
    return request.close();
  }

  Future<HttpClientRequest> _postRequest(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    return request;
  }

  static Future<String> _readBody(HttpClientResponse response) async {
    final buffer = StringBuffer();
    await for (final chunk in response.transform(utf8.decoder)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// Closes the underlying [HttpClient].
  ///
  /// Call this when the client is no longer needed to release resources.
  void close() => _http.close();
}
