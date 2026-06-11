# Free iOS hosting (vs Android stores)

There is **no free Apple store** that works like Amazon Appstore or Vivo App Store. Apple only allows easy public installs through the **App Store** ($99/year).

Below is what you can do at **₹0**, ranked by how close it feels to “hosted like Android.”

---

## Android vs iOS at ₹0

| | Android | iOS |
|--|---------|-----|
| **Free store listing** | ✅ Amazon, Vivo, Samsung, direct APK | ❌ App Store needs $99/yr |
| **Direct download link** | ✅ Tap APK → install | ❌ Needs sideload tool |
| **GitHub Releases** | ✅ Works great | ✅ IPA file only — extra install steps |
| **Your own website** | ✅ Link to APK | ⚠️ Link to IPA + Sideloadly/Diawi |
| **Auto-updates for friends** | ✅ Send new APK | ⚠️ Re-sign every ~7 days (free Apple ID) |

**Best free plan:** Android on Amazon + GitHub. iOS via **GitHub Pages install page** + **Sideloadly** or **AltStore**.

---

## Option 1 — GitHub Pages (recommended, ₹0)

A simple public URL you share like a mini “download site.”

**Your URL (after enabling Pages):**  
https://ankitspandey07.github.io/TashAdda/

**Enable once:**

1. GitHub repo → **Settings → Pages**
2. **Build and deployment → Source:** Deploy from branch
3. **Branch:** `main` → folder **`/docs`** → Save
4. Wait ~2 minutes — open the URL above

The page links to the latest APK/IPA on GitHub Releases and explains iOS install steps.

---

## Option 2 — Diawi (short install link, ₹0)

Good when you want one short link for iPhone users.

1. Download `TashAdda-v1.0.1-ios.ipa` from [Releases](https://github.com/Ankitspandey07/TashAdda/releases).
2. Upload at [diawi.com](https://www.diawi.com).
3. Share the link (e.g. `https://i.diawi.com/XXXXX`) on WhatsApp.

**Note:** Friends still need a valid signature. Easiest path: they install **Sideloadly** on a PC/Mac, download the IPA from GitHub, and sideload with **their** Apple ID. Diawi alone does not bypass Apple’s signing rules.

---

## Option 3 — AltStore (auto-refresh, ₹0)

Best for **you** and a few friends who install AltStore once.

1. [altstore.io](https://altstore.io) — AltServer on Mac/PC + AltStore on iPhone.
2. Install the IPA through AltStore.
3. AltStore refreshes before the 7-day free certificate expires.

---

## Option 4 — TrollStore (no weekly refresh, ₹0, limited)

Permanent install on **specific iOS versions** without re-signing every week.

- See [TrollStore](https://github.com/opa334/TrollStore) docs for supported versions.
- Not for all users — technical setup.

---

## Option 5 — EU alternative marketplaces (not ₹0 / not simple)

Since iOS 17.4, the **EU** allows alternative app marketplaces. Developers still pay Apple notarization fees and meet strict rules. This is **not** a free Amazon-style path for most indie apps.

---

## Option 6 — Apple App Store ($99/year)

The only way iOS works **like** Android stores for everyone:

- Tap install from App Store
- No Sideloadly, no 7-day expiry
- TestFlight for beta testers (same $99 program)

Skip until you have budget.

---

## What we recommend for TashAdda

| Audience | Share this |
|----------|------------|
| **Android friends** | GitHub Release APK or Amazon listing |
| **iPhone friends** | https://ankitspandey07.github.io/TashAdda/ + Sideloadly steps |
| **You (developer)** | AltStore or USB + Xcode |

---

## Update flow (when you release v1.0.2)

1. Build new APK + IPA → GitHub Release.
2. GitHub Pages page auto-points to `latest` release assets (update version in `docs/index.html` when you bump major links, or use release tag `latest` in URLs).
3. Tell Android users: new APK link. Tell iOS users: download new IPA → reinstall in Sideloadly/AltStore.

See also: [IOS_INSTALL.md](IOS_INSTALL.md) · [ZERO_BUDGET.md](ZERO_BUDGET.md)
