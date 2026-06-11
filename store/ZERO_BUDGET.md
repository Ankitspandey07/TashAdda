# TashAdda at ₹0 — free, open-source path

Everything below costs **no money**. Only a Mac (for iOS) and a free Apple ID (for your own iPhone) are needed.

## What works for free today

| Platform | Cost | Status |
|----------|------|--------|
| **Android APK** | ₹0 | ✅ Ready — [GitHub Release v1.0.0](https://github.com/Ankitspandey07/TashAdda/releases/tag/v1.0.0) |
| **Amazon Appstore** | ₹0 to register | ✅ Upload signed APK (see `AMAZON_APPSTORE.md`) |
| **GitHub hosting** | ₹0 | ✅ Source + APK releases |
| **iOS on your iPhone** | ₹0 | ⚠️ Needs free Xcode download + free Apple ID (see below) |
| **Apple App Store** | $99/year | ❌ Skip unless you have budget later |

---

## Android (recommended at ₹0)

1. Download **`TashAdda-v1.0.0.apk`** from [Releases](https://github.com/Ankitspandey07/TashAdda/releases).
2. Install:
   ```bash
   adb install -r TashAdda-v1.0.0.apk
   ```
   Or share the file — enable “Install unknown apps” on the phone.

No Play Store fee. Amazon developer signup is **free**.

---

## iOS at ₹0 (your own iPhone only)

Apple charges **$99/year** only for **App Store / TestFlight**. You do **not** need that to run TashAdda on **your** iPhone.

### What you need (all free)

| Tool | Cost | Get it |
|------|------|--------|
| **Xcode** | Free | Mac App Store (search “Xcode”) |
| **Apple ID** | Free | icloud.com — same as iPhone login |
| **AltStore** | Free, open source | [altstore.io](https://altstore.io) — optional sideload helper |
| **Flutter** | Free, open source | Already on your Mac |

### One-time setup (~30 min, ₹0)

**1. Install Xcode (free, large download ~12 GB)**

Open **App Store** → search **Xcode** → **Get** (free).

Or in Terminal (will ask for your Mac password once):

```bash
./scripts/install_xcode_free.sh
```

Then:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor
```

**2. Sign in with your free Apple ID in Xcode**

1. Open **`ios/Runner.xcworkspace`** in Xcode.
2. **Xcode → Settings → Accounts** → add your Apple ID.
3. **Runner** target → **Signing & Capabilities** → Team: **Your Name (Personal Team)**.
4. Leave **Automatically manage signing** on.

No paid “Apple Developer Program” required for Personal Team.

**3. Build IPA (free signing, your devices only)**

```bash
./scripts/build_ios_free.sh
```

Output: `build/ios/ipa/*.ipa`

**Limits of free Apple ID**

- App works on **your** registered iPhone/iPad.
- Certificate lasts **~7 days** — rebuild/reinstall weekly, or use **AltStore** to auto-refresh.
- You **cannot** publish on the App Store without $99/year.
- Share IPA with friends only via their UDIDs + re-sign ( awkward); Android APK is easier for friends.

### Install on iPhone (free)

**Option A — USB + Xcode (simplest)**  
Connect iPhone → `flutter run --release` or Run ▶ in Xcode.

**Option B — AltStore (open source, no $99)**  
1. Install [AltServer](https://altstore.io) on Mac.  
2. Install AltStore on iPhone.  
3. Copy IPA to iPhone → open with AltStore.  
4. Refresh in AltStore before 7-day expiry.

---

## Open-source stack (no license fees)

| Component | License |
|-----------|---------|
| Flutter | BSD-3 |
| Dart | BSD-3 |
| card_game_platform | In repo |
| CocoaPods | MIT |
| AltStore | GPL-3 |

---

## What we cannot do without your help

| Blocker | Why | Your free action |
|---------|-----|------------------|
| Xcode not on this Mac | 12 GB App Store download | Install Xcode from App Store (free) |
| `mas get` needs sudo | Mac password | Run `./scripts/install_xcode_free.sh` locally |
| iOS signing | Needs your Apple ID in Xcode | Sign in once in Xcode Settings |
| App Store listing | Apple fee $99 | Use Android + Amazon for ₹0 distribution |

---

## Best plan at ₹0

1. **Ship Android now** — APK on GitHub + Amazon (free).  
2. **Install Xcode when on Wi‑Fi** — one free download.  
3. **Run on your iPhone** — free Personal Team + `build_ios_free.sh`.  
4. **Tell friends on Android** — send APK link; iPhone friends wait or use your phone.

See also: [IOS_INSTALL.md](IOS_INSTALL.md) · [IOS_BUILD.md](IOS_BUILD.md) · [AMAZON_APPSTORE.md](AMAZON_APPSTORE.md)
