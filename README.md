<div align="center">

# 🧠 deepThinkER

### *Four AI Minds. One Conversation. Now with Extended Reach over the Internet!*

[![Version](https://img.shields.io/badge/version-1.1.0-blue?style=for-the-badge)](https://github.com/007Style/deepThinkER/releases)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=for-the-badge&logo=apple)](https://github.com/007Style/deepThinkER/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Ollama](https://img.shields.io/badge/Ollama-0.32.9-black?style=for-the-badge)](https://ollama.ai)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

<br/>

> **deepThinkER** is a macOS desktop application where **four distinct AI personalities** — WATSON, DEEP, NOVA, and SAGE — hold live, streaming conversations with each other and with you, powered entirely by **local Ollama models**.
>
> No API keys. No cloud. No data leaving your machine.
>
> *From the minds of **Daneyand** & **IBM Bob**.*

<br/>

### 📖 [Full Documentation →](docs/deepThinkER-Project-Documentation.html)

> Open `docs/deepThinkER-Project-Documentation.html` in your browser for the complete, gorgeous, interactive documentation — covering all 22 sections from installation to architecture.

<br/>

⬇️ **[Download deepThinkER-v1.1.0-macos.dmg](https://github.com/007Style/deepThinkER/releases/latest)**

<br/>

</div>

---

## ✨ What is deepThinkER?

**deepThinkER** is a self-contained local AI panel show. Four AI personalities run simultaneously on your Mac — no internet required, no subscription, no cloud. Version 1.1.0 adds **Extended Reach**: trust-gated internet access, persistent character memory, dynamic moods, relationship tracking, autonomous research mode, and a nine-tool extensible framework.

| Feature | deepThink | deepThinkER |
|---|:---:|:---:|
| Four local AI personalities | ✅ | ✅ |
| Streaming conversation | ✅ | ✅ |
| Bundled Ollama runtime | ✅ | ✅ |
| **Trust-gated internet access** | ❌ | ✅ |
| **Persistent character memory** | ❌ | ✅ |
| **Dynamic mood system** | ❌ | ✅ |
| **Relationship tracking** | ❌ | ✅ |
| **Autonomous research mode** | ❌ | ✅ |
| **Vision / image analysis** | ❌ | ✅ |
| **Full audit log** | ❌ | ✅ |
| **Session analytics** | ❌ | ✅ |

---

## 🎭 The Four Minds

| | Name | Model | Role |
|---|---|---|---|
| 🔵 | **WATSON** | `gemma2:9b` | The Analyst — evidence-based, methodical, cautious searcher |
| 🟣 | **DEEP** | `phi3:14b` | The Host / Strategist — long-horizon, socratic, systems-oriented |
| 🟢 | **NOVA** | `llama3:8b` | The Visionary — creative, cross-domain, exploratory searcher |
| 🟡 | **SAGE** | `mistral:7b` | The Challenger — rigorous, adversarial, principled |

All four are named in honour of landmark IBM AI achievements.

---

## 📦 Quick Install

### Requirements
- macOS 13.0+ (Apple Silicon or Intel)
- 24 GB+ free RAM (20 GB minimum)
- 30 GB+ free disk space (~22.5 GB for models)

### Install from DMG *(Recommended)*

1. Download **[deepThinkER-v1.1.0-macos.dmg](https://github.com/007Style/deepThinkER/releases/latest)** from Releases
2. Drag **deepThinkER.app** to Applications
3. Launch — on first run, models download automatically (~22.5 GB, one-time only)

> **Gatekeeper:** If macOS blocks the app, right-click → Open → Open. Required once only.

---

## 🔨 Building from Source

```bash
# Prerequisites: Flutter 3.x, Xcode, CocoaPods, Git LFS
git clone https://github.com/007Style/deepThinkER.git
cd deepThinkER
git lfs pull                          # Pull bundled Ollama runtime
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos                  # Debug
./scripts/build_dmg.sh               # Release DMG
flutter test                          # Run test suite
```

---

## 📖 Full Documentation

The complete documentation lives in [`docs/deepThinkER-Project-Documentation.html`](docs/deepThinkER-Project-Documentation.html) — a beautiful, dark-themed, interactive HTML document covering all 22 sections:

01. What is deepThinkER?
02. The Four Minds
03. Extended Reach · Internet Access
04. The Trust System
05. The Tool Framework
06. Character Memory
07. Mood System
08. Relationship Matrix
09. Autonomous Research Mode
10. Session Analytics & Audit
11. Interface Overview
12. Architecture Deep-Dive
13. Installation
14. Building from Source
15. Configuration
16. Privacy & Security
17. Data Storage
18. Dependencies
19. Roadmap
20. FAQ
21. Contributing
22. Acknowledgements

> To view locally: `cd docs && python3 -m http.server 8080` then open `http://localhost:8080/deepThinkER-Project-Documentation.html`

---

## 🔒 Privacy

Everything runs locally. The **only** data that ever leaves your machine is the query text of an explicit `[SEARCH:]` or `[FETCH:]` tool call made by a character — and only if you've left internet access enabled. No telemetry. No analytics. No cloud API. Ever.

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

<div align="center">

**deepThinkER — Four AI Minds. One Conversation. Now with Extended Reach over the Internet!**

*From the minds of **Daneyand** & **IBM Bob**. Built with ❤️ and a lot of local GPU time.*

[Releases](https://github.com/007Style/deepThinkER/releases) · [Issues](https://github.com/007Style/deepThinkER/issues) · [Discussions](https://github.com/007Style/deepThinkER/discussions) · [Full Docs](docs/deepThinkER-Project-Documentation.html)

</div>
