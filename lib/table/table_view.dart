import 'package:flutter/foundation.dart';

import '../engine/game_engine.dart';
import '../score/scoreboard.dart';

/// What the table UI needs to render one seat. Only [hand] that should be
/// visible to the local viewer is ever populated (their own, or revealed cards
/// at showdown) — enforcing the "never send opponents' cards" rule.
class SeatView {
  const SeatView({
    required this.seat,
    required this.name,
    required this.chips,
    required this.folded,
    required this.seen,
    required this.isYou,
    required this.isTurn,
    required this.status,
    this.hand,
    this.exited = false,
  });

  final int seat;
  final String name;
  final int chips;
  final bool folded;
  final bool seen;
  final bool isYou;
  final bool isTurn;
  final String status;

  /// Left mid-game — show empty seat UI.
  final bool exited;

  /// Card codes (e.g. `AS`), or null when hidden from this viewer.
  final List<String>? hand;
}

/// Immutable snapshot the table screen renders.
class TableView {
  const TableView({
    required this.phase,
    required this.pot,
    required this.stake,
    required this.seats,
    required this.yourTurn,
    required this.youSeen,
    required this.callCost,
    required this.raiseCost,
    required this.canRaise,
    required this.twoLeft,
    required this.canSideshow,
    required this.log,
    required this.winnerIds,
    this.winnerBanner = '',
    this.sideshow,
    this.sideshowTargets = const [],
    this.pendingSideshow,
    this.scoreLog = const [],
    this.standings = const [],
    this.sessionRounds = 0,
    this.chaalCount = 0,
    this.maxChaals = 25,
    this.mustShowOrPack = false,
    this.canShow = false,
  });

  final RoundPhase phase;
  final int pot;
  final int stake;
  final List<SeatView> seats;
  final bool yourTurn;
  final bool youSeen;
  final int callCost;
  final int raiseCost;
  final bool canRaise;
  final bool twoLeft;
  final bool canSideshow;
  final List<String> log;
  final List<String> winnerIds;

  /// Friendly winner headline (name + amount + hand) shown when the round ends.
  final String winnerBanner;

  /// Most recent sideshow comparison to reveal, or null.
  final SideshowReveal? sideshow;

  /// Seen opponents you may challenge when it is your turn.
  final List<SideshowTargetView> sideshowTargets;

  /// Active sideshow request waiting for accept/reject, or null.
  final PendingSideshowView? pendingSideshow;

  /// Recent round results (online session score log).
  final List<String> scoreLog;

  /// Net profit/loss vs session start for each player.
  final List<({String name, int net, int won, int lost, int roundsWon})>
      standings;

  /// Rounds completed in this room session.
  final int sessionRounds;

  final int chaalCount;
  final int maxChaals;
  final bool mustShowOrPack;
  final bool canShow;

  static const empty = TableView(
    phase: RoundPhase.lobby,
    pot: 0,
    stake: 0,
    seats: [],
    yourTurn: false,
    youSeen: false,
    callCost: 0,
    raiseCost: 0,
    canRaise: false,
    twoLeft: false,
    canSideshow: false,
    log: [],
    winnerIds: [],
  );
}

/// A seen opponent eligible for sideshow.
class SideshowTargetView {
  const SideshowTargetView({required this.id, required this.name});
  final String id;
  final String name;
}

/// Pending sideshow request shown to requester and target.
class PendingSideshowView {
  const PendingSideshowView({
    required this.requesterName,
    required this.targetName,
    required this.youAreTarget,
    required this.youAreRequester,
  });

  final String requesterName;
  final String targetName;
  final bool youAreTarget;
  final bool youAreRequester;
}

/// A transport-agnostic controller the [TableScreen] talks to. Implemented by
/// the local engine (single device / host) and the network client.
abstract class TableController extends ChangeNotifier {
  TableView get view;
  String get title;

  void see();
  void call();
  void raise();
  void fold();
  void show();
  void requestSideshow(String targetId);
  void respondSideshow(bool accept);

  /// Voluntary leave (online/LAN); no-op for local bot games.
  void leaveTable() {}

  /// Starts a new round (host/local only; no-op on a client).
  void nextRound() {}

  /// True when this device is the room host (can close the room).
  bool get canCloseRoom => false;

  /// Ends the room for everyone (host only).
  void closeRoom() {}

  /// Session totals for the exit summary, or null if no rounds were played.
  SessionSummary? get sessionSummary => null;

  /// Called when the host closes the room and sends final totals.
  void Function(SessionSummary summary)? onSessionEnd;
}
