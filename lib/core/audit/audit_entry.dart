// AuditEntry — value object for a single tool-call audit record.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:convert';

// ---------------------------------------------------------------------------
// AuditEntry
// ---------------------------------------------------------------------------

/// Records one tool invocation attempt in the persistent audit log.
class AuditEntry {
  final String id;
  final String sessionName;
  final String characterName;
  final String toolTag;
  final String argument;
  final DateTime timestamp;
  final bool wasRateLimited;
  final bool wasDisabled;

  /// Approximate number of bytes in the tool result output.
  final int responseBytes;

  /// Whether a prompt injection attempt was detected in the tool output.
  final bool injectionAttemptDetected;

  AuditEntry({
    required this.id,
    required this.sessionName,
    required this.characterName,
    required this.toolTag,
    required this.argument,
    required this.timestamp,
    required this.wasRateLimited,
    required this.wasDisabled,
    required this.responseBytes,
    this.injectionAttemptDetected = false,
  });

  factory AuditEntry.create({
    required String sessionName,
    required String characterName,
    required String toolTag,
    required String argument,
    required bool wasRateLimited,
    required bool wasDisabled,
    required int responseBytes,
    bool injectionAttemptDetected = false,
  }) {
    return AuditEntry(
      id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      sessionName: sessionName,
      characterName: characterName,
      toolTag: toolTag,
      argument: argument,
      timestamp: DateTime.now().toUtc(),
      wasRateLimited: wasRateLimited,
      wasDisabled: wasDisabled,
      responseBytes: responseBytes,
      injectionAttemptDetected: injectionAttemptDetected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionName': sessionName,
        'characterName': characterName,
        'toolTag': toolTag,
        'argument': argument,
        'timestamp': timestamp.toIso8601String(),
        'wasRateLimited': wasRateLimited,
        'wasDisabled': wasDisabled,
        'responseBytes': responseBytes,
        'injectionAttemptDetected': injectionAttemptDetected,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String? ?? '',
      sessionName: json['sessionName'] as String? ?? '',
      characterName: json['characterName'] as String? ?? '',
      toolTag: json['toolTag'] as String? ?? '',
      argument: json['argument'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      wasRateLimited: json['wasRateLimited'] as bool? ?? false,
      wasDisabled: json['wasDisabled'] as bool? ?? false,
      responseBytes: json['responseBytes'] as int? ?? 0,
      injectionAttemptDetected:
          json['injectionAttemptDetected'] as bool? ?? false,
    );
  }

  String toNdJsonLine() => json.encode(toJson());
}
