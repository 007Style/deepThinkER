import 'package:test/test.dart';
import 'package:deep_think_er/core/tools/tool_registry.dart';
import 'package:deep_think_er/core/tools/agent_tool.dart';
import 'package:deep_think_er/core/trust/trust_score.dart';

// ── Minimal stub tool for testing ──────────────────────────────────────────

class _StubTool implements AgentTool {
  @override
  final String tag;
  @override
  final bool enabled;
  @override
  final String disabledMessage;
  @override
  final bool requiresTrust = false;
  @override
  final TrustTier minimumTrust = TrustTier.low;

  const _StubTool({
    required this.tag,
    this.enabled = true,
    this.disabledMessage = 'disabled',
  });

  @override
  Future<ToolResult> execute(String argument, String characterName) async {
    return ToolResult.success(
      tag: tag,
      output: 'stub:$argument',
      characterName: characterName,
    );
  }
}

void main() {
  group('ToolRegistry', () {
    // Use a fresh registry for each test to avoid pollution from singletons.
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry.instanceForTesting();
    });

    test('resolve returns null for unknown tag', () {
      expect(registry.resolve('UNKNOWN'), isNull);
    });

    test('register and resolve by exact tag', () {
      registry.register(const _StubTool(tag: 'SEARCH'));
      expect(registry.resolve('SEARCH'), isNotNull);
    });

    test('resolve is case-insensitive', () {
      registry.register(const _StubTool(tag: 'SEARCH'));
      expect(registry.resolve('search'), isNotNull);
      expect(registry.resolve('Search'), isNotNull);
    });

    test('registering same tag replaces previous tool', () {
      registry.register(const _StubTool(tag: 'CALC', disabledMessage: 'v1'));
      registry.register(const _StubTool(tag: 'CALC', disabledMessage: 'v2'));
      expect(registry.resolve('CALC')!.disabledMessage, 'v2');
    });

    test('allTools returns all registered tools', () {
      registry.register(const _StubTool(tag: 'A'));
      registry.register(const _StubTool(tag: 'B'));
      expect(registry.allTools, hasLength(2));
    });

    test('enabledTools excludes disabled tools', () {
      registry.register(const _StubTool(tag: 'ENABLED', enabled: true));
      registry.register(const _StubTool(tag: 'DISABLED', enabled: false));
      final enabled = registry.enabledTools;
      expect(enabled.length, 1);
      expect(enabled.first.tag, 'ENABLED');
    });
  });
}
