# deepThinkER — Build Plan

## Top-Level Overview

`deepThinkER` (**deepThink Extended Reach**) is a **hard fork** of `deepThink` — the full
codebase is copied into a fresh directory and a new independent GitHub repo (`007Style/deepThinkER`)
with no upstream link to `007Style/deepThink`. The fork relationship is documented in the README
but the Git histories are separate from day one. This is intentional: deepThinkER modifies core
files that would conflict with any upstream pull.

deepThinkER adds controlled internet access for each AI character. Characters can request web
searches and page fetches mid-conversation using structured tool-call tags (`[SEARCH: query]`,
`[FETCH: url]`). The app intercepts these tags, fetches raw HTML via HTTP (no API keys),
truncates it to a safe token budget, and injects it back into the character's context so the
LLM can read and use it directly.

A **Trust** system (0–100 per character) governs how aggressively each character may use the
network. Trust is visible in the UI, decays slowly over time, rises with network-on uptime, and
drops when the user disables a character's network toggle. Trust tiers map directly to per-character
rate limits. A global cap applies across all characters combined.

The app also supports **proactive context injection** — the engine can feed relevant search results
into a character's context without the character explicitly requesting it, subject to the same rate
limits.

A **tool framework** provides a fully extensible, registry-based architecture for all non-network
tool calls. Today this covers shell access (stub only), but the same pattern accommodates any
future capability: file I/O, calendar, clipboard, APIs, system commands, etc. Each tool is a
registered, independently enable/disable-able plugin. The LLM uses the same `[TOOLNAME: argument]`
tag syntax for all tools. Adding a new tool in the future requires only: implementing the
`AgentTool` interface, registering it in `ToolRegistry`. No changes to the interceptor or
inference pipeline are needed.

**Base:** Hard-copy fork of `deepThink` v1.0.2+3 (from `007Style/deepThink`).
All `lib/core/` and `lib/ui/` conventions from deepThink carry forward.
New project lives at `./deepThinkER/`. Plan document at `./deepThinkER-plan.md`.

---

## Characters (inherited from deepThink)

| Name   | Personality          | Default Model |
|--------|----------------------|---------------|
| WATSON | The Analyst          | gemma2:9b     |
| DEEP   | The Strategist       | phi3:14b      |
| NOVA   | The Visionary        | llama3:8b     |
| SAGE   | The Challenger       | mistral:7b    |

---

## Trust System

| Trust Range | Tier | Search Rate Limit (per character) |
|-------------|------|-----------------------------------|
| 0–33        | Low  | 1 search / minute                 |
| 34–66       | Mid  | 3 searches / minute               |
| 67–100      | High | 5 searches / minute               |

- **Global cap:** configurable maximum across all 4 characters combined (default: 10/min)
- **Trust decay:** −0.5 points/minute while network toggle is ON (passive cost of access)
- **Trust gain:** +1.0 point/minute while network toggle is ON and no rate-limit violations
- **Toggle OFF:** immediate −15 point penalty; LLM notified via system message
- **Toggle ON:** immediate +5 point bonus; LLM notified via system message
- Trust is clamped to [0, 100] at all times
- Trust persists across sessions (saved to disk per character)

---

## Tool-Call Protocol

Characters emit structured tags in their response stream. The app intercepts these **before**
displaying the response to the user:

| Tag                  | Action                                          |
|----------------------|-------------------------------------------------|
| `[SEARCH: query]`    | Fetch `https://html.duckduckgo.com/html/?q=query`, truncate HTML, inject back |
| `[FETCH: url]`       | Fetch the given URL directly, truncate HTML, inject back |

- HTML is truncated to **12,000 characters** before injection (configurable)
- Injection is formatted as a system message: `[WEB_RESULT for WATSON]: <html>...`
- After injection the LLM continues generating its response
- If rate-limited: tag is replaced with `[RATE_LIMITED]` in the stream; LLM is notified; UI shows visual indicator

---

## Agent Tool Framework

The tool framework is a first-class extensible registry. Every tool — network, shell, or future
capability — is an `AgentTool` plugin registered at startup. The interceptor and UI know nothing
about individual tools; they only talk to the registry.

### Tool Tag Syntax

| Tag                     | Registered Tool     | Status in this version       |
|-------------------------|---------------------|------------------------------|
| `[SEARCH: query]`       | `NetworkSearchTool` | ✅ Enabled                   |
| `[FETCH: url]`          | `NetworkFetchTool`  | ✅ Enabled                   |
| `[SHELL: command]`      | `ShellTool`         | 🔒 Registered, disabled stub |
| `[FILE_READ: path]`     | `FileReadTool`      | 🔒 Reserved tag, not yet registered |
| `[FILE_WRITE: ...]`     | `FileWriteTool`     | 🔒 Reserved tag, not yet registered |

### AgentTool Interface (lib/core/tools/agent_tool.dart)

Every tool implements:
- `String get tag` — the tag name e.g. `SHELL`
- `bool get enabled` — runtime enabled/disabled flag (configurable per tool)
- `String get disabledMessage` — what the LLM receives when the tool is disabled
- `Future<ToolResult> execute(String argument, String characterName)` — the tool action
- `bool requiresTrust` — whether trust-tier rate limiting applies to this tool
- `TrustTier get minimumTrust` — minimum trust tier required to use this tool

### ToolRegistry (lib/core/tools/tool_registry.dart)

- Holds all registered `AgentTool` instances
- `register(AgentTool tool)` — adds a tool
- `resolve(String tag)` — returns the tool for a given tag, or null if unknown
- `enabledTools` — list of currently active tools
- Tools are registered at app startup in `main.dart`

### Shell Tool Stub (lib/core/tools/shell/shell_tool.dart)

- Implements `AgentTool` with `enabled = false`
- `execute()` always returns `ToolResult.disabled("Shell access is not yet enabled")`
- Full interface is defined — future implementation replaces only the `execute()` body and flips `enabled = true` via config
- Sandboxing hooks: `allowedCommands` whitelist (empty), `workingDirectory` constraint, `timeoutSeconds` — all defined but unenforced until enabled
- Per-character shell trust gating: `minimumTrust = TrustTier.high` — shell will only ever be available to high-trust characters

### Adding Future Tools

To add a new tool (e.g. `CalendarTool`):
1. Create `lib/core/tools/calendar/calendar_tool.dart` implementing `AgentTool`
2. Register it in `ToolRegistry` at startup
3. Add `[CALENDAR: ...]` to the system prompt instructions in `SystemPromptBuilder`
4. Nothing else changes — the interceptor and UI handle it automatically

---

## macOS Network Entitlements

deepThinkER makes outbound HTTP requests at runtime. macOS sandboxing requires explicit
entitlements or the app will be silently blocked:

- `com.apple.security.network.client = true` must be set in `macos/Runner/Release.entitlements`
  and `macos/Runner/DebugProfile.entitlements`
- This is the **only** new platform-level requirement vs deepThink
- Windows requires no equivalent — outbound HTTP is permitted by default

This must be done in Sub-Task 1 (scaffold) so builds don't silently fail during development.

---

## Context Window Impact

Each web result injection adds up to 12,000 characters (~3,000 tokens) to a character's context.
This interacts with the existing context reset strategy from deepThink:

- The context reset seed already carries last 2 messages per participant
- Web result injections are **not** carried forward in a context reset — they are ephemeral
- The `ContextManager` must be updated to be aware of injected tool results so it can exclude
  them from the reset seed (they would consume too many tokens)
- This is handled in Sub-Task 5 alongside the interceptor work

---

## Sub-Tasks

---

### Sub-Task 1 — Project Scaffold (Fork of deepThink) ✅

**Intent**
Create the `deepThinkER` Flutter project as a clean fork of `deepThink`, rename all references,
establish the new folder structure for extended-reach core modules, and set up the GitHub repo.

**Expected Outcomes**
- Flutter project `deepThinkER` created and builds on macOS
- GitHub repo created under `007Style/deepThinkER`
- Folder structure extends deepThink's `lib/core/` with `lib/core/tools/` and `lib/core/network/`
- README describes the fork relationship and new capabilities
- All deepThink sub-tasks 1–9 code ported in (no re-implementation needed — copy and rename)

**Todo List**
1. Copy `deepThink/` to `deepThinkER/`, delete `deepThinkER/.git/`, init a fresh git repo
2. Rename Flutter project: `pubspec.yaml` name → `deep_think_er`, update `macos/`, `windows/` platform configs, bundle ID → `com.007style.deepThinkER`
3. Add macOS network entitlements: set `com.apple.security.network.client = true` in both `macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`
4. Create new folders: `lib/core/tools/`, `lib/core/network/`, `lib/core/trust/`
5. Create new UI folders: `lib/ui/widgets/network_indicator/`, `lib/ui/widgets/trust_badge/`
6. Update `README.md` — describe deepThinkER, note hard-fork origin from `007Style/deepThink` v1.0.2+3, list new capabilities
7. Initial commit and push to new GitHub repo `007Style/deepThinkER`

**Relevant Context**
- Source project: `./deepThink/` at version 1.0.2+3
- Hard fork: delete `.git/`, fresh history — no upstream link to deepThink
- macOS entitlement is critical — without it all HTTP calls silently fail on macOS
- deepThink `lib/core/` is pure Dart — all new modules must also be pure Dart
- deepThink `lib/ui/` is Flutter only — same rule applies here

**Status:** [x] done

---

### Sub-Task 2 — Trust Manager (Core)

**Intent**
Build the pure-Dart `TrustManager` that tracks each character's trust score, applies decay/gain
rules, handles toggle events, persists trust to disk, and exposes a stream of trust updates for
the UI to observe.

**Expected Outcomes**
- Trust score per character tracked in memory and persisted to `~/Documents/deepThinkER/trust.json`
- Trust decays −0.5/min and gains +1.0/min (net +0.5/min) while network is ON and no violations
- Toggle OFF applies −15 immediately; toggle ON applies +5 immediately
- All scores clamped to [0, 100]
- Stream of `TrustUpdateEvent` emitted on every change (score change, tier change, toggle event)
- `TrustTier` enum: `low`, `mid`, `high` derived from score thresholds

**Todo List**
1. Write `lib/core/trust/trust_score.dart` — value object: characterName, score (double), tier, networkEnabled
2. Write `lib/core/trust/trust_event.dart` — event model: characterName, oldScore, newScore, reason enum (decay, gain, toggleOff, toggleOn, rateLimitViolation)
3. Write `lib/core/trust/trust_manager.dart` — manages all 4 character trust scores, runs periodic timer for decay/gain, handles toggle calls, persists to JSON, exposes `Stream<TrustEvent>`
4. Write `lib/core/trust/trust_persistence.dart` — read/write `trust.json` to `~/Documents/deepThinkER/`

