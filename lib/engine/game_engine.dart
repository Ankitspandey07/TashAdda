import 'dart:async';
import 'dart:math';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

import '../audio/sfx.dart';
import '../score/scoreboard.dart';

/// Phases of a single Teen Patti round as the table UI sees them.
enum RoundPhase { lobby, betting, sideshowPending, showdown, roundOver }

/// A sideshow request waiting for the target to accept or reject.
class PendingSideshow {
  PendingSideshow({required this.requesterId, required this.targetId});
  final String requesterId;
  final String targetId;
}

/// A revealed sideshow comparison, shown to players as an overlay so they can
/// see who challenged whom and both hands.
class SideshowReveal {
  SideshowReveal({
    required this.seq,
    required this.requester,
    required this.target,
    required this.winner,
    required this.requesterHand,
    required this.targetHand,
  });

  /// Increments each sideshow so the UI can tell a new one apart.
  final int seq;
  final String requester;
  final String target;
  final String winner;
  final List<String> requesterHand;
  final List<String> targetHand;
}

/// A seat in the engine: wraps the core [Player] plus runtime flags the table
/// needs (whether it is a bot, and a short status line for the UI).
class Seat {
  Seat({required this.player, this.isBot = false});

  final Player player;
  final bool isBot;
  String status = '';

  /// Left mid-game (online/LAN). Seat stays visible as empty/exited.
  bool hasExited = false;

  /// Player was offered Show because chips could not cover the next chaal.
  bool skippedShowWhenBroke = false;

  String get id => player.id;
  String get name => player.name;
}

/// Authoritative Teen Patti engine. Holds all secret state (every hand) and
/// exposes only what the UI/network layer should reveal.
///
/// TashAdda round limits:
/// - Up to 8 chaals in the blind phase (seen pays double).
/// - After chaal 8, all active players auto-see; betting equalizes.
/// - Up to 25 chaals total, then forced showdown.
class GameEngine extends ChangeNotifier {
  GameEngine({
    required this.boot,
    this.startChips = 1000,
    ICardGame? game,
    this.maxStake = 320,
    Random? random,
  })  : game = game ?? const TeenPattiGame(),
        _rng = random ?? Random() {
    if (boot <= 0 || startChips <= 0) {
      throw ArgumentError('boot and startChips must be positive');
    }
    if (boot > startChips) {
      throw ArgumentError('boot ($boot) cannot exceed startChips ($startChips)');
    }
  }

  /// Max chaals while cards may stay hidden (then auto-show all).
  static const int maxBlindPhaseChaals = 8;

  /// Max betting actions per round (blind phase + post-reveal chaals).
  static const int maxTotalChaals = 25;

  final int boot;
  final int startChips;
  final int maxStake;
  final Random _rng;

  /// The game ruleset in play (Teen Patti, Muflis, …). Betting is shared; only
  /// deck building and hand evaluation differ per game.
  final ICardGame game;

  final List<Seat> seats = [];
  RoundPhase phase = RoundPhase.lobby;
  int pot = 0;
  int stake = 0;
  int _turn = 0;
  final List<String> log = [];
  List<String> winnerIds = [];

  /// Friendly headline shown when a round ends (winner name + amount + hand).
  String winnerBanner = '';

  /// Most recent sideshow comparison (for the reveal overlay); null until one
  /// happens this round.
  SideshowReveal? lastSideshow;
  int _sideshowSeq = 0;

  /// Waiting for [targetId] to accept/reject a sideshow from [requesterId].
  PendingSideshow? pendingSideshow;
  Timer? _sideshowTimer;

  /// Session score log (online/LAN hosts attach this to views).
  final SessionScoreboard scoreboard = SessionScoreboard();

  int _chaalCount = 0;
  bool _equalBetting = false;

  int get chaalCount => _chaalCount;
  int get maxChaals => maxTotalChaals;
  bool get equalBetting => _equalBetting;
  bool get blindPhaseComplete => _chaalCount >= maxBlindPhaseChaals;

