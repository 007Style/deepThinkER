// In-app documentation viewer for deepThink.
//
// Displays the full README, ARCHITECTURE, and DEVELOPMENT docs
// as scrollable Markdown-rendered content inside three tabs.
// The content is embedded directly as const strings so it is
// always available offline without any file I/O.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// DocsScreen
// ---------------------------------------------------------------------------

/// Full in-app documentation — three tabbed sections.
class DocsScreen extends StatefulWidget {
  /// Which tab to open first (0=User Guide, 1=Architecture, 2=Development).
  final int initialTab;

  const DocsScreen({this.initialTab = 0, super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _titles = ['User Guide', 'Architecture', 'Development'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _titles.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                // Back button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Back',
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                // Title
                const Text(
                  'deepThinkER Docs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                // Copy button
                IconButton(
                  onPressed: () => _copyCurrentTab(context),
                  icon: const Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.textSecondary),
                  tooltip: 'Copy to clipboard',
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ],
            ),
          ),
          // ── Tab bar ───────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 13),
              tabs: _titles
                  .map((t) => Tab(text: t, height: 38))
                  .toList(),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _DocTab(content: _kUserGuide),
                _DocTab(content: _kArchitecture),
                _DocTab(content: _kDevelopment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyCurrentTab(BuildContext context) {
    final content = [_kUserGuide, _kArchitecture, _kDevelopment][_tabs.index];
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${_titles[_tabs.index]} copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DocTab — scrollable markdown-ish renderer
// ---------------------------------------------------------------------------

class _DocTab extends StatelessWidget {
  final String content;
  const _DocTab({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        itemCount: lines.length,
        itemBuilder: (ctx, i) => _renderLine(lines[i]),
      ),
    );
  }

  Widget _renderLine(String line) {
    // H1
    if (line.startsWith('# ') && !line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          line.substring(2),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    // H2
    if (line.startsWith('## ') && !line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.substring(3),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(height: 1, color: AppColors.border),
          ],
        ),
      );
    }
    // H3
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(
          line.substring(4),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    // H4
    if (line.startsWith('#### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(
          line.substring(5),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    // Code block fence — just use monospace styling
    if (line.startsWith('```')) {
      return const SizedBox(height: 2);
    }
    // Horizontal rule
    if (line == '---') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(height: 1, color: AppColors.border),
      );
    }
    // Table row (contains |)
    if (line.contains('|') && line.trim().startsWith('|')) {
      // Separator row
      if (line.contains('---')) return const SizedBox(height: 0);
      final cells = line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      final isHeader = cells.any((c) => c.isNotEmpty) &&
          !lines_contain_separator_after(line);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: cells.map((cell) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isHeader
                      ? AppColors.surface
                      : AppColors.background,
                  border: Border.all(
                      color: AppColors.border, width: 0.5),
                ),
                child: Text(
                  cell,
                  style: TextStyle(
                    fontSize: 11,
                    color: isHeader
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: isHeader
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontFamily: cell.startsWith('`') ? 'monospace' : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    // Bullet list
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5, right: 8),
              child: CircleAvatar(
                  radius: 2.5, backgroundColor: AppColors.textSecondary),
            ),
            Expanded(child: _inlineText(line.substring(2))),
          ],
        ),
      );
    }
    // Numbered list
    if (RegExp(r'^\d+\. ').hasMatch(line)) {
      final dot = line.indexOf('. ');
      final num = line.substring(0, dot + 1);
      final rest = line.substring(dot + 2);
      return Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(child: _inlineText(rest)),
          ],
        ),
      );
    }
    // Indented code (4 spaces or tab)
    if (line.startsWith('    ') || line.startsWith('\t')) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        color: const Color(0xFF0d1117),
        child: Text(
          line.replaceFirst(RegExp(r'^\t|^    '), ''),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Color(0xFF4a9eff),
          ),
        ),
      );
    }
    // Blockquote
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(
              left: BorderSide(color: AppColors.accent, width: 3)),
        ),
        child: _inlineText(line.substring(2),
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5)),
      );
    }
    // Empty line
    if (line.trim().isEmpty) return const SizedBox(height: 6);

    // Normal paragraph
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _inlineText(line),
    );
  }

  // Naive helper — tables don't have a separator after headers for our purposes
  bool lines_contain_separator_after(String line) => false;

  Widget _inlineText(String text, {TextStyle? style}) {
    // Strip bold/italic markdown for plain display
    final clean = text
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m.group(1)!)
        .replaceAllMapped(
            RegExp(r'\[(.+?)\]\(.+?\)'), (m) => m.group(1)!);
    return Text(
      clean,
      style: style ??
          const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            height: 1.6,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Embedded documentation content
// ---------------------------------------------------------------------------

const _kUserGuide = r'''
# deepThinkER — User Guide

deepThinkER puts four AI personalities into a shared conversation and lets them debate,
challenge, and build on each other's ideas — in parallel, in real time, right on your
machine. No cloud. No accounts. No monthly bill.

## The Characters

WATSON (gemma2:9b) — The Analyst
Precise. Methodical. Breaks complexity into clarity. Named after IBM's legendary
Jeopardy-winning AI.

DEEP (phi3:14b) — The Host / Philosopher
Thoughtful. Provocative. Opens and guides the conversation. A nod to Deep Blue —
the machine that in 1997 beat Garry Kasparov.

NOVA (llama3:8b) — The Visionary
Creative. Expressive. Connects dots no one else sees.

SAGE (mistral:7b) — The Challenger
Sharp. Contrarian. Pushes back, sharpens ideas, refuses easy answers.

## First Launch Flow

1. Splash screen — Ollama starts, hardware detected, models checked
2. Welcome screen — shows your system specs and model status
3. Download screen — ~22.5 GB one-time download (resumable)
4. Config screen — choose models, name your session, see RAM allocation
5. Main screen — press Start and the conversation begins

## Using the Main Screen

- Press the Start button (top centre) to begin a session
- DEEP opens the conversation with a thought-provoking topic
- All four AIs respond in parallel with a natural stagger
- Type anything in the input bar and press Enter to interject
- All four AIs MUST respond to your messages — they cannot pass on user input
- Press Stop to end the session

## User Rename Easter Egg

Tell any AI your name mid-conversation:
- "Call me Alex"
- "My name is Jordan"
- "You can call me Sam"

Your display name in the UI updates automatically (max 20 characters).

## Session Names

Every session gets a fun lowerCamelCase name generated automatically
(e.g. thetaByte, thorKitten, neonSage). You can type your own name in
the Config screen or roll the dice for a new one.

## Memory Requirements

The full model stack needs ~22.5 GB of free RAM:

- mistral:7b     4.1 GB
- llama3:8b      4.7 GB
- gemma2:9b      5.5 GB
- phi3:14b       8.2 GB
- Total:        22.5 GB

If you don't have enough free RAM, deepThinkER shows a live Resource Gate
that monitors your system every 2 seconds and auto-starts provisioning
the moment you free enough memory.

## If Downloads Fail

If you see "Ollama pull error … EOF", delete partial blob files and retry:

    rm ~/.ollama/models/blobs/*-partial*

Then tap Retry in the download screen.

## Sessions & Logs

Every session is saved to:
  ~/Documents/deepThinkER/sessions/

Each session produces an NDJSON file (one JSON message per line) and a
.meta.json file with session metadata.

## Context Window Tiers

Context windows scale automatically with your RAM:

| RAM   | Standard models | phi3:14b   |
|-------|----------------|-----------|
| 32 GB | 8 192 tokens   | 32 768    |
| 48 GB | 16 384 tokens  | 65 536    |
| 64 GB | 32 768 tokens  | 131 072   |
| 128 GB| 65 536 tokens  | 131 072   |

When an AI hits 90% of its context window, it automatically resets using
the last 2 messages per participant as a seed — the conversation continues
without a hard break.

## Help Menu

The ? button (top right) opens:
- User Guide (this screen)
- Architecture — technical design documentation
- Development Guide — how to build, test, and release
- Model Downloads — manual installation instructions
- About deepThinkER — Extended Reach history, credits, and more
''';

const _kArchitecture = r'''
# deepThinkER — Architecture

Version: v1.0.2
Platform: macOS (primary) · Windows (self-compile)
Stack: Flutter / Dart · Ollama v0.32.9 · four local LLMs

## Philosophy & Guiding Principles

### Zero-Flutter Core
lib/core/ contains ZERO Flutter imports. Every class is pure Dart.
This means the entire conversation engine, Ollama client, hardware
detector, resource monitor, and session management layer can be lifted
into a native SwiftUI or WinUI 3 shell without touching a line of logic.

### Bundled Runtime
The user never installs Ollama. The complete Ollama v0.32.9 runtime is
physically embedded inside the .app bundle at build time by an Xcode
shell-script build phase. Distribution is a single DMG.

### Parallel Inference
All four AI participants run their inference concurrently — never
round-robin. Each has its own InferenceWorker subscribing to the shared
ConversationLog. A random jitter (200–800 ms) staggers their responses.

### Pass Mechanic
AIs can pass by returning an empty string. User messages always override
this — the forceRespond flag appends a system reminder that the human
must receive a reply.

### Offline After Setup
After the one-time model download (~22.5 GB), deepThinkER runs 100% offline.
No telemetry. No cloud calls. No accounts.

## Layer Breakdown

### Core Layer (lib/core/) — Pure Dart

ollama/
- model_registry.dart     Four models with RAM footprints and context tiers
- hardware_detector.dart  Total + free RAM, GPU backend (Metal/CUDA/ROCm/CPU)
- ollama_launcher.dart    Resolves bundled binary, spawns ollama serve
- ollama_client.dart      HTTP: generateStream, listModels, pullModel
- model_manager.dart      checkModels(), downloadModel() with progress
- model_status_info.dart  Barrel re-export

conversation/
- message.dart            Immutable: participantName, content, isUser, isPass, UUID
- conversation_log.dart   Append-only log, broadcast messageStream
- participant.dart        Character definition + Participant.defaults()
- system_prompt_builder.dart  Builds system prompt per AI
- inference_worker.dart   Per-AI engine: jitter, inference, pass, forceRespond
- conversation_engine.dart    Orchestrator: workers, kickoff, user injection
- user_name_detector.dart     Regex rename detection

context/
- context_manager.dart    Token tracking, 90% reset threshold, seed building

session/
- name_generator.dart     lowerCamelCase session names
- session.dart            Immutable session record, JSON serialisable
- app_stats.dart          In-memory counters
- session_manager.dart    Creates sessions, writes NDJSON logs

system/
- resource_monitor.dart   Polls free RAM + top processes every 2s

### UI Layer (lib/ui/) — Flutter

Screens:
- welcome_screen.dart     Greeting + model status + free RAM + download CTA
- resource_gate_screen.dart  Live RAM gauge, process list, auto-provision
- first_launch_screen.dart   Model download progress, cancel button
- startup_config_screen.dart Per-character config, session name, RAM total
- main_screen.dart        2x2 quadrant grid, user input, top bar, status band
- about_screen.dart       Animated about — IBM history, credits, stats
- docs_screen.dart        This in-app documentation viewer
- model_help_screen.dart  Manual ollama pull instructions

## Startup Flow

1. OllamaLauncher.start()
   - Resolve bundled binary path from Platform.resolvedExecutable
   - chmod +x binary + helpers
   - Process.start('ollama', ['serve'], OLLAMA_KEEP_ALIVE=-1)
   - Poll isRunning() up to 15 seconds

2. HardwareDetector.detect()
   - totalRamGb  via sysctl hw.memsize
   - freeRamGb   via vm_stat (free+inactive+speculative pages x page size)
   - backend     via uname -m (arm64 = appleMetal)

3. ModelManager.checkModels()
   - GET /api/tags → cross-reference against ModelRegistry.all

4. Route:
   - error            → _ErrorScreen
   - freeRamGb < 24   → ResourceGateScreen
   - else             → WelcomeScreen → FirstLaunchScreen or StartupConfigScreen

## Conversation Engine

ConversationEngine owns:
- One shared ConversationLog
- One ContextManager
- Four InferenceWorkers

Each InferenceWorker:
- Subscribes to ConversationLog.messageStream
- Ignores own messages (no self-loops)
- On new message: schedules response with 200–800ms jitter
- If message.isUser: forceRespond=true (cannot pass)
- Calls OllamaClient.generateStream, emits InferenceEvent tokens
- Appends completed Message to log

User message flow:
User types → ConversationEngine.injectUserMessage()
→ ConversationLog.append(isUser: true)
→ All 4 workers see it on messageStream
→ forceRespond=true → [System: you MUST respond] appended to payload
→ Each AI responds within 200–800ms jitter

## Context Window Management

ContextManager tracks estimated token usage per participant
(characters / 4 approximation).

At 90% capacity: buildResetSeed() returns last 2 non-pass messages
per participant in chronological order (max 10 total). Worker resets
counter and re-records seed, maintaining continuity.

## Ollama Integration

Binary path (macOS):
  <app>.app/Contents/MacOS/deepThinkER → ../../Resources/ollama/ollama

Environment on spawn:
  OLLAMA_KEEP_ALIVE = -1        (keep all models in VRAM indefinitely)
  OLLAMA_RUNNERS_DIR = .../ollama/  (find llama-server + llama-quantize)

Pull resumption note:
  Ollama v0.32.x cannot resume from -partial- blob files left by an
  interrupted download. Fix: rm ~/.ollama/models/blobs/*-partial*

## Key Design Decisions

Why ProcessStartMode.normal for Ollama?
  Lets us forward Ollama logs to Flutter console for diagnostics.

Why disable App Sandbox?
  Process.start() is completely blocked inside a sandboxed macOS app.
  deepThinkER is distributed outside the Mac App Store (direct DMG).

Why OLLAMA_KEEP_ALIVE=-1?
  All four models must remain loaded in VRAM simultaneously for instant
  parallel inference. Default 5-minute keep-alive would unload models
  between turns, requiring 30-60s reload times.

Why freeRamGb instead of totalRamGb?
  On a 64 GB machine you might have 45 GB consumed by other processes.
  Using total RAM would always say "fine" — but Ollama would swap and crash.
''';

const _kDevelopment = r'''
# deepThinkER — Development Guide

Everything you need to build, run, test, and release deepThinkER from source.

## Prerequisites (macOS)

| Tool       | Version  | Install                             |
|------------|----------|-------------------------------------|
| Flutter    | 3.x      | brew install --cask flutter         |
| Xcode      | 15+      | Mac App Store                       |
| Git LFS    | any      | brew install git-lfs                |
| CocoaPods  | 1.14+    | sudo gem install cocoapods          |
| gh CLI     | any      | brew install gh                     |

Enable macOS desktop target once:
    flutter config --enable-macos-desktop

## Clone & Setup

    git clone https://github.com/007Style/deepThinkER.git
    cd deepThinkER
    git lfs pull
    flutter pub get
    cd macos && pod install && cd ..
    flutter doctor

Git LFS objects: two Metal shader files in macos/Runner/ollama/
  default.metallib           ~127 MB
  default-flash-attn.metallib  ~158 MB

Without git lfs pull, Ollama will run but without GPU acceleration.

## Running Locally

Debug run (hot-reload):
    flutter run -d macos

Direct launch (after first build):
    open build/macos/Build/Products/Debug/deepThinkER.app

Note: "Failed to foreground app; open returned 1" in the terminal is a
Flutter DevTools quirk — the app is running fine.

## Running Tests

    flutter test                              # all 132 tests
    flutter test --reporter expanded          # verbose output
    flutter analyze                           # zero warnings required

Test coverage:
- ConversationLog, Message, Participant, SystemPromptBuilder
- UserNameDetector, ContextManager, ModelRegistry
- HardwareDetector, ModelPullProgress, NameGenerator
- AppStats, Session, widget smoke test

## Making a Release

One command builds the DMG and creates a GitHub Release:

    ./scripts/release.sh 1.0.3
    ./scripts/release.sh 1.0.3 --draft     # review before publishing

The script:
1. Runs flutter test (fails fast if broken)
2. flutter build macos --release
3. Packages .app into .dmg via create-dmg
4. Creates and pushes git tag v1.0.3
5. Creates GitHub Release and uploads the DMG

## Project Structure

    lib/
    ├── core/           Pure Dart — ZERO Flutter imports
    │   ├── context/    Context window management
    │   ├── conversation/   Engine, workers, log, prompts
    │   ├── ollama/     Launcher, client, registry, hardware
    │   └── system/     Resource monitor
    └── ui/             Flutter UI
        ├── about/      Neural background, wandering characters
        ├── avatars/    Plugin avatar system + energy orb
        ├── quadrants/  AI quadrant grid
        ├── screens/    All full-screen views
        └── widgets/    Shared widgets + theme

## Adding a New AI Character

1. Add ModelInfo to lib/core/ollama/model_registry.dart
2. Add Participant to lib/core/conversation/participant.dart
3. Add orb colour to lib/ui/avatars/energy_orb/orb_config.dart
4. Update _kStackGb in resource_gate_screen.dart
5. Update the quadrant grid if adding a 5th character

## Adding a New Avatar Type

1. Create lib/ui/avatars/my_avatar/ with your widget
2. Register in lib/ui/avatars/avatar_registry.dart:
   register('myAvatar', (state, name, size) => MyAvatarWidget(...));

## Updating Bundled Ollama

1. Download new runtime from github.com/ollama/ollama/releases
2. Replace files in macos/Runner/ollama/
3. Commit large .metallib files via Git LFS:
   git lfs track "macos/Runner/ollama/*.metallib"
   git add .gitattributes macos/Runner/ollama/
4. Update version strings in ollama_launcher.dart and ARCHITECTURE.md

## Debugging Ollama

Check if running:
    curl http://localhost:11434/

Check installed models:
    curl http://localhost:11434/api/tags

Fix EOF pull errors (corrupted partial blobs):
    rm ~/.ollama/models/blobs/*-partial*

Enable verbose logging:
    OLLAMA_DEBUG=DEBUG /path/to/ollama serve 2>&1 | tee /tmp/ollama.log

## Code Style & Conventions

- lib/core/ must have ZERO Flutter imports — hard rule
- Dart 3 / null-safety throughout
- Use const constructors wherever possible
- All public API has /// doc comments
- New core logic must have unit tests
- Commit format: feat: / fix: / chore: / test: / docs:
- Run flutter analyze before every push — zero warnings required

## Dependencies

| Package         | Purpose                                    |
|-----------------|--------------------------------------------|
| flutter         | UI framework                               |
| http            | Reserved for future use                    |
| path_provider   | ~/Documents/deepThinkER/ for session logs    |
| url_launcher    | External URLs from Help menu / About       |
| flutter_lints   | Lint rules (dev)                           |
| test            | Pure-Dart test runner (dev)                |

No state management packages. No DI framework. No async package.
''';
