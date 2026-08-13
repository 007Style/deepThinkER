# deepThink — Development Guide

> Everything you need to build, run, test, and release deepThink from source.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Clone & Setup](#2-clone--setup)
3. [Project Structure](#3-project-structure)
4. [Running Locally (macOS)](#4-running-locally-macos)
5. [Running Tests](#5-running-tests)
6. [Building a Release DMG](#6-building-a-release-dmg)
7. [Building on Windows](#7-building-on-windows)
8. [CI / GitHub Actions](#8-ci--github-actions)
9. [Adding a New AI Character](#9-adding-a-new-ai-character)
10. [Adding a New Avatar Type](#10-adding-a-new-avatar-type)
11. [Updating the Bundled Ollama Version](#11-updating-the-bundled-ollama-version)
12. [Debugging Ollama Issues](#12-debugging-ollama-issues)
13. [What Changed in v1.0.2](#13-what-changed-in-v102)
14. [Code Style & Conventions](#14-code-style--conventions)
15. [Dependency Notes](#15-dependency-notes)

---

## 1. Prerequisites

### macOS

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.x (stable) | `brew install --cask flutter` |
| Xcode | 15+ | Mac App Store |
| Git LFS | any | `brew install git-lfs` |
| CocoaPods | 1.14+ | `sudo gem install cocoapods` |

Flutter must target macOS desktop. Enable it once:
```bash
flutter config --enable-macos-desktop
```

### Windows (self-compile only)
See [`windows/BUILD.md`](windows/BUILD.md) for the full Windows setup guide.

---

## 2. Clone & Setup

```bash
# 1. Clone (LFS is needed for the Metal shader files)
git clone https://github.com/007Style/deepThink.git
cd deepThink

# 2. Pull LFS objects (the two large .metallib shader files)
git lfs pull

# 3. Install Flutter dependencies
flutter pub get

# 4. Install CocoaPods dependencies
cd macos && pod install && cd ..

# 5. Verify everything is wired
flutter doctor
```

### Git LFS objects
Two Metal shader files in `macos/Runner/ollama/` are stored via LFS:
- `default.metallib` (~127 MB) — standard Apple Silicon compute shaders
- `default-flash-attn.metallib` (~158 MB) — Flash Attention variant

Without `git lfs pull` the app builds but Ollama will fail to run models on GPU.

---

## 3. Project Structure

```
deepThink/
├── lib/
│   ├── main.dart                  # Entry point, startup flow, global error hooks
│   ├── core/                      # Pure Dart — ZERO Flutter imports
│   │   ├── context/               # Context window management
│   │   ├── conversation/          # Engine, workers, log, participants, prompts
│   │   ├── ollama/                # Launcher, client, registry, hardware detector
│   │   └── system/                # Resource monitor
│   └── ui/                        # Flutter UI
│       ├── about/                 # Neural background + wandering characters
│       ├── avatars/               # Plugin avatar system + energy orb
│       ├── quadrants/             # AI quadrant grid
│       ├── screens/               # All full-screen views
│       └── widgets/               # Shared widgets + theme
│
├── test/                          # 132 unit + widget tests
│   ├── core/                      # Pure-Dart unit tests (no Flutter)
│   └── widget_test.dart           # Smoke test
│
├── macos/
│   ├── Runner/
│   │   ├── ollama/                # Bundled Ollama v0.32.9 runtime (Git LFS)
│   │   ├── copy_ollama.sh         # Xcode build phase script
│   │   ├── DebugProfile.entitlements
│   │   └── Release.entitlements
│   └── Runner.xcodeproj/
│
├── windows/
│   └── BUILD.md                   # Windows build instructions
│
├── scripts/
│   └── build_dmg.sh               # macOS DMG packaging script
│
├── .github/workflows/
│   ├── build_macos.yml            # CI: build + package DMG on tag push
│   └── build_windows.yml          # CI: validate Windows build on PR
│
├── ARCHITECTURE.md                # Deep technical design documentation
├── DEVELOPMENT.md                 # This file
└── README.md                      # User-facing project overview
```

---

## 4. Running Locally (macOS)

### Debug run (hot-reload, Dart VM service)
```bash
flutter run -d macos
```

> The "Failed to foreground app; open returned 1" message in the terminal is a
> Flutter DevTools quirk — the app is running fine. Look for the Dart VM service URL.

### Direct launch (no Flutter tooling)
After the first `flutter run` builds the `.app`:
```bash
open build/macos/Build/Products/Debug/deep_think.app
```

### Watching Ollama logs
Ollama's stdout/stderr are forwarded to the Flutter console via `print('[ollama] ...')`.
Run with `flutter run -d macos` and watch the terminal — every model load, inference
request, and error appears there.

### First-time model downloads
After launching, the app will detect that no models are installed and show the download
screen. The four models total ~22.5 GB:

| Model | Size | Character |
|-------|------|-----------|
| `mistral:7b` | ~4.1 GB | SAGE |
| `llama3:8b` | ~4.7 GB | NOVA |
| `gemma2:9b` | ~5.5 GB | WATSON |
| `phi3:14b` | ~8.2 GB | DEEP |

If a download fails with "Ollama pull error … EOF", delete any partial blob files and retry:
```bash
rm ~/.ollama/models/blobs/*-partial* 2>/dev/null
```

---

## 5. Running Tests

```bash
# All tests (132 total)
flutter test

# Specific test file
flutter test test/core/conversation/inference_worker_test.dart

# With verbose output
flutter test --reporter expanded
```

### Test organisation

```
test/
├── core/
│   ├── context/           context_manager_test.dart
│   ├── conversation/      message, log, participant, prompt, worker, user_name_detector
│   ├── ollama/            registry, hardware_detector, model_pull_progress
│   └── session/           name_generator, app_stats, session
└── widget_test.dart       splash screen smoke test
```

All core tests are pure Dart — no Flutter test binding, no mocking framework.
The widget test renders only static widgets to avoid `HttpClient` sandbox restrictions.

---

## 6. Building a Release DMG

### Manual build
```bash
# Full build + package
./scripts/build_dmg.sh

# Skip the Flutter build (re-use existing .app)
SKIP_BUILD=1 ./scripts/build_dmg.sh
```

The script:
1. Runs `flutter build macos --release`
2. Copies the `.app` to a staging folder
3. Creates a `.dmg` with `hdiutil`
4. Also copies a standalone `deep_think.app` alongside the DMG for direct testing
5. Produces `deepThink-v1.0.2.dmg` (~175 MB compressed)

### Via CI
Push a version tag to trigger the GitHub Actions workflow:
```bash
git tag v1.0.2
git push origin v1.0.2
```

The workflow runs on `macos-latest`, pulls LFS, installs dependencies, builds,
packages, and uploads the DMG as a GitHub Release artifact.

---

## 7. Building on Windows

See [`windows/BUILD.md`](windows/BUILD.md) for the complete guide, including:
- Installing Flutter, MSVC, and the Ollama Windows runtime
- Placing the runtime at `<exe dir>\ollama\ollama.exe`
- Packaging with NSIS or Inno Setup

Windows is not released as a binary — it is supported for self-compilation only.

---

## 8. CI / GitHub Actions

### `build_macos.yml`
**Trigger:** Push to `v*` tags (e.g. `v1.0.1`)  
**Steps:** checkout → git-lfs pull → flutter setup → pod install → flutter build → build_dmg.sh → upload artifact

### `build_windows.yml`
**Trigger:** Pull requests  
**Steps:** checkout → flutter setup → flutter build windows (validation only)

---

## 9. Adding a New AI Character

1. **Add a `ModelInfo`** in `lib/core/ollama/model_registry.dart`:
   ```dart
   static const ModelInfo myModel = ModelInfo(
     id: 'llama3.2:3b',
     displayName: 'Llama 3.2 3B',
     ramGb: 2.0,
     description: 'Compact and fast.',
     isHighContext: false,
   );
   ```
   Add it to `ModelRegistry.all`.

2. **Add a `Participant`** in `lib/core/conversation/participant.dart`:
   ```dart
   static const Participant echo = Participant(
     name: 'ECHO',
     personality: 'Summariser',
     role: 'Distils the conversation into key insights',
     isHost: false,
     assignedModelId: 'llama3.2:3b',
     masterPrompt: 'You are ECHO...',
   );
   ```
   Add to `Participant.defaults()`.

3. **Add an orb colour** in `lib/ui/avatars/energy_orb/orb_config.dart`.

4. **Update the quadrant grid** — `QuadrantGrid` currently renders a fixed 2×2.
   If adding a 5th participant, change to a `3-column` grid or similar.

5. **Update `_kStackGb`** in `resource_gate_screen.dart` to reflect the new total RAM requirement.

---

## 10. Adding a New Avatar Type

1. Create a new directory: `lib/ui/avatars/my_avatar/`
2. Implement a widget that accepts `AvatarState`, `characterName`, and `size`.
3. Register it in `lib/ui/avatars/avatar_registry.dart`:
   ```dart
   static void registerDefaults() {
     register('energyOrb', (state, name, size) => EnergyOrbAvatar(...));
     register('myAvatar',  (state, name, size) => MyAvatarWidget(...)); // ← add
   }
   ```
4. Use it anywhere: `AvatarRegistry.build('myAvatar', state: ..., characterName: ..., size: ...)`.

---

## 11. Updating the Bundled Ollama Version

1. Download the new Ollama macOS release binary from https://github.com/ollama/ollama/releases
2. Extract: `tar xzf ollama-darwin.tgz`
3. Replace the files in `macos/Runner/ollama/` — the binary, `llama-server`, `llama-quantize`, and `.metallib` files
4. Large `.metallib` files must be committed via Git LFS:
   ```bash
   git lfs track "macos/Runner/ollama/*.metallib"
   git add .gitattributes macos/Runner/ollama/
   git commit -m "chore: update bundled Ollama to vX.Y.Z"
   ```
5. Update the version string in comments in `ollama_launcher.dart` and `ARCHITECTURE.md`
6. Test: `flutter run -d macos` and confirm `time=... msg="Ollama ... (version X.Y.Z)"` in logs

---

## 12. Debugging Ollama Issues

### Check if Ollama is running
```bash
curl http://localhost:11434/
```

### Check which models are loaded
```bash
curl http://localhost:11434/api/tags | python3 -m json.tool
```

### Test a pull directly
```bash
OLLAMA_RUNNERS_DIR=/path/to/deep_think.app/Contents/Resources/ollama \
  /path/to/deep_think.app/Contents/Resources/ollama/ollama serve &
sleep 5
curl -X POST http://localhost:11434/api/pull \
  -H 'Content-Type: application/json' \
  -d '{"name":"mistral:7b","stream":true}'
```

### Fix "EOF on pull"
Partial blob files from an interrupted download block future pulls:
```bash
rm ~/.ollama/models/blobs/*-partial*
# Then retry the download in the app
```

### Enable verbose Ollama logging
The app already sets `OLLAMA_DEBUG=INFO`. For maximum verbosity:
```bash
OLLAMA_DEBUG=DEBUG \
  /path/to/ollama serve 2>&1 | tee /tmp/ollama.log
```

---

## 13. What Changed in v1.0.2

| Area | Change |
|------|--------|
| **Startup hang fix** | `isRunning()` drain now has a 3 s timeout; `HttpClient` always closed in `finally` — prevents hang when Ollama keeps HTTP connection alive |
| **External Ollama detection** | `lsof` check before spawn; `ExternalOllamaException` → `ExternalOllamaScreen` (Kill & Retry) |
| **Pause / Resume** | Amber ⏸ / green ▶ button in top bar; `abortInFlight()` closes `HttpClient` to cancel in-flight streams; auto-resumes when user sends a message while paused |
| **Stop-forever fix** | `unloadModel` wrapped in 5 s `Future.timeout`; `_stop()` calls `pause()` first; `IOSink` lifecycle pinned to `endSession()` |
| **Start guard** | `_isBusy` flag blocks double-press; spinner + label shown during stopping/starting |
| **⚙ Configure button** | New button in top bar (right of session name, left of Help); stops session and navigates back to `StartupConfigScreen`; shows confirmation dialog if session is running |
| **Config persistence** | `ParticipantPrefs` saves/loads model + prompt per character to `~/Documents/deepThink/participant_prefs.json`; Reset to Defaults button |
| **Session transcripts** | Plain-text `.txt` files with human-readable filenames (`name_YYYY-MM-DD_HH-MM-SS.txt`); Help → Session Transcripts opens Finder |
| **Auto-scroll lock** | Per-panel scroll lock; "Jump to Latest" pill; "Warp to Head" button scrolls all panels to top |
| **App quit kills Ollama** | PID file written on spawn; `AppDelegate.swift.applicationWillTerminate` reads it and sends SIGKILL synchronously |

---

## 14. Code Style & Conventions

- **`lib/core/`** — Zero Flutter imports. Enforced by convention, checked on review.
- **Dart 3 / null-safety** — All code is sound null-safe.
- **`const` constructors** — Use wherever possible for performance.
- **`analysis_options.yaml`** — `flutter_lints` rule set. Run `flutter analyze` before pushing.
- **Doc comments** — All public API has `///` doc comments with examples where non-obvious.
- **Test coverage** — New core logic must have unit tests. New screens should have a smoke test.
- **Commit messages** — `type: description` format (`feat:`, `fix:`, `chore:`, `test:`, `docs:`).

---

## 15. Dependency Notes

deepThink intentionally keeps its dependency footprint tiny:

| Package | Why |
|---------|-----|
| `flutter` | UI framework |
| `http` | Used nowhere currently (Ollama client uses `dart:io` `HttpClient` directly for streaming control) — kept for future use |
| `path_provider` | Resolves `~/Documents/deepThink/` for session logs |
| `url_launcher` | Opens external URLs from Help menu |
| `flutter_lints` (dev) | Lint rules |
| `test` (dev) | Dart test runner for pure-Dart tests |

No state management packages. No dependency injection framework. No `async` package.
The architecture is simple enough that none are needed.