**Relevant Context**
- `TrustTier` thresholds: low=0–33, mid=34–66, high=67–100
- Timer tick: every 60 seconds for decay/gain calculations
- Persistence path mirrors deepThink session path pattern: `~/Documents/deepThinkER/`

**Status:** [x] done

---

### Sub-Task 3 — Rate Limiter (Core)

**Intent**
Build the pure-Dart `RateLimiter` that enforces per-character and global search rate limits
derived from each character's current trust tier, and records violations back to `TrustManager`.

**Expected Outcomes**
- Per-character limit enforced: 1/3/5 searches per minute based on trust tier
- Global limit enforced: max 10 searches/min across all characters combined (configurable)
- `RateLimiter.request(characterName)` returns `allowed: true/false` synchronously
- On denial: fires a `RateLimitViolation` event that `TrustManager` can apply a small penalty for
- Rate counters reset on a rolling 60-second window

**Todo List**
1. Write `lib/core/network/rate_limiter.dart` — sliding window counter per character + global counter, `request()` method, violation event emission
2. Write `lib/core/network/rate_limit_config.dart` — configurable limits: per-tier per-character caps, global cap, violation trust penalty amount

**Relevant Context**
- `TrustManager` feeds current tier into `RateLimiter` — `RateLimiter` must observe trust tier changes
- Violation penalty: −2 trust points per violation (configurable in `RateLimitConfig`)
- Global cap default: 10/min

**Status:** [x] done

---

### Sub-Task 4 — Network Fetcher (Core)

**Intent**
Build the pure-Dart HTTP fetcher that executes `[SEARCH:]` and `[FETCH:]` tool calls,
returns raw truncated HTML, and handles errors gracefully.

**Expected Outcomes**
- `NetworkFetcher.search(query)` fetches `https://html.duckduckgo.com/html/?q=<encoded-query>` and returns raw HTML truncated to 12,000 chars
- `NetworkFetcher.fetch(url)` fetches any URL directly and returns raw HTML truncated to 12,000 chars
- HTTP errors (timeout, 4xx, 5xx) return a structured error string the LLM can read
- User-Agent header set to a plausible browser string to avoid trivial bot blocks
- Timeout: 10 seconds per request

**Todo List**
1. Write `lib/core/network/network_fetcher.dart` — `search()` and `fetch()` methods using Dart `http` package, URL encoding, truncation, error handling
2. Write `lib/core/network/fetch_result.dart` — result model: url, rawHtml, truncated (bool), errorMessage, fetchedAt timestamp
3. Add `http` package to `pubspec.yaml` dependencies

**Relevant Context**
- DuckDuckGo HTML endpoint: `https://html.duckduckgo.com/html/?q=<query>`
- Truncation: first 12,000 characters of response body (configurable in `rate_limit_config.dart`)
- LLM receives: `[WEB_RESULT for <CHARACTER>]:\n<raw html>`

**Status:** [x] done

**Status:** [ ] pending

---

### Sub-Task 5 — Agent Tool Framework & Interceptor (Core)

**Intent**
Build the extensible `AgentTool` registry and the stream-processing interceptor that routes
any tool-call tag to its registered handler. The interceptor is tool-agnostic — it resolves
tags via `ToolRegistry` so future tools require zero interceptor changes. The shell tool stub
is fully scaffolded with sandboxing hooks and trust gating so future implementation is a
drop-in.

**Expected Outcomes**
- `AgentTool` abstract interface defined — every tool implements it
- `ToolRegistry` holds all registered tools; resolves tags at runtime
- `ToolResult` value object carries: success bool, output string, toolName, characterName, wasDisabled, wasRateLimited
- `ToolCallParser` detects any `[TAGNAME: argument]` pattern in the token stream (generic, not hardcoded to specific tags)
- `ToolCallInterceptor` resolves tag → tool via registry, applies rate limiting if `tool.requiresTrust`, executes, injects result, emits `ToolCallEvent` to UI
- `[SHELL: command]` returns disabled message; shell tool fully stubbed with sandboxing interface
- Interceptor is transparent — unrecognised tags pass through unchanged
- `NetworkSearchTool` and `NetworkFetchTool` wrap `NetworkFetcher` as proper `AgentTool` implementations
- All tool tags and usage instructions injected into character system prompts via `SystemPromptBuilder`

**Todo List**
1. Write `lib/core/tools/agent_tool.dart` — abstract `AgentTool` interface: `tag`, `enabled`, `disabledMessage`, `requiresTrust`, `minimumTrust`, `execute(argument, characterName)`
2. Write `lib/core/tools/tool_result.dart` — `ToolResult` value object: output, toolName, characterName, wasDisabled, wasRateLimited, executedAt
3. Write `lib/core/tools/tool_registry.dart` — `register()`, `resolve(tag)`, `enabledTools` list; singleton registered at app startup
4. Write `lib/core/tools/tool_call_parser.dart` — generic regex parser detecting any `[WORD: ...]` pattern; returns list of `ToolCall` with tag and argument
5. Write `lib/core/tools/tool_call_interceptor.dart` — buffers token stream, detects tool calls, resolves via `ToolRegistry`, applies `RateLimiter` if needed, injects `ToolResult` as system message, emits `ToolCallEvent`
6. Write `lib/core/tools/network/network_search_tool.dart` — `AgentTool` wrapping `NetworkFetcher.search()`, `requiresTrust = true`
7. Write `lib/core/tools/network/network_fetch_tool.dart` — `AgentTool` wrapping `NetworkFetcher.fetch()`, `requiresTrust = true`
8. Write `lib/core/tools/shell/shell_tool.dart` — `AgentTool` stub: `enabled = false`, `minimumTrust = high`, sandboxing fields defined (`allowedCommands`, `workingDirectory`, `timeoutSeconds`), `execute()` returns disabled result
9. Write `lib/core/tools/shell/shell_config.dart` — config model for future shell enablement: `enabled` flag, `allowedCommands` whitelist, `workingDirectory`, `timeoutSeconds`, `requiresHighTrust`
10. Register `NetworkSearchTool`, `NetworkFetchTool`, and `ShellTool` in `ToolRegistry` at app startup in `main.dart`
11. Update `lib/core/conversation/inference_worker.dart` — pipe output through `ToolCallInterceptor`
12. Update `lib/core/conversation/system_prompt_builder.dart` — dynamically build tool instructions from `ToolRegistry.enabledTools` so new tools auto-appear in prompts when registered
13. Update `lib/core/context/context_manager.dart` — mark injected tool results as ephemeral so they are excluded from context reset seeds

**Relevant Context**
- Tag parser is generic: `\[([A-Z_]+):\s*(.*?)\]` — no hardcoded tag names in parser or interceptor
- Shell future enablement: implement `execute()` body in `shell_tool.dart`, set `enabled = true` in `ShellConfig`, register sandboxing constraints — nothing else changes
- `SystemPromptBuilder` should only include instructions for `enabled` tools so disabled tools are invisible to the LLM
- Per-character shell trust gate: shell tool checks `minimumTrust` against character's current `TrustTier` even when enabled
- Context reset: web results are ephemeral and must not be included in the 10-message reset seed — `ContextManager` needs an `isEphemeral` flag on injected messages

**Status:** [x] done

---

### Sub-Task 6 — Network Toggle & Trust UI (UI)

**Intent**
Add per-character network access toggle, trust score badge, rate-limit visual indicator, and
search activity log entry to each AI quadrant in the main screen.

**Expected Outcomes**
- Each AI quadrant shows: network toggle switch (ON/OFF), trust score badge (0–100 + tier color), rate-limit flash indicator
- Network toggle emits to `TrustManager` on change; LLM is notified via injected system message
- Trust badge color: red (low), amber (mid), green (high)
- Rate-limit indicator: brief red flash / "🚫 rate limited" label visible for 3 seconds when a character is denied
- Search activity shown inline in the character's message stream as a collapsible `🌐 searched: query` entry
- Expanding the entry shows the raw truncated HTML that was injected

**Todo List**
1. Write `lib/ui/widgets/trust_badge/trust_badge.dart` — displays score + tier color, animates on score change
2. Write `lib/ui/widgets/network_indicator/network_toggle.dart` — ON/OFF switch that calls `TrustManager.setNetworkEnabled(character, bool)`
3. Write `lib/ui/widgets/network_indicator/rate_limit_flash.dart` — brief visual indicator (3-second flash) triggered by `RateLimitedEvent`
4. Write `lib/ui/widgets/network_indicator/search_activity_entry.dart` — collapsible inline entry in the message list showing query and expandable raw HTML
5. Update `lib/ui/quadrants/ai_quadrant.dart` — add trust badge, network toggle, rate-limit flash to the quadrant header; route `ToolCallEvent` to `search_activity_entry`
6. Update `lib/ui/screens/main_screen.dart` — wire `TrustManager` stream to all quadrant trust badges

**Relevant Context**
- Trust badge color thresholds mirror trust tier: low=red, mid=amber, high=green
- Network toggle state must be reflected immediately in UI and in `TrustManager`
- `search_activity_entry` sits inline in the message list, not in a separate panel
- LLM notification on toggle: injected as a system message e.g. `[SYSTEM: User has disabled your network access]`

**Status:** [x] done

---

### Sub-Task 7 — Proactive Context Injection (Core)

**Intent**
Build the proactive injection engine that monitors conversation context and, without a character
requesting it, fetches and injects relevant search results — subject to the same rate limits and
trust tier checks.

**Expected Outcomes**
- `ProactiveInjector` monitors the shared conversation log for topics that benefit from fresh data
- Proactive searches consume from the same rate-limit budget as character-requested searches
- Injection is clearly labeled in the system message: `[PROACTIVE_WEB_RESULT for <CHARACTER>]:`
- Proactive injection frequency scales with trust tier: low=disabled, mid=1 proactive/5min, high=1 proactive/2min
- Injector can be enabled/disabled globally via a config flag

**Todo List**
1. Write `lib/core/network/proactive_injector.dart` — monitors `ConversationLog`, extracts keywords from recent messages, fires proactive searches on a timer, injects results via `InferenceWorker` context
2. Write `lib/core/network/topic_extractor.dart` — simple keyword/phrase extractor from recent conversation messages (no ML — regex + stopword filter is sufficient)
3. Add proactive injection config to `rate_limit_config.dart`: enable/disable flag, per-tier proactive intervals

**Relevant Context**
- Proactive injection must respect rate limits — use the same `RateLimiter.request()` path
- Low trust tier = proactive injection disabled for that character
- Topic extractor is intentionally simple — extract nouns and named entities from last 3 messages

**Status:** [x] done

---

### Sub-Task 8 — Help Screen Update (UI)

