# deepThinkER — Extended Reach

> A hard fork of [deepThink](https://github.com/007Style/deepThink) — four AI personalities in
> parallel conversation, now with controlled internet access, trust-gated tool calls, persistent
> character memory, mood, inter-character relationships, and an autonomous research mode.

---

## What's New in deepThinkER

| Feature | Description |
|---------|-------------|
| 🌐 **Internet Access** | Characters search DuckDuckGo and fetch pages via `[SEARCH:]` / `[FETCH:]` tool tags |
| 🔒 **Trust System** | Per-character trust score (0–100) gates network rate limits; decays and grows over time |
| 🧰 **Tool Framework** | Extensible `AgentTool` registry — shell, file, calc, image, memory tools all plug in the same way |
| 🧠 **Character Memory** | Each character builds a persistent long-term memory store across sessions |
| 😤 **Mood System** | Mood shifts based on conversation dynamics; modifies system prompt tone |
| 🤝 **Relationships** | Characters form opinions of each other; scores persist and affect how they address one another |
| 🔬 **Research Mode** | Characters autonomously gather, debate, and synthesise findings on a topic you set |
| 🤫 **Whisper Mode** | Private messages to a single character, invisible to the others |
| 🎭 **Hot-Swap** | Replace a character mid-session without stopping the conversation |
| ⏪ **Replay** | Load a past session and continue or reflect on it |

---

## Fork Origin

deepThinkER is a **hard fork** of `007Style/deepThink` v1.0.2+3.

- The Git history starts fresh — no upstream link to deepThink
- Core files (`inference_worker`, `system_prompt_builder`, `context_manager`, `conversation_engine`) are significantly modified
- `deepThink` and `deepThinkER` are independent projects sharing a common ancestry

---

## Characters

| Name | IBM Reference | Personality | Default Model |
|------|---------------|-------------|---------------|
| WATSON | IBM Watson AI | The Analyst | gemma2:9b |
| DEEP | Deep Blue | The Strategist | phi3:14b |
| NOVA | IBM POWER | The Visionary | llama3:8b |
| SAGE | IBM NL Research | The Challenger | mistral:7b |

---

## Models

| Model | Tag | ~RAM |
|-------|-----|------|
| Mistral 7B | mistral:7b | ~4.1 GB |
| Llama 3 8B | llama3:8b | ~4.7 GB |
| Gemma 2 9B | gemma2:9b | ~5.5 GB |
| Phi-3 14B | phi3:14b | ~8.2 GB |
| llava 7B | llava:7b | ~4.7 GB (vision — loaded on demand) |

All models download at first launch. App runs fully offline after that.

---

## Architecture

See [DESIGN.md](DESIGN.md) for the full build plan, sub-task list, and architecture diagram.

```
lib/
├── core/          ← Pure Dart — no Flutter imports
│   ├── ollama/    ← Ollama client, model manager, hardware detector
│   ├── conversation/  ← Engine, workers, context management
│   ├── trust/     ← Trust scores, decay/gain, persistence
│   ├── network/   ← Fetcher, rate limiter, proactive injector
│   ├── tools/     ← AgentTool registry + all tool implementations
│   ├── memory/    ← Per-character persistent memory
│   ├── mood/      ← Session-scoped mood engine
│   ├── relationships/ ← Cross-session relationship matrix
│   ├── research/  ← Autonomous research mode engine
│   └── ...
└── ui/            ← Flutter only
    ├── quadrants/ ← 4-pane conversation layout
    ├── widgets/   ← Trust badge, network toggle, mood indicator, etc.
    └── screens/   ← Main, startup, research, analytics, memory panel
```

---

## Build (macOS)

```bash
flutter pub get
flutter build macos
```

Requires Flutter 3.x and Ollama installed locally.

---

## Data Locations

| Data | Path |
|------|------|
| Session logs | `~/Documents/deepThinkER/sessions/` |
| Memory stores | `~/Documents/deepThinkER/memory/` |
| Trust scores | `~/Documents/deepThinkER/trust.json` |
| Relationships | `~/Documents/deepThinkER/relationships.json` |
| Settings | `~/Documents/deepThinkER/settings.json` |
| Workspace | `~/Documents/deepThinkER/workspace/` |
| Research reports | `~/Documents/deepThinkER/reports/` |
| Audit log | `~/Documents/deepThinkER/audit.json` |

---

## Credits

Built by Daneyand & IBM's Bob  
Contact: daneyand@ibm.com
