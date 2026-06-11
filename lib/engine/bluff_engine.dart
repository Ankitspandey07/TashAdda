import 'dart:async';
import 'dart:math';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

/// Phases of a Bluff (a.k.a. Cheat / Bullshit) turn.
enum BluffPhase {
  /// The current player must play 1–4 cards and claim they are the required rank.
  play,

  /// A play just happened; others may call "Bluff!" before the next play.
  callWindow,

  /// Someone emptied their hand and survived — game over.
  roundOver,
}

/// Plural display name for a rank value (2..14).
String bluffRankName(int v) {
  switch (v) {
    case 14:
      return 'Aces';
    case 13:
      return 'Kings';
    case 12:
      return 'Queens';
    case 11:
      return 'Jacks';
    case 10:
      return 'Tens';
    default:
      return '${v}s';
  }
}

class BluffPlayer {
  BluffPlayer({required this.id, required this.name, this.isBot = false});
  final String id;
  final String name;
  final bool isBot;
  final List<PlayingCard> hand = [];
}

/// A pending claim awaiting possible challenge.
class BluffClaim {
  BluffClaim({
    required this.playerIndex,
    required this.rankValue,
    required this.cards,
  });
  final int playerIndex;
  final int rankValue;
  final List<PlayingCard> cards;
  int get count => cards.length;
  bool get isTruthful => cards.every((c) => c.rank.value == rankValue);
}

/// Bluff / Cheat engine for one device (human + bots).
///
/// Rules implemented: a single 52-card deck is dealt out; the required rank
/// advances A→2→3…→K→A each play; on your turn you must play 1–4 cards face
/// down claiming they are the required rank (you may lie). After a play, others
/// may call "Bluff!". If the claim was a lie the player takes the whole pile;
/// if it was true the caller takes the pile. First player to empty their hand
/// (and survive the call window) wins.
class BluffEngine extends ChangeNotifier {
  BluffEngine({Random? random, this.callTimeout})
      : _rng = random ?? Random.secure();

  final Random _rng;

  /// When set (used by networked hosts), pending human callers are auto-passed
  /// after this duration so an idle/disconnected player can't stall the table.
  /// Left null for single-device play (the local human has unlimited time).
  final Duration? callTimeout;

  static const int maxPlayCards = 4;

  final List<BluffPlayer> players = [];
  BluffPhase phase = BluffPhase.play;
  int turn = 0;
  int requiredRank = 14; // start on Aces
  final List<PlayingCard> pile = [];
  BluffClaim? lastClaim;
  final List<String> log = [];
  String? winnerId;

  /// Non-claimant human seats that still have a chance to call this window.
  /// Humans get first refusal; bots only decide once all humans have passed.
  Set<int> _humanPending = {};
  Timer? _callTimer;

  BluffPlayer get current => players[turn];
  int get humanIndex => players.indexWhere((p) => !p.isBot);

  /// Can [idx] call on the pending claim right now?
  bool mayCall(int idx) =>
      phase == BluffPhase.callWindow &&
      lastClaim != null &&
      lastClaim!.playerIndex != idx &&
      _humanPending.contains(idx);

  /// Can the local human call on the pending claim?
  bool get humanMayCall => mayCall(humanIndex);

  void _say(String m) {
    log.insert(0, m);
    if (log.length > 50) log.removeLast();
  }

  void addPlayer(BluffPlayer p) => players.add(p);

  void startGame() {
    final deck = Deck.forPlayers(players.length)..shuffle(_rng);
    for (final p in players) {
      p.hand.clear();
    }
    // Round-robin deal.
    var i = 0;
    while (deck.remaining > 0) {
      players[i % players.length].hand.addAll(deck.deal(1));
      i++;
    }
    for (final p in players) {
      _sortHand(p);
    }
    pile.clear();
    lastClaim = null;
    winnerId = null;
    requiredRank = 14;
    turn = 0;
    phase = BluffPhase.play;
    _humanPending = {};
    _callTimer?.cancel();
    _say('Cards dealt. Claim ${bluffRankName(requiredRank)}.');
    notifyListeners();
    _maybeBotPlay();
  }

  void _sortHand(BluffPlayer p) =>
      p.hand.sort((a, b) => a.rank.value.compareTo(b.rank.value));

  int _nextRank(int v) => v == 14 ? 2 : v + 1;

  /// Plays [cards] from the current player as a claim of [requiredRank].
  void play(List<PlayingCard> cards) {
    if (phase != BluffPhase.play) return;
    if (cards.isEmpty || cards.length > maxPlayCards) return;
    final p = current;
    // Validate the cards belong to the player's hand (by identity).
    for (final c in cards) {
      if (!p.hand.contains(c)) return;
    }
    for (final c in cards) {
      p.hand.remove(c);
    }
    pile.addAll(cards);
    lastClaim = BluffClaim(
        playerIndex: turn, rankValue: requiredRank, cards: List.of(cards));
    phase = BluffPhase.callWindow;
    // Every non-claimant human gets first chance to call.
    _humanPending = {
      for (var i = 0; i < players.length; i++)
        if (i != turn && !players[i].isBot) i
    };
    _say('${p.name} plays ${cards.length} as ${bluffRankName(requiredRank)}.');
    notifyListeners();

    if (_humanPending.isEmpty) {
      // No human to wait on — bots decide after a short beat.
      Future.delayed(const Duration(milliseconds: 700), _resolveByBots);
    } else if (callTimeout != null) {
      // Networked: don't let an idle player stall the window forever.
      _callTimer?.cancel();
      _callTimer = Timer(callTimeout!, () {
        _humanPending.clear();
        _resolveByBots();
      });
    }
  }

