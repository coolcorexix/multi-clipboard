#!/bin/bash

set -e

# Build the executable
swift build -c release

# Paths
APP_BUNDLE="./build/MultiClipboard.app"
EXECUTABLE=".build/release/MultiClipboard"
PLIST="Resources/Info.plist"
ICON="Resources/MultiClipboard.icns"

# Check required files
if [ ! -f "$EXECUTABLE" ]; then
  echo "Error: Executable not found at $EXECUTABLE. Build failed."
  exit 1
fi
if [ ! -f "$PLIST" ]; then
  echo "Error: Info.plist not found at $PLIST."
  exit 1
fi
if [ ! -f "$ICON" ]; then
  echo "Error: Icon file not found at $ICON."
  exit 1
fi

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy files
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"
cp "$PLIST" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICON" "$APP_BUNDLE/Contents/Resources/"

# Copy any other resources (optional)
# cp -R Resources/* "$APP_BUNDLE/Contents/Resources/"

chmod +x "$APP_BUNDLE/Contents/MacOS/MultiClipboard"

# Done

echo "App bundle created at $APP_BUNDLE"
echo "To use the app, drag it to your /Applications folder and launch it from there."
echo "If you still see the Terminal icon, try restarting Finder or logging out and back in." 