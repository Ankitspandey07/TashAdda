#!/usr/bin/env bash
# Build TashAdda IPA with a FREE Apple ID (Personal Team) — ₹0 / $0.
# No paid Apple Developer Program required.
# Limits: your devices only, ~7-day cert (rebuild or use AltStore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode not found. Install free Xcode first:"
  echo "  ./scripts/install_xcode_free.sh"
  echo "  or App Store → Xcode → Get"
  exit 1
fi

echo "==> Flutter pub get"
export PATH="${PATH:-}:${HOME}/flutter/bin:/Users/ankitpandey/flutter/bin"
flutter pub get

if [[ -f ios/Podfile ]]; then
  echo "==> pod install"
  (cd ios && pod install)
fi

echo ""
echo "==> Before first build, set signing in Xcode (one time, free):"
echo "    open ios/Runner.xcworkspace"
echo "    Runner → Signing → Team: Your Name (Personal Team)"
echo ""

echo "==> Building IPA (development export — free Apple ID)"
flutter build ipa --release --export-method development

OUT="$ROOT/build/ios/ipa"
echo ""
echo "Done. IPA (free Personal Team signing):"
ls -la "$OUT"/*.ipa 2>/dev/null || ls -la "$OUT"

echo ""
echo "Install: USB + Xcode, or AltStore (altstore.io — free, open source)."
echo "Re-sign every ~7 days with free Apple ID, or refresh via AltStore."