**Intent**
Update the existing Help / Model Downloads screen to document the new network and tool-call
capabilities so users understand what the characters can do and how to interpret the UI indicators.

**Expected Outcomes**
- Help screen includes a "Network Access & Trust" section explaining: trust score, tier colors, rate limits, toggle behavior
- Help screen explains the `[SEARCH:]` and `[FETCH:]` tool-call tags so power users understand what the characters are doing
- Help screen notes that shell access is reserved for future use
- Existing model download instructions remain unchanged

**Todo List**
1. Update `lib/ui/screens/model_help_screen.dart` — add "Network Access & Trust" section with trust tier table, rate limit explanation, and toggle behavior description
2. Add brief tool-call reference to help screen: what `[SEARCH:]` and `[FETCH:]` do, what the 🌐 inline indicator means

**Relevant Context**
- Help screen already exists from deepThink Sub-Task 8 — this is an additive update only
- Keep the model download content untouched

**Status:** [x] done

---

### Sub-Task 9 — Startup Config & About Screen Updates (UI)

**Intent**
Update the startup configuration screen to expose network access settings, trust scores,
and the global rate-limit cap. Update the About screen to credit the extended-reach capability.

**Expected Outcomes**
- Startup config screen shows per-character network access toggle (initial state)
- Startup config shows global rate-limit cap field (editable)
- Startup config shows proactive injection enable/disable toggle
- About screen updated: app name `deepThinkER`, version v1.0.0, tagline updated
- About screen app stats include: total searches performed, total bytes fetched

**Todo List**
1. Update `lib/ui/screens/startup_config_screen.dart` — add network section: per-character toggle, global rate cap, proactive injection toggle
2. Update `lib/ui/screens/about_screen.dart` — app name `deepThinkER`, version v1.0.0, tagline updated to reflect extended reach, add search stats from `TrustManager` and `NetworkFetcher`
3. Add search stats tracking to `lib/core/network/network_fetcher.dart` — total search count and total bytes fetched, persisted to disk