  /// The current player ([seatIndex]) plays [cards]; used by network hosts to
  /// apply a remote player's move (and validates it really is their turn).
  void playBy(int seatIndex, List<PlayingCard> cards) {
    if (phase != BluffPhase.play || turn != seatIndex) return;
    play(cards);
  }

  /// Local human passes on calling.
  void pass() => passBy(humanIndex);

  /// Local human calls bluff on the pending claim.
  void callBluff() => callBy(humanIndex);

  /// [seatIndex] passes on calling. Once every human has passed, bots decide.
  void passBy(int seatIndex) {
    if (phase != BluffPhase.callWindow) return;
    if (!_humanPending.remove(seatIndex)) return;
    if (_humanPending.isEmpty) {
      _callTimer?.cancel();
      _resolveByBots();
    } else {
      notifyListeners();
    }
  }

  /// [seatIndex] calls bluff on the pending claim.
  void callBy(int seatIndex) {
    if (!mayCall(seatIndex)) return;
    _callTimer?.cancel();
    _resolve(seatIndex);
  }

  /// Resolves the call window using bot suspicion only (no human caller).
  void _resolveByBots() {
    if (phase != BluffPhase.callWindow || lastClaim == null) return;
    final claim = lastClaim!;
    int? caller;
    for (var idx = 0; idx < players.length; idx++) {
      if (idx == claim.playerIndex) continue;
      if (!players[idx].isBot) continue; // human decides via UI
      if (_botWantsToCall(idx, claim)) {
        caller = idx;
        break;
      }
    }
    _resolve(caller);
  }

  bool _botWantsToCall(int botIndex, BluffClaim claim) {
    final held =
        players[botIndex].hand.where((c) => c.rank.value == claim.rankValue).length;
    // More of that rank than can exist => certain bluff.
    if (held + claim.count > 4) return true;
    var p = 0.05 * claim.count;
    if (claim.count >= 3) p += 0.18;
    p += 0.03 * held; // fewer left for the claimant
    if (pile.length <= claim.count) p *= 0.4; // little to lose early
    return _rng.nextDouble() < p.clamp(0, 0.9);
  }

  /// Resolves the pending claim. [caller] is the challenger index, or null if
  /// nobody called.
  void _resolve(int? caller) {
    if (phase != BluffPhase.callWindow || lastClaim == null) return;
    _callTimer?.cancel();
    _humanPending = {};
    final claim = lastClaim!;
    final claimant = players[claim.playerIndex];

    if (caller != null) {
      final truthful = claim.isTruthful;
      final loserIdx = truthful ? caller : claim.playerIndex;
      final loser = players[loserIdx];
      final revealed = claim.cards.map((c) => c.code).join(' ');
      _say('${players[caller].name} calls BLUFF on ${claimant.name}! '
          'Cards were $revealed — ${truthful ? 'TRUE' : 'a lie'}. '
          '${loser.name} picks up ${pile.length}.');
      loser.hand.addAll(pile);
      _sortHand(loser);
      pile.clear();
      // Loser starts the next claim sequence.
      turn = loserIdx;
      requiredRank = _nextRank(requiredRank);
      _afterResolve(startTurnAlreadySet: true);
      return;
    }

    // No call — claim stands.
    _say('No challenge. ${claimant.name} has ${claimant.hand.length} left.');
    if (claimant.hand.isEmpty) {
      winnerId = claimant.id;
      phase = BluffPhase.roundOver;
      _say('${claimant.name} wins — emptied their hand!');
      notifyListeners();
      return;
    }
    requiredRank = _nextRank(requiredRank);
    turn = _nextActive(claim.playerIndex);
    _afterResolve(startTurnAlreadySet: true);
  }

  void _afterResolve({required bool startTurnAlreadySet}) {
    // Win check (a wrongly-challenged truthful player can be empty here).
    for (final p in players) {
      if (p.hand.isEmpty) {
        winnerId = p.id;
        phase = BluffPhase.roundOver;
        _say('${p.name} wins — emptied their hand!');
        notifyListeners();
        return;
      }
    }
    phase = BluffPhase.play;
    lastClaim = null;
    notifyListeners();
    _maybeBotPlay();
  }

  int _nextActive(int from) => (from + 1) % players.length;

  void _maybeBotPlay() {
    if (phase != BluffPhase.play) return;
    if (!current.isBot) return;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (phase != BluffPhase.play || !current.isBot) return;
      play(_botChooseCards(current));
    });
  }

  /// Bot picks cards to play: truthfully if it holds the required rank,
  /// otherwise bluffs with its lowest single card.
  List<PlayingCard> _botChooseCards(BluffPlayer bot) {
    final matching =
        bot.hand.where((c) => c.rank.value == requiredRank).toList();
    if (matching.isNotEmpty) {
      return matching.take(maxPlayCards).toList();
    }
    // Bluff: dump the lowest card (hand is sorted ascending).
    return [bot.hand.first];
  }

  /// Test/AI helper: resolve the current call window with an explicit caller
  /// (or null). Exposed for deterministic tests.
  @visibleForTesting
  void debugResolve(int? caller) => _resolve(caller);

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }
}
