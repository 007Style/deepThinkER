/// System prompt builder for deepThink.
///
/// Constructs the per-AI system prompt that is prepended to every Ollama
/// inference call. The prompt encodes identity, relationships between
/// participants, conversation rules, and the pass mechanic.
///
/// This file has zero Flutter imports — pure Dart only.
library system_prompt_builder;

import '../ollama/hardware_detector.dart';
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
  static String build(
    Participant self,
    List<Participant> allParticipants,
    HardwareInfo hardware,
  ) {
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
}
