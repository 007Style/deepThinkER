/// InjectionGuard — scans text for prompt-injection patterns matching
/// registered ToolRegistry tags and escapes them.
///
/// This file has zero Flutter imports — pure Dart only.
library injection_guard;

import '../tools/tool_registry.dart';

// ---------------------------------------------------------------------------
// InjectionGuard
// ---------------------------------------------------------------------------

/// Scans a string for `[TAG: ...]` patterns where TAG matches any registered
/// [ToolRegistry] tag, and escapes them to `(TAG: ...)` to prevent prompt
/// injection via web or file content.
class InjectionGuard {
  final ToolRegistry _registry;

  /// Creates an [InjectionGuard] backed by [registry].
  InjectionGuard(this._registry);

  /// Singleton instance backed by [ToolRegistry.instance].
  static final InjectionGuard instance = InjectionGuard(ToolRegistry.instance);

  /// Sanitises [text] by escaping any `[TAG: ...]` patterns where TAG is a
  /// registered tool tag.
  ///
  /// Matched patterns are replaced with `(TAG: ...)` so they are no longer
  /// parsed as tool calls by [ToolCallParser].
  ///
  /// Returns the sanitised string. If no injection patterns are found, returns
  /// [text] unchanged.
  String sanitise(String text) {
    var result = text;
    bool detected = false;
    for (final tool in _registry.allTools) {
      final tag = RegExp.escape(tool.tag.toUpperCase());
      final pattern = RegExp(r'\[' + tag + r'\s*:[^\]]*\]', caseSensitive: false);
      if (pattern.hasMatch(result)) {
        detected = true;
        result = result.replaceAllMapped(pattern, (m) {
          final inner = m[0]!.substring(1, m[0]!.length - 1);
          return '($inner)';
        });
      }
    }
    return detected ? result : text;
  }

  /// Returns `true` if [text] contains any injection patterns.
  bool containsInjection(String text) {
    for (final tool in _registry.allTools) {
      final tag = RegExp.escape(tool.tag.toUpperCase());
      final pattern = RegExp(r'\[' + tag + r'\s*:[^\]]*\]', caseSensitive: false);
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }
}