  /// Index of the seat whose turn it is.
  int get turnIndex => _turn;
  Seat get current => seats[_turn];

  List<Seat> get activeSeats => seats
      .where((s) => !s.player.hasFolded && !s.hasExited)
      .toList(growable: false);

  List<Seat> get playingSeats =>
      seats.where((s) => !s.hasExited).toList(growable: false);

  bool get isBettingPhase =>
      phase == RoundPhase.betting || phase == RoundPhase.sideshowPending;
  bool get twoLeft => activeSeats.length == 2;

  void addSeat(Seat seat) {
    seats.add(seat);
    notifyListeners();
  }

  void _say(String msg) {
    log.insert(0, msg);
    if (log.length > 40) log.removeLast();
  }

  /// Cost for [seat] to call at the current stake.
  int callCost(Seat seat) {
    if (_equalBetting || seat.player.isBlind) return stake;
    return stake * 2;
  }

  /// Cost for [seat] to raise (double the unit).
  int raiseCost(Seat seat) {
    if (_equalBetting || seat.player.isBlind) return stake * 2;
    return stake * 4;
  }

  bool canAffordCall(Seat seat) => seat.player.chips >= callCost(seat);

  /// True when the current player must Show or Pack before chaal.
  bool mustShowOrPack(Seat seat) =>
      seat == current &&
      phase == RoundPhase.betting &&
      !seat.player.hasFolded &&
      !seat.hasExited &&
      seat.player.chips > 0 &&
      !canAffordCall(seat);

  bool get canRaise => stake < maxStake;

  /// Deals a fresh round. All seats must already be added.
  void startRound() {
    if (seats.length < game.minPlayers) {
      throw StateError('Need at least ${game.minPlayers} players');
    }
    final playing = playingSeats;
    if (playing.length < game.minPlayers) {
      throw StateError('Not enough players at the table');
    }
    final deck = game.buildDeck(playing.length)..shuffle(_rng);
    pot = 0;
    stake = boot;
    winnerIds = [];
    winnerBanner = '';
    lastSideshow = null;
    pendingSideshow = null;
    _sideshowTimer?.cancel();
    _chaalCount = 0;
    _equalBetting = false;
    for (final s in seats) {
      if (s.hasExited) {
        s.status = 'Exited';
        continue;
      }
      s.player.resetForNewRound();
      s.player.chips = startChips;
      s.status = '';
      s.skippedShowWhenBroke = false;
    }
    // Deal one card at a time, like a real dealer.
    for (var i = 0; i < game.cardsPerPlayer; i++) {
      for (final s in playing) {
        s.player.hand.addAll(deck.deal(1));
      }
    }
    // Everyone posts the boot.
    for (final s in playing) {
      s.player.chips -= boot;
      pot += boot;
    }
    _turn = seats.indexOf(playing.first);
    phase = RoundPhase.betting;
    _say('New round dealt. Boot $boot each. Pot $pot.');
    Sfx.instance.deal();
    notifyListeners();
    _maybeRunBots();
  }

  /// Current player looks at their cards (blind -> seen).
  void see(Seat seat) {
    seat.player.see();
    _say('${seat.name} saw their cards.');
    notifyListeners();
  }

  /// Player left mid-game; others continue with an empty seat.
  void markExited(Seat seat) {
    if (seat.hasExited) return;
    seat.hasExited = true;
    seat.status = 'Exited';
    _say('${seat.name} left the table.');
    Sfx.instance.fold();
    if (activeSeats.length == 1) {
      _finishByFold(activeSeats.first);
      return;
    }
    if (phase == RoundPhase.betting && seat.id == current.id) {
      _advance();
    } else {
      notifyListeners();
    }
  }

