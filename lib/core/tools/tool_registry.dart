/// Singleton registry of all AgentTool instances in deepThinkER.
///
/// Tools are registered at app startup in main.dart and resolved by the
/// ToolCallInterceptor during inference.
///
/// This file has zero Flutter imports — pure Dart only.
library tool_registry;

import 'agent_tool.dart';

// ---------------------------------------------------------------------------
// ToolRegistry
// ---------------------------------------------------------------------------

/// Central registry for all [AgentTool] implementations.
///
/// Access via [ToolRegistry.instance].
///
/// ```dart
/// ToolRegistry.instance.register(NetworkSearchTool(fetcher));
/// final tool = ToolRegistry.instance.resolve('SEARCH');
/// ```
class ToolRegistry {
  ToolRegistry._();

  static final ToolRegistry instance = ToolRegistry._();

  final Map<String, AgentTool> _tools = {};

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Registers [tool] in the registry.
  ///
  /// The tool's [AgentTool.tag] is normalised to uppercase so lookups
  /// are always case-insensitive.
  ///
  /// Registering a tag that already exists replaces the previous tool.
  void register(AgentTool tool) {
    _tools[tool.tag.toUpperCase()] = tool;
  }

  /// Resolves a tool by [tag] (case-insensitive).
  ///
  /// Returns `null` if no tool is registered for [tag].
  AgentTool? resolve(String tag) => _tools[tag.toUpperCase()];

  /// All registered tools, enabled or not.
  List<AgentTool> get allTools => List.unmodifiable(_tools.values);

  /// Only the tools whose [AgentTool.enabled] flag is `true`.
  List<AgentTool> get enabledTools =>
      _tools.values.where((t) => t.enabled).toList();
}
