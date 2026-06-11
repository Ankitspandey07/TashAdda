# TashAdda

**Play card games with your friends — not strangers.**

TashAdda is a private table app. You host a room, share a code or join on the same Wi‑Fi, and play with people you know. There is no public matchmaking and no random opponents — only you, your friends, and optional bots to fill empty seats.

## Download

| Platform | Version | File | GitHub Release |
|----------|---------|------|----------------|
| **Android** | 1.0.1 (latest) | [releases/TashAdda-v1.0.1.apk](releases/TashAdda-v1.0.1.apk) | [Releases](https://github.com/Ankitspandey07/TashAdda/releases) |
| **iOS** | 1.0.1 (latest) | [releases/TashAdda-v1.0.1-ios.ipa](releases/TashAdda-v1.0.1-ios.ipa) | [Releases](https://github.com/Ankitspandey07/TashAdda/releases) |

### Android

```bash
adb install -r releases/TashAdda-v1.0.1.apk
```

Or open **Releases** on GitHub and download the APK. Enable “Install unknown apps” if needed.

### iOS (iPhone / iPad)

Apple does **not** install `.ipa` files directly from a link like Android. Use one of these:

| Method | Best for |
|--------|----------|
| **[Sideloadly](https://sideloadly.io)** | Friends installing with their Apple ID (recommended) |
| **[AltStore](https://altstore.io)** | Auto-refresh before 7-day cert expiry |
| **[Diawi](https://www.diawi.com)** | Share a short install link (upload the IPA) |
| **TrollStore** | Permanent install on supported iOS versions |
| **USB + Xcode** | Building from source on your Mac |

Full step-by-step guide: **[store/IOS_INSTALL.md](store/IOS_INSTALL.md)**

> Free Apple ID builds expire after **~7 days** — reinstall or use AltStore. For the easiest friend experience, share the **Android APK** link.

## How to play

### Play vs Bots (solo on one phone)

1. Open **Play vs Bots** from the home screen.
2. Pick a game, set **starting chips** and **boot (ante)**, and choose how many bots join.
3. Tap **Deal** — you play at a private table on your device.

Good for learning rules or practicing when no friends are around.

### Play with friends — same room (LAN / offline)

Everyone must be on the **same Wi‑Fi or mobile hotspot**.

**Host**

1. **Create Local Room** → enter your name and room name.
2. Set boot and chip limit for the session.
3. Tap **Create & broadcast** — friends see the room in **Search Local Rooms**.
4. When everyone has joined, tap **Start game**. Empty seats can be filled with bots (minimum 3 players).

**Join**

1. **Search Local Rooms** → pick the host’s table → **Join**.
2. Wait for the host to start.

### Play with friends — anywhere (online)

Uses a fixed relay server; only a **6-letter room code** is needed (no IP addresses).

**Host**

1. **Play Online** → enter your name → set boot and chips → **Create room & get code**.
2. Share the code (WhatsApp, SMS, etc.).
3. Start when friends have joined.

**Join**

1. **Play Online** → enter the room code → **Join room**.

Friends connect to **your** room only. TashAdda does not put you into public lobbies with unknown players.

## Games included

| Game | Status |
|------|--------|
| Classic 3-card | Playable |
| Muflis (lowball) | Playable |
| Bluff (Cheat) | Playable |
| AK47, Joker, 999, Andar Bahar | Coming soon |

## Table rules (TashAdda)

- **Starting chips** = per-round limit (e.g. 1000 or 200). Everyone resets to that amount each round.
- **Boot** is posted at the start of every round.
- Up to **8 blind chaals**, then all cards are shown; up to **25 chaals** total per round.
- If you cannot afford the next chaal: **Show** or **Pack** (see in-app rules sheet).

Hosts set boot and chip limit for LAN and online rooms; all joiners use the same settings.

## Fair play

- Cards are shuffled with a cryptographically secure RNG (`Random.secure()`).
- Winners are decided only by standard hand ranking — no hidden player advantage.
- Bots use only their own cards to decide bets; they never see your hand.

## Build from source

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.12+.

```bash
git clone https://github.com/Ankitspandey07/TashAdda.git
cd TashAdda
flutter pub get
flutter test
flutter build apk --release          # Android
./scripts/sign_and_build_ios_ipa.sh  # iOS (Mac + free Apple ID)
```

The `card_game_platform` package lives in `packages/card_game_platform` (no extra clone needed).

## Publish a new version (maintainers)

1. Bump `version` in `pubspec.yaml`.
2. Build Android: `flutter build apk --release`
3. Build iOS: `./scripts/sign_and_build_ios_ipa.sh`
4. Copy to `releases/` (see [releases/README.md](releases/README.md)).
5. Commit, push, and create a GitHub Release with APK + IPA assets.

## Platform guides

| Guide | Contents |
|-------|----------|
| [store/IOS_INSTALL.md](store/IOS_INSTALL.md) | Sideloadly, AltStore, Diawi, TrollStore, OTA website |
| [store/IOS_BUILD.md](store/IOS_BUILD.md) | Build IPA on Mac |
| [store/ZERO_BUDGET.md](store/ZERO_BUDGET.md) | ₹0 distribution plan |
| [store/AMAZON_APPSTORE.md](store/AMAZON_APPSTORE.md) | Amazon Appstore checklist |

## Related repos

- [tashadda-vercel](https://github.com/Ankitspandey07/tashadda-vercel) — online relay server

## License

Private project — all rights reserved unless otherwise noted.
