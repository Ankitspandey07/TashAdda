# Amazon Appstore — TashAdda submission checklist

Use this folder when listing **TashAdda** on the [Amazon Appstore](https://developer.amazon.com/apps-and-games).

## Current status (read this first)

| Requirement | Status | Notes |
|-------------|--------|-------|
| **Signed release APK** | ✅ Ready | `releases/TashAdda-v1.0.0.apk` — production keystore (not debug). |
| **Keystore (.jks)** | ✅ Created locally | `android/tashadda-release.jks` — **on your machine only**, never in Git. |
| **App icon 512×512** | ✅ Ready | [`icon-512.png`](icon-512.png) |
| **Screenshots (2–3)** | ⚠️ You capture | Take from your phone after install (see [Screenshot guide](#screenshots)). |
| **Short description** | ✅ Ready | [`listing-copy.txt`](listing-copy.txt) |
| **Long description** | ✅ Ready | [`listing-copy.txt`](listing-copy.txt) |
| **Package name** | ✅ Set | `com.cardgames.teen_patti_app` |
| **Version** | ✅ Set | `1.0.0` (versionCode `1` in `pubspec.yaml`) |

---

## Step 1 — Create a release keystore (one time)

**Do this before uploading.** Without it, every APK you built so far is debug-signed.

### Option A — Android Studio (matches Amazon’s guide)

1. Open **`TashAdda/android`** in Android Studio (File → Open).
2. **Build → Generate Signed Bundle / APK**
3. Choose **APK** (not App Bundle — Amazon wants APK).
4. **Create new keystore**
   - Path: `TashAdda/android/tashadda-release.jks`
   - Password: choose a strong password and **save it in a password manager**
   - Alias: `tashadda`
   - Validity: 25+ years
   - Fill in name/org (can be your name).
5. Select **release** → Finish.

### Option B — Command line

From the `TashAdda/android` folder:

```bash
keytool -genkey -v \
  -keystore tashadda-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias tashadda
```

Then create `android/key.properties` (never commit this file):

```bash
cp key.properties.example key.properties
# Edit key.properties with your real passwords
```

Example `key.properties`:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=tashadda
storeFile=../tashadda-release.jks
```

**Back up** `tashadda-release.jks` and passwords offline. If you lose them, you cannot update the same Amazon listing.

---

## Step 2 — Build the signed release APK

```bash
cd TashAdda
flutter pub get
flutter build apk --release
```

Output (upload **this** file):

```text
build/app/outputs/flutter-apk/app-release.apk
```

Verify it is **not** debug-signed (optional, needs Android SDK `apksigner`):

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

You should **not** see `CN=Android Debug` in the certificate.

Copy for your records:

```bash
cp build/app/outputs/flutter-apk/app-release.apk releases/TashAdda-v1.0.0-amazon.apk
```

---

## Step 3 — Assets for the Amazon listing

### App icon

Upload [`store/icon-512.png`](icon-512.png) (512×512 PNG).

### Screenshots

Amazon typically wants **2–3 phone screenshots** (often 1080×1920 or similar).

Suggested scenes to capture on your Redmi after installing the signed APK:

1. **Home menu** — logo, Play vs Bots, Online, Local room buttons.
2. **Online lobby** — room code visible (blur code if you prefer).
3. **Table in play** — cards, pot, action buttons (use vs Bots for a clean shot).

Capture on device:

```bash
adb shell screencap -p /sdcard/shot1.png
adb pull /sdcard/shot1.png store/screenshots/01-home.png
```

Save files under `store/screenshots/` (optional, for your own archive).

### Descriptions

Copy from [`listing-copy.txt`](listing-copy.txt):

- **Short** — one sentence for the store header.
- **Long** — full feature list for the detail page.

---

## Step 4 — Amazon Developer Console

1. Register at [Amazon Developer Portal](https://developer.amazon.com/) if needed.
2. **Add new app** → Android → upload **`app-release.apk`** (signed, not debug).
3. Fill **title**: `TashAdda`
4. Paste short + long descriptions from `listing-copy.txt`.
5. Upload **icon-512.png** and screenshots.
6. Set **content rating** questionnaire (card games / simulated gambling — answer honestly).
7. Declare **permissions** (Internet, Wi‑Fi, location for LAN discovery — already in manifest).
8. **AdMob**: app contains ads — declare accordingly in the questionnaire.
9. Submit for review.

---

## App details (for forms)

| Field | Value |
|-------|--------|
| App name | TashAdda |
| Package | `com.cardgames.teen_patti_app` |
| Category | Games → Card |
| Current version | 1.0.0 (1) |
| Min Android | 7.0 (API 24) |
| Privacy | No account server; online play uses room codes via relay; profile stored on device |

---

## Future Amazon updates

1. Bump version in `pubspec.yaml` (e.g. `1.0.1+2` — the number after `+` is `versionCode`).
2. Build with the **same keystore**: `flutter build apk --release`
3. Upload new APK in Amazon console under the same app listing.

Never change the keystore for the same package name.

---

## What was wrong with the older GitHub APK?

Earlier builds used the debug signing key. **v1.0.0 on GitHub Releases is now signed with the production release keystore** and is valid for Amazon upload. Always rebuild with the same keystore for updates (`flutter build apk --release`).
