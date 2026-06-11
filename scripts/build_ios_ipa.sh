#!/usr/bin/env bash
# Build a signed TashAdda IPA for iPhone/iPad.
# Requires: macOS, Xcode (full app from App Store), Apple Developer account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Flutter pub get"
flutter pub get

echo "==> iOS pods (if Podfile exists)"
if [[ -f ios/Podfile ]]; then
  (cd ios && pod install)
fi

echo "==> Build IPA"
# Uses automatic signing from Xcode project / export options.
# First time: open ios/Runner.xcworkspace in Xcode, set Team under Signing.
flutter build ipa --release

OUT="$ROOT/build/ios/ipa"
echo ""
echo "Done. IPA output:"
ls -la "$OUT"/*.ipa 2>/dev/null || ls -la "$OUT"

echo ""
echo "Install on a registered device via Xcode → Window → Devices, or distribute via TestFlight."
