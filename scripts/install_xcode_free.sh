#!/usr/bin/env bash
# Install Xcode from the Mac App Store — FREE (no Apple Developer fee).
# Needs: Mac password when prompted, Apple ID signed into App Store.
set -euo pipefail

XCODE_APP_ID=497799835

echo "TashAdda — free Xcode installer"
echo "================================"
echo "Xcode is FREE from Apple. Download size ~12 GB."
echo ""

if [[ -d /Applications/Xcode.app ]]; then
  echo "✓ Xcode already installed at /Applications/Xcode.app"
  xcode-select --switch /Applications/Xcode.app/Contents/Developer 2>/dev/null || {
    echo "Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  }
  exit 0
fi

if ! command -v mas >/dev/null 2>&1; then
  echo "Installing mas (Mac App Store CLI) via Homebrew..."
  brew install mas
fi

echo "Downloading Xcode from App Store (this can take 30–60+ minutes)..."
echo "You may be asked for your Mac login password and App Store Apple ID."
echo ""

mas get "$XCODE_APP_ID" || {
  echo ""
  echo "If mas failed, install manually:"
  echo "  1. Open App Store app"
  echo "  2. Search 'Xcode'"
  echo "  3. Click Get (free)"
  exit 1
}

echo ""
echo "✓ Xcode installed. Run:"
echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
echo "  sudo xcodebuild -runFirstLaunch"
echo "  flutter doctor"
