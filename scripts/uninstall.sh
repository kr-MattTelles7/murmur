#!/bin/bash
# Removes Murmur and everything it created: app, speech model, settings, caches, mic permission.
# Usage: gh api repos/kr-MattTelles7/murmur/contents/scripts/uninstall.sh -H "Accept: application/vnd.github.raw" | bash
# Add `-s -- --with-engine` after `bash` to also remove whisper-cpp. DRY_RUN=1 only prints what would be removed.
set -uo pipefail
BUNDLE_ID="com.murmur.app"
run() { if [ -n "${DRY_RUN:-}" ]; then echo "  would run: $*"; else "$@"; fi; }

PATHS=(
  "/Applications/Murmur.app"
  "$HOME/Applications/Murmur.app"
  "$HOME/Library/Application Support/Murmur"
  "$HOME/Library/Preferences/$BUNDLE_ID.plist"
  "$HOME/Library/Caches/$BUNDLE_ID"
  "$HOME/Library/HTTPStorages/$BUNDLE_ID"
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
  "$HOME/Library/Logs/Murmur"
)

echo "→ Quitting Murmur…"
run pkill -x Murmur
run pkill -f "whisper-server.*Application Support/Murmur"

echo "→ Removing files…"
for p in "${PATHS[@]}"; do
  [ -e "$p" ] && { echo "  $p"; run rm -rf "$p"; }
done

echo "→ Resetting microphone permission…"
run tccutil reset Microphone "$BUNDLE_ID" >/dev/null 2>&1
run defaults delete "$BUNDLE_ID" >/dev/null 2>&1

if [ "${1:-}" = "--with-engine" ]; then
  echo "→ Removing whisper-cpp…"
  run brew uninstall whisper-cpp
else
  echo "  (whisper-cpp left installed. Re-run with --with-engine to remove it too.)"
fi
echo "✓ Murmur removed."
