#!/usr/bin/env bash
# release.sh — Build deepThink locally and publish a GitHub Release with the DMG.
#
# Usage:
#   ./scripts/release.sh 1.0.2           # build + release v1.0.2
#   ./scripts/release.sh 1.0.2 --draft   # build but publish as a draft first
#
# Requirements:
#   - Flutter SDK in PATH
#   - create-dmg  (installed automatically via Homebrew if missing)
#   - gh CLI      (https://cli.github.com — must be authenticated: gh auth login)
#
# What it does:
#   1. Runs flutter test  (fails fast if tests break)
#   2. Runs flutter build macos --release
#   3. Packages the .app into a .dmg  (via create-dmg)
#   4. Creates a git tag  vX.Y.Z
#   5. Pushes the tag to GitHub
#   6. Creates a GitHub Release and uploads the DMG

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
VERSION="${1:-}"
DRAFT_FLAG=""

if [[ -z "${VERSION}" ]]; then
  echo "Usage: ./scripts/release.sh <version> [--draft]"
  echo "  e.g. ./scripts/release.sh 1.0.2"
  exit 1
fi

if [[ "${2:-}" == "--draft" ]]; then
  DRAFT_FLAG="--draft"
fi

TAG="v${VERSION}"
BUNDLE_NAME="deep_think"
APP_PATH="build/macos/Build/Products/Release/${BUNDLE_NAME}.app"
DMG_NAME="deepThink-${TAG}-macos.dmg"
DMG_PATH="build/${DMG_NAME}"

# ── Helpers ───────────────────────────────────────────────────────────────────
header() { echo ""; echo "━━━ $* ━━━"; }
ok()     { echo "  ✓ $*"; }
fail()   { echo "  ✗ $*" >&2; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────────────────
header "Preflight"

command -v flutter >/dev/null || fail "flutter not found in PATH"
command -v gh      >/dev/null || fail "gh CLI not found — install from https://cli.github.com"

gh auth status >/dev/null 2>&1 || fail "Not authenticated with gh — run: gh auth login"

# Check the tag doesn't already exist
if git rev-parse "${TAG}" >/dev/null 2>&1; then
  fail "Tag ${TAG} already exists. Bump the version number."
fi

ok "Flutter found"
ok "gh CLI authenticated"
ok "Tag ${TAG} is fresh"

# ── Tests ─────────────────────────────────────────────────────────────────────
header "Running tests"
flutter test || fail "Tests failed — fix before releasing"
ok "All tests passed"

# ── Build ─────────────────────────────────────────────────────────────────────
header "Building release .app"
flutter build macos --release
[[ -d "${APP_PATH}" ]] || fail "Expected .app not found at ${APP_PATH}"
ok "Built ${APP_PATH}"

# ── DMG packaging ─────────────────────────────────────────────────────────────
header "Packaging DMG"

if ! command -v create-dmg &>/dev/null; then
  echo "  → create-dmg not found — installing via Homebrew..."
  brew install create-dmg
fi

rm -f "${DMG_PATH}"

create-dmg \
  --volname "deepThink" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "${BUNDLE_NAME}.app" 160 185 \
  --hide-extension "${BUNDLE_NAME}.app" \
  --app-drop-link 430 185 \
  "${DMG_PATH}" \
  "${APP_PATH}"

DMG_SIZE=$(du -sh "${DMG_PATH}" | cut -f1)
ok "Created ${DMG_PATH}  (${DMG_SIZE})"

# ── Tag & push ────────────────────────────────────────────────────────────────
header "Tagging ${TAG}"
git tag -a "${TAG}" -m "deepThink ${TAG}"
git push origin "${TAG}"
ok "Pushed tag ${TAG}"

# ── GitHub Release ────────────────────────────────────────────────────────────
header "Creating GitHub Release ${TAG}"

RELEASE_NOTES="## deepThink ${TAG}

### Install (macOS)
1. Download \`${DMG_NAME}\` below
2. Open the DMG
3. Drag **deepThink** to your Applications folder
4. Launch — deepThink handles the rest

> First launch: macOS may prompt you to allow the app in System Preferences → Security & Privacy.

### Requirements
- macOS 13 Ventura or later
- Apple Silicon (M1/M2/M3/M4) recommended
- ~24 GB free RAM for the full model stack

### AI Models (~22.5 GB total, downloaded on first launch)

| Model | Tag | RAM |
|-------|-----|-----|
| Mistral 7B | \`mistral:7b\` | ~4.1 GB |
| Llama 3 8B | \`llama3:8b\` | ~4.7 GB |
| Gemma 2 9B | \`gemma2:9b\` | ~5.5 GB |
| Phi-3 14B  | \`phi3:14b\`  | ~8.2 GB |

### Windows
No binary release yet — see [windows/BUILD.md](https://github.com/007Style/deepThink/blob/main/windows/BUILD.md) to compile from source.

---
*From the minds of Daneyand & IBM's Bob*"

gh release create "${TAG}" \
  "${DMG_PATH}" \
  --title "deepThink ${TAG}" \
  --notes "${RELEASE_NOTES}" \
  ${DRAFT_FLAG}

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎉  deepThink ${TAG} released!"
echo ""
echo "  DMG:     ${DMG_PATH}  (${DMG_SIZE})"
echo "  Release: https://github.com/007Style/deepThink/releases/tag/${TAG}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
