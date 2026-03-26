# GhostConnect

A lightweight macOS menu bar app for quickly launching [Ghostty](https://ghostty.org) terminal sessions with SSH + tmux.

Click the ghost icon in your menu bar → pick a server → configure your tmux sessions → hit Launch. GhostConnect opens a new Ghostty window with multiple tabs, each connected to a remote tmux session.

## Screenshots

<!-- TODO: add screenshot -->

## Features

- **Menu bar app** — lives in your macOS menu bar as a pixel ghost icon, no Dock clutter
- **Auto-reads SSH config** — parses `~/.ssh/config` to populate the server list
- **Multi-tab launch** — opens a new Ghostty window with one tab per tmux session
- **Smart tmux attach** — attaches to existing sessions or creates new ones (`tmux attach -t name || tmux new -s name`)
- **Tab naming** — sets each Ghostty tab title to the session name via OSC escape sequences
- **Persistent config** — remembers your last server and session list between launches (`~/.config/ghostty/ghost-connect.json`)
- **Auto Start** — optional login item to launch on boot (macOS 13+)
- **Catppuccin Mocha theme** — dark UI with pixel ghost branding, consistent with Ghostty's aesthetic
- **No Accessibility permissions needed** — launches a script inside Ghostty itself, avoiding macOS permission headaches
- **Portable** — works on any Mac with Ghostty and Xcode Command Line Tools

## Requirements

- macOS 12+
- [Ghostty](https://ghostty.org) terminal installed
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3 (for icon generation, included with macOS / Homebrew)
- SSH config at `~/.ssh/config` with `Host` entries

## Install

```bash
git clone https://github.com/Linwei94/GhostConnect.git
cd GhostConnect
chmod +x build.sh
./build.sh
```

The app is installed to `~/Applications/GhostConnect.app`. Drag it to your Dock if you like, or just let it live in the menu bar.

## Usage

1. **Click the ghost icon** in the menu bar — a panel drops down
2. **Select a server** from the list (parsed from your `~/.ssh/config`)
3. **Add/remove tmux sessions** — each one becomes a Ghostty tab
4. **Click Launch** — a new Ghostty window opens with all your sessions connected

### How it works

When you click Launch, GhostConnect:

1. Generates a temporary bash launcher script
2. Opens a new Ghostty window via `open -na Ghostty.app --args -e <script>`
3. The script runs **inside Ghostty**, where it has permission to use `osascript` to create new tabs (Cmd+T) and paste SSH commands (Cmd+V)
4. The first tab uses `exec ssh` to replace the launcher shell, so no extra processes linger
5. Tab titles are set via OSC 0 escape sequences (`\e]0;name\a`)

This approach avoids the need for macOS Accessibility permissions entirely.

### Right-click menu

Right-click the ghost icon is not needed — everything is in the panel. Click outside the panel to dismiss it.

### Configuration file

Your settings are saved to `~/.config/ghostty/ghost-connect.json`:

```json
{
  "server": "linwei-lab2",
  "sessions": ["research", "research-2", "projects"]
}
```

## Build from source

### Quick build

```bash
./build.sh
```

This will:
1. Generate a pixel ghost `.icns` icon (via `gen_icon.py`)
2. Compile the Swift source
3. Create the `.app` bundle at `~/Applications/GhostConnect.app`
4. Code-sign with ad-hoc signature

### Manual build

```bash
# Compile
xcrun swiftc -framework SwiftUI -framework Cocoa -framework ServiceManagement -O -o GhostConnect main.swift

# Generate icon
python3 gen_icon.py

# Bundle
mkdir -p ~/Applications/GhostConnect.app/Contents/{MacOS,Resources}
cp GhostConnect ~/Applications/GhostConnect.app/Contents/MacOS/
cp Info.plist ~/Applications/GhostConnect.app/Contents/
cp AppIcon.icns ~/Applications/GhostConnect.app/Contents/Resources/
codesign -f -s - ~/Applications/GhostConnect.app
```

## Project structure

```
GhostConnect/
├── main.swift      # Complete app source (SwiftUI + AppKit, single file)
├── Info.plist      # macOS app bundle metadata
├── gen_icon.py     # Generates pixel ghost .icns icon (pure Python, no PIL)
├── build.sh        # One-command build script
└── README.md
```

## Tech stack

- **Swift + SwiftUI + AppKit** — native macOS, single-file app
- **NSPanel** — borderless floating panel for the menu bar dropdown
- **NSStatusItem** — menu bar icon with pixel ghost template image
- **ServiceManagement** — login item for auto-start (macOS 13+)
- **Pure Python PNG encoder** — generates the app icon without any dependencies

## License

MIT
