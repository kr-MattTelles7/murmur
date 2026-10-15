#!/bin/bash
# Installs the latest Murmur release into /Applications.
# Usage: gh api repos/OWNER/murmur/contents/scripts/install.sh -H "Accept: application/vnd.github.raw" | bash
set -euo pipefail
REPO="${MURMUR_REPO:-kr-MattTelles7/murmur}"

command -v gh >/dev/null   || { echo "Install the GitHub CLI first: brew install gh && gh auth login"; exit 1; }
command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
[ "$(uname -m)" = "arm64" ] || { echo "Murmur needs an Apple Silicon Mac."; exit 1; }

echo "→ Installing speech engine (whisper-cpp)…"
brew list whisper-cpp >/dev/null 2>&1 || brew install whisper-cpp

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "→ Downloading Murmur…"
gh release download --repo "$REPO" --pattern 'Murmur-*.zip' --dir "$TMP"

pkill -x Murmur 2>/dev/null || true
rm -rf /Applications/Murmur.app
ditto -x -k "$TMP"/Murmur-*.zip /Applications
open /Applications/Murmur.app
echo "✓ Murmur installed. Look for the waveform icon in your menu bar. Press ⌥Space to dictate."
