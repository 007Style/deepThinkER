#!/bin/bash
# Copies the bundled Ollama runtime into the .app bundle at build time.
# This script runs as an Xcode build phase (Shell Script Build Phase).
#
# The Ollama files live at:   $SRCROOT/Runner/ollama/
# They are copied to:          $BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources/ollama/

set -euo pipefail

SRC="$SRCROOT/Runner/ollama"
DST="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources/ollama"

if [ ! -d "$SRC" ]; then
  echo "warning: Ollama source directory not found at $SRC — skipping copy."
  exit 0
fi

echo "Copying Ollama runtime: $SRC -> $DST"
mkdir -p "$DST"
cp -R "$SRC/." "$DST/"

# Ensure all files are executable where needed
chmod +x "$DST/ollama" || true
chmod +x "$DST/llama-server" || true
chmod +x "$DST/llama-quantize" || true

echo "Ollama runtime copied successfully."