  /// Current player calls or raises.
  void bet(Seat seat, {required bool raise}) {
    if (phase != RoundPhase.betting || seat != current || seat.hasExited) {
      return;
    }
    if (mustShowOrPack(seat)) {
      seat.skippedShowWhenBroke = true;
      _packBroke(seat, reason: 'Not enough chips for chaal — packed.');
      return;
    }
    if (seat.player.chips <= 0) {
      _packBroke(seat);
      return;
    }
    if (raise && !canRaise) raise = false;
    final cost = raise ? raiseCost(seat) : callCost(seat);
    if (seat.player.chips < cost) {
      if (mustShowOrPack(seat) || seat.skippedShowWhenBroke) {
        _packBroke(seat);
      }
      return;
    }
    seat.skippedShowWhenBroke = false;
    seat.player.chips -= cost;
    seat.player.currentBet += cost;
    pot += cost;
    if (raise) stake = (stake * 2).clamp(0, maxStake);
    _say('${seat.name} ${seat.player.isSeen ? 'chaal' : 'blind'} '
        '${raise ? 'raise' : 'call'} $cost. Pot $pot.');
    if (raise) {
      Sfx.instance.raise();
    } else {
      Sfx.instance.bet();
    }
    _afterChaal();
  }

  void _packBroke(Seat seat, {String? reason}) {
    seat.player.hasFolded = true;
    seat.status = 'Packed (no chips)';
    _say(reason ?? '${seat.name} packed — out of chips.');
    Sfx.instance.fold();
    if (activeSeats.length == 1) {
      _finishByFold(activeSeats.first);
      return;
    }
    _advance();
  }

  void _afterChaal() {
    _chaalCount++;
    if (!_equalBetting && _chaalCount >= maxBlindPhaseChaals) {
      _forceRevealAll();
    }
    if (_chaalCount >= maxTotalChaals) {
      _say('Chaal limit ($maxTotalChaals) — showdown!');
      _showdown(activeSeats);
      return;
    }
    _advance();
  }

  void _forceRevealAll() {
    _equalBetting = true;
    for (final s in activeSeats) {
      if (s.player.isBlind) {
        s.player.see();
      }
    }
    _say('After $maxBlindPhaseChaals chaals — all cards shown · equal betting.');
  }

  /// Current player folds (packs).
  void fold(Seat seat) {
    if (phase != RoundPhase.betting || seat != current) return;
    seat.player.hasFolded = true;
    seat.status = 'Packed';
    _say('${seat.name} packed.');
    Sfx.instance.fold();
    if (activeSeats.length == 1) {
      _finishByFold(activeSeats.first);
      return;
    }
    _advance();
  }

  /// With two players left, pay and force showdown. Also allowed when broke
  /// (puts in remaining chips).
  void show(Seat seat) {
    if (phase != RoundPhase.betting || seat != current || seat.hasExited) {
      return;
    }
    final broke = mustShowOrPack(seat);
    if (!twoLeft) {
      if (broke) _packBroke(seat);
      return;
    }
    final cost = broke
        ? seat.player.chips
        : callCost(seat).clamp(0, seat.player.chips);
    if (cost <= 0) {
      _packBroke(seat);
      return;
    }
    seat.player.chips -= cost;
    seat.player.currentBet += cost;
    pot += cost;
    seat.skippedShowWhenBroke = false;
    _say('${seat.name} called Show for $cost.');
    Sfx.instance.bet();
    if (!broke) {
      _chaalCount++;
      if (_chaalCount >= maxTotalChaals) {
        _showdown(activeSeats);
        return;
      }
    }
    _showdown(activeSeats);
  }

  /// Seen active opponents the current player may challenge in a sideshow.
  List<Seat> sideshowTargets(Seat seat) {
    if (twoLeft || !seat.player.isSeen || seat.player.hasFolded || seat.hasExited) {
      return const [];
    }
    return activeSeats
        .where((s) =>
            s.id != seat.id &&
            s.player.isSeen &&
            !s.player.hasFolded &&
            !s.hasExited)
        .toList(growable: false);
  }

  /// Legacy helper — first eligible target (bots use this).
  Seat? sideshowTarget(Seat seat) {
    final t = sideshowTargets(seat);
    return t.isEmpty ? null : t.first;
  }

