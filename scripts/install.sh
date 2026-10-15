#!/bin/bash
# Installs Murmur: speech engine, speech model, and the app itself.
# Usage: gh api repos/kr-MattTelles7/murmur/contents/scripts/install.sh -H "Accept: application/vnd.github.raw" | bash
# Local testing: MURMUR_APP_SRC=dist/Murmur.app ./scripts/install.sh
set -euo pipefail
REPO="${MURMUR_REPO:-kr-MattTelles7/murmur}"
MODEL="ggml-large-v3-turbo-q5_0.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL"
MODEL_SIZE=574041195
MODEL_DIR="$HOME/Library/Application Support/Murmur/models"

command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
[ "$(uname -m)" = "arm64" ] || { echo "Murmur needs an Apple Silicon Mac."; exit 1; }
if [ -z "${MURMUR_APP_SRC:-}" ]; then
  command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh && gh auth login"; exit 1; }
fi

echo "→ Installing speech engine (whisper-cpp)…"
brew list whisper-cpp >/dev/null 2>&1 || brew install whisper-cpp

mkdir -p "$MODEL_DIR"
if [ "$(stat -f%z "$MODEL_DIR/$MODEL" 2>/dev/null || echo 0)" -eq "$MODEL_SIZE" ]; then
  echo "→ Speech model already downloaded."
else
  echo "→ Downloading speech model (~570 MB, one time)…"
  curl -fL --progress-bar -C - -o "$MODEL_DIR/$MODEL.part" "$MODEL_URL"
  [ "$(stat -f%z "$MODEL_DIR/$MODEL.part")" -eq "$MODEL_SIZE" ] || { echo "Model download looks incomplete. Re-run the installer."; exit 1; }
  mv "$MODEL_DIR/$MODEL.part" "$MODEL_DIR/$MODEL"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -n "${MURMUR_APP_SRC:-}" ]; then
  echo "→ Using local build: $MURMUR_APP_SRC"
  ditto "$MURMUR_APP_SRC" "$TMP/Murmur.app"
else
  echo "→ Downloading Murmur…"
  gh release download --repo "$REPO" --pattern 'Murmur-*.zip' --dir "$TMP"
  ditto -x -k "$TMP"/Murmur-*.zip "$TMP"
fi

pkill -x Murmur 2>/dev/null || true
rm -rf /Applications/Murmur.app
ditto "$TMP/Murmur.app" /Applications/Murmur.app
open /Applications/Murmur.app
echo "✓ Murmur installed. Look for the waveform icon in your menu bar. Press ⌥Space to dictate."
