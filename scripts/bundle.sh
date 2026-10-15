#!/bin/bash
# Builds dist/Murmur.app (ad-hoc signed) from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"
swift build -c release
APP=dist/Murmur.app
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Murmur" "$APP/Contents/MacOS/Murmur"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Murmur</string>
  <key>CFBundleDisplayName</key><string>Murmur</string>
  <key>CFBundleIdentifier</key><string>com.murmur.app</string>
  <key>CFBundleExecutable</key><string>Murmur</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Murmur listens to your microphone to turn speech into text. Audio is processed on this Mac and never saved.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION)"