  /// Request a sideshow with a chosen seen opponent; target must accept.
  void requestSideshow(Seat seat, String targetId) {
    if (phase != RoundPhase.betting || seat != current || twoLeft) return;
    if (!seat.player.isSeen) return;
    Seat? target;
    for (final s in seats) {
      if (s.id == targetId) {
        target = s;
        break;
      }
    }
    if (target == null ||
        !target.player.isSeen ||
        target.player.hasFolded ||
        target.id == seat.id) {
      return;
    }
    final chosen = target;
    pendingSideshow =
        PendingSideshow(requesterId: seat.id, targetId: chosen.id);
    phase = RoundPhase.sideshowPending;
    _say('${seat.name} requested sideshow with ${chosen.name}.');
    _sideshowTimer?.cancel();
    _sideshowTimer = Timer(const Duration(seconds: 5), () {
      if (pendingSideshow?.requesterId == seat.id &&
          pendingSideshow?.targetId == chosen.id) {
        _cancelSideshow(
            reason: 'Sideshow timed out — ${chosen.name} did not respond.');
      }
    });
    notifyListeners();
    _maybeBotRespondSideshow();
  }

  /// Target accepts or rejects a pending sideshow request.
  void respondSideshow(Seat target, bool accept) {
    final pending = pendingSideshow;
    if (pending == null || phase != RoundPhase.sideshowPending) return;
    if (target.id != pending.targetId) return;
    _sideshowTimer?.cancel();
    final requester = seats.firstWhere((s) => s.id == pending.requesterId);
    if (!accept) {
      _cancelSideshow(reason: '${target.name} rejected sideshow.');
      return;
    }
    _executeSideshow(requester, target);
  }

  void _cancelSideshow({String? reason}) {
    pendingSideshow = null;
    phase = RoundPhase.betting;
    if (reason != null) _say(reason);
    notifyListeners();
    _maybeRunBots();
  }

  void _executeSideshow(Seat seat, Seat target) {
    pendingSideshow = null;
    phase = RoundPhase.betting;
    if (seat.player.chips < callCost(seat)) {
      _packBroke(seat, reason: '${seat.name} could not pay sideshow — packed.');
      return;
    }
    final cost = callCost(seat);
    seat.player.chips -= cost;
    seat.player.currentBet += cost;
    pot += cost;
    Sfx.instance.bet();
    _chaalCount++;
    final cmp = game.compare(seat.player.hand, target.player.hand);
    final requesterWon = cmp >= 0;
    _sideshowSeq++;
    lastSideshow = SideshowReveal(
      seq: _sideshowSeq,
      requester: seat.name,
      target: target.name,
      winner: requesterWon ? seat.name : target.name,
      requesterHand: seat.player.hand.map((c) => c.code).toList(),
      targetHand: target.player.hand.map((c) => c.code).toList(),
    );
    if (requesterWon) {
      target.player.hasFolded = true;
      target.status = 'Lost sideshow';
      _say('${seat.name} won sideshow vs ${target.name}.');
    } else {
      seat.player.hasFolded = true;
      seat.status = 'Lost sideshow';
      _say('${seat.name} lost sideshow vs ${target.name}.');
    }
    if (activeSeats.length == 1) {
      _finishByFold(activeSeats.first);
      return;
    }
    if (_chaalCount >= maxTotalChaals) {
      _showdown(activeSeats);
      return;
    }
    _advance();
  }

  void _advance() {
    if (activeSeats.isEmpty) return;
    final start = _turn;
    var steps = 0;
    do {
      _turn = (_turn + 1) % seats.length;
      steps++;
      if (steps > seats.length) {
        // Safety: should never happen; avoid infinite loop.
        return;
      }
    } while (seats[_turn].player.hasFolded || seats[_turn].hasExited);
    if (_turn == start && (seats[_turn].player.hasFolded || seats[_turn].hasExited)) {
      return;
    }
    final cur = current;
    if (cur.player.chips <= 0 && !cur.player.hasFolded) {
      _packBroke(cur);
      return;
    }
    notifyListeners();
    _maybeRunBots();
  }

