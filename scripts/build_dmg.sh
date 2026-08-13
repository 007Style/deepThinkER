#!/usr/bin/env bash
set -euo pipefail

# build_dmg.sh — Build and package deepThinkER as a macOS DMG
#
# Usage:
#   ./scripts/build_dmg.sh           # uses default version 1.0.0
#   ./scripts/build_dmg.sh 1.2.0     # override version
#
# Requirements:
#   - Flutter SDK in PATH
#   - create-dmg  (auto-installed via brew if missing)

VERSION="${1:-1.0.0}"
DISPLAY_NAME="deepThinkER"
BUNDLE_NAME="deep_think_er"          # Flutter uses pubspec name for the bundle
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${BUNDLE_NAME}.app"
OUTPUT_DIR="build"
DMG_NAME="${DISPLAY_NAME}-v${VERSION}-macos.dmg"
OUTPUT_PATH="${OUTPUT_DIR}/${DMG_NAME}"
SKIP_BUILD="${SKIP_BUILD:-0}"     # set SKIP_BUILD=1 to skip flutter build

# ── 1. Ensure create-dmg is available ───────────────────────────────────────
if ! command -v create-dmg &>/dev/null; then
  echo "==> create-dmg not found — installing via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew is not installed. Install it from https://brew.sh and re-run." >&2
    exit 1
  fi
  brew install create-dmg
fi

# ── 2. Flutter release build ─────────────────────────────────────────────────
if [ "${SKIP_BUILD}" = "1" ]; then
  echo "==> Skipping Flutter build (SKIP_BUILD=1)"
else
  echo "==> Building ${DISPLAY_NAME} v${VERSION} for macOS (release)..."
  flutter build macos --release
fi

if [ ! -d "${APP_PATH}" ]; then
  echo "ERROR: Expected app bundle not found at: ${APP_PATH}" >&2
  exit 1
fi

# ── 3. Package as DMG ────────────────────────────────────────────────────────
echo "==> Packaging as DMG: ${DMG_NAME}"

# Remove any stale DMG from a previous run
rm -f "${OUTPUT_PATH}"

create-dmg \
  --volname "${DISPLAY_NAME}" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "${BUNDLE_NAME}.app" 160 185 \
  --hide-extension "${BUNDLE_NAME}.app" \
  --app-drop-link 430 185 \
  "${OUTPUT_PATH}" \
  "${APP_PATH}"

# ── 4. Copy standalone .app next to the DMG ──────────────────────────────────
APP_COPY="${OUTPUT_DIR}/${BUNDLE_NAME}.app"
echo "==> Copying standalone .app: ${APP_COPY}"
rm -rf "${APP_COPY}"
cp -R "${APP_PATH}" "${APP_COPY}"

# ── 5. Done ──────────────────────────────────────────────────────────────────
echo ""
echo "✓ Build complete:"
echo "  DMG:        ${OUTPUT_PATH}"
echo "  Standalone: ${APP_COPY}"
