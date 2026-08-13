# deepThink — Architecture

> **Version:** v1.0.2
> **Platform:** macOS (primary) · Windows (self-compile)
> **Stack:** Flutter / Dart · Ollama v0.32.9 · four local LLMs
> **Contact:** daneyand@ibm.com

---

## Table of Contents

1. [Philosophy & Guiding Principles](#1-philosophy--guiding-principles)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Layer Breakdown](#3-layer-breakdown)
   - 3.1 [Core Layer — Pure Dart](#31-core-layer--pure-dart)
   - 3.2 [UI Layer — Flutter](#32-ui-layer--flutter)
   - 3.3 [Native Layer — macOS & Windows](#33-native-layer--macos--windows)
4. [Startup Flow](#4-startup-flow)
5. [Conversation Engine](#5-conversation-engine)
6. [Inference Worker Design](#6-inference-worker-design)
7. [Context Window Management](#7-context-window-management)
8. [Ollama Integration](#8-ollama-integration)
9. [Resource Monitoring](#9-resource-monitoring)
10. [Avatar System](#10-avatar-system)
11. [Session Management](#11-session-management)
12. [Data Flow Diagram](#12-data-flow-diagram)
13. [Key Design Decisions](#13-key-design-decisions)
14. [Known Constraints](#14-known-constraints)

---

## 1. Philosophy & Guiding Principles

### Zero-Flutter Core
`lib/core/` contains **zero Flutter imports**. Every class is pure Dart.
This is a hard architectural rule — not a style preference. It means the entire
conversation engine, Ollama client, hardware detector, resource monitor, and
session management layer can be lifted wholesale into a native SwiftUI or WinUI 3
shell in the future without touching a line of logic.

### Bundled Runtime
The user never installs Ollama. The complete Ollama v0.32.9 runtime is physically
embedded inside the `.app` bundle at build time by an Xcode shell-script build phase.
Distribution is a single DMG — download, drag, done.

### Parallel Inference
All four AI participants run their inference concurrently — never round-robin.
Each has its own `InferenceWorker` subscribing to the shared `ConversationLog`.
A random jitter (200–800 ms) staggers their responses naturally.

### Pass Mechanic
AIs can pass by returning an empty string. The system prompt instructs each model
to pass rather than produce filler. User messages always override this — the
`forceRespond` flag appends a system reminder that the human must receive a reply.

### Offline After Setup
After the one-time model download (~22.5 GB), deepThink runs 100% offline.
No telemetry. No cloud calls. No accounts.

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        deepThink.app                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Flutter UI Layer                       │  │
│  │  Screens · Widgets · Quadrant Grid · Avatar System        │  │
│  │  Resource Gate · Welcome · Download · Config · Main       │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │  calls / streams                      │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │               Core Layer (pure Dart)                      │  │
│  │                                                           │  │
│  │  ConversationEngine ──► InferenceWorker × 4               │  │
│  │       │                      │                            │  │
│  │  ConversationLog         OllamaClient                     │  │
│  │  ContextManager          HardwareDetector                 │  │
│  │  SessionManager          ResourceMonitor                  │  │
│  │  NameGenerator           ModelManager                     │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │  HTTP localhost:11434                 │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │           Bundled Ollama v0.32.9 (serve)                  │  │
│  │    Contents/Resources/ollama/ollama                       │  │
│  │    + llama-server  + llama-quantize  + *.metallib         │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │  loads models from                   │
│                    ~/.ollama/models/                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Layer Breakdown

### 3.1 Core Layer — Pure Dart

All files live under `lib/core/`. Zero Flutter imports anywhere in this tree.

#### `ollama/`

| File | Responsibility |
|------|---------------|
| `model_registry.dart` | Defines `ModelInfo` and `ModelRegistry.all` — the canonical list of four models with display names, RAM footprints, and context tiers. |
| `hardware_detector.dart` | Detects total and **free** RAM (`vm_stat` on macOS, WMIC on Windows), GPU backend (Metal / CUDA / ROCm / CPU), and maps RAM to `RamTier`. |
| `ollama_launcher.dart` | Resolves the bundled Ollama binary path from `Platform.resolvedExecutable`, `chmod +x`s it, spawns `ollama serve` with `OLLAMA_KEEP_ALIVE=-1` and `OLLAMA_RUNNERS_DIR`, and polls until the server responds. |
| `ollama_client.dart` | Low-level HTTP client: `generateStream`, `listModels`, `pullModel` (streaming NDJSON), `isHealthy`. Handles `{"error":"..."}` responses, partial line buffering, and EOF detection. |
| `model_manager.dart` | Higher-level: `checkModels()` cross-references `listModels()` against the registry; `downloadModel()` streams `ModelPullProgress` events. |
| `model_status_info.dart` | Barrel re-export of `ModelStatus` and `ModelPullProgress`. |

#### `conversation/`

| File | Responsibility |
|------|---------------|
| `message.dart` | Immutable value type: `participantName`, `content`, `isUser`, `isPass`, auto-generated UUID `id`, `timestamp`. |
| `conversation_log.dart` | Thread-safe append-only log. Exposes `allMessages` (unmodifiable list), `messageStream` (broadcast), `getLastN`, `getLastNForParticipant`, `getLastNPerParticipant`. |
| `participant.dart` | AI character definition: `name`, `personality`, `role`, `isHost`, `assignedModelId`, `masterPrompt`. `Participant.defaults()` returns the four canonical characters. |
| `system_prompt_builder.dart` | Combines the master prompt, participant roster, conversation rules (including pass mechanic and user-response mandate), and hardware context into a single system message. |
| `inference_worker.dart` | Per-AI engine: subscribes to `ConversationLog.messageStream`, applies jitter, calls `OllamaClient.generateStream`, emits `InferenceEvent` tokens, handles pass detection, context resets, and the `forceRespond` user-message flag. |
| `conversation_engine.dart` | Top-level orchestrator: creates workers, merges their event streams, injects user messages, appends the kickoff prompt, manages start/stop lifecycle. |
| `user_name_detector.dart` | Regex-based detection of user rename patterns ("call me X", "my name is X") in AI token output. |

#### `context/`

| File | Responsibility |
|------|---------------|
| `context_manager.dart` | Per-participant token counter. Signals `needsReset()` at 90% of context window. `buildResetSeed()` returns the last 2 non-pass messages per participant for continuity. |

#### `session/`

| File | Responsibility |
|------|---------------|
| `name_generator.dart` | Generates fun lowerCamelCase session names (`thetaByte`, `thorKitten`) from a word list with optional seeded `Random`. |
| `session.dart` | Immutable session record: id, name, participants, timestamps, message/token counters. JSON serialisable. |
| `app_stats.dart` | Mutable global counters: total sessions, messages, tokens, dates. |
| `session_manager.dart` | Creates sessions, writes NDJSON log files under `~/Documents/deepThink/sessions/`, updates `AppStats`. |

#### `system/`

| File | Responsibility |
|------|---------------|
| `resource_monitor.dart` | Polls free RAM every 2 s (`vm_stat` / WMIC), scans top processes by RSS (`ps aux` / WMIC), emits `ResourceSnapshot` on a broadcast stream. Auto-detects total RAM once on first poll. |

---

### 3.2 UI Layer — Flutter

All files under `lib/ui/`. May import Flutter freely.

#### Screens (`lib/ui/screens/`)

| Screen | Shown when |
|--------|-----------|
| `welcome_screen.dart` | After startup — greets user, shows model status, free RAM, download CTA. Re-detects hardware if arriving from cancel path. |
| `resource_gate_screen.dart` | Free RAM < 24 GB. Live RAM gauge, top process list, model stack readiness, tips. Auto-provisions and advances once RAM ≥ 20 GB. |
| `first_launch_screen.dart` | One or more models missing. Scrollable per-model progress bars, overall bar, cancel-and-go-back button. |
| `startup_config_screen.dart` | All models installed. Per-character model selector, session name, dice roll, RAM total, hardware display. Loads saved `ParticipantPrefs` on entry. |
| `main_screen.dart` | Active conversation. 2×2 quadrant grid, user input bar, top bar (Start/Stop, Pause/Resume, Configure, Help), status band. Routes `InferenceEvent` tokens to per-quadrant streams. |
| `external_ollama_screen.dart` | Port 11434 held by a foreign process. Offers Kill & Retry rather than hanging. |
| `about_screen.dart` | Help → About. Animated neural background, wandering emoji characters (🤖🧠💡⚡). |
| `model_help_screen.dart` | Help → Model Downloads. Manual `ollama pull` instructions. |

#### Quadrants (`lib/ui/quadrants/`)

| File | Responsibility |
|------|---------------|
| `ai_quadrant.dart` | Single AI panel: avatar, character name, scrolling message list, live token stream display. |
| `quadrant_grid.dart` | 2×2 `GridView` of four `AiQuadrant` widgets. |

#### Avatars (`lib/ui/avatars/`)

| File | Responsibility |
|------|---------------|
| `avatar_widget.dart` | `AvatarState` enum (idle / thinking / speaking / waiting) + `AvatarWidget` base. |
| `avatar_registry.dart` | Plugin-style registry: `registerDefaults()` registers built-in types; `build(type, state, characterName, size)` creates widgets. |
| `energy_orb/orb_config.dart` | Per-character orb colour config (WATSON=blue, DEEP=purple, NOVA=amber, SAGE=red). |
| `energy_orb/orb_painter.dart` | `CustomPainter` — concentric glow rings, state-driven animation. |
| `energy_orb/energy_orb_avatar.dart` | `AnimatedBuilder` driving `OrbPainter` at 60 fps. |

#### Widgets (`lib/ui/widgets/`)

| File | Responsibility |
|------|---------------|
| `app_theme.dart` | `AppColors` constants + `AppTheme.darkTheme` ThemeData. |
| `status_band.dart` | Thin footer: hardware backend, RAM tier, session name. |
| `start_stop_button.dart` | Animated Start / Stop toggle. |
| `user_input_bar.dart` | Text field + send button. Disabled when engine not running. |
| `model_selector.dart` | Per-character dropdown for model assignment. |
| `character_config_card.dart` | Full character config card (avatar, name, model, prompt preview). |
| `ram_total_display.dart` | Live RAM allocation sum as characters are configured. |
| `help_menu.dart` | Help menu: User Guide, Architecture, Dev Guide, Model Downloads, Session Transcripts, About. |
| `start_stop_button.dart` | Animated Start / Stop toggle with busy-spinner state. |

#### About animations (`lib/ui/about/`)

| File | Responsibility |
|------|---------------|
| `neural_background_painter.dart` | `CustomPainter` — animated nodes and edges simulating a neural network. |
| `wandering_character.dart` | Single emoji that wanders randomly across the screen. |
| `wandering_characters_layer.dart` | Positions four wandering characters (🤖🧠💡⚡) on the about screen. |

---

### 3.3 Native Layer — macOS & Windows

#### macOS

- **`macos/Runner/ollama/`** — Full Ollama v0.32.9 runtime (binary, `llama-server`, `llama-quantize`, Metal shader `.metallib` files). Tracked via Git LFS for the large shader files.
- **`macos/Runner/copy_ollama.sh`** — Xcode shell-script build phase. Copies the entire runtime into `Contents/Resources/ollama/` at every build.
- **`macos/Runner/DebugProfile.entitlements`** / **`Release.entitlements`** — App Sandbox disabled (required for `Process.start()`), CS library validation disabled, network client+server, home-relative path exceptions for `~/.ollama/` and `~/Documents/deepThink/`.
- **`scripts/build_dmg.sh`** — Packages the release `.app` into a compressed DMG.
- **`.github/workflows/build_macos.yml`** — CI: builds and packages DMG on version tag push.

#### Windows

- **`windows/BUILD.md`** — Step-by-step guide for building on Windows (Flutter, MSVC, Ollama runtime placement, NSIS packaging).
- **`.github/workflows/build_windows.yml`** — CI: validates the Windows build on pull requests.

---

## 4. Startup Flow

```
main()
  │
  ├─ FlutterError.onError + PlatformDispatcher.onError  (global error hooks)
  ├─ ProcessSignal.sigterm / sigint → OllamaLauncher.killAll()
  ├─ AvatarRegistry.registerDefaults()
  └─ runApp(DeepThinkApp)
       └─ _AppLoader.initState()
            │
            ├─ 1. OllamaLauncher.start()
            │       ├─ isRunning()? → skip if already up
            │       │     (includes 3 s drain timeout — never hangs on keep-alive)
            │       ├─ lsof TCP:11434 → port taken by foreign PID?
            │       │     └─ throw ExternalOllamaException → ExternalOllamaScreen
            │       ├─ resolve bundled binary path
            │       ├─ chmod +x binary + helpers
            │       ├─ Process.start('ollama', ['serve'], OLLAMA_KEEP_ALIVE=-1)
            │       ├─ write PID → $TMPDIR/deepthink_ollama.pid
            │       ├─ forward stdout/stderr to flutter: print
            │       └─ poll isRunning() up to 120 s
            │
            ├─ 2. HardwareDetector.detect()
            │       ├─ totalRamGb  (sysctl hw.memsize)
            │       ├─ freeRamGb   (vm_stat free+inactive+speculative pages)
            │       ├─ backend     (uname -m → arm64 → appleMetal)
            │       └─ → HardwareInfo
            │
            ├─ 3. ModelManager.checkModels()
            │       ├─ GET /api/tags
            │       └─ cross-reference against ModelRegistry.all
            │
            └─ 4. Route:
                    ├─ ExternalOllamaException → ExternalOllamaScreen (Kill & Retry)
                    ├─ other error  → _ErrorScreen
                    ├─ freeRamGb < 24  → ResourceGateScreen (live monitor)
                    └─ else            → WelcomeScreen
                                              └─ missing models → FirstLaunchScreen
                                              └─ all present   → StartupConfigScreen
                                                                     └─ MainScreen (pushReplacement)
                                                                           └─ Configure button
                                                                                 └─ StartupConfigScreen
```

---

## 5. Conversation Engine

```
ConversationEngine
  │
  ├─ ConversationLog          (shared append-only log + broadcast stream)
  ├─ ContextManager           (per-participant token counter)
  │
  └─ InferenceWorker × 4
       ├─ subscribes to ConversationLog.messageStream
       ├─ ignores own messages (no self-loops)
       ├─ on new message:
       │     ├─ if inferencing → set _pendingResponse (+ _pendingIsUserMessage)
       │     └─ else          → scheduleResponse(forceRespond: msg.isUser)
       │
       ├─ scheduleResponse: Timer(200–800 ms jitter)
       │
       └─ runInference:
             ├─ emit isThinking=true
             ├─ buildMessages(allParticipants, forceRespond)
             │     ├─ system prompt (masterPrompt + rules + hardware)
             │     ├─ history (full log, no passes; or reset seed if 90% ctx)
             │     └─ if forceRespond → append "[System: you MUST respond]"
             ├─ OllamaClient.generateStream → emit tokens
             ├─ append completed Message to log
             └─ emit isDone + handle pending
```

**Kickoff:** On `engine.start()`, a synthetic `System` message is appended:
> "The conversation is beginning. DEEP, please open with a thought-provoking topic or question."

DEEP sees this and opens the conversation. The other three participants see DEEP's response
on the log and respond in turn.

---

## 6. Inference Worker Design

### Jitter
Each worker waits a random 200–800 ms before calling Ollama. This prevents all four
models from simultaneously hammering the GPU scheduler, produces more natural
interleaving, and avoids the thundering-herd pattern that causes the context scheduler
to queue requests.

### Pass Mechanic
The system prompt contains:
> "If you have nothing meaningful to add, respond with ONLY an empty string: `""`"

A response is a pass if `fullResponse.trim().isEmpty`. Passes are recorded in the log
(as `isPass: true`) so context history stays complete, but they are filtered from the
displayed message list and from context-window reset seeds.

### User-Message Override (`forceRespond`)
When `message.isUser == true`, `forceRespond = true` is threaded through
`_scheduleResponse` → `_runInference` → `_buildMessages`. A final chat message is
appended to the payload:

```
[System: The human user just sent a message above.
 You MUST respond directly to them.
 Do NOT return an empty string. Do NOT pass.]
```

This overrides the pass mechanic and guarantees every AI replies to user input.

### Pending Queue
A single `_pendingResponse` bool acts as a one-deep queue. If a message arrives
while inference is already running, the flag is set. On `finally`, if `_pendingResponse`
is true, another `scheduleResponse` is fired. `_pendingIsUserMessage` tracks whether
the pending message was from the user so `forceRespond` is preserved correctly.

---

## 7. Context Window Management

`ContextManager` tracks estimated token usage per participant using a character-based
approximation (`recordFromText` counts `text.length ~/ 4` tokens).

When `needsReset(participantName, contextWindowSize)` returns true (at 90% capacity),
`buildResetSeed` is called, which returns the last 2 non-pass messages per participant
in chronological order (capped at 10 messages total). The worker resets its counter
and re-records the seed, ensuring continuity without filling the context.

### Context Window Tiers

| RAM Tier | Standard models | phi3:14b |
|----------|----------------|---------|
| 32 GB    | 8 192          | 32 768  |
| 48 GB    | 16 384         | 65 536  |
| 64 GB    | 32 768         | 131 072 |
| 128 GB   | 65 536         | 131 072 |

---

## 8. Ollama Integration

### Binary Resolution

```dart
// macOS: <app>.app/Contents/MacOS/deep_think  →  ../../Resources/ollama/ollama
final exeDir = File(Platform.resolvedExecutable).parent;
final contentsDir = exeDir.parent;
return '${contentsDir.path}/Resources/ollama/ollama';
```

### Environment Variables Set on Spawn

| Variable | Value | Purpose |
|----------|-------|---------|
| `OLLAMA_KEEP_ALIVE` | `-1` | Keep all four models in VRAM indefinitely |
| `OLLAMA_RUNNERS_DIR` | `Contents/Resources/ollama/` | Find `llama-server` and `llama-quantize` |

### Pull Resumption

Ollama v0.32.x cannot resume from `-partial-*` blob files left by an interrupted
multi-part download. If a pull returns `{"error":"EOF"}` at the manifest stage, the
cause is corrupted partial blobs in `~/.ollama/models/blobs/`. The fix: delete all
`*-partial*` files and retry.

The `OllamaClient.pullModel` stream properly:
- Buffers partial lines across chunk boundaries
- Detects `{"error":"..."}` and throws `HttpException`
- Flushes remaining buffer on stream close
- Recognises all intermediate status strings (`pulling layer`, `verifying sha256 digest`,
  `writing manifest`, `removing any unused layers`, `success`)

---

## 9. Resource Monitoring

`ResourceMonitor` runs in the background during the resource-gate phase:

- **Poll interval:** 2 seconds
- **Free RAM (macOS):** `vm_stat` — sums free + inactive + speculative pages × page size (16 384 B on Apple Silicon)
- **Free RAM (Windows):** `WMIC OS get FreePhysicalMemory` (KB)
- **Top processes:** `ps -axo rss,comm` sorted by RSS, filtered for >100 MB, AI processes highlighted
- **Thresholds:**
  - `< 16 GB` free → critical red banner
  - `< 24 GB` free → warning orange banner + ResourceGateScreen
  - `≥ 20 GB` free → auto-provision (start Ollama + re-check models → advance)

---

## 10. Avatar System

The avatar system is plugin-style: types are registered at app startup and looked up by
string key. This allows new avatar types to be added without modifying call sites.

```dart
AvatarRegistry.register('energyOrb', (state, name, size) => EnergyOrbAvatar(...));
AvatarRegistry.build('energyOrb', state: AvatarState.thinking, characterName: 'DEEP', size: 80);
```

`EnergyOrbAvatar` uses a `CustomPainter` (`OrbPainter`) that draws concentric animated
rings with character-specific colours:

| Character | Primary colour |
|-----------|--------------|
| WATSON    | `#3b82d4` (IBM blue) |
| DEEP      | `#7c5cd8` (IBM indigo) |
| NOVA      | `#F59E0B` (amber) |
| SAGE      | `#EF4444` (red) |

---

## 11. Session Management

Each session produces a plain-text transcript at:
```
~/Documents/deepThink/sessions/<session-name>_YYYY-MM-DD_HH-MM-SS.txt
```

The file is opened before `engine.start()` fires so no messages are ever missed on the
broadcast stream. `SessionManager` owns the `IOSink` lifecycle — `endSession()` is the
only place the sink is closed, preventing double-close hangs.

`AppStats` (in-memory, not persisted) tracks cumulative totals for the current process
lifetime: sessions started, messages exchanged, tokens generated.

`ParticipantPrefs` persists the last-used model and system prompt for each character to
`~/Documents/deepThink/participant_prefs.json`. Loaded automatically when
`StartupConfigScreen` opens — so a returning user's choices are pre-filled every time.

---

## 12. Data Flow Diagram

```
User types message
        │
        ▼
UserInputBar.onSubmit(text)
        │
        ▼
ConversationEngine.injectUserMessage(userName, text)
        │
        ▼
ConversationLog.append(Message(isUser: true))
        │
        ├──────────────────────────────────────────────────────┐
        │ messageStream broadcast                              │
        ▼                                                      ▼
InferenceWorker[WATSON]                          InferenceWorker[SAGE]
  _pendingIsUserMessage = true                     forceRespond = true (not inferencing)
  (was inferencing)                                       │
        │                                                  ▼
        │                                     Timer(jitter 200–800ms)
        │                                                  │
        │                                                  ▼
  (current inference finishes)                OllamaClient.generateStream(
        │                                       model: 'mistral:7b',
        ▼                                       messages: [..., forceRespondReminder]
  Timer(jitter, forceRespond=true)            )
        │                                                  │
        ▼                                                  ▼ tokens
  OllamaClient.generateStream(...)          InferenceEvent(token: "I think...")
        │                                                  │
        ▼                                                  ▼
  InferenceEvent(token: "...")        ConversationEngine.eventStream
                                                           │
                                                           ▼
                                            MainScreen._handleEvent
                                                           │
                                                           ▼
                                            _QuadrantState.tokenController.add(token)
                                                           │
                                                           ▼
                                               AiQuadrant live text display
```

---

## 13. Key Design Decisions

### Why not `async` package for StreamGroup?
The core layer has zero third-party dependencies. `StreamGroup` is a 30-line
internal implementation that avoids pulling in `package:async` just for one utility.

### Why `ProcessStartMode.normal` for Ollama?
`detachedWithStdio` was the original choice for fire-and-forget, but it makes stdout/stderr
unreadable. Switching to `normal` lets us forward Ollama's logs to the Flutter console via
`print('[ollama] ...')` which is invaluable for diagnosing model loading and inference issues.

### Why disable App Sandbox?
`Process.start()` is completely blocked inside a sandboxed macOS app. deepThink is
distributed outside the Mac App Store (direct DMG), so the sandbox requirement does not
apply. Both `DebugProfile.entitlements` and `Release.entitlements` set
`com.apple.security.app-sandbox = false`. The Ollama binary itself is properly signed by
Ollama Inc. (TeamIdentifier `3MU9H2V9Y9`).

### Why `OLLAMA_KEEP_ALIVE=-1`?
All four models must remain loaded in VRAM simultaneously for instant parallel inference.
The default 5-minute keep-alive would unload models between turns, requiring 30–60 s
reload times. With `-1` they stay loaded indefinitely until the process exits.

### Why `freeRamGb` instead of just `totalRamGb`?
On a machine with 64 GB RAM you might have 45 GB consumed by other processes (browsers,
AI tools, Xcode). Using total RAM to decide whether to start inference would always return
"fine" — but then Ollama would swap to disk and freeze or crash. Free RAM is the correct
signal.

---

## 14. Known Constraints

| Constraint | Notes |
|-----------|-------|
| macOS only (officially) | Windows build works but requires self-compilation; no binary release yet |
| No resume for partial Ollama downloads | Ollama v0.32.x limitation — delete `-partial-*` blobs and retry |
| 4-participant limit | Hardcoded in `Participant.defaults()` and the 2×2 UI grid |
| No conversation replay | Sessions are saved as plain-text transcripts; no UI to replay them yet |
| Token counting is approximate | `text.length ~/ 4` — accurate enough for 90% threshold triggering |
| Git LFS required | `macos/Runner/ollama/*.metallib` files are 127 MB and 158 MB |
| `ConversationEngine` is single-use | `stop()` closes the internal `ConversationLog` stream; a new instance must be created on every Start |
