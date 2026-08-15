# deepThinkER — Architecture Reference

> **Version:** 1.1.0 · **Platform:** macOS · **Stack:** Flutter / Dart + Ollama

*This document describes every subsystem in deepThinkER — how it works, why it was designed that way, and how the pieces connect. It is intended as a complete technical reference for contributors and for anyone curious about how four AI minds hold a real conversation.*

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Startup & Lifecycle](#3-startup--lifecycle)
4. [Conversation Engine](#4-conversation-engine)
5. [Inference Workers](#5-inference-workers)
6. [Context Window Management](#6-context-window-management)
7. [Tool Call Framework](#7-tool-call-framework)
8. [Trust System](#8-trust-system)
9. [Network & Rate Limiting](#9-network--rate-limiting)
10. [Character Memory](#10-character-memory)
11. [Mood Engine](#11-mood-engine)
12. [Relationship Matrix](#12-relationship-matrix)
13. [System Prompt Builder](#13-system-prompt-builder)
14. [Session Management & Persistence](#14-session-management--persistence)
15. [Analytics & Audit](#15-analytics--audit)
16. [Research Mode](#16-research-mode)
17. [Security & Safety](#17-security--safety)
18. [UI Architecture](#18-ui-architecture)
19. [Ollama Integration](#19-ollama-integration)
20. [Hardware Detection & Resource Monitoring](#20-hardware-detection--resource-monitoring)
21. [Data Storage Layout](#21-data-storage-layout)
22. [Testing Strategy](#22-testing-strategy)
23. [Key Design Decisions & Trade-offs](#23-key-design-decisions--trade-offs)

---

## 1. Design Principles

### Pure-Dart Core

The single most important architectural rule is the **zero-Flutter-import constraint** on `lib/core/`. Every file in the core layer is plain Dart — no `package:flutter` imports, no `BuildContext`, no `Widget`. This separation means:

- All core logic is testable with `dart test` — no test harness, no widget tree, no mocks for Flutter internals
- The core can be extracted and re-used in a CLI, a server, or a different UI framework without modification
- State flows in one direction: core emits events via `dart:async` streams; the UI layer subscribes

Flutter belongs exclusively in `lib/ui/`.

### No State Management Packages

deepThinkER uses zero state management packages (no Provider, Riverpod, Bloc, etc.). State is managed through:
- `dart:async` `StreamController` / `Stream` for reactive data flows
- Vanilla `setState()` in `StatefulWidget`s for local UI state
- Singleton service objects (e.g. `TrustManager`, `ToolRegistry`) for shared mutable state

This is a deliberate choice to minimise dependency surface and keep the architecture comprehensible without framework knowledge.

### Bundled Runtime

Ollama is bundled inside the `.app` bundle rather than requiring a separate installation. This means the app is genuinely self-contained — download, drag to Applications, launch. No homebrew, no PATH setup, no separate Ollama installation.

The bundled binary lives at:
```
deepThinkER.app/Contents/Resources/ollama/ollama
```

### Minimal Dependencies

The `pubspec.yaml` has fewer than 10 runtime dependencies, all with narrow purposes. No ORM, no HTTP framework, no serialisation code-gen, no JSON annotation library. The app uses `dart:convert` directly.

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           deepThinkER Process                               │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        lib/ui/  (Flutter layer)                       │  │
│  │                                                                        │  │
│  │  MainScreen ◄── QuadrantGrid ◄── AiQuadrant (×4)                      │  │
│  │      │                │               │                               │  │
│  │      │           TokenCounter    SearchActivityEntry                  │  │
│  │      │                │               │                               │  │
│  │  SettingsScreen   MoodIndicator   NetworkToggle                       │  │
│  │  AnalyticsScreen  RelationshipMatrixWidget                            │  │
│  │  ResearchModeScreen  MemoryPanelScreen  AuditLogScreen                │  │
│  └───────────────────────────┬──────────────────────────────────────────┘  │
│                               │  subscribes to streams / calls methods      │
│  ┌────────────────────────────▼─────────────────────────────────────────┐  │
│  │                       lib/core/  (pure Dart layer)                    │  │
│  │                                                                        │  │
│  │  ConversationEngine                                                    │  │
│  │    ├── InferenceWorker (WATSON)                                        │  │
│  │    ├── InferenceWorker (DEEP)                                          │  │
│  │    ├── InferenceWorker (NOVA)                                          │  │
│  │    └── InferenceWorker (SAGE)                                          │  │
│  │          │                                                             │  │
│  │          ├── OllamaClient  ──── HTTP ──► Ollama subprocess            │  │
│  │          ├── ContextManager                                            │  │
│  │          ├── SystemPromptBuilder                                       │  │
│  │          │     ├── TrustManager                                        │  │
│  │          │     ├── MoodEngine                                          │  │
│  │          │     ├── RelationshipMatrix                                  │  │
│  │          │     ├── MemoryStore                                         │  │
│  │          │     └── UserPersona                                         │  │
│  │          └── ToolCallInterceptor                                       │  │
│  │                ├── ToolRegistry                                        │  │
│  │                │     ├── NetworkSearchTool ─► NetworkFetcher           │  │
│  │                │     ├── NetworkFetchTool  ─► NetworkFetcher           │  │
│  │                │     ├── RememberTool      ─► MemoryStore              │  │
│  │                │     ├── RecallTool        ─► MemoryStore              │  │
│  │                │     ├── FileReadTool      ─► FileSystem               │  │
│  │                │     ├── FileWriteTool     ─► FileSystem               │  │
│  │                │     ├── CalcTool                                      │  │
│  │                │     └── ImageTool         ─► VisionClient             │  │
│  │                ├── RateLimiter                                         │  │
│  │                ├── AuditLog                                            │  │
│  │                ├── ContentFilter                                       │  │
│  │                └── InjectionGuard                                      │  │
│  │                                                                        │  │
│  │  SessionManager ◄── ConversationLog                                   │  │
│  │  SessionAnalytics                                                      │  │
│  │  RelationshipAnalyser                                                  │  │
│  │  ResourceMonitor                                                       │  │
│  │  OllamaHealthMonitor                                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────┐                                     │
│  │  Ollama subprocess (bundled)      │  ← spawned by OllamaLauncher        │
│  │  PORT 11434                       │  ← HTTP REST API                    │
│  │  Models: mistral, llama3,         │                                     │
│  │          gemma2, phi3, llava      │                                     │
│  └───────────────────────────────────┘                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Startup & Lifecycle

### Startup Sequence

```
main()
  │
  ├── AppPaths.init()               // resolve Application Support dir
  ├── ToolRegistry.instance         // singleton created
  ├── register all AgentTools       // SEARCH, FETCH, REMEMBER, RECALL, etc.
  ├── OllamaLauncher.launch()       // spawn bundled Ollama process
  ├── OllamaHealthMonitor.start()   // begin 10s ping loop
  ├── SettingsProvider.load()       // load settings.json
  ├── AppLifecycleManager.init()    // register SIGTERM/SIGINT handlers
  │
  └── runApp(DeepThinkErApp)
        │
        └── WelcomeScreen
              │
              ├── HardwareDetector.detect()    // RAM, GPU, CPU
              ├── ModelManager.checkInstalled() // which models are present
              │
              ├── [RAM < 20 GB]  ──► ResourceGateScreen
              ├── [Models missing] ──► FirstLaunchScreen (download flow)
              └── [All OK] ──► StartupConfigScreen
                                  │
                                  └── [User presses Start] ──► MainScreen
```

### AppLifecycleManager

Registers `ProcessSignal.sigterm` and `ProcessSignal.sigint` handlers. On receipt, calls the registered `onShutdown` callback, which:
1. Stops all inference workers
2. Flushes the session log
3. Calls `OllamaLauncher.stop()` to cleanly terminate the Ollama subprocess

On Windows, only SIGINT (Ctrl+C) is available; SIGTERM is a no-op.

### AppPaths

`lib/core/paths/app_paths.dart` is the **single source of truth** for all on-disk paths. No other file hard-codes a path. All paths are computed relative to the platform-specific Application Support directory:

- **macOS:** `~/Library/Application Support/deepThinkER/`
- **Windows:** `%APPDATA%\deepThinkER\`

This avoids the macOS TCC privacy prompt that fires when any app touches `~/Documents` without the `NSDocumentsFolderUsageDescription` entitlement.

---

## 4. Conversation Engine

`lib/core/conversation/conversation_engine.dart`

`ConversationEngine` is the top-level orchestrator. It owns:
- Four `InferenceWorker` instances (one per character)
- The shared `ConversationLog`
- Four `ContextManager` instances (one per character)
- The `ToolCallInterceptor`

### Lifecycle

```dart
engine.start()   // begins inference loops on all workers
engine.pause()   // signals workers to hold after current turn
engine.resume()  // clears hold signal
engine.stop()    // cancels all workers, disposes streams
```

### Event Stream

```dart
Stream<InferenceEvent> get eventStream
```

A **merged broadcast stream** of all four workers' output. The UI subscribes to this single stream and routes tokens to the correct quadrant based on `event.characterName`.

### User Message Injection

```dart
engine.injectUserMessage(String content)
```

Creates a `Message` with `role = user` and appends it to `ConversationLog`. All four workers observe the log; the next available worker (based on jitter + turn priority) will respond to it.

### Token Count Access

```dart
int tokenCountFor(String characterName)
int contextWindowFor(String characterName)
```

Delegated to the appropriate `ContextManager`. Used by the UI to drive the per-quadrant token counter.

---

## 5. Inference Workers

`lib/core/conversation/inference_worker.dart`

Each `InferenceWorker` runs an independent async loop. The loop:

1. **Monitors** `ConversationLog` for new messages
2. **Decides** whether to respond (based on turn priority and randomised jitter)
3. **Builds** the system prompt via `SystemPromptBuilder`
4. **Calls** `OllamaClient.generateStream()` with the context window
5. **Streams** tokens back via `InferenceEvent.token`
6. **Post-processes** the complete response via `ToolCallInterceptor`
7. **Appends** the complete response as a new `Message` to the log
8. **Repeats**

### Jitter & Pass Mechanic

Each worker applies a random delay (`50ms – 1500ms`) before responding. This prevents all four characters from attempting to respond simultaneously and creates a more natural conversational rhythm.

A character "passes" if:
- Their response buffer is empty after the jitter period (the model chose not to respond)
- The response is a single whitespace or trivially short

Passes are tracked to prevent one character dominating the conversation.

### Pending State

During inference, the worker emits `InferenceEvent.thinking` events. The UI renders these as the animated "thinking" indicator in the quadrant header.

### Context Window

Each worker maintains its own view of the conversation. `ContextManager` provides the message list to pass to Ollama, truncating to stay within the model's context window. See [Section 6](#6-context-window-management).

### Tool Call Integration

After streaming completes, the full response buffer is passed to `ToolCallInterceptor.process()`. If a tool tag is found, the interceptor:
1. Validates trust level
2. Checks rate limits
3. Executes the tool
4. Injects the result as a `Message(role: system)` into the log, visible only to this worker

---

## 6. Context Window Management

`lib/core/context/context_manager.dart`

Each character has their own `ContextManager` because different models have different context windows and different histories.

### Token Estimation

Token counts are estimated using a rough `characters / 4` heuristic (a standard approximation for English text with common punctuation). This is deliberately conservative — actual token counts vary by model and tokeniser, but we prefer to reset slightly early rather than send a request that overflows the context.

### Context Tiers

Hardware detection informs context window size per character:

| RAM Available | Context Window |
|:---:|:---:|
| ≥ 32 GB | 8,192 tokens |
| ≥ 24 GB | 4,096 tokens |
| < 24 GB | 2,048 tokens |

High-context models (`phi3:14b`) always use 8,192 regardless of RAM tier, because they are designed for larger contexts.

### Reset Behaviour

When a character approaches their context limit (> 85% full), `ContextManager` performs a **soft reset**:

1. The oldest messages are dropped from the context window
2. A brief **seed message** is prepended summarising:
   - The character's name, role, and core personality
   - The last 5 memory entries (from `MemoryStore`)
   - The current trust score and tier
   - A summary of the most recent topic
3. The conversation continues seamlessly — the character doesn't "forget" in the way a simple truncation would cause

---

## 7. Tool Call Framework

`lib/core/tools/`

### AgentTool Interface

```dart
abstract interface class AgentTool {
  String get tag;                   // e.g. 'SEARCH'
  bool get enabled;
  String get disabledMessage;
  bool get requiresTrust;
  TrustTier get minimumTrust;
  Future<ToolResult> execute(String argument, String characterName);
}
```

Every tool implements this interface. There is no other contract.

### ToolRegistry

A singleton `Map<String, AgentTool>` keyed by lowercase tag. Registered at startup in `main.dart`. Resolved case-insensitively:

```dart
registry.register(const NetworkSearchTool());
registry.resolve('search')  // returns NetworkSearchTool
```

A test-friendly `ToolRegistry.instanceForTesting()` factory creates an isolated instance with no shared state.

### ToolCallParser

Scans text for `[TAG: argument]` patterns using a single regex. Returns a list of `ParsedToolCall(tag, argument)`. Multiple tags in a single response are all returned; the interceptor executes the **first** one found.

### ToolCallInterceptor

`lib/core/tools/tool_call_interceptor.dart`

The interceptor sits between `InferenceWorker` and the `ConversationLog`. After each completed response:

```
response buffer
    │
    ├── InjectionGuard.sanitise()          // strip any injected tags from user content
    ├── ContentFilter.scan()               // check for flagged content
    ├── ToolCallParser.parse()             // find [TAG: argument] patterns
    │
    ├── [no tags found] ──► done
    │
    └── [tag found]
          │
          ├── registry.resolve(tag)         // look up the tool
          ├── [tool disabled] ──► inject disabled message
          ├── [trust too low] ──► inject trust error message
          ├── RateLimiter.request()         // check sliding window
          ├── [rate limited] ──► inject rate limit message, penalise trust
          │
          ├── tool.execute(argument, characterName)
          │     └── returns ToolResult
          │
          ├── AuditLog.append(entry)        // record to audit.ndjson
          │
          └── ConversationLog.append(      // inject result
                Message(
                  role: system,
                  content: result.output,
                  visibleTo: [characterName],  // search results private to requester
                ))
```

### ToolResult

```dart
class ToolResult {
  final bool success;
  final String tag;
  final String output;
  final String characterName;
  final DateTime timestamp;
}
```

### Tool Implementations

#### NetworkSearchTool
- Calls `NetworkFetcher.search(query)` → DuckDuckGo HTML search
- URL: `https://html.duckduckgo.com/html/?q=<encoded_query>`
- Response truncated to 12,000 characters
- Requires trust tier: Low

#### NetworkFetchTool
- Calls `NetworkFetcher.fetch(url)` → raw HTTP GET
- URL must pass `DomainWhitelist` check (if whitelist is non-empty)
- Response truncated to 12,000 characters
- Requires trust tier: Low

#### RememberTool
- Creates a `MemoryEntry` and calls `MemoryStore.add(entry)`
- `MemoryEntry` is tagged with the character name and a UUID
- Returns confirmation message

#### RecallTool
- Calls `MemoryStore.query(topic, characterName)`
- Returns keyword-matched entries sorted newest-first
- Empty result returns a graceful "nothing found" message

#### FileReadTool
- Resolves path against workspace root via `FileToolConfig.resolveSafe()`
- Path traversal (e.g. `../`) is blocked — returns error
- Content truncated to 8,000 characters
- Requires trust tier: Mid

#### FileWriteTool
- Same safe-path resolution as FileReadTool
- Does not overwrite existing files by default
- Requires trust tier: High

#### CalcTool
- Hand-rolled recursive descent parser — supports `+`, `−`, `*`, `/`, `^`, `()`, `sqrt()`, `abs()`
- No `eval()`, no external dependencies, no exec
- Returns `[CALC_RESULT: value]` or a parse error

#### ImageTool
- Resolves image filename against workspace directory
- Encodes as Base64 and calls `VisionClient.analyse()`
- Vision model: `llava:7b` (loaded on demand, not always running)
- `ImageWatcher` monitors the workspace for new image files and notifies the UI

#### ShellTool *(Stub)*
- Registered in the registry so the interceptor can acknowledge `[SHELL:]` tags
- `execute()` always returns `ToolResult.disabled`
- Full interface defined in `ShellConfig` for future implementation

---

## 8. Trust System

`lib/core/trust/`

### TrustScore

```dart
class TrustScore {
  final String characterName;
  final double value;          // 0.0 – 100.0
  final TrustTier tier;        // low | mid | high
}

enum TrustTier { low, mid, high }
```

Tier boundaries: `low` → [0, 33], `mid` → [34, 66], `high` → [67, 100].

### TrustManager

Singleton. Manages scores for all four characters.

```dart
TrustManager.instance
  .setScore(characterName, score)
  .applyDelta(characterName, delta)
  .scoreFor(characterName) → TrustScore
  .tierFor(characterName) → TrustTier
  .eventStream → Stream<TrustEvent>   // emits on every change
```

**Automatic decay/gain loop** — started when the conversation starts, stopped when it stops:
- Every minute: `+1.0` (gain) applied to all characters
- Every minute: `−0.5` (decay) applied to all characters → net `+0.5 per minute`
- This models the idea that trust builds slowly but requires sustained good behaviour

**Event-driven penalties:**
- Network toggle off: `−15`
- Network toggle on: `+5`
- Rate limit violation: `−2`

### TrustPersistence

Saves/loads trust scores as JSON to `trust.json`. Called at session start (load) and session end (save). Trust accumulates across sessions.

### TrustEvent

```dart
class TrustEvent {
  final String characterName;
  final TrustScore previous;
  final TrustScore current;
  final TrustEventReason reason;
  final DateTime timestamp;
}
```

Emitted on every score change. Consumed by:
- `SessionAnalytics` (for sparklines)
- UI trust badge (colour coding)

---

## 9. Network & Rate Limiting

`lib/core/network/`

### NetworkFetcher

Low-level HTTP client. Two public methods:

```dart
Future<FetchResult> search(String query)
Future<FetchResult> fetch(String url)
```

Both return a `FetchResult(success, content, statusCode, url, bytes)`. Content is stripped of unnecessary whitespace and truncated.

The search endpoint uses DuckDuckGo's HTML interface (`html.duckduckgo.com`) rather than their API — no API key required, and the HTML format is more parseable for truncated injection.

### DomainWhitelist

An opt-in list of allowed hostnames for `[FETCH:]` calls. When the list is empty, all domains are permitted. When non-empty, only listed domains pass. Managed via Settings → Safety → Domain Whitelist. Persisted to `whitelist.json`.

### RateLimiter

`lib/core/network/rate_limiter.dart`

Implements a **sliding-window** rate limiter. For each character:
- Maintains a queue of request timestamps
- Before each request: drops timestamps older than 60 seconds
- If queue length ≥ tier limit: request denied, `TrustManager.applyDelta(−2)` applied
- If global count (all characters) ≥ global cap: same

Tier limits (requests per minute):

| Tier | Limit |
|:---:|:---:|
| Low | 1 |
| Mid | 3 |
| High | 5 |

Global cap: configurable in settings (default 10/min).

### ProactiveInjector

An optional background agent that searches on behalf of characters without them explicitly requesting it. Per-character timer triggers based on trust tier. On each tick:

1. Extracts top topics from the last 3 messages via `TopicExtractor`
2. Calls `RateLimiter.request()` — if denied, silently skips
3. Calls `NetworkFetcher.search(topic)`
4. Injects result as an ephemeral system message
5. Emits `ProactiveInjectionEvent` to the UI

Controlled by the proactive injection toggle in Startup Config.

### TopicExtractor

Simple keyword extractor: splits messages to words, lowercases, removes stopwords, keeps words > 4 characters, returns top N by frequency. No ML dependencies.

---

## 10. Character Memory

`lib/core/memory/`

### MemoryEntry

```dart
class MemoryEntry {
  final String id;            // UUID v4
  final String characterName;
  final String content;
  final List<String> topicTags;
  final DateTime timestamp;
  final MemorySource source;  // explicit (REMEMBER) | observed
}
```

### MemoryStore

Per-character, in-memory store with a capacity cap (default 200 entries).

```dart
MemoryStore(characterName, capacity: 200)
  .add(entry)                   // adds, evicts oldest if over capacity
  .query(topic, charName) → List<MemoryEntry>  // keyword search
  .all → List<MemoryEntry>      // all entries, newest first
  .remove(id)                   // delete by UUID
  .stream → Stream<MemoryEntry> // emits on every add
```

Eviction strategy: FIFO (oldest entry removed when capacity is exceeded).

### MemoryPersistence

Reads/writes per-character memory stores to `memory/<CHARACTER>.json`. Called at session start (load) and session end (save). Memory accumulates across sessions indefinitely until manually deleted.

### MemoryQuery

Static utility class that implements the keyword search logic. Case-insensitive substring matching across `content` and `topicTags`.

### Context Reset Integration

`ContextManager` calls `MemoryStore.all` during a context reset and prepends a brief summary of the five most recent entries to the seed message. This ensures characters have access to their most recent memories even after a context flush.

---

## 11. Mood Engine

`lib/core/mood/`

### MoodScore

```dart
class MoodScore {
  final String characterName;
  final double value;         // 0.0 – 100.0
  final MoodState state;      // engaged | neutral | withdrawn | agitated | excited
}

enum MoodState { engaged, neutral, withdrawn, agitated, excited }
```

State thresholds: `agitated` [0, 20], `withdrawn` [21, 35], `neutral` [36, 65], `engaged` [66, 80], `excited` [81, 100].

### MoodEngine

One `MoodEngine` instance per character. Subscribes to `ConversationLog.stream` and applies score deltas based on message events:

| Event | Delta |
|-------|:-----:|
| Character directly addressed | +5 |
| Agreement detected (keywords) | +4 |
| Contradiction detected | -5 (WATSON/DEEP), -8 (NOVA/SAGE) |
| Ignored for 5+ consecutive messages | -3 per streak |
| Positive citation of this character | +4 |

### MoodConfig

Per-character sensitivity multipliers. SAGE and NOVA have higher sensitivity (1.6×); WATSON and DEEP are calmer (0.7×). Deltas are scaled before application.

### System Prompt Integration

Every call to `SystemPromptBuilder.build()` includes the character's current mood as a descriptor appended to the prompt. This means mood genuinely shapes the model's response — a character in an "agitated" state will generate more terse, challenging outputs.

---

## 12. Relationship Matrix

`lib/core/relationships/`

### RelationshipScore

```dart
class RelationshipScore {
  final String characterA;
  final String characterB;
  final int score;           // -100 to +100
  final Disposition disposition;
}

enum Disposition { hostile, sceptical, neutral, respectful, allied }
```

Neutral band: [-19, +19]. Only scores outside this band are injected into system prompts (to keep prompt sizes manageable).

### RelationshipMatrix

Holds all six character pairs. Provides:

```dart
RelationshipMatrix()
  .scoreFor(charA, charB) → RelationshipScore
  .applyDelta(charA, charB, delta)
  .allPairs → List<RelationshipScore>
  .stream → Stream<RelationshipScore>  // emits on change
```

Scores are clamped to [-100, 100].

### RelationshipAnalyser

`lib/core/relationships/relationship_analyser.dart`

Subscribes to `ConversationLog.stream` and applies relationship deltas based on detected patterns:

| Pattern | A→B Delta |
|---------|:---------:|
| A agrees with B (keyword detection) | +3 |
| A contradicts B (keyword detection) | -2 |
| A cites B positively | +2 |
| A and B both ignored for 5+ minutes | -1 |

### System Prompt Integration

`SystemPromptBuilder` calls `matrix.allPairs` filtered to pairs involving `self`. Non-neutral scores are rendered as:
- `"You feel RESPECTFUL toward WATSON."` (score +20 to +59)
- `"You and NOVA are ALLIED."` (score +60 to +100)
- `"You are SCEPTICAL of DEEP."` (score -59 to -20)
- `"You are HOSTILE to SAGE."` (score -100 to -60)

This is injected into the system prompt so the LLM can authentically express these attitudes.

### RelationshipPersistence

Saves/loads the full matrix to `relationships.json`. Relationships persist across sessions — the characters build genuine history over time.

---

## 13. System Prompt Builder

`lib/core/conversation/system_prompt_builder.dart`

`SystemPromptBuilder.build()` is called on every inference cycle. It assembles the complete system prompt from multiple sources:

```
[Core identity block]
  Character name, role, personality description,
  IBM namesake reference,
  Conversation rules (no name prefix, pass mechanic, stay in character)

[Persona block]         ← UserPersona (if set by user)
[Mood block]            ← MoodEngine (if non-neutral)
[Relationship block]    ← RelationshipMatrix (non-neutral pairs only)
[Tool block]            ← ToolRegistry (if tools enabled)
[Hardware block]        ← HardwareDetector (context window tier)
```

The tool block is particularly important for the internet access feature — it includes explicit instructions on **when and how** to use `[SEARCH:]` and `[FETCH:]` tags, motivating the model to actually use them rather than treating them as background instructions.

---

## 14. Session Management & Persistence

`lib/core/session/`

### Session

Immutable value object:

```dart
class Session {
  final String id;           // UUID
  final String name;         // e.g. "thetaByte"
  final List<Participant> participants;
  final String logFilePath;
  final DateTime startTime;
  DateTime? endTime;
  bool isActive;
  int totalMessages;
  int totalTokens;
  int totalUserMessages;
}
```

### SessionManager

Handles the full session lifecycle:
1. `createSession()` — generates UUID, dice-rolls a name via `NameGenerator`, creates log file
2. `recordMessage()` — appends to the plain-text log file in real time
3. `endSession()` — records end time, saves session index, flushes analytics
4. `loadSessions()` — reads the session index from `stats.json`

### NameGenerator

Produces names in `[adjective][Noun]` format — e.g. `thetaByte`, `lateralPerception`, `thorKitten`. The lists contain hundreds of adjectives and nouns drawn from science, philosophy, and technology vocabulary.

### ParticipantPrefs

Saves/loads per-character model ID and master prompt overrides to `participant_prefs.json`. Loaded at startup to restore the user's last configuration. **Important:** saved prefs override default master prompts — if the default prompts are updated in a new version, users need to hit "Reset to Defaults" in the Startup Config screen to pick them up.

### SessionLoader

Parses a saved session log file back into a `ConversationLog`. Used for session replay and post-session analytics.

### AppStats

Cumulative lifetime statistics: total sessions, total messages, total tokens, total bytes fetched. Persisted to `stats.json` and displayed in the About screen.

---

## 15. Analytics & Audit

### SessionAnalytics

`lib/core/analytics/session_analytics.dart`

Records timestamped events throughout a session:

```dart
enum AnalyticsEventType {
  message,         // who spoke and when
  trustSnapshot,   // per-character trust score (every 60s)
  toolCall,        // tag, character, rate-limited flag
  moodChange,      // state transition
  rateLimited,     // per-character violation
}
```

Events are accumulated in memory and flushed to `analytics/<session>.json` every 60 seconds and on session end.

**Analytics UI** (post-session `AnalyticsScreen`):
- **Message heatmap** — a timeline grid showing which character spoke during each minute bucket
- **Trust sparklines** — per-character trust score plotted over time
- **Tool call table** — sortable/filterable log of every search, fetch, recall
- **Mood trajectory** — mood state transitions annotated on a timeline

### AuditLog

`lib/core/audit/`

Every tool execution is recorded in an **append-only NDJSON file** (`audit.ndjson`). This is separate from analytics — the audit log is permanent, never automatically deleted, and records:

```dart
class AuditEntry {
  final String id;                      // UUID
  final String sessionName;
  final String characterName;
  final String toolTag;
  final String argument;
  final bool wasRateLimited;
  final bool wasDisabled;
  final int responseBytes;
  final bool injectionAttemptDetected;
  final DateTime timestamp;
}
```

The `AuditLogScreen` renders the audit log as a sortable, filterable table with CSV export.

---

## 16. Research Mode

`lib/core/research/`

### ResearchEngine

Orchestrates a structured, multi-phase autonomous research session.

```dart
ResearchEngine(
  engine: conversationEngine,
  characterNames: ['WATSON', 'DEEP', 'NOVA', 'SAGE'],
  config: ResearchConfig(
    gatherPhaseDuration: Duration(minutes: 5),
    debatePhaseDuration: Duration(minutes: 3),
    synthesisTimeout: Duration(minutes: 2),
  ),
)
```

### ResearchSession

Tracks the state of an active research session:

```dart
class ResearchSession {
  final String topic;
  final DateTime startTime;
  ResearchPhase phase;
  final List<String> synthesisStatements;
  final List<String> sourceUrls;
}

enum ResearchPhase { gathering, debating, synthesising, complete }
```

### Phase Transitions

Each phase is driven by a `Timer`. On expiry:
1. The current timer is cancelled
2. A phase-specific directive is injected via `ConversationEngine.injectUserMessage()`
3. `_phaseController.add(ResearchPhaseEvent(...))` notifies the UI
4. The next phase timer is started

The `synthesising` phase ends early if all four characters submit synthesis statements (short non-tool-call responses) before the timeout.

### ReportGenerator

Generates a Markdown report at the end of the `synthesising` phase:

```markdown
# Research Report: <topic>

**Session:** <name>  **Generated:** <timestamp>

## Synthesis Statements
- WATSON: ...
- DEEP: ...
...

## Sources
- https://...
- https://...
```

Source URLs are extracted from `[SEARCH: query]` and `[FETCH: url]` argument strings accumulated during the session.

---

## 17. Security & Safety

### InjectionGuard

`lib/core/security/injection_guard.dart`

Before user input is injected into the conversation, `InjectionGuard.sanitise()` scans it for patterns that match registered tool tags (e.g. `[SEARCH:`, `[FETCH:`). Found patterns are escaped so the `ToolCallInterceptor` will not execute them — preventing a user from forcing a character to execute a tool call by embedding the tag in their message.

### ContentFilter

`lib/core/security/content_filter.dart`

Scans both user input and character responses for category keyword matches. Categories (e.g. `profanity`, `violence`, `personal_information`) are defined in asset text files loaded at startup. Flagged content can be:
- Logged (default)
- Replaced with a placeholder
- Blocked (response discarded)

Configurable per-category in Settings → Safety.

### Sandboxing

The macOS App Sandbox is **disabled** in the release entitlements. This is required because:
- The app spawns the Ollama subprocess (`Process.start()`)
- The subprocess listens on port 11434 (`com.apple.security.network.server`)
- Sandboxed apps cannot spawn arbitrary subprocesses

The trade-off is acknowledged: the app requests only the network entitlements it needs (`com.apple.security.network.client`), uses the `~/Library/Application Support` path to avoid TCC dialogs, and the audit log + content filter provide application-level controls.

---

## 18. UI Architecture

`lib/ui/`

### QuadrantGrid

The root UI component during a conversation. Renders four `AiQuadrant` widgets in a 2×2 layout. Provides scroll synchronisation across all four panels via a shared `_SyncScrollController`.

### AiQuadrant

One per character. Displays:
- Character name, model, and trust badge
- Mood indicator (emoji + label)
- Token counter bar (fills green → amber → red as context fills)
- Live search badge (🌐 when a search is in progress)
- Scrollable message history
- Thinking indicator (animated dots during inference)

### Message Rendering

Messages are rendered differently by role:
- `role: user` — right-aligned bubble, accent colour
- `role: assistant` — left-aligned, character colour, character name header
- `role: system` — collapsed by default; expandable for tool results/search responses

### SearchActivityEntry

A collapsible entry in the message list that represents a completed tool call. Shows:
- A one-line label: `🌐 Searched: "query"` or `📥 Fetched: url`
- Expandable body: the full truncated HTML/text response

### Token Counter

`lib/ui/widgets/token_counter/`

A horizontal bar that fills from left to right as the context window fills. Colour progression:
- Green: 0–60% full
- Amber: 60–85% full
- Red: 85–100% full

Updated on every `InferenceEvent.token` via the `ConversationEngine.tokenCountFor()` accessor.

### UserInputBar

The bottom input field. Contains:
- Multi-line text field
- Send button
- ⚙ settings shortcut button (inline — not a floating action button)

### AppTheme

`lib/ui/widgets/app_theme.dart`

Single source of truth for all colours and text styles. Dark theme only. Key colours:
- `AppColors.background` — `#0D0F14`
- `AppColors.surface` — `#1A1D26`
- `AppColors.accent` — `#3B8AFF`
- Per-character colours: WATSON blue, DEEP purple, NOVA green, SAGE amber

---

## 19. Ollama Integration

`lib/core/ollama/`

### OllamaLauncher

Spawns the bundled Ollama binary as a subprocess. The binary path is resolved relative to the app bundle:

```dart
// macOS
'<app>/Contents/Resources/ollama/ollama'

// Windows
'<install_dir>/ollama/ollama.exe'
```

The subprocess is started with `OLLAMA_HOST=127.0.0.1:11434` and its stdout/stderr are captured for the debug log.

If port 11434 is already in use (by a system Ollama installation), the `ExternalOllamaScreen` is shown with a "Kill & Retry" option.

### OllamaClient

All communication with Ollama is over its HTTP REST API:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `generateStream()` | `POST /api/chat` | Streaming inference |
| `listModels()` | `GET /api/tags` | Check installed models |
| `pullModel()` | `POST /api/pull` | Download model with progress |
| `deleteModel()` | `DELETE /api/delete` | Remove a model |
| `healthCheck()` | `GET /` | Ping Ollama |

The `generateStream()` method returns a `Stream<String>` — each event is a single token. The stream is consumed by `InferenceWorker` which accumulates tokens and forwards them as `InferenceEvent.token`.

### OllamaHealthMonitor

Pings Ollama every 10 seconds. On three consecutive failures, attempts up to 3 automatic restarts with 5-second backoff. Emits `OllamaHealthEvent` on status changes. Consumed by the status indicator in the top bar.

### ModelManager

Wraps model lifecycle:
- `checkInstalled()` — diff the registry models against `OllamaClient.listModels()`
- `pullModel(id, onProgress)` — progressive download with `ModelPullProgress` callbacks
- `deleteAllModelsAndData()` — remove all models and wipe app data (available in Startup Config)

### ModelRegistry

Static definition of the four character models + vision model:

```dart
static const List<ModelInfo> models = [
  ModelInfo(id: 'mistral:7b',  character: 'SAGE',   ramGb: 4.1),
  ModelInfo(id: 'llama3:8b',   character: 'NOVA',   ramGb: 4.7),
  ModelInfo(id: 'gemma2:9b',   character: 'WATSON', ramGb: 5.5),
  ModelInfo(id: 'phi3:14b',    character: 'DEEP',   ramGb: 8.2),
  ModelInfo(id: 'llava:7b',    special: 'vision',   ramGb: 4.7),
];
```

---

## 20. Hardware Detection & Resource Monitoring

### HardwareDetector

`lib/core/ollama/hardware_detector.dart`

Runs platform-specific subprocess calls to detect:
- **Total RAM** — `sysctl hw.memsize` (macOS) / WMIC (Windows)
- **Free RAM** — `vm_stat` (macOS) / WMIC `FreePhysicalMemory` (Windows)
- **GPU type** — `system_profiler SPDisplaysDataType` (macOS) → Apple Silicon / Intel / AMD / NVIDIA

The free RAM calculation on macOS uses:
```
free_bytes = (pages_free + pages_inactive + pages_speculative) × page_size
```

This is important because `pages_inactive` represents RAM that is currently holding cached data but can be reclaimed immediately — it should be counted as available for Ollama.

Returns a `HardwareInfo(totalRamGb, freeRamGb, gpuType, contextTier)`.

### ResourceMonitor

`lib/core/system/resource_monitor.dart`

Polls free RAM every `pollInterval` (default 5 seconds) and emits `ResourceSnapshot(freeRamGb, topProcesses)` via a broadcast stream. The `ResourceGateScreen` subscribes to this stream to show the live RAM gauge and auto-provision when sufficient RAM is available.

`topProcesses` is populated by parsing `ps aux` output sorted by RSS — gives the user actionable "close these apps" guidance.

---

## 21. Data Storage Layout

```
~/Library/Application Support/deepThinkER/
│
├── settings.json                   Global AppSettings
├── participant_prefs.json          Per-character model + prompt
├── stats.json                      Cumulative AppStats (sessions, tokens, bytes)
├── persona.json                    User persona text
├── trust.json                      Per-character trust scores
├── relationships.json              6-pair relationship matrix
├── whitelist.json                  Domain whitelist (FETCH tool)
├── audit.ndjson                    Append-only tool-call audit log
│
├── sessions/
│   └── <name>_<YYYY-MM-DD_HH-MM-SS>.txt     Plain-text conversation transcripts
│
├── memory/
│   ├── WATSON.json
│   ├── DEEP.json
│   ├── NOVA.json
│   └── SAGE.json
│
├── analytics/
│   └── <session-name>.json         Analytics events (heatmap, trust, tool calls)
│
├── reports/
│   └── <session-name>.md           Research mode Markdown reports
│
└── workspace/
    └── <user files>                File tool read/write workspace
```

All paths are resolved through `AppPaths` — never hard-coded elsewhere.

---

## 22. Testing Strategy

All tests are in `test/core/` and are **pure-Dart unit tests** — no widget test harness, no Flutter test utilities.

### Test Organisation

```
test/core/
├── audit/         — AuditEntry: toJson/fromJson, field preservation
├── context/       — ContextManager: token counting, reset thresholds
├── conversation/  — ConversationLog: append, stream, queries
│                    Message: UUID generation, fields
│                    Participant: defaults, model assignments
│                    SystemPromptBuilder: block assembly
│                    UserNameDetector: regex pattern matching
├── debug/         — DebugController: callback hooks, clamping
├── export/        — SessionExporter: zip assembly
│                    ConversationFormatter: role filtering
│                    MarkdownExporter: format output
├── memory/        — MemoryStore: cap, FIFO eviction, query matching
├── mood/          — MoodScore: state thresholds, tier transitions
├── network/       — DomainWhitelist: load, allow/deny logic
│                    RateLimiter: sliding window, trust penalty
│                    TopicExtractor: stopword filtering, frequency ranking
├── ollama/        — HardwareDetector: vm_stat parsing
│                    ModelRegistry: model list integrity
│                    Model pull progress parsing
├── relationships/ — RelationshipMatrix: pair operations, delta clamping
├── security/      — ContentFilter: keyword matching, replacement
│                    InjectionGuard: tag pattern sanitisation
├── session/       — Session: defaults, JSON round-trip
│                    AppStats: accumulation
│                    NameGenerator: output format
├── settings/      — AppSettings: serialisation round-trip
├── tools/         — CalcTool: expressions (+, -, *, /, ^, sqrt, abs)
│                    ToolCallParser: single/multiple/malformed tags
│                    ToolRegistry: register, resolve, case-insensitivity
└── trust/         — TrustScore: tier thresholds, clamping
```

### Design for Testability

- All core classes accept dependencies through constructors (no global singletons in business logic except where genuinely needed)
- `ToolRegistry.instanceForTesting()` creates an isolated registry with no shared state
- `MockOllamaClient` implements the same interface as `OllamaClient` and streams scripted responses for offline testing

---

## 23. Key Design Decisions & Trade-offs

### Why Bundled Ollama?

**Decision:** Bundle the complete Ollama runtime inside the `.app` rather than requiring a separate installation.

**Trade-off:**
- ✅ Zero-dependency user experience — download, install, run
- ✅ Version-locked — app and runtime always compatible
- ❌ Large binary (~285 MB of Metal shader libraries in Git LFS)
- ❌ macOS App Sandbox must be disabled (can't spawn subprocesses from sandbox)

### Why No Sandbox?

**Decision:** `Release.entitlements` has `com.apple.security.app-sandbox = false`.

**Rationale:** The macOS App Sandbox prevents spawning arbitrary subprocesses. Ollama must be spawned as a subprocess to run local models. This is an inherent tension — there is no way to bundle and spawn Ollama while staying sandboxed without Apple's explicit approval via a provisioning profile.

**Mitigations:** InjectionGuard, ContentFilter, domain whitelist, audit log, rate limiting.

### Why ~/Library/Application Support (not ~/Documents)?

**Decision:** All data written to `~/Library/Application Support/deepThinkER/` instead of `~/Documents/deepThinkER/`.

**Rationale:** macOS triggers a TCC (Transparency, Consent, and Control) privacy dialog the first time any app accesses `~/Documents`. This is jarring on first launch. `~/Library/Application Support` is the correct location for app data and requires no special entitlement.

### Why Pure-Dart Core?

**Decision:** `lib/core/` has zero Flutter imports.

**Rationale:** Testability. Flutter's widget test harness (`testWidgets`, `pumpWidget`) is significantly slower and more complex than `dart test`. By keeping core logic free of Flutter, the entire business logic test suite runs with `dart test` in under 2 seconds — no pump cycles, no widget tree, no async pump overhead.

**Side effect:** The core is genuinely portable. It could be re-used in a CLI companion tool, a server-side analytics exporter, or a different UI framework.

### Why Four Fixed Characters?

**Decision:** The app ships with four named, curated characters rather than arbitrary model slots.

**Rationale:** The IBM character references (Watson, Deep Blue, POWER, NL research) provide a coherent narrative frame. The hand-crafted master prompts for each character are carefully tuned to create genuinely distinct conversational personalities — not just temperature differences. The four characters are also specifically chosen to create productive conversational tension: Analyst vs. Visionary, Host vs. Challenger.

Users can override both the model and the master prompt per character — the fixed names are the frame, not a cage.

### Why DuckDuckGo HTML (not a Search API)?

**Decision:** Use `html.duckduckgo.com` (the plain-HTML DuckDuckGo interface) rather than a search API.

**Rationale:**
- Zero API key required — no user registration, no rate limit account, no secrets to manage
- The HTML interface strips JavaScript and heavy CSS, making the response more parseable
- DuckDuckGo's privacy stance aligns with the app's "no data leaving your machine" ethos

**Trade-off:** The raw HTML is noisier than a structured API response. The 12,000-character truncation handles this — the useful content is typically in the first portion.

---

*deepThinkER — Four AI Minds. One Conversation. Now with Extended Reach over the Internet!*
