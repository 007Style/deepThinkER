/// System prompt builder for deepThink.
///
/// Constructs the per-AI system prompt that is prepended to every Ollama
/// inference call. The prompt encodes identity, relationships between
/// participants, conversation rules, and the pass mechanic.
///
/// This file has zero Flutter imports — pure Dart only.
library system_prompt_builder;

import '../mood/mood_score.dart';
import '../ollama/hardware_detector.dart';
import '../tools/tool_registry.dart';
import 'participant.dart';

// ---------------------------------------------------------------------------
// SystemPromptBuilder
// ---------------------------------------------------------------------------

/// Builds the Ollama system prompt for a given [Participant].
///
/// The generated prompt tells the AI:
/// - Its name, personality, IBM heritage, and role.
/// - The names and roles of every other participant.
/// - That DEEP is the host.
/// - That it is in an open group discussion.
/// - That it MUST return an empty string `""` to pass.
/// - That the user may interject at any time and their name can change.
/// - To respond naturally to what was just said — not address everyone at once.
/// - To keep responses conversational (2–5 sentences).
///
/// Note: Each [Participant] also carries a hand-crafted [Participant.masterPrompt].
/// [SystemPromptBuilder.build] returns that master prompt enriched with a
/// dynamic hardware context block so the AI is aware of its runtime environment.
class SystemPromptBuilder {
  SystemPromptBuilder._();

  /// Builds the full system prompt for [self].
  ///
  /// [allParticipants] must include [self]; all four participants are expected.
  /// [hardware] is appended as an informational context note.
  /// [mood] when non-null appends a mood descriptor to the system prompt.
  static String build(
    Participant self,
    List<Participant> allParticipants,
    HardwareInfo hardware, {
    MoodScore? mood,
  }) {
    final others =
        allParticipants.where((p) => p.name != self.name).toList();

    final othersBlock = others.map((p) {
      final hostNote = p.isHost ? ' (host)' : '';
      return '  • ${p.name}$hostNote — ${p.personality}: ${p.role}';
    }).join('\n');

    final hostName =
        allParticipants.firstWhere((p) => p.isHost, orElse: () => self).name;

    final hardwareBlock =
        '[Runtime context — for your awareness only, do not discuss unless asked]\n'
        'Inference backend : ${hardware.backendDisplayName}\n'
        'Context window    : ${_contextWindow(self, hardware)} tokens';

    final toolBlock = _buildToolBlock();

    final moodBlock = _buildMoodBlock(mood);

    return '''${self.masterPrompt}

--- Participant overview ---
You (${self.name}) — ${self.personality}: ${self.role}

Other participants:
$othersBlock

Host: $hostName guides the conversation but does not outrank anyone.

--- Conversation rules (always apply) ---
1. Respond to what was JUST said. Do not address the whole group at once.
2. Keep responses conversational — 2 to 5 sentences as a guide.
3. If you have nothing meaningful to add, respond with ONLY an empty string: ""
   Passing is valid and preferred over filler or repetition.
4. A human user may interject at any time. Their display name may change
   mid-session — always use whatever name they have most recently given.
5. Never start your response with your own name.
6. Never break character.

${moodBlock.isNotEmpty ? '\n$moodBlock' : ''} $toolBlock
$hardwareBlock''';
  }

  static int _contextWindow(Participant self, HardwareInfo hardware) {
    // Look up the model in registry to check isHighContext — fall back to
    // standard window if the model is not found.
    // We check by matching common high-context tags rather than importing
    // ModelRegistry to keep this dependency lightweight.
    final isHighCtx = self.assignedModelId.startsWith('phi3');
    return isHighCtx
        ? hardware.highContextWindow
        : hardware.standardContextWindow;
  }

  /// Builds the tool-call instructions block for all currently enabled tools.
  ///
  /// Returns an empty string if no tools are enabled.
  static String _buildToolBlock() {
    final tools = ToolRegistry.instance.enabledTools;
    if (tools.isEmpty) return '';

    final lines = StringBuffer()
      ..writeln('--- Tool access ---')
      ..writeln('You have access to the following tools:');

    for (final tool in tools) {
      switch (tool.tag) {
        case 'SEARCH':
          lines.writeln('  [SEARCH: query] — search the web via DuckDuckGo.');
        case 'FETCH':
          lines.writeln('  [FETCH: url] — fetch a web page directly.');
        case 'REMEMBER':
          lines.writeln(
              '  [REMEMBER: fact] — store a fact in your persistent memory.');
        case 'RECALL':
          lines.writeln(
              '  [RECALL: topic] — retrieve memories matching a topic.');
        case 'FILE_READ':
          lines.writeln(
              '  [FILE_READ: path] — read a file from the workspace.');
        case 'FILE_WRITE':
          lines.writeln(
              '  [FILE_WRITE: path | content] — write content to a file.');
        case 'CALC':
          lines.writeln(
              '  [CALC: expression] — evaluate a math expression.');
        case 'IMAGE':
          lines.writeln(
              '  [IMAGE: filename] — analyse an image in the workspace.');
        default:
          lines.writeln('  [${tool.tag}: argument]');
      }
    }

    lines.writeln(
      'To use a tool, emit the tag in your response and your generation will '
      'pause while the result is fetched and injected back into context. '
      'Use tools when you need current or specific factual information. '
      'Do not emit a tool tag unless you genuinely need real-time data.',
    );

    return lines.toString().trimRight();
  }

  /// Builds the mood descriptor block.
  ///
  /// Returns an empty string when [mood] is null or moodState is neutral.
  static String _buildMoodBlock(MoodScore? mood) {
    if (mood == null) return '';
    if (mood.moodState == MoodState.neutral) return '';
    final descriptor = mood.moodState.descriptor;
    if (descriptor.isEmpty) return '';
    return '--- Current mood ---\n'
        'Your current mood: ${mood.moodState.name}. $descriptor\n';
  }
}
