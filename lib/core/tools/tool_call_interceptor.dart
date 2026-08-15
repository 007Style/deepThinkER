// ToolCallInterceptor — scans the LLM response buffer for tool-call tags
// and executes the first matching tool found.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:async';

import '../audit/audit_log.dart';
import '../network/rate_limiter.dart';
import '../security/content_filter.dart';
import '../security/injection_guard.dart';
import '../trust/trust_manager.dart';
import 'agent_tool.dart';
import 'tool_call_parser.dart';
import 'tool_registry.dart';

// ---------------------------------------------------------------------------
// ToolCallEvent
// ---------------------------------------------------------------------------

/// Emitted when a tool-call tag was found and processed (allowed or denied).
class ToolCallEvent {
  final String characterName;
  final String tag;
  final String argument;
  final ToolResult result;
  final DateTime timestamp;

  ToolCallEvent({
    required this.characterName,
    required this.tag,
    required this.argument,
    required this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'ToolCallEvent($characterName $tag="$argument" '
      'rateLimited=${result.wasRateLimited})';
}

// ---------------------------------------------------------------------------
// InterceptResult
// ---------------------------------------------------------------------------

/// The result of a [ToolCallInterceptor.process] call.
class InterceptResult {
  /// The token buffer with any matched tag replaced by the tool output.
  final String modifiedBuffer;

  /// The event produced by processing the tag, or `null` if no tag was found.
  final ToolCallEvent? event;

  const InterceptResult({
    required this.modifiedBuffer,
    this.event,
  });
}

// ---------------------------------------------------------------------------
// ToolCallInterceptor
// ---------------------------------------------------------------------------

/// Processes a token buffer looking for the first registered tool-call tag.
///
/// Only one tag is processed per [process] call.  The caller (inference
/// worker) should call [process] after accumulating enough tokens that a
/// full `[TAG: ...]` pattern could have completed.
class ToolCallInterceptor {
  final ToolRegistry registry;
  final RateLimiter rateLimiter;
  final TrustManager trustManager;

  /// Session name used to tag audit entries.  Can be updated each session.
  String sessionName;

  /// Optional content filter — when provided, injected content is sanitised
  /// through [ContentFilter.sanitise] before being placed in the LLM context.
  final ContentFilter? contentFilter;

  final StreamController<ToolCallEvent> _eventController =
      StreamController<ToolCallEvent>.broadcast();

  ToolCallInterceptor({
    required this.registry,
    required this.rateLimiter,
    required this.trustManager,
    this.sessionName = '',
    this.contentFilter,
  });

  /// The most recent [ToolCallEvent] produced by [process], or `null`.
  /// Reset to `null` at the start of each [process] call.
  ToolCallEvent? _lastEvent;
  ToolCallEvent? get lastEvent => _lastEvent;

  /// Broadcast stream emitting a [ToolCallEvent] for each intercepted tag.
  Stream<ToolCallEvent> get eventStream => _eventController.stream;

  /// Scans [tokenBuffer] for tool-call tags, executes the first match,
  /// and returns the modified buffer with the tag replaced by the result.
  ///
  /// Returns the buffer unchanged with [InterceptResult.event] == `null`
  /// if no known tag is present.
  Future<InterceptResult> process(
    String tokenBuffer,
    String characterName,
  ) async {
    _lastEvent = null; // Reset for this call.
    final calls = ToolCallParser.parse(tokenBuffer);
    if (calls.isEmpty) {
      return InterceptResult(modifiedBuffer: tokenBuffer);
    }

    // Process only the first tag.
    for (final call in calls) {
      final tool = registry.resolve(call.tag);
      if (tool == null) continue; // Unknown tag — skip.

      ToolResult result;

      if (!tool.enabled) {
        result = ToolResult.disabled(
          tag: call.tag,
          reason: tool.disabledMessage,
          characterName: characterName,
        );
      } else if (tool.requiresTrust) {
        // Check trust tier and rate limit.
        final tier = rateLimiter.currentTier(characterName);
        if (_tierBelow(tier, tool.minimumTrust)) {
          result = ToolResult.disabled(
            tag: call.tag,
            reason:
                'Requires ${tool.minimumTrust.label} trust tier or higher.',
            characterName: characterName,
          );
        } else {
          final rateResult = rateLimiter.request(characterName, tier);
          if (!rateResult.allowed) {
            result = ToolResult.rateLimited(
              tag: call.tag,
              reason: rateResult.reason,
              characterName: characterName,
            );
          } else {
            result = await tool.execute(call.argument, characterName);
          }
        }
      } else {
        result = await tool.execute(call.argument, characterName);
      }

      // Sanitise tool output before injecting into LLM context.
      final guard = InjectionGuard(registry);
      final injectionDetected = guard.containsInjection(result.output);
      var sanitisedOutput = guard.sanitise(result.output);
      if (contentFilter != null) {
        sanitisedOutput = contentFilter!.sanitise(sanitisedOutput);
      }

      // Replace the matched tag in the buffer with the injection marker.
      final injectionText =
          '\n[WEB_RESULT for $characterName]:\n$sanitisedOutput\n';
      final modified = tokenBuffer.replaceRange(
        call.startIndex,
        call.endIndex,
        injectionText,
      );

      final event = ToolCallEvent(
        characterName: characterName,
        tag: call.tag,
        argument: call.argument,
        result: result,
      );

      _lastEvent = event;

      if (!_eventController.isClosed) {
        _eventController.add(event);
      }

      // Record in audit log (fire-and-forget).
      AuditLog.instance.record(
        AuditEntry.create(
          sessionName: sessionName,
          characterName: characterName,
          toolTag: call.tag,
          argument: call.argument,
          wasRateLimited: result.wasRateLimited,
          wasDisabled: result.wasDisabled,
          responseBytes: result.output.length,
          injectionAttemptDetected: injectionDetected,
        ),
      ).ignore();

      return InterceptResult(modifiedBuffer: modified, event: event);
    }

    // All tags were unknown — return unchanged.
    return InterceptResult(modifiedBuffer: tokenBuffer);
  }

  /// Closes the event stream controller.
  Future<void> dispose() => _eventController.close();

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Returns `true` if [actual] is strictly below [required] in the tier
  /// ordering: low < mid < high.
  static bool _tierBelow(TrustTier actual, TrustTier required) {
    const order = [TrustTier.low, TrustTier.mid, TrustTier.high];
    return order.indexOf(actual) < order.indexOf(required);
  }
}
