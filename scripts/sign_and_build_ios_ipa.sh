#!/usr/bin/env bash
# One-time free Apple ID setup, then build installable IPA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${PATH:-}:${HOME}/flutter/bin:/Users/ankitpandey/flutter/bin"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Install Xcode from the App Store first."
  exit 1
fi

IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | rg "Apple Development|iPhone Developer" || true)
if [[ -z "$IDENTITIES" ]]; then
  echo "No iOS signing certificate found."
  echo ""
  echo "Do this once (free Apple ID — no \$99 fee):"
  echo "  1. open ios/Runner.xcworkspace"
  echo "  2. Xcode → Settings → Accounts → + → Sign in with Apple ID"
  echo "  3. Runner target → Signing & Capabilities → Team: Your Name (Personal Team)"
  echo "  4. Run this script again"
  echo ""
  open "$ROOT/ios/Runner.xcworkspace"
  exit 1
fi

echo "==> Certificate found. Building signed IPA..."
flutter pub get
flutter build ipa --release --export-method development

OUT="$ROOT/build/ios/ipa"
mkdir -p "$ROOT/releases"
VER=$(rg '^version:' "$ROOT/pubspec.yaml" | sed 's/version: //; s/+.*//')
IPA=$(ls "$OUT"/*.ipa 2>/dev/null | head -1)
if [[ -n "$IPA" ]]; then
  cp "$IPA" "$ROOT/releases/TashAdda-v${VER}-ios.ipa"
  cp "$IPA" "$ROOT/releases/TashAdda-ios.ipa"
  echo ""
  echo "✓ IPA ready:"
  echo "  $IPA"
  echo "  releases/TashAdda-v${VER}-ios.ipa"
  echo ""
  echo "Install: connect iPhone via USB → Xcode → Window → Devices, or use AltStore."
fi
