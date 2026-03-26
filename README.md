# GhostConnect

A pixel-art styled macOS app for launching Ghostty terminal with multiple SSH + tmux sessions in separate tabs.

<p align="center">
  <img src="screenshot.png" width="420" alt="GhostConnect screenshot">
</p>

## Features

- Reads SSH hosts from `~/.ssh/config` automatically
- Configure multiple tabs, each with a tmux session name
- One-click launch: opens Ghostty with all tabs connected
- Sets tab titles to session names
- Saves your configuration between launches
- Pixel-art ghost aesthetic with Catppuccin Mocha theme
- CRT scanline overlay effect

## Build

Requirements: macOS 12+, Xcode Command Line Tools, Python 3

```bash
chmod +x build.sh
./build.sh
```

The app will be installed to `~/Applications/GhostConnect.app`. Drag it to your Dock.

## Usage

1. Select your SSH server from the dropdown
2. Add/remove tmux session tabs
3. Click **LAUNCH**

The app will open Ghostty and create a tab for each session, connecting via SSH and attaching to the tmux session (or creating it if it doesn't exist).

## Configuration

Settings are saved to `~/.config/ghostty/ghost-connect.json` and restored on next launch.

## License

MIT
