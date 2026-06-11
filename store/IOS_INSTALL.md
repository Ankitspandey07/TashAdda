# Install TashAdda on iPhone / iPad

Apple does **not** let you tap an `.ipa` on a website and install it like an Android APK. You need one of the methods below.

> **Free Apple ID builds** (Personal Team) expire after **~7 days**. Reinstall or refresh before expiry.  
> **Easiest for friends:** share the **Android APK** link — iOS sideloading is more steps.

---

## Download

| Version | IPA | GitHub Release |
|---------|-----|----------------|
| **1.0.1** (latest) | [releases/TashAdda-v1.0.1-ios.ipa](../releases/TashAdda-v1.0.1-ios.ipa) | [Releases](https://github.com/Ankitspandey07/TashAdda/releases) |

Also on the latest GitHub Release page: download `TashAdda-v1.0.1-ios.ipa`.

---

## Option A — Sideloadly (recommended for friends)

Works on Windows and Mac. Re-signs the IPA with **your** Apple ID so it installs on **your** iPhone.

1. Install [Sideloadly](https://sideloadly.io) on your computer.
2. Connect iPhone with USB.
3. Drag `TashAdda-v1.0.1-ios.ipa` into Sideloadly.
4. Enter your **Apple ID** (free iCloud account is fine).
5. Click **Start** → on iPhone: **Settings → General → VPN & Device Management** → trust the developer profile.
6. Re-sign every **~7 days** (free Apple ID limit).

---

## Option B — AltStore / SideStore (auto-refresh)

Open-source sideloading; refreshes the app in the background before the cert expires.

1. Mac/PC: install [AltServer](https://altstore.io).
2. iPhone: install **AltStore** or **SideStore** (same idea).
3. Copy the IPA to the phone (AirDrop, Files, etc.).
4. Open the IPA with AltStore → install.
5. Refresh in AltStore weekly (or enable background refresh).

---

## Option C — Diawi (link sharing)

[Diawi](https://www.diawi.com) hosts your IPA and gives a short install link.

1. Upload `TashAdda-v1.0.1-ios.ipa` at diawi.com.
2. Open the link on the iPhone in **Safari**.
3. Tap install → trust profile in Settings.

**Note:** The IPA must still be signed for the device. A GitHub IPA signed with the maintainer’s cert may **not** install on your phone unless you re-sign first (use Sideloadly) or Diawi is used after you upload **your** re-signed copy.

---

## Option D — TrollStore (no 7-day expiry, specific iOS versions)

[TrollStore](https://github.com/opa334/TrollStore) installs apps permanently on supported iOS versions without repeated re-signing.

- Requires a compatible iOS version and one-time setup (see TrollStore docs).
- Convert/install the IPA through TrollStore once installed.
- Best for power users; not for everyone.

---

## Option E — USB + Xcode (your own Mac)

If you build from source with your Apple ID:

```bash
git clone https://github.com/Ankitspandey07/TashAdda.git
cd TashAdda
open ios/Runner.xcworkspace
# Xcode → Signing → Personal Team
flutter run --release
```

Or: **Xcode → Window → Devices and Simulators** → drag the IPA onto your connected iPhone.

---

## Option F — Install from your own website (OTA)

You can host an install page, but Apple only allows **Safari → Install** when:

1. The IPA and a `manifest.plist` are served over **HTTPS**.
2. The IPA is signed for **ad-hoc** or **enterprise** distribution (device UDIDs registered), **or** the user re-signs with their Apple ID.

Example manifest (`manifest.plist`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>https://YOUR-HOST/TashAdda-v1.0.1-ios.ipa</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>com.cardgames.tashadda</string>
        <key>bundle-version</key>
        <string>1.0.1</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>TashAdda</string>
      </dict>
    </dict>
  </array>
</dict>
```

Install link (must open in **Safari** on iPhone):

```text
itms-services://?action=download-manifest&url=https://YOUR-HOST/manifest.plist
```

**GitHub Pages** can host the plist + a simple HTML page, but the IPA file is large (~19 MB) — GitHub Releases + Sideloadly is simpler for most friends.

---

## After install

1. **Settings → General → VPN & Device Management** → trust the developer app.
2. **Settings → TashAdda** → allow **Local Network** (for LAN rooms).
3. Allow camera/photos if you set a profile picture.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Unable to install” | Re-sign with **your** Apple ID via Sideloadly |
| App expires after 7 days | Reinstall or use AltStore refresh |
| Online room SSL error | Use mobile data; office Wi‑Fi may block HTTPS |
| LAN rooms empty | Allow Local Network permission on iOS |

See also: [IOS_BUILD.md](IOS_BUILD.md) · [ZERO_BUDGET.md](ZERO_BUDGET.md)