  void _finishByFold(Seat winner) {
    winner.player.chips += pot;
    winnerIds = [winner.id];
    winner.status = 'Winner (+$pot)';
    winnerBanner = '${winner.name} won $pot — everyone else packed!';
    _say('${winner.name} wins $pot (all others packed).');
    phase = RoundPhase.roundOver;
    _recordScore(null);
    notifyListeners();
  }

  void _showdown(List<Seat> contenders) {
    phase = RoundPhase.showdown;
    final entries = contenders
        .map((s) => ShowdownEntry(s.id, s.player.hand))
        .toList(growable: false);
    final winners = game.determineWinners(entries);
    winnerIds = winners;
    final share = winners.isEmpty ? 0 : pot ~/ winners.length;
    String? winCategory;
    for (final s in contenders) {
      final res = game.evaluate(s.player.hand);
      if (winners.contains(s.id)) {
        s.player.chips += share;
        s.status = 'Winner (+$share) · ${res.categoryName}';
        winCategory = res.categoryName;
      } else {
        s.status = res.categoryName;
      }
    }
    final names = winners
        .map((id) => seats.firstWhere((s) => s.id == id).name)
        .join(' & ');
    if (winners.length > 1) {
      winnerBanner = '$names split the pot — $share each!';
    } else if (winners.isNotEmpty) {
      winnerBanner = '$names won $pot with ${winCategory ?? 'the best hand'}!';
    }
    _say('Showdown: ${winners.length > 1 ? 'split pot' : 'winner decided'}.');
    phase = RoundPhase.roundOver;
    _recordScore(winCategory);
    notifyListeners();
  }

  void _recordScore(String? handNote) {
    scoreboard.recordRound(
      roundStartChips: startChips,
      winnerIds: winnerIds,
      pot: pot,
      seats: [
        for (final s in seats)
          (id: s.id, name: s.name, chips: s.player.chips),
      ],
      handNote: handNote,
    );
  }

  void _maybeBotRespondSideshow() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (phase != RoundPhase.sideshowPending) return;
      final pending = pendingSideshow;
      if (pending == null) return;
      final target = seats.firstWhere((s) => s.id == pending.targetId);
      if (!target.isBot) return;
      respondSideshow(target, _rng.nextDouble() < 0.55);
    });
  }

  /// Drives bot turns until it is a human's turn or the round ends.
  void _maybeRunBots() {
    Future.delayed(const Duration(milliseconds: 650), () {
      if (phase == RoundPhase.sideshowPending) return;
      if (phase != RoundPhase.betting) return;
      final seat = current;
      if (!seat.isBot) return;
      _botAct(seat);
    });
  }

  void _botAct(Seat seat) {
    if (seat.hasExited) return;
    if (mustShowOrPack(seat)) {
      if (twoLeft && _rng.nextDouble() < 0.6) {
        show(seat);
      } else {
        seat.skippedShowWhenBroke = true;
        fold(seat);
      }
      return;
    }
    if (seat.player.isBlind && !_equalBetting && _rng.nextDouble() < 0.35) {
      seat.player.see();
    } else if (seat.player.isBlind && _equalBetting) {
      seat.player.see();
    }
    final strength = game.evaluate(seat.player.hand).category; // 1..6
    final r = _rng.nextDouble();

    if (twoLeft) {
      // Decide between show, call, or fold.
      if (strength >= 3 || r < 0.5) {
        show(seat);
      } else if (r < 0.8) {
        bet(seat, raise: false);
      } else {
        fold(seat);
      }
      return;
    }

    if (strength >= 4 && canRaise && r < 0.7) {
      bet(seat, raise: true);
    } else if (strength >= 2 || r < 0.65) {
      bet(seat, raise: false);
    } else {
      fold(seat);
    }
  }
}
