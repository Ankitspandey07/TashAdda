# TashAdda releases

Versioned Android APKs for TashAdda. Download the latest from [GitHub Releases](https://github.com/Ankitspandey07/TashAdda/releases) or directly from this folder.

## Version history

| Version | Date | APK | Notes |
|---------|------|-----|-------|
| **1.0.0** | 2026-06-09 | [TashAdda-v1.0.0.apk](TashAdda-v1.0.0.apk) | Initial release — vs bots, LAN rooms, online rooms, chip limits, session scoreboard, Bluff, AdMob |

`TashAdda.apk` in this folder always matches the **latest** published version (currently v1.0.0).

## Install

```bash
adb install -r TashAdda-v1.0.0.apk
```

Enable **Install via USB** on Xiaomi/MIUI if install is blocked.

## Publish next version

1. Build release APK (see root [README.md](../README.md)).
2. Add `TashAdda-vX.Y.Z.apk` here and refresh the table above.
3. Overwrite `TashAdda.apk` with the new build.
4. Tag and upload:
   ```bash
   gh release create vX.Y.Z TashAdda-vX.Y.Z.apk --title "TashAdda vX.Y.Z" --notes "..."
   ```
