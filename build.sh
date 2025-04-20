#!/bin/bash

# Build the executable
swift build -c release

# Create app bundle structure
APP_BUNDLE="./build/MultiClipboard.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy files
cp .build/release/MultiClipboard "$APP_BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$APP_BUNDLE/Contents/"
cp MultiClipboard.entitlements "$APP_BUNDLE/Contents/Resources/"

echo "App bundle created at $APP_BUNDLE"
echo "Please drag the app bundle to your Applications folder and then add it to System Settings > Privacy & Security > Accessibility" 