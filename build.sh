#!/bin/bash
set -e

SRC="$HOME/.config/ghostty/GhostConnect"
APP="$HOME/Applications/GhostConnect.app"

echo ""
echo "  =============================="
echo "  Building GhostConnect.app"
echo "  =============================="
echo ""

# 1. Generate icon
echo "[1/3] Generating pixel ghost icon..."
python3 "$SRC/gen_icon.py"

# 2. Compile Swift
echo "[2/3] Compiling Swift..."
xcrun swiftc \
    -framework SwiftUI \
    -framework Cocoa \
    -O \
    -o "$SRC/GhostConnect" \
    "$SRC/main.swift"

# 3. Bundle .app
echo "[3/3] Creating app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$SRC/GhostConnect" "$APP/Contents/MacOS/"
cp "$SRC/Info.plist" "$APP/Contents/"

if [ -f "$SRC/AppIcon.icns" ]; then
    cp "$SRC/AppIcon.icns" "$APP/Contents/Resources/"
fi

# Cleanup build artifacts
rm -f "$SRC/GhostConnect" "$SRC/AppIcon.icns"

echo ""
echo "  Done! App installed at:"
echo "  $APP"
echo ""
echo "  Drag it to your Dock, or run:"
echo "  open \"$APP\""
echo ""
