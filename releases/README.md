# TashAdda releases

Versioned builds for Android and iOS. Download from [GitHub Releases](https://github.com/Ankitspandey07/TashAdda/releases), this folder, or:

| Host | Link |
|------|------|
| **itch.io** | https://ankitspandey07.itch.io/tashadda |
| **AppHost** | https://appho.st/my/dashboard (iOS hosting) |
| **GitHub Pages** | https://ankitspandey07.github.io/TashAdda/ |

## Version history

| Version | Date | Android | iOS | Notes |
|---------|------|---------|-----|-------|
| **1.0.1** | 2026-06-10 | [TashAdda-v1.0.1.apk](TashAdda-v1.0.1.apk) | [TashAdda-v1.0.1-ios.ipa](TashAdda-v1.0.1-ios.ipa) | Seat layout fix, iOS white-screen fix, online SSL hints, fair shuffle (`Random.secure`). |
| **1.0.0** | 2026-06-09 | [TashAdda-v1.0.0.apk](TashAdda-v1.0.0.apk) | — | First signed Android release — vs bots, LAN, online, Bluff, AdMob. |

`TashAdda.apk` and `TashAdda-ios.ipa` always match the **latest** published version.

## Android install

```bash
adb install -r TashAdda-v1.0.1.apk
```

Enable **Install via USB** on Xiaomi/MIUI if install is blocked.

## iOS install

iPhone cannot install `.ipa` like a normal download. See **[store/IOS_INSTALL.md](../store/IOS_INSTALL.md)** for:

- **Sideloadly** (recommended)
- **AltStore / SideStore**
- **Diawi** (shareable link)
- **TrollStore** (supported iOS versions)
- **OTA website** (manifest.plist + HTTPS)

Quick path: download the IPA → install with [Sideloadly](https://sideloadly.io) using your free Apple ID → trust profile in Settings.

## Publish next version

1. Bump `version` in `pubspec.yaml`.
2. Build Android: `flutter build apk --release`
3. Build iOS: `./scripts/sign_and_build_ios_ipa.sh`
4. Copy artifacts here and update the table above.
5. Commit, push, and create a GitHub Release:
   ```bash
   gh release create vX.Y.Z \
     releases/TashAdda-vX.Y.Z.apk \
     releases/TashAdda-vX.Y.Z-ios.ipa \
     --title "TashAdda vX.Y.Z" \
     --notes "Release notes."
   ```
