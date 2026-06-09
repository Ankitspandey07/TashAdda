# card_game_platform

Framework-agnostic **core** for a cross-platform (Android/iOS) multiplayer card
game platform. This package is pure Dart with no Flutter dependency, so the game
logic can be unit-tested on its own and later wired into a Flutter UI and the
dual-stack networking layer without changes.

> **Status: Phase 1 complete** — data models, dynamic deck scaling, the modular
> game interface, the round state machine, and the Teen Patti hand evaluator
> (including 104-card double-deck tie handling). Phases 2–4 are scaffolded by the
> architecture below but not yet implemented.

## Why Dart/Flutter

The spec left the engine as a placeholder. Flutter was chosen because it is a
single codebase for Android + iOS and `dart:io` exposes raw `RawDatagramSocket`
(UDP broadcast for local room discovery) and `Socket`/`ServerSocket` (TCP state
sync) natively — exactly what the dual-stack networking requires, with no native
modules. The core here stays engine-agnostic regardless.

## Run

```bash
dart pub get
dart test
dart analyze
```

## What's in here (Phase 1)

```
lib/
  card_game_platform.dart        # barrel export
  src/
    models/
      card.dart                  # PlayingCard, Rank, Suit (deckIndex for dup copies)
      deck.dart                  # Deck.forPlayers() -> 52 (<=5) or 104 (>5)
      player.dart                # Player: chips, seat, blind/seen state, private hand
      game_state.dart            # GamePhase machine + guarded transitions + startRound
    games/
      hand_result.dart           # comparable result; equal == tie (split pot)
      i_card_game.dart           # ICardGame plug-in contract + ShowdownEntry
      teen_patti/
        teen_patti_game.dart     # Teen Patti rules + hand evaluator
test/                            # deck scaling, every category, run ordering, ties
```

### Key design points

- **Dynamic deck scaling.** `Deck.forPlayers(n)` returns one 52-card deck for
  `n <= 5` and a 104-card double deck for `n > 5`. Jokers are never included.
- **Double-deck ties.** In double-deck mode two players can hold identical face
  values. `PlayingCard.deckIndex` keeps physical copies distinct, but the
  evaluator ignores it, so identical hands produce equal `HandResult`s and
  `determineWinners` returns **all** tied players for a split pot.
- **Modular games.** Lobby/networking/state-machine code depends only on
  `ICardGame`. New games (Rummy, Poker, Blackjack) implement that interface
  without touching transport code.
- **Authoritative state machine.** `GameState.transitionTo` rejects illegal
  phase jumps:
  `lobbyWaiting → shufflingAndDealing → playerTurnActive → sideShowEvaluation →
  showdown → payoutCalculation`.
- **Security posture (enforced later by transport).** Player hands live on the
  authoritative host's `GameState`; transport code must only ever send a player
  their own cards — never the full deck or opponents' cards.

### Teen Patti ranking & a documented assumption

Ranking (high → low): **Trail > Pure Sequence > Sequence > Color > Pair > High
Card.**

Run ordering uses the common Indian Teen Patti rule: **A-K-Q is the highest run
and A-2-3 is the second highest**, then runs rank by top card (K-Q-J … 4-3-2).
Variants differ here; to switch to the "A-2-3 is lowest" variant, change
`_runValue` in `teen_patti_game.dart`.

## Roadmap (not yet implemented)

- **Phase 2 — Local UI (Flutter):** main menu, lobby room creation with the 3–5
  seat constraint, table canvas layout.
- **Phase 3 — Local network layer:** UDP broadcast discovery on port `7777`
  (1.5s `{roomName, playerCount, hostIp}` packets via `RawDatagramSocket`), plus
  a TCP host-client state syncer. Android manifest needs
  `CHANGE_WIFI_MULTICAST_STATE`; iOS needs the local-network usage description.
- **Phase 4 — Central server:** online matchmaking/room routing (plain WebSocket
  server proposed) with 6-digit room codes and public/private rooms.
```
