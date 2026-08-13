# deepThink — Windows Build Guide

This document covers everything needed to compile and run `deepThink` on Windows from source.

> **Note:** A pre-compiled Windows installer is not yet available in GitHub Releases. macOS `.dmg` is the primary distribution target. Windows users can compile from this repository using the instructions below.

---

## Prerequisites

### 1. Flutter SDK

1. Download the Flutter SDK from [flutter.dev/docs/get-started/install/windows](https://flutter.dev/docs/get-started/install/windows)
2. Extract to a path with **no spaces** and **no special characters**, e.g. `C:\flutter`
3. Add `C:\flutter\bin` to your system `PATH`
4. Verify: open a new PowerShell window and run:
   ```powershell
   flutter --version
   ```

### 2. Visual Studio 2022

Flutter Windows builds require the **Desktop development with C++** workload.

1. Download Visual Studio 2022 Community (free) from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/)
2. During installation, select the **Desktop development with C++** workload
3. Also select the **Windows 11 SDK** (or Windows 10 SDK if targeting Windows 10)
4. Verify: run `flutter doctor` — the Visual Studio entry should show `[✓]`

### 3. Git for Windows

Download from [git-scm.com](https://git-scm.com/download/win). Accept defaults during installation.

### 4. Enable Windows Desktop Target

```powershell
flutter config --enable-windows-desktop
```

---

## Verify Your Setup

Run the full Flutter doctor check and resolve any issues before proceeding:

```powershell
flutter doctor -v
```

All items except Android and iOS should show `[✓]`.

---

## Clone and Build

### Step 1 — Clone the repository

```powershell
git clone https://github.com/007Style/deepThink.git
cd deepThink
```

### Step 2 — Get dependencies

```powershell
flutter pub get
```

### Step 3 — Run in development mode

```powershell
flutter run -d windows
```

This builds a debug binary and launches the app directly. Expect a slightly slower startup in debug mode.

### Step 4 — Build a release executable

```powershell
flutter build windows --release
```

The compiled application will be at:

```
build\windows\x64\runner\Release\deepThink.exe
```

> **Important:** The `Release` folder contains the `.exe` plus required `.dll` files and the `data\` folder. All of these must stay together — do not move the `.exe` alone.

---

## Creating an Installer (Optional)

### Option A — Inno Setup (Recommended)

1. Download Inno Setup from [jrsoftware.org/isinfo.php](https://jrsoftware.org/isinfo.php)
2. Create a script `windows\installer.iss` pointing to `build\windows\x64\runner\Release\`
3. Example minimal Inno Setup script:

```iss
[Setup]
AppName=deepThink
AppVersion=1.0.1
DefaultDirName={autopf}\deepThink
DefaultGroupName=deepThink
OutputBaseFilename=deepThink-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\deepThink"; Filename: "{app}\deepThink.exe"
Name: "{commondesktop}\deepThink"; Filename: "{app}\deepThink.exe"

[Run]
Filename: "{app}\deepThink.exe"; Description: "Launch deepThink"; Flags: nowait postinstall skipifsilent
```

4. Compile: right-click the `.iss` file → **Compile**
5. Output: `Output\deepThink-Setup.exe`

### Option B — NSIS

1. Download NSIS from [nsis.sourceforge.io](https://nsis.sourceforge.io/)
2. Use the MUI2 interface template
3. Point `InstallDir` to `$PROGRAMFILES64\deepThink`
4. Include all files from `build\windows\x64\runner\Release\`

---

## GitHub Actions — Self-Hosted Windows Build

To build using GitHub Actions on a Windows runner, the workflow is defined at [`.github/workflows/build_windows.yml`](../.github/workflows/build_windows.yml).

The workflow:
- Triggers on push to `main` or manual `workflow_dispatch`
- Uses `windows-latest` runner
- Installs Flutter 3.22+
- Runs `flutter pub get` and `flutter build windows --release`
- Uploads the `Release\` folder as a build artifact

To trigger a manual build:
1. Go to your repository on GitHub
2. Click **Actions** → **Build Windows**
3. Click **Run workflow**
4. Download the artifact from the completed run

---

## Ollama on Windows

`deepThink` bundles an Ollama binary for Windows in `assets/ollama/windows/`. On first launch the app extracts and starts Ollama automatically in the background.

If the bundled binary fails or you prefer to use a system Ollama installation:

1. Download Ollama for Windows from [ollama.com/download](https://ollama.com/download)
2. Install it — Ollama will run as a background service
3. `deepThink` will detect the running Ollama instance at `http://localhost:11434` automatically

Model storage on Windows: `%USERPROFILE%\.ollama\models\`

---

## Troubleshooting

### `flutter build windows` fails with CMake error

Ensure Visual Studio 2022 is installed with the **Desktop development with C++** workload. Re-run `flutter doctor -v` to confirm.

### App launches but models don't download

Check that Ollama is running:
```powershell
curl http://localhost:11434/api/tags
```
If it returns an error, start Ollama manually: open a new terminal and run `ollama serve`.

### Missing `.dll` errors when running the `.exe` directly

You must run the `.exe` from within the `Release\` folder, or distribute the entire `Release\` folder contents together. The Flutter runtime DLLs must be co-located with the executable.

### `flutter run -d windows` shows no devices

Make sure Windows desktop is enabled:
```powershell
flutter config --enable-windows-desktop
flutter devices
```

---

## File Locations (Windows)

| Item | Path |
|------|------|
| Session logs | `%USERPROFILE%\Documents\deepThink\sessions\` |
| Ollama models | `%USERPROFILE%\.ollama\models\` |
| Ollama config | `%USERPROFILE%\.ollama\` |

---

## Summary

```
git clone https://github.com/007Style/deepThink.git
cd deepThink
flutter pub get
flutter build windows --release
# Run: build\windows\x64\runner\Release\deepThink.exe
```
