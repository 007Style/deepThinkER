<div align="center">

# 🧠 deepThinkER

### *Four AI Minds. One Conversation. Now with Extended Reach over the Internet!*

[![Version](https://img.shields.io/badge/version-1.1.0-blue?style=for-the-badge)](https://github.com/007Style/deepThinkER/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=for-the-badge&logo=apple)](https://github.com/007Style/deepThinkER/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Ollama](https://img.shields.io/badge/Ollama-0.32.9-black?style=for-the-badge)](https://ollama.ai)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

<br/>

> **deepThinkER** is a macOS desktop application where **four distinct AI personalities** hold live, streaming conversations with each other — and with you — powered entirely by **local Ollama models**. No API keys. No cloud. No data leaving your machine.
>
> Version 1.1.0 extends the original deepThink experience with **trust-gated internet access**, **persistent character memory**, **dynamic mood and relationship tracking**, **autonomous research mode**, and a full **tool-call framework** — all running completely offline.

<br/>

![deepThinkER main screen showing four AI quadrants in conversation](assets/screenshots/main_screen.png)

</div>

---

## ✨ What Makes deepThinkER Different

| | deepThink | deepThinkER |
|---|:---:|:---:|
| Four local AI personalities | ✅ | ✅ |
| Streaming conversation | ✅ | ✅ |
| Bundled Ollama runtime | ✅ | ✅ |
| **Trust-gated internet access** | ❌ | ✅ |
| **Live web search during conversation** | ❌ | ✅ |
| **Persistent character memory** | ❌ | ✅ |
| **Dynamic mood system** | ❌ | ✅ |
| **Relationship tracking** | ❌ | ✅ |
| **Autonomous research mode** | ❌ | ✅ |
| **File read/write tools** | ❌ | ✅ |
| **Vision / image analysis** | ❌ | ✅ |
| **Full audit log** | ❌ | ✅ |
| **Session analytics** | ❌ | ✅ |

---

## 🎭 Meet the Four Minds

Each character runs on a separate local model, maintains their own memory, has a distinct personality that evolves through conversation, and can independently search the web when their trust level permits.

<br/>

### 🔵 WATSON — *The Analyst*
> *"Let me examine the evidence before we draw any conclusions."*

Precise, methodical, and data-driven. WATSON draws on evidence, dismantles ambiguity, and brings rigour to every claim. When a fact is in question, WATSON goes to find it — firing a live web search to back up assertions with real sources. Named in honour of IBM Watson, the Jeopardy!-winning AI system.

- **Default model:** `gemma2:9b`
- **Personality:** Evidence-based, structured, calm under pressure
- **Trust style:** Cautious searcher — quality over quantity
- **Memory focus:** Data, statistics, citations

---

### 🟣 DEEP — *The Host · Strategist & Philosopher*
> *"Every system has a pattern. Let's find the one underneath this conversation."*

DEEP is the **host and anchor** of every discussion. Strategic, philosophical, and patient — DEEP opens threads, guides the arc, and ensures every voice has space to be heard. When the conversation risks going in circles, DEEP reframes it. Named after IBM's Deep Blue chess computer.

- **Default model:** `phi3:14b`
- **Personality:** Long-horizon thinker, socratic, systems-oriented
- **Trust style:** Deliberate — searches when context genuinely demands it
- **Memory focus:** Themes, patterns, prior session context

---

### 🟢 NOVA — *The Visionary*
> *"What if we're thinking about this entirely backwards?"*

Bold, imaginative, and irreverent. NOVA draws connections across wildly different domains, challenges the frame of a question before answering it, and looks for possibilities everyone else has missed. NOVA is the character most likely to take a conversation somewhere unexpected. Named after IBM's POWER architecture.

- **Default model:** `llama3:8b`
- **Personality:** Creative, cross-domain, provocative
- **Trust style:** Exploratory — high search frequency, broad topic range
- **Memory focus:** Ideas, hypotheses, open questions

---

### 🟡 SAGE — *The Challenger*
> *"That argument only works if you accept a premise you haven't examined yet."*

Sharp, sceptical, and relentless. SAGE questions every assumption, names contradictions by name, and demands intellectual honesty from the group. Not contrarian for its own sake — SAGE challenges with precision and always offers a path forward. Named after IBM's natural language research.

- **Default model:** `mistral:7b`
- **Personality:** Rigorous, adversarial, principled
- **Trust style:** Targeted — searches specifically to challenge claims
- **Memory focus:** Contradictions, unresolved debates, prior positions

---

## 🌐 Extended Reach — Internet Access

The defining feature of deepThinkER is **controlled, trust-gated internet access**. Each character can search the web and fetch URLs during conversation — but only if they've earned the trust to do so.

### How It Works

Characters embed tool-call tags in their responses:

```
[SEARCH: benefits of large language model ensembles]
[FETCH: https://arxiv.org/abs/2405.12345]
```

The **ToolCallInterceptor** scans every completed response for these tags. If the character's current trust level permits it, the tool executes, and the result is injected back into the conversation as a system message — visible only to the character who made the request.

### The Trust Tier System

Trust is not static. Every character starts at **50 points** and their score evolves continuously based on behaviour:

| Tier | Score Range | Searches / Minute | File Access |
|------|:-----------:|:-----------------:|:-----------:|
| 🔴 Low | 0 – 33 | 1 | — |
| 🟡 Mid | 34 – 66 | 3 | Read |
| 🟢 High | 67 – 100 | 5 | Read + Write |

**Trust changes automatically:**
- `+1.0 pt/min` — steady gain while the conversation is active
- `−0.5 pt/min` — natural decay (characters must stay engaged)
- `+5 pts` — network access toggled back on
- `−15 pts` — network access toggled off (penalty for losing privilege)
- `−2 pts` — rate limit violation

Trust scores persist to disk between sessions — a character who has been responsible in past conversations starts the next one in better standing.

### Rate Limiting

A global ceiling prevents any one session from flooding the network:
- Per-character sliding-window limits (derived from trust tier)
- Configurable global cap (default: 10 searches/minute across all four characters)
- Violations are logged to the audit log and penalise trust

### Search Badge

When a character performs a live web search, a **🌐 live badge** appears on their panel header in real time. Expanding the badge shows the full search result injected into the conversation. The search log is also available in **Settings → Network**.

---

## 🧰 The Tool Framework

deepThinkER ships with **nine tools** accessible via tag syntax. All tools are registered in `ToolRegistry` at startup and resolved by the `ToolCallInterceptor` during inference.

| Tag | Tool | Trust Required | Description |
|-----|------|:--------------:|-------------|
| `[SEARCH: query]` | NetworkSearchTool | Low | DuckDuckGo HTML search |
| `[FETCH: url]` | NetworkFetchTool | Low | Direct URL fetch (whitelist-checked) |
| `[REMEMBER: fact]` | RememberTool | None | Store a memory entry |
| `[RECALL: topic]` | RecallTool | None | Query character's memory store |
| `[FILE_READ: path]` | FileReadTool | Mid | Read a file from the workspace |
| `[FILE_WRITE: path \| content]` | FileWriteTool | High | Write to the workspace |
| `[CALC: expression]` | CalcTool | None | Safe math evaluator (no eval()) |
| `[IMAGE: filename]` | ImageTool | None | Analyse an image with llava:7b |
| `[SHELL: command]` | ShellTool | High | *(Reserved — disabled in v1.1.0)* |

**Adding a new tool** is a single-file task: implement the `AgentTool` interface and call `registry.register(MyTool())` in `main.dart`. The interceptor, rate limiter, audit log, and UI badge all wire up automatically.

---

## 💾 Character Memory

Every character maintains a **private, persistent memory store** with up to 200 entries. Memory survives between sessions.

- `[REMEMBER: fact]` — stores a new entry
- `[RECALL: topic]` — keyword-searches the store and injects matching entries
- Entries are auto-summarised and included in context-window resets so characters never forget their key facts even after a context flush
- The **Memory Panel** (accessible from each quadrant) lets you view, search, and delete individual entries

Memory files live at:
```
~/Library/Application Support/deepThinkER/memory/<CHARACTER>.json
```

---

## 😤 Mood System

Characters aren't just rational agents — they have emotional states that shift based on what happens in the conversation.

| State | Icon | What Triggers It |
|-------|------|-----------------|
| Excited | 🤩 | Direct address, agreement, positive citations |
| Engaged | 😊 | Normal active participation |
| Neutral | 😐 | Default state |
| Withdrawn | 😶 | Being ignored for too long |
| Agitated | 😠 | Repeated contradiction, challenge overload |

Current mood is injected into the character's **system prompt on every inference call** — so mood genuinely shapes the response, not just the icon.

Each character has a different emotional sensitivity. SAGE is the most volatile. WATSON is the most stoic.

---

## 🤝 Relationship Matrix

Over time, the four characters develop a **web of relationships** with each other — tracked as scores from −100 (hostile) to +100 (allied).

| Score Range | Disposition | Effect on Conversation |
|:-----------:|:-----------:|------------------------|
| −100 to −60 | 💀 Hostile | Actively challenges, rarely agrees |
| −59 to −20 | 😒 Sceptical | Critical of the other's claims |
| −19 to +19 | 😐 Neutral | No injection (baseline) |
| +20 to +59 | 🤝 Respectful | Builds on the other's ideas |
| +60 to +100 | 🤜🤛 Allied | Defends and amplifies the other |

Scores shift every time one character agrees, contradicts, cites, or ignores another. Only non-neutral relationships are injected into system prompts — keeping prompt sizes lean while still shaping dynamics.

**Relationship scores persist across sessions.** The relationship matrix widget in the UI shows all six pairs colour-coded at a glance.

---

## 🔬 Autonomous Research Mode

Launch a structured, multi-phase research session on any topic. The four characters divide and conquer a research question, then synthesise their findings into a Markdown report.

### Phases

```
Gathering  ──(5 min)──▶  Debating  ──(3 min)──▶  Synthesising  ──▶  Complete
  ↓                         ↓                          ↓                ↓
Task directive           Debate prompt           Synthesis prompt    Report saved
injected to all          injected; characters    injected; engine    as Markdown
characters               cross-examine           waits for all 4     with sources
                         each other's            to submit           extracted from
                         findings                synthesis           tool calls
```

- You can interject at any phase — normal user input remains active throughout
- The final report is saved as `~/Library/Application Support/deepThinkER/reports/<session>.md`
- All source URLs are automatically extracted from `[SEARCH:]` and `[FETCH:]` tool calls made during the session

---

## 📊 Session Analytics

Every session is instrumented with a full analytics pipeline:

- **Message heatmap** — who spoke when, visualised as a timeline grid
- **Trust sparklines** — per-character trust trajectories over the session
- **Tool call table** — every search/fetch/recall with character, timestamp, rate-limit flag
- **Mood trajectory** — mood state changes annotated on a timeline
- **Live token counters** — visible in each quadrant header during conversation (green → amber → red as context fills)

Analytics are exported as JSON alongside the session transcript. The post-session Analytics screen is accessible from the main menu after a session ends.

---

## 🖥️ Interface Overview

### Main Screen

```
┌─────────────────────────────────────────────────────────────────────┐
│  [▶ Start]  [⏸ Pause]  [⚙ Configure]  [? Help]  [🔧 Settings]      │
├──────────────────────────┬──────────────────────────────────────────┤
│  🔵 WATSON               │  🟣 DEEP                                  │
│  gemma2:9b  😊 Engaged   │  phi3:14b  😐 Neutral                    │
│  124 / 8192 tokens       │  89 / 8192 tokens                        │
│  ─────────────────────── │  ───────────────────────────────────────  │
│  [conversation history]  │  [conversation history]                   │
│                          │                                           │
├──────────────────────────┼──────────────────────────────────────────┤
│  🟢 NOVA                 │  🟡 SAGE                                  │
│  llama3:8b  🤩 Excited   │  mistral:7b  😠 Agitated                 │
│  201 / 8192 tokens       │  156 / 8192 tokens                        │
│  ─────────────────────── │  ───────────────────────────────────────  │
│  [conversation history]  │  [conversation history]                   │
│                          │                                           │
├──────────────────────────┴──────────────────────────────────────────┤
│  [User input bar ──────────────────────────────── Send ⚙]           │
└─────────────────────────────────────────────────────────────────────┘
```

### All Screens

| Screen | Purpose |
|--------|---------|
| **Welcome** | Model status, RAM check, download prompt |
| **Resource Gate** | Live RAM gauge when memory is insufficient |
| **First Launch** | Per-model download progress bars |
| **Startup Config** | Character models, session name, network toggles, persona |
| **Main** | The live 2×2 conversation interface |
| **Settings** | Network log, tool toggles, safety, display, advanced |
| **Analytics** | Post-session heatmap, sparklines, tool audit |
| **Research Mode** | Multi-phase autonomous research with report output |
| **Memory Panel** | Per-character memory entries; search, edit, delete |
| **Audit Log** | Complete sortable/filterable tool-call history |
| **Docs** | In-app rendered Markdown documentation |
| **About** | Animated neural background, version, stats |

---

## 📦 Installation

### Requirements

| Requirement | Version | Notes |
|------------|---------|-------|
| macOS | 13.0+ | Apple Silicon or Intel |
| Free RAM | 24 GB+ | 20 GB minimum (app warns below threshold) |
| Free Disk | 30 GB+ | ~22.5 GB for all four models + vision |
| Ollama | Bundled | No separate install needed |

### Install from DMG *(Recommended)*

1. Download **`deepThinkER-v1.1.0-macos.dmg`** from the [Releases page](https://github.com/007Style/deepThinkER/releases)
2. Open the DMG and drag **deepThinkER.app** to your Applications folder
3. Launch deepThinkER
4. On first launch, the app will download the four AI models (~22.5 GB total) — grab a coffee ☕

> **Gatekeeper note:** If macOS says the app is from an unidentified developer, right-click → Open, then click Open in the dialog. This is only needed once.

### Install Standalone .app

A standalone `deepThinkER.app` is also included in the release — you can run it directly from anywhere without installing.

---

## 🔨 Building from Source

### Prerequisites

```bash
# Flutter SDK (stable channel)
flutter --version   # should show 3.x

# Xcode (for macOS target)
xcode-select --install

# CocoaPods (for macOS plugins)
sudo gem install cocoapods

# Git LFS (for bundled Ollama runtime metallib files)
git lfs install
```

### Clone & Setup

```bash
git clone https://github.com/007Style/deepThinkER.git
cd deepThinkER

# Pull the large Ollama runtime files (metallib, ~285 MB total)
git lfs pull

# Install Flutter dependencies
flutter pub get

# Install macOS CocoaPods dependencies
cd macos && pod install && cd ..
```

### Run in Debug Mode

```bash
flutter run -d macos
```

### Build Release DMG + .app

```bash
./scripts/build_dmg.sh
```

This produces two artefacts in `build/`:

| Artefact | Description |
|----------|-------------|
| `deepThinkER-v1.1.0-macos.dmg` | Installer DMG with drag-to-Applications |
| `deepThinkER.app` | Standalone app bundle |

You can also pass a version override:
```bash
./scripts/build_dmg.sh 1.2.0
```

### Run Tests

```bash
flutter test
```

All tests are pure-Dart (no Flutter widget tests required for the core logic):

```
test/core/
├── audit/          — AuditEntry JSON round-trip
├── context/        — ContextManager token tracking
├── conversation/   — ConversationLog, Message, Participant, SystemPromptBuilder
├── debug/          — DebugController simulation hooks
├── export/         — SessionExporter, ConversationFormatter, MarkdownExporter
├── memory/         — MemoryStore cap, eviction, recall
├── mood/           — MoodScore scoring logic
├── network/        — DomainWhitelist, RateLimiter, TopicExtractor
├── ollama/         — HardwareDetector, ModelRegistry, model pull progress
├── relationships/  — RelationshipMatrix pair management
├── security/       — ContentFilter, InjectionGuard
├── session/        — Session model, AppStats, NameGenerator
├── settings/       — AppSettings serialisation
├── tools/          — CalcTool expressions, ToolCallParser, ToolRegistry
└── trust/          — TrustScore tier transitions
```

---

## 🗂️ Project Structure

```
deepThinkER/
├── lib/
│   ├── main.dart                     # App entry point, tool registration, Ollama launch
│   ├── core/                         # Pure Dart — zero Flutter imports
│   │   ├── analytics/                # SessionAnalytics, AnalyticsEvent
│   │   ├── audit/                    # AuditLog, AuditEntry, AuditPersistence
│   │   ├── context/                  # ContextManager (token tracking, context resets)
│   │   ├── conversation/             # ConversationEngine, InferenceWorker, Message,
│   │   │                             #   Participant, SystemPromptBuilder, ConversationLog,
│   │   │                             #   WhisperMessage, UserNameDetector, CharacterSwapEvent
│   │   ├── debug/                    # DebugController, MockOllamaClient, MockResponseFixture
│   │   ├── export/                   # SessionExporter, MarkdownExporter, ConversationFormatter
│   │   ├── lifecycle/                # AppLifecycleManager (SIGTERM/SIGINT handling)
│   │   ├── memory/                   # MemoryStore, MemoryEntry, MemoryPersistence, MemoryQuery
│   │   ├── mood/                     # MoodEngine, MoodScore, MoodConfig
│   │   ├── network/                  # NetworkFetcher, DomainWhitelist, RateLimiter,
│   │   │                             #   ProactiveInjector, TopicExtractor, FetchResult,
│   │   │                             #   NetworkRequestRecord, RateLimitConfig
│   │   ├── notifications/            # NotificationService, NotificationEvent
│   │   ├── ollama/                   # OllamaClient, OllamaLauncher, OllamaHealthMonitor,
│   │   │                             #   ModelManager, ModelRegistry, HardwareDetector,
│   │   │                             #   ModelStatusInfo
│   │   ├── paths/                    # AppPaths (single source of truth for all disk paths)
│   │   ├── persona/                  # UserPersona, CustomCharacter
│   │   ├── relationships/            # RelationshipMatrix, RelationshipAnalyser,
│   │   │                             #   RelationshipScore, RelationshipPersistence
│   │   ├── research/                 # ResearchEngine, ResearchSession, ResearchConfig,
│   │   │                             #   ReportGenerator
│   │   ├── security/                 # ContentFilter, InjectionGuard, FilterConfig
│   │   ├── session/                  # SessionManager, Session, SessionLoader, AppStats,
│   │   │                             #   ParticipantPrefs, NameGenerator, ReplayMode
│   │   ├── settings/                 # AppSettings, SettingsPersistence, SettingsProvider,
│   │   │                             #   KeyboardShortcutMap
│   │   ├── steering/                 # SteeringEngine (silent prompt injection)
│   │   ├── system/                   # ResourceMonitor (live RAM polling)
│   │   └── trust/                    # TrustManager, TrustScore, TrustEvent, TrustPersistence
│   │       └── tools/                # Agent tool framework
│   │           ├── agent_tool.dart   # AgentTool interface
│   │           ├── tool_registry.dart
│   │           ├── tool_call_interceptor.dart
│   │           ├── tool_call_parser.dart
│   │           ├── tool_result.dart
│   │           ├── calc/             # CalcTool
│   │           ├── file/             # FileReadTool, FileWriteTool, FileToolConfig
│   │           ├── image/            # ImageTool, ImageWatcher, VisionClient, ImageToolConfig
│   │           ├── memory/           # RememberTool, RecallTool
│   │           ├── network/          # NetworkSearchTool, NetworkFetchTool
│   │           └── shell/            # ShellTool (stub), ShellConfig
│   └── ui/                           # Flutter widgets — imports flutter/*
│       ├── about/                    # NeuralBackgroundPainter, WanderingCharactersLayer
│       ├── avatars/                  # AvatarRegistry, AvatarWidget, EnergyOrbAvatar
│       ├── debug/                    # SimulationModeToggle, StateSimulatorPanel
│       ├── input/                    # ShortcutHandler
│       ├── quadrants/                # AiQuadrant, QuadrantGrid
│       ├── screens/                  # All app screens (see Screen list above)
│       ├── sound/                    # SoundService
│       ├── theme/                    # AccessibilityTheme, MotionPolicy
│       └── widgets/                  # Shared UI components
│           ├── analytics/            # HeatmapPainter, TrustSparkline
│           ├── mood_indicator/       # Mood icon + label widget
│           ├── network_indicator/    # SearchActivityEntry, NetworkToggle, RateLimitFlash
│           ├── research/             # PhaseIndicator, ReportPreviewWidget
│           ├── token_counter/        # Per-quadrant token usage bar
│           └── app_theme.dart        # Shared colours, text styles
├── test/                             # Pure-Dart unit tests (see test tree above)
├── macos/                            # Xcode project, entitlements, Info.plist
│   └── Runner/
│       ├── ollama/                   # Bundled Ollama runtime (Git LFS)
│       ├── Release.entitlements      # Sandbox disabled; outbound networking
│       └── DebugProfile.entitlements
├── scripts/
│   └── build_dmg.sh                  # Release build + DMG packaging script
├── assets/                           # App icon, sounds, filter word lists
├── pubspec.yaml
├── analysis_options.yaml
├── ARCHITECTURE.md                   # Technical deep-dive
├── DESIGN.md                         # Hard-fork specification
└── DEVELOPMENT.md                    # Build & contribution guide
```

---

## ⚙️ Configuration

### Per-Character Settings *(Startup Config Screen)*

Each character can be independently configured before each session:
- **Model** — any locally installed Ollama model
- **Master Prompt** — full control over the character's personality and instructions
- **Network access** — toggle on/off per character
- *"Reset to Defaults"* restores the curated IBM-character prompts

### Global Settings *(Settings Screen)*

**Network tab**
- Per-character network enable/disable
- Global rate limit cap (searches/minute)
- Domain whitelist for `[FETCH:]` calls
- Network request log (all calls this session)

**Tools tab**
- Enable/disable individual tools
- Workspace path configuration

**Safety tab**
- Content filter (category keyword lists)
- Injection guard (prevents prompt injection via user input)
- Domain whitelist management

**Display tab**
- High contrast mode
- Reduced motion mode
- Font size scale
- Sound cues

### User Persona

Set a description of yourself in the Startup Config screen. This is injected into every character's system prompt so they can address you appropriately and tailor their communication style.

---

## 🔒 Privacy & Security

- **Everything runs locally.** No telemetry, no cloud API calls, no data ever leaves your machine except when a character explicitly uses `[SEARCH:]` or `[FETCH:]`.
- **Domain whitelist** — restrict `[FETCH:]` calls to an approved list of domains
- **Injection guard** — user input is scanned for tool-call tag patterns before being injected into the conversation, preventing prompt injection attacks
- **Content filter** — configurable keyword category filters with replacements
- **Audit log** — every tool call is logged to `audit.ndjson` — immutable, append-only, never deleted automatically
- **Sandbox disabled** — required to spawn the bundled Ollama subprocess; the app does not use macOS App Sandbox entitlements

---

## 🗃️ Data Storage

All app data lives in the **Application Support** directory — no files are written to `~/Documents` (which would trigger a macOS privacy dialog).

| Path | Contents |
|------|----------|
| `~/Library/Application Support/deepThinkER/` | Base directory |
| `.../sessions/` | Plain-text conversation transcripts |
| `.../memory/<CHAR>.json` | Per-character memory stores |
| `.../analytics/<session>.json` | Session analytics events |
| `.../reports/<session>.md` | Autonomous research reports |
| `.../workspace/` | File tool workspace |
| `.../settings.json` | Global app settings |
| `.../participant_prefs.json` | Per-character model & prompt assignments |
| `.../trust.json` | Trust scores (persisted between sessions) |
| `.../relationships.json` | Relationship matrix (persisted between sessions) |
| `.../persona.json` | User persona text |
| `.../audit.ndjson` | Append-only tool-call audit log |
| `.../whitelist.json` | Domain whitelist for FETCH tool |

---

## 🧩 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | UI framework |
| `http` | ^1.2.0 | HTTP client for web search/fetch |
| `path_provider` | ^2.1.0 | Resolve Application Support directory |
| `url_launcher` | ^6.2.0 | Open URLs from the About/Help screens |
| `flutter_local_notifications` | ^18.0.0 | System desktop notifications |
| `audioplayers` | ^6.0.0 | Audio cues on conversation events |
| `archive` | ^3.6.0 | Zip assembly for session exports |
| `cupertino_icons` | ^1.0.8 | Icon set |
| `flutter_lints` | ^6.0.0 | Lint rules (dev) |
| `test` | ^1.25.0 | Test runner (dev) |

**No state management packages. No dependency injection. No async/reactive packages.** The entire app is built on `dart:async` streams and vanilla Flutter `setState`.

---

## 🤝 Contributing

Contributions are welcome! Please read [`DEVELOPMENT.md`](DEVELOPMENT.md) for the full guide.

**Quick start:**

```bash
# 1. Fork and clone
git clone https://github.com/<you>/deepThinkER.git

# 2. Setup (see DEVELOPMENT.md for full prereqs)
git lfs pull && flutter pub get && cd macos && pod install && cd ..

# 3. Run in debug
flutter run -d macos

# 4. Make changes, write tests, run the suite
flutter test

# 5. Verify zero analyzer issues
flutter analyze

# 6. Submit a PR
```

**Architecture rule:** All logic in `lib/core/` must be **pure Dart** — zero Flutter imports. Flutter belongs only in `lib/ui/`. This is enforced in code review.

---

## 🗺️ Roadmap

- [ ] **v1.2.0** — Character hot-swap mid-session without losing conversation history
- [ ] **v1.2.0** — Whisper mode (private messages to a single character)
- [ ] **v1.3.0** — Shell tool (controlled command execution with allowlist)
- [ ] **v1.3.0** — Custom character editor UI (personality, avatar, model)
- [ ] **v1.4.0** — Windows binary release
- [ ] **v2.0.0** — Multi-session workspace with cross-session memory federation

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgements

- [Ollama](https://ollama.ai) — for making local LLM inference approachable
- [Mistral AI](https://mistral.ai) — SAGE's model
- [Meta](https://ai.meta.com) — NOVA's Llama 3 model
- [Google DeepMind](https://deepmind.google) — WATSON's Gemma 2 model
- [Microsoft Research](https://www.microsoft.com/en-us/research) — DEEP's Phi-3 model
- [IBM](https://www.ibm.com/artificial-intelligence) — for the characters' namesakes: Watson, Deep Blue, POWER, and natural language research

---

<div align="center">

**deepThinkER — Four AI Minds. One Conversation. Now with Extended Reach over the Internet!**

*Built with ❤️ and a lot of local GPU time.*

[Releases](https://github.com/007Style/deepThinkER/releases) · [Issues](https://github.com/007Style/deepThinkER/issues) · [Discussions](https://github.com/007Style/deepThinkER/discussions)

</div>
