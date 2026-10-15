# Murmur

Local, private voice-to-text for macOS. Lives in your menu bar. Press **⌥Space** anywhere, talk, press it again, and the text is on your clipboard.

- Runs OpenAI Whisper `large-v3-turbo` on-device via [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (Metal accelerated)
- Audio is held in memory only. Nothing is saved: no audio, no transcripts, no history
- Works in any app, including the terminal (just ⌘V after dictating)
- English only

## Install

Requires an Apple Silicon Mac, [Homebrew](https://brew.sh) and the [GitHub CLI](https://cli.github.com) (`gh auth login`).

```bash
gh api repos/kr-MattTelles7/murmur/contents/scripts/install.sh -H "Accept: application/vnd.github.raw" | bash
```

On first launch, click the menu bar icon and download the speech model (~570 MB, once). Allow microphone access when asked.

## Use

| Action | How |
|---|---|
| Start / stop dictating | **⌥Space** anywhere, or the mic button |
| Copy text | Auto-copied when you stop (toggle in the window), or **Copy** |
| Quit | Right-click the menu bar icon |

Dictations append to the box until you press **Clear**.

## Build from source

```bash
brew install whisper-cpp
./scripts/bundle.sh 0.1.0   # produces dist/Murmur.app
```

## Why a command instead of a .zip download?

The app is not notarized by Apple. A browser-downloaded copy gets quarantined and macOS blocks it until you right-click → Open. Installing through the command avoids that.
