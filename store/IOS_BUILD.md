# TashAdda — iOS build & IPA

Same app as Android. **Costs ₹0** if you use a free Apple ID (Personal Team) — no $99 program needed for your own iPhone.

**Install on iPhone:** [IOS_INSTALL.md](IOS_INSTALL.md) (Sideloadly, AltStore, Diawi, TrollStore)

**Start here if you have no budget:** [ZERO_BUDGET.md](ZERO_BUDGET.md)

## App details

| Field | Value |
|-------|--------|
| App name | TashAdda |
| Bundle ID | `com.cardgames.tashadda` |
| Version | 1.0.0 (1) |
| Min iOS | 13.0 |

## Quick start (free)

```bash
# 1. Install Xcode from App Store (free) — once
./scripts/install_xcode_free.sh

sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 2. Xcode → Settings → Accounts → add free Apple ID
# 3. Open ios/Runner.xcworkspace → Signing → Personal Team

# 4. Build signed IPA (after step 2–3 in Xcode)
./scripts/sign_and_build_ios_ipa.sh
```

## Paid vs free Apple signing

| | Free Apple ID | Paid Developer ($99/yr) |
|--|---------------|-------------------------|
| Run on your iPhone | ✅ | ✅ |
| App Store / TestFlight | ❌ | ✅ |
| Cert lifetime | ~7 days | 1 year |
| Share with many friends easily | ❌ | ✅ (TestFlight) |
| Cost | **₹0** | ~₹8,000/yr |

For ₹0, use **free Personal Team** + optional **AltStore** (open source).

## Install on iPhone (free)

1. **USB:** `flutter run --release` with iPhone connected.  
2. **AltStore:** [altstore.io](https://altstore.io) — sideload the IPA, auto-refresh weekly.  
3. **Rebuild weekly:** `./scripts/build_ios_free.sh` and reinstall.

## What's configured in the repo

- `ios/` platform, icons, permissions (LAN, camera, photos)
- Ads disabled on iOS v1 (no iOS AdMob setup needed)
- `scripts/build_ios_free.sh` — free signing path
- `scripts/build_ios_ipa.sh` — paid-team / App Store path

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Cannot find xcodebuild` | Install free Xcode from App Store |
| Signing failed | Add Apple ID in Xcode → Personal Team |
| App expired after 7 days | Rebuild or use AltStore refresh |
| Local rooms empty | Allow Local Network on iOS |