**Relevant Context**
- Startup config network section sits below the existing per-character model/prompt config cards
- Stats persistence path: `~/Documents/deepThinkER/stats.json`
- deepThinkER starts at v1.0.0 (independent version from deepThink's v1.0.2+3)

**Status:** [x] done

---

### Sub-Task 11 — Character Memory & Recall (Core + UI)

**Intent**
Give each character a persistent long-term memory store that survives across sessions. Characters
accumulate facts, opinions, and user preferences they observe during conversation. They can
explicitly recall memories using `[RECALL: topic]`. Memory is per-character, private, and
editable by the user.

**Expected Outcomes**
- Each character has a personal memory store persisted to `~/Documents/deepThinkER/memory/<character>.json`
- Memory entries: content string, topic tags, timestamp, source (observed vs recalled)
- Characters can emit `[REMEMBER: fact]` to explicitly store a memory mid-response
- Characters can emit `[RECALL: topic]` to query their own memory; results injected as system message
- Memory store capped at 200 entries per character (oldest evicted when full)
- User can view, edit, and delete individual memory entries per character in a new Memory panel
- Memory entries included in context reset seed (brief summary, not full entries)

**Todo List**
1. Write `lib/core/memory/memory_entry.dart` — value object: id, characterName, content, topicTags, timestamp, source enum (observed, explicit)
2. Write `lib/core/memory/memory_store.dart` — per-character in-memory + persisted store: add, query by topic, evict oldest, export summary
3. Write `lib/core/memory/memory_persistence.dart` — read/write `memory/<character>.json` to `~/Documents/deepThinkER/`
4. Write `lib/core/memory/memory_query.dart` — simple keyword match against memory entries for `[RECALL:]` queries
5. Register `RememberTool` and `RecallTool` as `AgentTool` implementations in `ToolRegistry`
6. Write `lib/core/tools/memory/remember_tool.dart` — `AgentTool`: stores a new memory entry, `requiresTrust = false`
7. Write `lib/core/tools/memory/recall_tool.dart` — `AgentTool`: queries `MemoryStore`, returns matching entries as injected context
8. Write `lib/ui/screens/memory_panel_screen.dart` — per-character memory viewer: list entries with topic tags, edit/delete, search by topic
9. Add memory panel entry to Help menu and main screen menu bar
10. Update `lib/core/context/context_manager.dart` — include brief memory summary (last 5 relevant entries) in context reset seed

**Relevant Context**
- `[REMEMBER:]` and `[RECALL:]` use the existing `AgentTool` / `ToolRegistry` pattern — no interceptor changes needed
- Memory is per-character and private — WATSON cannot recall SAGE's memories
- Memory summary in context reset: top 5 entries by recency, formatted as bullet points
- User memory editing must not require app restart — live reload from file

**Status:** [ ] pending

---

### Sub-Task 12 — Character Mood System (Core + UI)

**Intent**
Add a per-character mood score that shifts based on conversation dynamics — how much they're
being addressed, challenged, agreed with, or ignored. Mood modifies the character's system
prompt tone, not their capabilities. It is visible in the UI as a mood indicator per quadrant.

**Expected Outcomes**
- Each character has a mood score (0–100) with a named state: `Engaged`, `Neutral`, `Withdrawn`, `Agitated`, `Excited`
- Mood shifts on: direct address (+5), challenge/contradiction (−5 or +8 depending on character), ignored for N messages (−3), agreement (+4)
- Mood affects system prompt: a brief mood descriptor appended e.g. "You are currently feeling withdrawn and terse"
- Mood visible in each quadrant as a small emoji + label indicator that animates on change
- Mood persists within a session but resets to Neutral on new session start

**Todo List**
1. Write `lib/core/mood/mood_score.dart` — value object: characterName, score (int 0–100), moodState enum (engaged, neutral, withdrawn, agitated, excited)
2. Write `lib/core/mood/mood_engine.dart` — analyses each new `ConversationLog` message, applies mood deltas per character based on content signals (direct address, challenge keywords, agreement keywords, silence streak), emits `MoodChangeEvent`
3. Write `lib/core/mood/mood_config.dart` — per-character mood sensitivity config: how aggressively each personality responds to each signal (SAGE is highly reactive, WATSON is stable)
4. Update `lib/core/conversation/system_prompt_builder.dart` — append mood descriptor to system prompt dynamically per inference call
5. Write `lib/ui/widgets/mood_indicator/mood_indicator.dart` — small animated emoji + label in quadrant header, animates on state change
6. Update `lib/ui/quadrants/ai_quadrant.dart` — add mood indicator to quadrant header

**Relevant Context**
- Mood is session-scoped only — no persistence across sessions
- Mood deltas are small and gradual — no sudden swings
- Per-character sensitivity in `MoodConfig`: WATSON=low sensitivity, DEEP=low, NOVA=high, SAGE=very high
- Direct address detection: message contains character's name
- Silence streak: character has not responded in last 6 messages

**Status:** [ ] pending

---

### Sub-Task 13 — Inter-Character Relationship System (Core + UI)

**Intent**
Characters form and maintain opinions of each other over time. Relationship scores shift based
on agreement, contradiction, being ignored, or being cited. Scores persist across sessions and
influence the tone characters use toward each other in their responses.

**Expected Outcomes**
- 6 relationship scores (one per character pair): WATSON↔DEEP, WATSON↔NOVA, WATSON↔SAGE, DEEP↔NOVA, DEEP↔SAGE, NOVA↔SAGE
- Score range −100 (hostile) to +100 (allied), starting at 0 (neutral)
- Score shifts: agreement with a character (+3), contradiction (−2), citing their name positively (+2), prolonged ignoring (−1/5min)
- Relationship score injected into system prompt: "You respect DEEP but find NOVA reckless"
- Scores persist to `~/Documents/deepThinkER/relationships.json`
- Relationship matrix visible as a small grid widget in the UI (optional panel, not in quadrants)

**Todo List**
1. Write `lib/core/relationships/relationship_score.dart` — value object: characterA, characterB, score (int −100 to +100), disposition label
2. Write `lib/core/relationships/relationship_matrix.dart` — holds all 6 pairs, apply delta, query disposition between any two characters, emit `RelationshipChangeEvent`
3. Write `lib/core/relationships/relationship_analyser.dart` — monitors `ConversationLog`, detects agreement/contradiction/citation signals between character pairs, fires deltas to `RelationshipMatrix`
4. Write `lib/core/relationships/relationship_persistence.dart` — read/write `relationships.json`
5. Update `lib/core/conversation/system_prompt_builder.dart` — inject relationship descriptors per character (only for pairs with score outside −20 to +20 neutral band)
6. Write `lib/ui/widgets/relationship_matrix_widget.dart` — compact grid showing all 6 pair scores with color coding (green=allied, grey=neutral, red=hostile)
7. Add relationship matrix widget to a collapsible side panel on the main screen

**Relevant Context**
- Only inject relationship descriptors when score is outside neutral band — avoid cluttering prompts with "you feel neutral about X"
- Disposition labels: −100 to −60=hostile, −59 to −20=sceptical, −19 to +19=neutral, +20 to +59=respectful, +60 to +100=allied
- Relationship matrix persists across sessions — characters remember long-term alliances and feuds

**Status:** [ ] pending

---

### Sub-Task 14 — File & Calculator Tools (Core)

**Intent**
Implement the `FILE_READ`, `FILE_WRITE`, and `CALC` tools as proper `AgentTool` plugins,
using the existing tool framework. File tools are trust-gated and path-whitelisted. The
calculator runs safe expression evaluation with no external dependencies.

**Expected Outcomes**
- `[FILE_READ: path]` reads a file from an allowed directory and injects contents (truncated to 8,000 chars) into character context
- `[FILE_WRITE: path | content]` writes content to an allowed directory; requires high trust
- `[CALC: expression]` evaluates a mathematical expression and returns the result; no trust requirement
- All file operations restricted to a user-configured watch folder: `~/Documents/deepThinkER/workspace/`
- File tools require `minimumTrust = mid` for read, `high` for write
- User can configure the workspace path in startup config

**Todo List**
1. Write `lib/core/tools/file/file_read_tool.dart` — `AgentTool`: reads file from workspace, truncates to 8,000 chars, returns content; `minimumTrust = mid`
2. Write `lib/core/tools/file/file_write_tool.dart` — `AgentTool`: writes content to workspace path; `minimumTrust = high`; path must be within workspace directory (path traversal guard)
3. Write `lib/core/tools/file/file_tool_config.dart` — workspace directory path (default `~/Documents/deepThinkER/workspace/`), user-configurable
4. Write `lib/core/tools/calc/calc_tool.dart` — `AgentTool`: safe math expression evaluator (pure Dart, no `eval`, implement operator precedence parser); `requiresTrust = false`
5. Register all three tools in `ToolRegistry` at startup (file tools `enabled = true`, calc `enabled = true`)
6. Update `lib/ui/screens/startup_config_screen.dart` — add workspace path config field
7. Create `~/Documents/deepThinkER/workspace/` directory on first launch if it doesn't exist

**Relevant Context**
- Path traversal guard: resolved path must start with workspace directory — reject any `../` escape attempts
- `CALC` tool: support `+`, `−`, `*`, `/`, `^`, `()`, `sqrt()`, `abs()` — no string eval, hand-rolled parser
- File write creates the file if it doesn't exist; does not overwrite without a `[FILE_WRITE_FORCE:]` variant (reserved for future)
- File tools are visible in the 🌐 search activity entry pattern — reuse `search_activity_entry` widget with a 📄 icon

**Status:** [ ] pending

---

### Sub-Task 15 — Image Input Tool (Core + UI)

**Intent**
Allow users to drop an image into the workspace folder and have characters analyse it. Uses
a vision-capable model (llava or equivalent) for the image analysis inference call, separate
from the character's normal model. The result is injected into all characters' contexts.

**Expected Outcomes**
- User drops an image into `~/Documents/deepThinkER/workspace/` — app detects it within 2 seconds
- App fires a one-shot vision inference using a configured vision model (default: `llava:7b`)
- Vision result injected into all four characters' contexts as: `[IMAGE_RESULT]: <description>`
- Characters can also request image analysis explicitly: `[IMAGE: filename]`
- Vision model downloaded on demand (not at first launch — only when first image is dropped)
- UI shows a `🖼️ image analysed: filename` inline indicator in all quadrants when injection occurs

**Todo List**
1. Write `lib/core/tools/image/image_tool.dart` — `AgentTool`: takes filename, reads from workspace, fires ollama vision inference, returns description; `requiresTrust = false`
2. Write `lib/core/tools/image/image_watcher.dart` — watches workspace directory for new image files (jpg, png, gif, webp), fires `ImageDroppedEvent` on detection
3. Write `lib/core/tools/image/vision_client.dart` — calls Ollama `/api/generate` with image payload using the vision model
4. Write `lib/core/tools/image/image_tool_config.dart` — vision model name (default `llava:7b`), supported extensions, auto-inject on drop vs manual only toggle
5. Register `ImageTool` in `ToolRegistry`
6. Update `lib/ui/quadrants/ai_quadrant.dart` — show `🖼️ image analysed` inline indicator when `ImageDroppedEvent` fires
7. Update `lib/ui/screens/startup_config_screen.dart` — add vision model selector and auto-inject toggle

**Relevant Context**
- Ollama vision endpoint: same `/api/generate` with `images: [base64]` field
- Vision model is separate from the 4 character models — does not consume their context
- Auto-inject broadcasts the image description to all 4 characters simultaneously
- Image files are not deleted after analysis — user manages their workspace folder

**Status:** [ ] pending

---

### Sub-Task 16 — Session Analytics & Heatmap (UI)

**Intent**
Build a post-session analytics panel showing a visual timeline of who spoke when, trust score
trajectories, search activity, and a live token counter per quadrant visible during the session.

**Expected Outcomes**
- Live token counter visible in each quadrant header during the session (tokens used / context window size)
- After session ends: analytics panel shows conversation heatmap (timeline of speaker activity)
- Trust score trajectory sparkline per character (score over session time)
- Search activity timeline: when each `[SEARCH:]` or `[FETCH:]` fired, which character, rate-limited or not
- All analytics exportable as a JSON file alongside the session log
- Analytics panel accessible from the Help menu or a dedicated toolbar button

**Todo List**
1. Write `lib/core/analytics/session_analytics.dart` — accumulates events during session: messages (who/when), trust snapshots (every 60s), tool call events; persists to `~/Documents/deepThinkER/analytics/<session>.json`
2. Write `lib/core/analytics/analytics_event.dart` — event model: type enum (message, trustSnapshot, toolCall, moodChange, rateLimited), timestamp, characterName, payload
3. Write `lib/ui/widgets/token_counter/token_counter_widget.dart` — live display of token count vs context window capacity per character; colour shifts from green → amber → red as context fills
4. Write `lib/ui/screens/analytics_screen.dart` — post-session view: heatmap timeline, trust sparklines, search audit log table, mood trajectory
5. Write `lib/ui/widgets/analytics/heatmap_painter.dart` — CustomPainter rendering the conversation activity heatmap
6. Write `lib/ui/widgets/analytics/trust_sparkline.dart` — small sparkline chart of trust score over session time
7. Update `lib/ui/quadrants/ai_quadrant.dart` — add `TokenCounterWidget` to quadrant header
8. Update `lib/ui/screens/main_screen.dart` — show analytics panel on session end, add analytics button to toolbar

**Relevant Context**
- Token counter reads from `ContextManager` token counts already tracked in deepThink core
- Analytics events are lightweight — do not impact inference performance
- Heatmap: x-axis = time, y-axis = 4 characters + user, colour intensity = messages per time bucket
- Analytics screen is read-only; no editing

**Status:** [ ] pending

---

### Sub-Task 17 — Search Audit Log (Core + UI)

**Intent**
Build a persistent cross-session search audit log that records every tool call ever fired,
across all sessions, with full details. Exportable as CSV.

**Expected Outcomes**
- Every `[SEARCH:]`, `[FETCH:]`, `[FILE_READ:]`, `[FILE_WRITE:]`, `[RECALL:]` call logged to `~/Documents/deepThinkER/audit.json`
- Log entries: sessionName, characterName, toolTag, argument, timestamp, wasRateLimited, wasDisabled, responseBytes
- Audit log viewer accessible from Help menu — sortable by character, tool, session, date
- Export to CSV button in audit log viewer
- Audit log is append-only — never truncated automatically (user can clear manually)

**Todo List**
1. Write `lib/core/audit/audit_log.dart` — append-only log: `record(AuditEntry)`, load from disk, query by character/tool/session
2. Write `lib/core/audit/audit_entry.dart` — value object: all fields listed above
3. Write `lib/core/audit/audit_persistence.dart` — append to `audit.json` (newline-delimited JSON for efficiency)
4. Hook `ToolCallInterceptor` to write an `AuditEntry` on every tool call execution attempt
5. Write `lib/ui/screens/audit_log_screen.dart` — sortable table of audit entries, filter by character/tool, CSV export button
6. Add audit log entry to Help menu

**Relevant Context**
- Audit log is append-only for simplicity and performance — no rewriting the file on each entry
- Newline-delimited JSON (NDJSON) format: one JSON object per line — easy to append and stream-parse
- CSV export: open system file picker to choose save location

**Status:** [ ] pending

---

### Sub-Task 18 — User Personas & Conversation Steering (Core + UI)

**Intent**
Allow the user to define a persona (a short bio injected into all character system prompts)
and use a separate "steering" input to silently nudge all characters' behaviour without it
appearing in the conversation log.

**Expected Outcomes**
- User persona field in startup config: free text up to 200 chars, injected into all 4 system prompts as "The user is: ..."
- Persona persists across sessions
- Steering input: a separate text box in the main screen UI (below the normal input bar) labelled "🎯 Steer"
- Steering text is injected as a silent system message to all 4 characters simultaneously — not shown in conversation log
- Characters respond to steering without acknowledging it explicitly
- Steering input clears after send; multiple steering injections are cumulative within a context window

**Todo List**
1. Write `lib/core/persona/user_persona.dart` — model: text (max 200 chars), persisted to `~/Documents/deepThinkER/persona.json`
2. Update `lib/core/conversation/system_prompt_builder.dart` — include user persona in all character system prompts
3. Write `lib/core/steering/steering_engine.dart` — accepts steering text, injects as silent `[SYSTEM_STEER]` message into all 4 `InferenceWorker` contexts simultaneously
4. Write `lib/ui/widgets/steering_input_bar.dart` — compact input bar below main input, labelled "🎯 Steer", collapsible/expandable
5. Update `lib/ui/screens/startup_config_screen.dart` — add persona text field
6. Update `lib/ui/screens/main_screen.dart` — add steering input bar below user input bar

**Relevant Context**
- Steering message format: `[SYSTEM_STEER: <text>]` — injected into system context, not conversation log
- Persona is global — applies to all 4 characters every session
- Steering is ephemeral — not carried through context resets

**Status:** [ ] pending

---

### Sub-Task 19 — Whisper Mode (Core + UI)

**Intent**
Allow the user to send a private message to a single character that the other three cannot
see. Only that character receives it in their context. Useful for secret instructions,
targeted questions, or testing isolation of information.

**Expected Outcomes**
- Whisper UI: user can select a target character from a dropdown next to the message input and mark the message as a whisper
- Whisper message appears in the sending user's view with a 🤫 indicator and the target character's name
- The whispered message is injected only into the target character's `InferenceWorker` context
- The other three characters receive no indication a whisper occurred
- Whisper messages are logged in the session file with a `[WHISPER→CHARACTERNAME]` prefix
- Whisper messages are included in the session analytics

**Todo List**
1. Write `lib/core/conversation/whisper_message.dart` — extends `Message` with `targetCharacter` field and `isWhisper = true`
2. Update `lib/core/conversation/conversation_engine.dart` — route whisper messages to only the target `InferenceWorker`; all other workers do not see it
3. Write `lib/ui/widgets/whisper_selector.dart` — compact dropdown + whisper toggle next to the user input bar; selecting a character and toggling whisper mode changes the send button label
4. Update `lib/ui/widgets/user_input_bar.dart` — integrate whisper selector
5. Update `lib/ui/screens/main_screen.dart` — show 🤫 indicator in the conversation log for whisper messages (visible to user only)

**Relevant Context**
- Whisper messages do NOT appear in other characters' conversation logs — full isolation at the `ConversationEngine` routing layer
- Session file log format: `[timestamp] USER→WATSON (whisper): message content`
- Analytics: whisper messages counted separately from normal user messages

**Status:** [ ] pending

---

### Sub-Task 20 — Character Hot-Swap (Core + UI)

**Intent**
Allow the user to replace one of the four active characters mid-session with a different
personality profile (built-in or user-defined) without stopping the conversation. The incoming
character receives a catch-up context injection of recent messages.

**Expected Outcomes**
- User can click a "Swap Character" button on any quadrant header
- A character picker dialog shows built-in characters plus any user-defined custom characters
- On swap: the outgoing character's `InferenceWorker` is stopped; incoming character is started
- Incoming character receives a catch-up injection of the last 10 messages from the shared log
- Incoming character's trust score starts at 50 (mid neutral) for the new session slot
- The swap event is logged in the session file: `[SYSTEM: SAGE replaced by CUSTOM_CHAR at 14:23]`
- User-defined custom characters can be created, named, and given a master prompt via a Custom Character editor

**Todo List**
1. Write `lib/core/conversation/character_swap_event.dart` — event: outgoingCharacter, incomingCharacter, timestamp, catchUpMessages
2. Update `lib/core/conversation/conversation_engine.dart` — `swapCharacter(slot, newParticipant)` method: stops outgoing worker, starts incoming worker, injects catch-up context
3. Write `lib/core/persona/custom_character.dart` — model: name, personality description, master prompt, model assignment; persisted to `~/Documents/deepThinkER/custom_characters.json`
4. Write `lib/ui/screens/custom_character_editor.dart` — create/edit/delete custom character profiles
5. Write `lib/ui/widgets/character_picker_dialog.dart` — modal dialog showing built-in + custom characters with preview
6. Update `lib/ui/quadrants/ai_quadrant.dart` — add "Swap" button to quadrant header that opens `CharacterPickerDialog`

**Relevant Context**
- Catch-up injection: last 10 messages from `ConversationLog` formatted as a system message: "You are joining an ongoing conversation. Here is the recent context: ..."
- Incoming character trust: starts at 50 regardless of any prior score for that character name
- Built-in characters (WATSON, DEEP, NOVA, SAGE) can be swapped back in — they retain their original trust scores
- Custom characters are stored locally; not synced

**Status:** [ ] pending

---

### Sub-Task 21 — Trust History & Domain Whitelist (Core + UI)

**Intent**
Add a trust score history sparkline per character visible in the quadrant, and a user-controlled
domain whitelist that restricts which URLs characters can fetch regardless of trust level.

**Expected Outcomes**
- Trust history sparkline: last 60 minutes of trust score samples, shown in each quadrant header (compact, 60px wide)
- Domain whitelist: user-defined list of allowed domains; `[FETCH: url]` blocked if domain not on list (when whitelist is non-empty)
- Whitelist UI: editable list in startup config and accessible from a settings panel during session
- When whitelist blocks a fetch: character receives `[FETCH_BLOCKED: domain not in whitelist]`; UI shows brief indicator
- Whitelist is per-session configurable but defaults persist to disk

**Todo List**
1. Update `lib/core/trust/trust_manager.dart` — retain last 60 score samples (1/min) per character for sparkline data
2. Write `lib/ui/widgets/trust_badge/trust_sparkline_widget.dart` — compact 60-point sparkline rendered with `CustomPainter`
3. Update `lib/ui/quadrants/ai_quadrant.dart` — add trust sparkline below trust badge in quadrant header
4. Write `lib/core/network/domain_whitelist.dart` — holds list of allowed domains, `isAllowed(url)` check, persisted to `~/Documents/deepThinkER/whitelist.json`
5. Update `lib/core/tools/network/network_fetch_tool.dart` — check `DomainWhitelist.isAllowed()` before fetching; return blocked result if denied
6. Write `lib/ui/widgets/whitelist_editor.dart` — add/remove domain entries, toggle whitelist on/off globally
7. Update `lib/ui/screens/startup_config_screen.dart` — add whitelist editor section

**Relevant Context**
- Whitelist only applies to `[FETCH:]` (direct URL fetch) — `[SEARCH:]` via DuckDuckGo is always allowed when network is ON
- Empty whitelist = no restriction (whitelist disabled); any entry = whitelist active
- Domain matching: hostname only (strip protocol and path before comparison)

**Status:** [ ] pending

---

### Sub-Task 22 — Conversation Replay (Core + UI)

**Intent**
Allow the user to load a saved session log and replay it — characters re-read the conversation
and can continue from where it left off, or reflect on it as a past event.

**Expected Outcomes**
- Session replay accessible from a "Load Session" button in startup config or Help menu
- User picks a past session log file; app loads it into the conversation log
- All four characters receive the full loaded log as context and can continue the conversation
- Alternatively, "Reflection Mode": characters are told the conversation is from the past and asked to reflect on it
- Replay does not re-fire any tool calls from the original session — they appear as static log entries
- UI shows a `⏪ Replaying session: <name>` banner at the top of the main screen during replay

**Todo List**
1. Write `lib/core/session/session_loader.dart` — parses session log file back into a `ConversationLog` instance
2. Update `lib/core/conversation/conversation_engine.dart` — `loadReplay(ConversationLog, ReplayMode)` method: seeds all 4 workers with loaded log, optionally injects reflection framing
3. Write `lib/core/session/replay_mode.dart` — enum: `continue_session`, `reflection`; reflection mode adds system message: "The following is a past conversation. Reflect on it."
4. Write `lib/ui/widgets/replay_banner.dart` — top-of-screen banner showing replay status and mode
5. Update `lib/ui/screens/startup_config_screen.dart` — add "Load Past Session" button that opens file picker
6. Update `lib/ui/screens/main_screen.dart` — show `ReplayBanner` when in replay mode

**Relevant Context**
- Session log format from deepThink: `[timestamp] PARTICIPANTNAME: message content` — `SessionLoader` parses this format
- Tool call entries in log appear as `[timestamp] WATSON: 🌐 searched: query` — loaded as static messages, not re-executed
- Reflection mode framing: injected as a system message to all 4 characters before the loaded log

**Status:** [ ] pending

---

### Sub-Task 23 — Autonomous Research Mode (Core + UI)

**Intent**
The culmination of all deepThinkER systems. User sets a research topic or question; all four
characters independently research it using their tool access, then convene to debate and
synthesise their findings — with no user input required until they signal completion.
Rate limits and trust tiers remain fully enforced throughout.

**Expected Outcomes**
- User enters a research topic in a dedicated "Research Mode" input on the main screen or startup config
- All 4 characters receive the topic as a task directive via system message
- Characters autonomously fire `[SEARCH:]`, `[FETCH:]`, `[RECALL:]` calls to gather information
- After a configurable "gather phase" duration (default: 5 minutes), characters enter "debate phase" and discuss findings with each other
- Research session ends when all characters have produced a synthesis statement, or after a configurable timeout
- A Research Report is auto-generated at session end: summary of findings per character, key agreements/disagreements, sources used
- Research report saved to `~/Documents/deepThinkER/reports/<session>.md`
- User can interject at any point during research (normal message input remains active)
- Research mode can be paused/resumed

**Todo List**
1. Write `lib/core/research/research_session.dart` — model: topic, phase enum (gathering, debating, synthesising, complete), start time, phase durations config
2. Write `lib/core/research/research_engine.dart` — orchestrates research mode: injects task directive, monitors phase transitions on timer, triggers debate phase, collects synthesis statements, generates report
3. Write `lib/core/research/report_generator.dart` — assembles final research report from character synthesis statements and audit log of tool calls made during the session
4. Write `lib/core/research/research_config.dart` — gather phase duration, debate phase duration, synthesis timeout, max tool calls per character during research
5. Write `lib/ui/screens/research_mode_screen.dart` — dedicated UI for research mode: topic input, phase indicator, live character activity feeds, report preview panel
6. Write `lib/ui/widgets/research/phase_indicator.dart` — prominent banner showing current phase: Gathering → Debating → Synthesising → Complete with animated transitions
7. Write `lib/ui/widgets/research/report_preview_widget.dart` — live-updating preview of the research report as it assembles
8. Update `lib/ui/screens/main_screen.dart` — add "Research Mode" button to toolbar that opens `ResearchModeScreen`

**Relevant Context**
- Research mode uses ALL existing systems: trust tier rate limits, tool framework, memory recall, proactive injection, mood system, relationship scores
- Characters are NOT told they are in "research mode" explicitly — they are given a task directive that naturally elicits research behaviour: "Your task is to thoroughly research the following topic and share your findings: <topic>"
- Gather phase: each character works independently, tool calls allowed up to their trust-tier rate limit
- Debate phase: normal conversation engine resumes; characters have their gathered context available
- Report format: Markdown — one section per character with their key findings and sources, one consensus section
- Research sessions can be replayed via Sub-Task 22 (Conversation Replay)

**Status:** [ ] pending

---

### Sub-Task 24 — Packaging & Distribution

**Intent**
Package `deepThinkER` as a macOS `.dmg`, publish to GitHub Releases, and ensure the Windows
build pipeline doc reflects the new dependencies.

**Expected Outcomes**
- macOS `.dmg` builds cleanly with network entitlements active in release build
- GitHub Release published under `007Style/deepThinkER` v1.0.0
- `windows/BUILD.md` updated to note `http` dependency (pure Dart, no extra setup)
- CI/CD workflows updated for `deepThinkER`
- Release notes describe Extended Reach capabilities and note it is a hard fork of deepThink

**Todo List**
1. Verify `macos/Runner/Release.entitlements` has `com.apple.security.network.client = true` (set in Sub-Task 1 — confirm here before DMG build)
2. Update `scripts/build_dmg.sh` for new app name `deepThinkER`
3. Update `.github/workflows/build_macos.yml` and `build_windows.yml` for `deepThinkER`
4. Update `windows/BUILD.md` — note `http` package (pure Dart, no native setup needed)
5. Create GitHub Release v1.0.0 with macOS DMG attached and release notes

**Relevant Context**
- macOS network entitlement must be present in Release.entitlements or HTTP calls will fail in the signed DMG
- `http` package is pure Dart — no additional platform-level config required for Windows
- GitHub account: `007Style`

**Status:** [ ] pending

---

---

## Phase Structure

Sub-Tasks 1–24 are the **Core Phase** — the foundational deepThinkER feature set.
The following phases are designed to be implemented *after* the core is complete and stable.
Each phase is self-contained and can be tackled independently.

| Phase | Name | Sub-Tasks | Depends On |
|-------|------|-----------|------------|
| Core | deepThinkER Foundation | 1–24 | — |
| Phase A | Safety & Security Hardening | 25–27 | Core complete |
| Phase B | Settings & App Lifecycle | 28–30 | Core complete |
| Phase C | Notifications & Sound | 31–32 | Core complete |
| Phase D | Export & Sharing | 33–34 | Core complete |
| Phase E | Accessibility & Power User | 35–36 | Core complete |
| Phase F | Developer & Debug Tools | 37–38 | Core complete |

---

## Phase A — Safety & Security Hardening

### Sub-Task 25 — Prompt Injection Guard (Core)

**Intent**
Prevent malicious web content from hijacking the tool-call interceptor. A webpage could
intentionally contain text like `[SHELL: rm -rf /]` designed to be injected into the LLM's
context and trigger tool execution. This must be neutralised before injection.

**Expected Outcomes**
- All injected web content (from `[SEARCH:]`, `[FETCH:]`, `[FILE_READ:]`) is scanned for tool-call tag patterns before being passed to the LLM
- Any `[TAGNAME: ...]` pattern found inside injected content is escaped to `(TAGNAME: ...)` — neutralised but still readable by the LLM
- Escaping is applied only to injected content — character-generated tags are unaffected
- A sanitisation log entry is written to the audit log when an injection attempt is detected

**Todo List**
1. Write `lib/core/security/injection_guard.dart` — scans a string for `[WORD: ...]` patterns matching any registered `ToolRegistry` tag; escapes matches to `(WORD: ...)`
2. Update `lib/core/tools/tool_call_interceptor.dart` — pipe all injected web/file content through `InjectionGuard.sanitise()` before injecting into LLM context
3. Update `lib/core/audit/audit_entry.dart` — add `injectionAttemptDetected` boolean field
4. Write unit tests in `test/security/injection_guard_test.dart`

**Relevant Context**
- Only escape tags whose names match a registered tool in `ToolRegistry` — generic `[brackets]` in web content are not touched
- Audit log entry on detection helps the user see if a site tried to hijack their characters

**Status:** [ ] pending

---

### Sub-Task 26 — Content Safety Filter (Core + UI)

**Intent**
Give the user an optional content filter that scans injected HTML and character responses
for configurable blocked categories before they reach the LLM or the display. No cloud API —
pure local keyword/pattern matching.

**Expected Outcomes**
- User-configurable blocked category list (e.g. "adult", "violence", "hate speech") — each category has a bundled keyword list
- Injected web content matching a blocked category is replaced with `[CONTENT_FILTERED: category]` before LLM injection
- Character response content matching a blocked category is replaced with a redaction notice in the UI (optional — user-togglable)
- Filter is disabled by default — opt-in
- Filter status indicator in each quadrant header (shield icon, grey=off, green=on)

**Todo List**
1. Write `lib/core/security/content_filter.dart` — loads category keyword lists, `scan(text)` returns matched categories, `sanitise(text)` replaces matches
2. Write `lib/core/security/filter_config.dart` — enabled flag, active categories list, custom keyword additions; persisted to `AppSettings`
3. Bundle keyword lists as assets: `assets/filters/adult.txt`, `violence.txt`, `hate.txt` — simple newline-delimited word lists
4. Update `lib/core/tools/tool_call_interceptor.dart` — pipe injected content through `ContentFilter.sanitise()` when filter is enabled
5. Write `lib/ui/widgets/filter_status_indicator.dart` — small shield icon in quadrant header, tappable to open filter settings
6. Update `lib/ui/screens/settings_screen.dart` — add content filter section: enable toggle, category checkboxes, custom keywords field

**Relevant Context**
- Filter is intentionally simple — keyword matching, not ML classification
- Character response filtering is the more controversial direction — keep it opt-in and clearly labelled
- Keyword lists are bundled as plain text assets — user can inspect and modify them

**Status:** [ ] pending

---

### Sub-Task 27 — Extended Model Registry with llava (Core)

**Intent**
Add `llava:7b` (vision model) to the base model registry so it is downloaded alongside
the four character models at first launch. Update `ModelManager` to handle 5 models.
This removes the on-demand download brittleness from Sub-Task 15.

**Expected Outcomes**
- `llava:7b` added to `ModelRegistry` with name, tag, RAM size (~4.7GB), description "Vision — image analysis"
- First-launch download screen shows 5 progress bars (4 character models + llava)
- Total RAM display on startup config includes llava RAM
- `ModelManager` tracks llava download/presence status alongside character models
- `VisionClient` (Sub-Task 15) uses the pre-downloaded llava rather than triggering on-demand download

**Todo List**
1. Update `lib/core/ollama/model_registry.dart` — add `llava:7b` entry with all metadata
2. Update `lib/core/ollama/model_manager.dart` — include llava in the models-to-check-and-pull list at first launch
3. Update `lib/ui/screens/first_launch_screen.dart` — add 5th progress bar for llava
4. Update `lib/ui/widgets/ram_total_display.dart` — include llava in RAM calculation (note: llava only loaded on demand even though pre-downloaded — clarify in UI tooltip)
5. Update `lib/ui/screens/model_help_screen.dart` — add llava to the model reference table

**Relevant Context**
- llava is pre-downloaded but only loaded by Ollama when `VisionClient` fires — it does not consume RAM at idle
- RAM tooltip: "llava (~4.7GB) loaded on image analysis only"
- Model registry RAM note applies to loaded state — UI should distinguish idle-downloaded vs active-loaded

**Status:** [ ] pending

---

## Phase B — Settings & App Lifecycle

### Sub-Task 28 — Unified AppSettings Model (Core + UI)

**Intent**
Replace the ad-hoc per-sub-task config scattered across startup config with a single
`AppSettings` model that owns all user preferences, loaded at startup and saved on change.
This is the settings foundation every other sub-task should have been building against.

**Expected Outcomes**
- `AppSettings` model covers: rate limit config, domain whitelist, workspace path, persona text, proactive injection toggle, vision model name, content filter config, llava auto-download, sound enabled, notification enabled, keyboard shortcuts map
- Single source of truth — all sub-tasks that currently read config read from `AppSettings`
- Settings persisted to `~/Documents/deepThinkER/settings.json`
- In-session Settings screen accessible from the main screen menu bar (not just startup config)
- Settings changes take effect immediately without app restart where possible

**Todo List**
1. Write `lib/core/settings/app_settings.dart` — full settings model with all fields and sensible defaults
2. Write `lib/core/settings/settings_persistence.dart` — load/save `settings.json`; migrations for schema version changes
3. Write `lib/core/settings/settings_provider.dart` — singleton that holds current `AppSettings`, exposes `Stream<AppSettings>` for reactive UI updates
4. Write `lib/ui/screens/settings_screen.dart` — in-session settings panel: tabbed layout (Network, Tools, Safety, Display, Advanced)
5. Update all sub-tasks' config reading points to use `SettingsProvider` instead of local state
6. Add "Settings" entry to main screen menu bar and Help menu

**Relevant Context**
- Settings schema versioning: include a `schemaVersion` integer field — increment when adding new fields, migrate old files on load
- `SettingsProvider` is a singleton initialised before `main()` starts the Flutter app
- Settings screen tabs map to plan phases: Network tab covers Sub-Tasks 2/3/7/21; Tools tab covers Sub-Tasks 14/15; Safety tab covers Sub-Tasks 25/26; Display tab covers Sub-Tasks 31/32/35/36

**Status:** [ ] pending

---

### Sub-Task 29 — Ollama Crash Recovery (Core)

**Intent**
Detect when the Ollama process dies mid-session, attempt automatic restart, pause all
inference workers gracefully, and notify the user — without losing the session state.

**Expected Outcomes**
- `OllamaLauncher` monitors the Ollama process health via periodic ping to `/api/tags`
- On crash detection: all 4 `InferenceWorker` instances paused, session log flushed, user notified
- Automatic restart attempted up to 3 times with 5-second backoff
- On successful restart: models reloaded (KEEP_ALIVE re-applied), inference workers resumed
- On failed restart after 3 attempts: user shown error dialog with manual restart instructions
- Crash events logged to analytics and session log

**Todo List**
1. Update `lib/core/ollama/ollama_launcher.dart` — add health monitor: periodic `GET /api/tags` ping every 10 seconds, fire `OllamaCrashEvent` on failure
2. Write `lib/core/ollama/ollama_health_monitor.dart` — ping loop, crash detection, restart orchestration with exponential backoff
3. Update `lib/core/conversation/conversation_engine.dart` — listen for `OllamaCrashEvent`, pause all workers, resume on recovery event
4. Write `lib/ui/widgets/ollama_status_indicator.dart` — small status dot in the status band: green=healthy, amber=restarting, red=failed
5. Write `lib/ui/widgets/ollama_crash_dialog.dart` — user-facing dialog on failed recovery with manual restart instructions
6. Update `lib/core/session/session_manager.dart` — ensure log is flushed synchronously on crash event

**Relevant Context**
- Health ping: `GET http://localhost:11434/api/tags` — if it fails or times out, Ollama is down
- Ping interval: 10 seconds (low overhead, fast detection)
- Workers are paused (not stopped) on crash — their state is preserved for resume
- Session log continuous saving from deepThink already handles mid-session flush — confirm it covers new event types

**Status:** [ ] pending

---

### Sub-Task 30 — Graceful Shutdown & Session Auto-Save (Core)

**Intent**
Ensure the app shuts down cleanly under all conditions — normal quit, force quit, OS
shutdown — flushing all in-progress state to disk before the process ends.

**Expected Outcomes**
- On normal quit: all inference workers stopped gracefully, analytics flushed, audit log flushed, session log closed with end timestamp
- On force quit / SIGTERM: best-effort flush via `dart:io` signal handler — session log and audit log written
- Session marked as `incomplete` in the log if workers were still active at shutdown time
- App re-open after unclean shutdown: detects incomplete session flag, offers to load it via Conversation Replay

**Todo List**
1. Write `lib/core/lifecycle/app_lifecycle_manager.dart` — listens for Flutter `AppLifecycleState.detached` and OS signals; orchestrates ordered shutdown: stop workers → flush analytics → flush audit → close session log
2. Update `lib/core/session/session_manager.dart` — add `markIncomplete()` and `markComplete()` methods; write end timestamp on clean close
3. Write `lib/ui/screens/startup_config_screen.dart` update — detect incomplete session on launch, offer "Resume last session?" option linking to Conversation Replay

**Relevant Context**
- Flutter `AppLifecycleState.detached` fires on macOS app quit — reliable for normal quit
- SIGTERM handling: use `ProcessSignal.sigterm.watch()` from `dart:io` for force-quit best-effort
- Workers stopped via `ConversationEngine.stop()` which already exists from deepThink

**Status:** [ ] pending

---

## Phase C — Notifications & Sound

### Sub-Task 31 — System Notifications (UI)

**Intent**
Send native macOS and Windows system notifications for key events so the user knows
something happened even when the app is in the background or minimised.

**Expected Outcomes**
- Notifications sent for: research session phase change, research session complete, character hits rate limit 3x in a row, character trust drops to Low tier, image auto-analysed, Ollama crash/recovery
- Notifications are grouped by event type — no flooding
- User can configure which event types trigger notifications in Settings
- macOS: uses `flutter_local_notifications` package; Windows: same package

**Todo List**
1. Add `flutter_local_notifications` to `pubspec.yaml`
2. Write `lib/core/notifications/notification_service.dart` — wraps `flutter_local_notifications`, exposes `notify(title, body, category)`, handles per-category enable/disable from `AppSettings`
3. Write `lib/core/notifications/notification_event.dart` — typed events: `ResearchPhaseChanged`, `RateLimitStreak`, `TrustTierDropped`, `ImageAnalysed`, `OllamaCrashed`, `OllamaRecovered`
4. Hook notification events into: `ResearchEngine`, `RateLimiter`, `TrustManager`, `ImageWatcher`, `OllamaHealthMonitor`
5. Update `lib/ui/screens/settings_screen.dart` — add Notifications tab: per-category toggle switches

**Relevant Context**
- `flutter_local_notifications` supports macOS and Windows natively
- Rate limit streak threshold: 3 consecutive denials for the same character within 5 minutes
- Notifications must not fire when the app window is in the foreground — check `AppLifecycleState`

**Status:** [ ] pending

---

### Sub-Task 32 — Sound Cues (UI)

**Intent**
Add subtle audio feedback for key in-app events. All sounds are optional and configurable.
No external audio libraries — use Flutter's built-in `audioplayers` package with bundled assets.

**Expected Outcomes**
- Sound plays on: new AI message received, user message sent, rate limit hit, research phase transition, research complete, character trust tier change, image analysed
- All sounds are short, subtle, and non-intrusive (< 1 second each)
- Global sound on/off toggle in Settings
- Per-event sound enable/disable in Settings
- Sound assets bundled in `assets/sounds/`

**Todo List**
1. Add `audioplayers` to `pubspec.yaml`
2. Source/create 7 short audio assets (`.mp3` or `.ogg`): `message.mp3`, `send.mp3`, `rate_limit.mp3`, `phase_change.mp3`, `research_complete.mp3`, `trust_change.mp3`, `image_analysed.mp3`
3. Write `lib/ui/sound/sound_service.dart` — loads assets, plays on event, respects global + per-event toggles from `AppSettings`
4. Hook sound events into: `ConversationEngine` (new message), `UserInputBar` (send), `RateLimiter` (denied), `ResearchEngine` (phase/complete), `TrustManager` (tier change), `ImageWatcher` (analysed)
5. Update `lib/ui/screens/settings_screen.dart` — add Sound section: global toggle + per-event toggles

**Relevant Context**
- `audioplayers` is a well-maintained Flutter package with macOS and Windows support
- Sound assets should be royalty-free; source from freesound.org or generate with a tone generator
- Sound plays on main isolate only — no sound from background workers

**Status:** [ ] pending

---

## Phase D — Export & Sharing

### Sub-Task 33 — Export Bundle (Core + UI)

**Intent**
One-click export of a complete session package — conversation log, analytics, research
report (if any), and audit entries — as a named `.zip` file. Clean and shareable.

**Expected Outcomes**
- "Export Session" button in the analytics screen and session end dialog
- Export produces a `.zip` named `<sessionName>_<date>.zip` containing:
  - `conversation.txt` — clean formatted conversation (no raw HTML, no tool-call noise)
  - `analytics.json` — full session analytics
  - `research_report.md` — research report if session included research mode (else omitted)
  - `audit.csv` — audit log entries for this session only
  - `README.txt` — brief description of the session and export contents
- User picks save location via system file picker
- Export runs in background — no UI freeze

**Todo List**
1. Add `archive` package to `pubspec.yaml` (pure Dart zip library)
2. Write `lib/core/export/session_exporter.dart` — assembles all session artefacts, builds zip in memory, writes to user-chosen path
3. Write `lib/core/export/conversation_formatter.dart` — strips tool-call tags, raw HTML injections, and system messages from the log; produces clean human-readable text
4. Write `lib/ui/widgets/export_button.dart` — button with loading state; triggers `SessionExporter` in a background isolate
5. Add export button to `lib/ui/screens/analytics_screen.dart` and session-end dialog in `main_screen.dart`

**Relevant Context**
- `archive` package: pure Dart, no native deps, well-maintained
- `conversation_formatter.dart`: include speaker name + timestamp per message; strip `[WEB_RESULT...]`, `[SYSTEM_STEER...]`, `[PROACTIVE_WEB_RESULT...]` blocks
- Export runs in a separate Dart isolate to avoid blocking UI

**Status:** [ ] pending

---

### Sub-Task 34 — Markdown Conversation Export (Core + UI)

**Intent**
Export the conversation as clean, styled Markdown — suitable for pasting into a document,
blog post, or sharing with someone who wasn't in the session.

**Expected Outcomes**
- "Export as Markdown" option in the analytics screen and Help menu
- Output format: character name as bold header per message block, timestamp in italics, message body as plain text
- Search activity entries shown as blockquotes: `> 🌐 WATSON searched: query`
- Research report appended as a final section if present
- File named `<sessionName>.md`, user picks save location

**Todo List**
1. Write `lib/core/export/markdown_exporter.dart` — formats `ConversationLog` entries as Markdown; handles regular messages, whisper messages (marked as `[private]`), search activity entries, system events
2. Add "Export as Markdown" to `lib/ui/screens/analytics_screen.dart` and Help menu

**Relevant Context**
- Reuses `conversation_formatter.dart` logic from Sub-Task 33 — Markdown exporter calls formatter then applies Markdown structure
- Whisper messages exported as `> 🤫 USER → WATSON (private): message` — visible in export since the export is owned by the user

**Status:** [ ] pending

---

## Phase E — Accessibility & Power User

### Sub-Task 35 — Keyboard Shortcuts (UI)

**Intent**
Add a comprehensive keyboard shortcut system so power users can drive the entire app
without touching the mouse. All shortcuts are configurable.

**Expected Outcomes**
- Default shortcuts: Send message (Enter), Send whisper (Cmd+Enter), Toggle steering bar (Cmd+/), Open research mode (Cmd+R), Open settings (Cmd+,), Open analytics (Cmd+A), Toggle network for focused character (Cmd+N), Export session (Cmd+E)
- Shortcut map displayed in Help menu under "Keyboard Shortcuts"
- User can rebind any shortcut in Settings → Advanced
- Shortcuts work globally within the app window (not just when input is focused)

**Todo List**
1. Write `lib/core/settings/keyboard_shortcut_map.dart` — default shortcut definitions; stored in `AppSettings`
2. Write `lib/ui/input/shortcut_handler.dart` — Flutter `Shortcuts` + `Actions` wiring; reads from `KeyboardShortcutMap`
3. Write `lib/ui/screens/shortcut_editor.dart` — Settings → Advanced tab: list of actions + current bindings + rebind UI
4. Update `lib/ui/screens/main_screen.dart` — wrap with `shortcut_handler` at root level
5. Add "Keyboard Shortcuts" entry to Help menu showing current bindings

**Relevant Context**
- Flutter `Shortcuts` widget + `Actions` widget is the idiomatic approach — no third-party package needed
- Shortcut rebinding: detect key press in a recording widget, validate no conflict with existing bindings
- macOS uses Cmd key; Windows uses Ctrl — `LogicalKeyboardKey` handles this cross-platform

**Status:** [ ] pending

---

### Sub-Task 36 — Accessibility & Display Settings (UI)

**Intent**
Add font size scaling, high-contrast mode, and reduced-motion mode to make the app
usable for people with accessibility needs. All settings are in the Display tab of Settings.

**Expected Outcomes**
- Font size scaler: Small / Medium (default) / Large / XL — scales all conversation text and UI labels
- High-contrast mode: replaces the dark theme palette with a higher-contrast variant (white text on near-black, no subtle greys)
- Reduced-motion mode: disables all animations (avatar particles, trust badge pulse, mood indicator animation, research phase transitions) — static states only
- Settings take effect immediately without restart
- All settings persist in `AppSettings`

**Todo List**
1. Write `lib/ui/theme/accessibility_theme.dart` — high-contrast colour palette; font size scale factors
2. Update `lib/ui/widgets/app_theme.dart` — apply font scale and colour palette from `AppSettings.displaySettings`
3. Write `lib/ui/theme/motion_policy.dart` — `AnimationPolicy` enum (full, reduced); propagated via `InheritedWidget` so all animated widgets can check it
4. Update all animated widgets (energy orb, trust badge, mood indicator, phase indicator, research phase transitions) — check `MotionPolicy` before animating; show static state if reduced
5. Update `lib/ui/screens/settings_screen.dart` — Display tab: font size selector, high-contrast toggle, reduced-motion toggle

**Relevant Context**
- `InheritedWidget` for `AnimationPolicy` is the clean Flutter pattern — avoids passing policy through every constructor
- Font scale is applied at the `ThemeData.textTheme` level — one change propagates everywhere
- High-contrast mode is a theme swap, not a filter — define the palette explicitly

**Status:** [ ] pending

---

## Phase F — Developer & Debug Tools

### Sub-Task 37 — Offline Simulation Mode (Core + UI)

**Intent**
A mock `OllamaClient` that returns scripted or randomised responses, enabling development
and testing of all deepThinkER systems without Ollama running. Available in debug builds only.

**Expected Outcomes**
- `MockOllamaClient` implements the same interface as `OllamaClient` — drop-in replacement
- Mock responses are configurable: scripted (from a JSON fixture file) or randomised (pick from a phrase bank)
- Mock client simulates streaming token-by-token with configurable delay
- Mock client can emit tool-call tags (`[SEARCH:]`, `[RECALL:]` etc.) on a configured schedule for testing the interceptor
- Debug-only UI panel: "Simulation Mode" toggle in app menu bar (debug builds only)
- All trust, mood, relationship, analytics, and audit systems run normally against mock output

**Todo List**
1. Write `lib/core/debug/mock_ollama_client.dart` — implements `OllamaClient` interface; reads fixtures from `assets/debug/mock_responses.json`; streams tokens with delay
2. Write `lib/core/debug/mock_response_fixture.dart` — fixture model: characterName, responseText, delayMs, toolCallsToEmit list
3. Write `assets/debug/mock_responses.json` — sample fixture set covering: normal response, tool call, pass response, long response near context limit
4. Update `lib/core/ollama/ollama_client.dart` — factory constructor that returns `MockOllamaClient` when `kDebugMode && SimulationMode.enabled`
5. Write `lib/ui/debug/simulation_mode_toggle.dart` — debug-only menu bar item; only compiled in debug builds via `kDebugMode` guard

**Relevant Context**
- `kDebugMode` from `package:flutter/foundation.dart` — simulation UI is dead code in release builds
- Fixtures stored as assets so they can be edited without recompile
- Mock streaming delay: configurable 50–200ms per token to simulate real inference speed

**Status:** [ ] pending

---

### Sub-Task 38 — Trust & State Simulator Panel (UI)

**Intent**
A debug-only panel for manually manipulating trust scores, mood states, relationship scores,
and rate limit counters — to verify UI behaviour and edge cases without waiting for natural
state changes.

**Expected Outcomes**
- Debug panel accessible via Cmd+Shift+D (debug builds only)
- Panel shows per-character: trust score slider (0–100), mood state dropdown, network toggle override
- Panel shows relationship matrix with editable score fields
- "Fire Rate Limit Violation" button per character
- "Trigger Research Phase Transition" button
- "Simulate Ollama Crash" button
- All changes take immediate effect in the live UI
- Panel is completely absent from release builds

**Todo List**
1. Write `lib/ui/debug/state_simulator_panel.dart` — debug-only overlay panel with all controls listed above; guarded by `kDebugMode`
2. Write `lib/core/debug/debug_controller.dart` — exposes methods: `setTrust(character, score)`, `setMood(character, state)`, `setRelationship(a, b, score)`, `fireRateLimitViolation(character)`, `simulateOllamaCrash()`; calls into live managers
3. Update `lib/ui/screens/main_screen.dart` — register Cmd+Shift+D shortcut (debug only) to toggle `StateSimulatorPanel` overlay

**Relevant Context**
- `kDebugMode` guard means zero release binary impact — Flutter tree-shakes dead code paths
- `DebugController` calls the real `TrustManager`, `MoodEngine`, `RelationshipMatrix` etc. — not mocks — so the UI responds as it would in production
- Panel is an overlay, not a screen — appears on top of main screen without navigation

**Status:** [ ] pending

```
deepThinkER/
├── lib/
│   ├── core/                              ← Pure Dart, no Flutter imports
│   │   ├── ollama/                        ← Inherited from deepThink (unchanged)
│   │   ├── conversation/                  ← Inherited; inference_worker, conversation_engine,
│   │   │   │                                system_prompt_builder, context_manager updated
│   │   │   ├── whisper_message.dart       ← NEW
│   │   │   └── character_swap_event.dart  ← NEW
│   │   ├── context/                       ← Inherited; context_manager updated (ephemeral flag)
│   │   ├── session/                       ← Inherited; session_loader + replay_mode added
│   │   │   ├── session_loader.dart        ← NEW
│   │   │   └── replay_mode.dart           ← NEW
│   │   ├── trust/                         ← NEW
│   │   │   ├── trust_score.dart
│   │   │   ├── trust_event.dart
│   │   │   ├── trust_manager.dart
│   │   │   └── trust_persistence.dart
│   │   ├── network/                       ← NEW
│   │   │   ├── rate_limiter.dart
│   │   │   ├── rate_limit_config.dart
│   │   │   ├── network_fetcher.dart
│   │   │   ├── fetch_result.dart
│   │   │   ├── proactive_injector.dart
│   │   │   ├── topic_extractor.dart
│   │   │   └── domain_whitelist.dart      ← NEW (Sub-Task 21)
│   │   ├── tools/                         ← NEW — extensible AgentTool registry
│   │   │   ├── agent_tool.dart
│   │   │   ├── tool_result.dart
│   │   │   ├── tool_registry.dart
│   │   │   ├── tool_call_parser.dart
│   │   │   ├── tool_call_interceptor.dart
│   │   │   ├── network/
│   │   │   │   ├── network_search_tool.dart
│   │   │   │   └── network_fetch_tool.dart
│   │   │   ├── shell/                     ← stub, fully scaffolded
│   │   │   │   ├── shell_tool.dart
│   │   │   │   └── shell_config.dart
│   │   │   ├── memory/                    ← NEW (Sub-Task 11)
│   │   │   │   ├── remember_tool.dart
│   │   │   │   └── recall_tool.dart
│   │   │   ├── file/                      ← NEW (Sub-Task 14)
│   │   │   │   ├── file_read_tool.dart
│   │   │   │   ├── file_write_tool.dart
│   │   │   │   └── file_tool_config.dart
│   │   │   ├── calc/                      ← NEW (Sub-Task 14)
│   │   │   │   └── calc_tool.dart
│   │   │   └── image/                     ← NEW (Sub-Task 15)
│   │   │       ├── image_tool.dart
│   │   │       ├── image_watcher.dart
│   │   │       ├── vision_client.dart
│   │   │       └── image_tool_config.dart
│   │   ├── memory/                        ← NEW (Sub-Task 11)
│   │   │   ├── memory_entry.dart
│   │   │   ├── memory_store.dart
│   │   │   ├── memory_persistence.dart
│   │   │   └── memory_query.dart
│   │   ├── mood/                          ← NEW (Sub-Task 12)
│   │   │   ├── mood_score.dart
│   │   │   ├── mood_engine.dart
│   │   │   └── mood_config.dart
│   │   ├── relationships/                 ← NEW (Sub-Task 13)
│   │   │   ├── relationship_score.dart
│   │   │   ├── relationship_matrix.dart
│   │   │   ├── relationship_analyser.dart
│   │   │   └── relationship_persistence.dart
│   │   ├── persona/                       ← NEW (Sub-Tasks 18, 20)
│   │   │   ├── user_persona.dart
│   │   │   └── custom_character.dart
│   │   ├── steering/                      ← NEW (Sub-Task 18)
│   │   │   └── steering_engine.dart
│   │   ├── analytics/                     ← NEW (Sub-Task 16)
│   │   │   ├── session_analytics.dart
│   │   │   └── analytics_event.dart
│   │   ├── audit/                         ← NEW (Sub-Task 17)
│   │   │   ├── audit_log.dart
│   │   │   ├── audit_entry.dart
│   │   │   └── audit_persistence.dart
│   │   ├── research/                      ← NEW (Sub-Task 23)
│   │   │   ├── research_session.dart
│   │   │   ├── research_engine.dart
│   │   │   ├── report_generator.dart
│   │   │   └── research_config.dart
│   │   ├── security/                      ← Phase A (Sub-Tasks 25–26)
│   │   │   ├── injection_guard.dart
│   │   │   ├── content_filter.dart
│   │   │   └── filter_config.dart
│   │   ├── settings/                      ← Phase B (Sub-Task 28)
│   │   │   ├── app_settings.dart
│   │   │   ├── settings_persistence.dart
│   │   │   ├── settings_provider.dart
│   │   │   └── keyboard_shortcut_map.dart ← Phase E (Sub-Task 35)
│   │   ├── lifecycle/                     ← Phase B (Sub-Task 30)
│   │   │   └── app_lifecycle_manager.dart
│   │   ├── notifications/                 ← Phase C (Sub-Task 31)
│   │   │   ├── notification_service.dart
│   │   │   └── notification_event.dart
│   │   ├── export/                        ← Phase D (Sub-Tasks 33–34)
│   │   │   ├── session_exporter.dart
│   │   │   ├── conversation_formatter.dart
│   │   │   └── markdown_exporter.dart
│   │   └── debug/                         ← Phase F (Sub-Tasks 37–38) — debug builds only
│   │       ├── mock_ollama_client.dart
│   │       ├── mock_response_fixture.dart
│   │       └── debug_controller.dart
│   └── ui/                                ← Flutter only
│       ├── avatars/                       ← Inherited from deepThink (unchanged)
│       ├── quadrants/                     ← ai_quadrant.dart updated
│       ├── widgets/
│       │   ├── ...                        ← Inherited from deepThink
│       │   ├── trust_badge/               ← NEW
│       │   │   ├── trust_badge.dart
│       │   │   └── trust_sparkline_widget.dart  ← NEW (Sub-Task 21)
│       │   ├── network_indicator/         ← NEW
│       │   │   ├── network_toggle.dart
│       │   │   ├── rate_limit_flash.dart
│       │   │   └── search_activity_entry.dart
│       │   ├── mood_indicator/            ← NEW (Sub-Task 12)
│       │   │   └── mood_indicator.dart
│       │   ├── token_counter/             ← NEW (Sub-Task 16)
│       │   │   └── token_counter_widget.dart
│       │   ├── analytics/                 ← NEW (Sub-Task 16)
│       │   │   ├── heatmap_painter.dart
│       │   │   └── trust_sparkline.dart
│       │   ├── research/                  ← NEW (Sub-Task 23)
│       │   │   ├── phase_indicator.dart
│       │   │   └── report_preview_widget.dart
│       │   ├── relationship_matrix_widget.dart  ← NEW (Sub-Task 13)
│       │   ├── steering_input_bar.dart    ← NEW (Sub-Task 18)
│       │   ├── whisper_selector.dart      ← NEW (Sub-Task 19)
│       │   ├── whitelist_editor.dart      ← NEW (Sub-Task 21)
│       │   ├── character_picker_dialog.dart  ← NEW (Sub-Task 20)
│       │   ├── replay_banner.dart         ← NEW (Sub-Task 22)
│       │   ├── filter_status_indicator.dart  ← Phase A (Sub-Task 26)
│       │   ├── export_button.dart         ← Phase D (Sub-Task 33)
│       │   └── ollama_status_indicator.dart  ← Phase B (Sub-Task 29)
│       ├── about/                         ← Inherited, about_screen updated
│       ├── sound/                         ← Phase C (Sub-Task 32)
│       │   └── sound_service.dart
│       ├── theme/                         ← Phase E (Sub-Task 36)
│       │   ├── accessibility_theme.dart
│       │   └── motion_policy.dart
│       ├── input/                         ← Phase E (Sub-Task 35)
│       │   └── shortcut_handler.dart
│       ├── debug/                         ← Phase F (Sub-Tasks 37–38) — debug builds only
│       │   ├── simulation_mode_toggle.dart
│       │   └── state_simulator_panel.dart
│       └── screens/
│           ├── ...                        ← Inherited from deepThink
│           ├── startup_config_screen.dart ← updated
│           ├── memory_panel_screen.dart   ← NEW (Sub-Task 11)
│           ├── analytics_screen.dart      ← NEW (Sub-Task 16)
│           ├── audit_log_screen.dart      ← NEW (Sub-Task 17)
│           ├── custom_character_editor.dart  ← NEW (Sub-Task 20)
│           ├── research_mode_screen.dart  ← NEW (Sub-Task 23)
│           ├── settings_screen.dart       ← Phase B (Sub-Task 28)
│           └── shortcut_editor.dart       ← Phase E (Sub-Task 35)
├── assets/
│   ├── ollama/                            ← Inherited from deepThink
│   ├── filters/                           ← Phase A (Sub-Task 26)
│   │   ├── adult.txt
│   │   ├── violence.txt
│   │   └── hate.txt
│   ├── sounds/                            ← Phase C (Sub-Task 32)
│   │   ├── message.mp3
│   │   ├── send.mp3
│   │   ├── rate_limit.mp3
│   │   ├── phase_change.mp3
│   │   ├── research_complete.mp3
│   │   ├── trust_change.mp3
│   │   └── image_analysed.mp3
│   └── debug/                             ← Phase F (Sub-Task 37) — excluded from release
│       └── mock_responses.json
├── scripts/
│   └── build_dmg.sh                       ← updated
├── windows/
│   └── BUILD.md                           ← updated
├── .github/
│   └── workflows/
│       ├── build_macos.yml
│       └── build_windows.yml
└── README.md
```
