import '../engine/game_engine.dart';
import 'table_view.dart';

/// Builds the [TableView] a specific viewer (seat id) is allowed to see.
///
/// This is the single chokepoint that enforces the security rule: a seat's
/// [SeatView.hand] is only filled for the viewer themselves, or for non-folded
/// contenders once the round is over (showdown reveal). Opponents' hidden cards
/// are never included, so the host can serialize this straight to the wire.
TableView buildTableView(GameEngine engine, String viewerSeatId) {
  final viewer = engine.seats.firstWhere((s) => s.id == viewerSeatId);
  final reveal = engine.phase == RoundPhase.roundOver;
  final myTurn = engine.isBettingPhase &&
      engine.phase != RoundPhase.sideshowPending &&
      engine.current.id == viewerSeatId;

  final seats = engine.seats.map((s) {
    // Your own cards stay face-down until you tap "See cards" (true Teen Patti
    // blind play). Everyone's cards reveal at showdown.
    final showHand = (s.id == viewerSeatId &&
            (s.player.isSeen || engine.blindPhaseComplete)) ||
        (reveal && !s.player.hasFolded && engine.winnerIds.isNotEmpty);
    return SeatView(
      seat: s.player.seat,
      name: s.name,
      chips: s.player.chips,
      folded: s.player.hasFolded && !s.hasExited,
      seen: s.player.isSeen || engine.blindPhaseComplete,
      isYou: s.id == viewerSeatId,
      isTurn: engine.isBettingPhase &&
          engine.current.id == s.id &&
          !s.hasExited,
      status: s.hasExited
          ? 'Exited'
          : (s.status.isNotEmpty
              ? s.status
              : (engine.winnerIds.contains(s.id) ? 'Winner' : '')),
      hand: showHand ? s.player.hand.map((c) => c.code).toList() : null,
      exited: s.hasExited,
    );
  }).toList();

  return TableView(
    phase: engine.phase,
    pot: engine.pot,
    stake: engine.stake,
    seats: seats,
    yourTurn: myTurn,
    youSeen: viewer.player.isSeen,
    callCost: engine.callCost(viewer),
    raiseCost: engine.raiseCost(viewer),
    canRaise: engine.canRaise,
    twoLeft: engine.twoLeft,
    canSideshow: myTurn && engine.sideshowTargets(viewer).isNotEmpty,
    log: List.of(engine.log),
    winnerIds: List.of(engine.winnerIds),
    winnerBanner: engine.winnerBanner,
    sideshow: engine.lastSideshow,
    chaalCount: engine.chaalCount,
    maxChaals: engine.maxChaals,
    mustShowOrPack: engine.mustShowOrPack(viewer),
    canShow: engine.twoLeft && myTurn,
    sideshowTargets: [
      for (final t in engine.sideshowTargets(viewer))
        SideshowTargetView(id: t.id, name: t.name),
    ],
    pendingSideshow: _pendingView(engine, viewerSeatId),
    scoreLog: [
      for (final e in engine.scoreboard.log.take(8))
        '${e.name}: ${e.note} · balance ${e.balance}',
    ],
    standings: engine.scoreboard.standings([
      for (final s in engine.seats)
        (id: s.id, name: s.name, chips: s.player.chips),
    ]),
    sessionRounds: engine.scoreboard.roundsPlayed,
  );
}

PendingSideshowView? _pendingView(GameEngine engine, String viewerSeatId) {
  final p = engine.pendingSideshow;
  if (p == null) return null;
  final requester = engine.seats.firstWhere((s) => s.id == p.requesterId);
  final target = engine.seats.firstWhere((s) => s.id == p.targetId);
  return PendingSideshowView(
    requesterName: requester.name,
    targetName: target.name,
    youAreTarget: p.targetId == viewerSeatId,
    youAreRequester: p.requesterId == viewerSeatId,
  );
}

Map<String, dynamic>? _sideshowToJson(SideshowReveal? s) => s == null
    ? null
    : {
        'seq': s.seq,
        'requester': s.requester,
        'target': s.target,
        'winner': s.winner,
        'requesterHand': s.requesterHand,
        'targetHand': s.targetHand,
      };

SideshowReveal? _sideshowFromJson(Object? raw) {
  if (raw == null) return null;
  final j = (raw as Map).cast<String, dynamic>();
  return SideshowReveal(
    seq: j['seq'] as int,
    requester: j['requester'] as String,
    target: j['target'] as String,
    winner: j['winner'] as String,
    requesterHand: (j['requesterHand'] as List).cast<String>(),
    targetHand: (j['targetHand'] as List).cast<String>(),
  );
}

Map<String, dynamic> seatToJson(SeatView s) => {
      'seat': s.seat,
      'name': s.name,
      'chips': s.chips,
      'folded': s.folded,
      'seen': s.seen,
      'isYou': s.isYou,
      'isTurn': s.isTurn,
      'status': s.status,
      'hand': s.hand,
      'exited': s.exited,
    };

Map<String, dynamic> tableViewToJson(TableView v) => {
      't': 'view',
      'phase': v.phase.name,
      'pot': v.pot,
      'stake': v.stake,
      'yourTurn': v.yourTurn,
      'youSeen': v.youSeen,
      'callCost': v.callCost,
      'raiseCost': v.raiseCost,
      'canRaise': v.canRaise,
      'twoLeft': v.twoLeft,
      'canSideshow': v.canSideshow,
      'chaalCount': v.chaalCount,
      'maxChaals': v.maxChaals,
      'mustShowOrPack': v.mustShowOrPack,
      'canShow': v.canShow,
      'log': v.log,
      'winnerIds': v.winnerIds,
      'winnerBanner': v.winnerBanner,
      'sideshow': _sideshowToJson(v.sideshow),
      'sideshowTargets': [
        for (final t in v.sideshowTargets) {'id': t.id, 'name': t.name},
      ],
      'pendingSideshow': v.pendingSideshow == null
          ? null
          : {
              'requesterName': v.pendingSideshow!.requesterName,
              'targetName': v.pendingSideshow!.targetName,
              'youAreTarget': v.pendingSideshow!.youAreTarget,
              'youAreRequester': v.pendingSideshow!.youAreRequester,
            },
      'scoreLog': v.scoreLog,
      'standings': [
        for (final s in v.standings)
          {
            'name': s.name,
            'net': s.net,
            'won': s.won,
            'lost': s.lost,
            'roundsWon': s.roundsWon,
          },
      ],
      'sessionRounds': v.sessionRounds,
      'seats': v.seats.map(seatToJson).toList(),
    };

TableView tableViewFromJson(Map<String, dynamic> j) => TableView(
      phase: RoundPhase.values.firstWhere((p) => p.name == j['phase']),
      pot: j['pot'] as int,
      stake: j['stake'] as int,
      yourTurn: j['yourTurn'] as bool,
      youSeen: j['youSeen'] as bool,
      callCost: j['callCost'] as int,
      raiseCost: j['raiseCost'] as int,
      canRaise: j['canRaise'] as bool,
      twoLeft: j['twoLeft'] as bool,
      canSideshow: j['canSideshow'] as bool,
      chaalCount: (j['chaalCount'] as int?) ?? 0,
      maxChaals: (j['maxChaals'] as int?) ?? 25,
      mustShowOrPack: (j['mustShowOrPack'] as bool?) ?? false,
      canShow: (j['canShow'] as bool?) ?? false,
      log: (j['log'] as List).cast<String>(),
      winnerIds: (j['winnerIds'] as List).cast<String>(),
      winnerBanner: (j['winnerBanner'] as String?) ?? '',
      sideshow: _sideshowFromJson(j['sideshow']),
      sideshowTargets: [
        for (final e in (j['sideshowTargets'] as List? ?? const []))
          SideshowTargetView(
            id: (e as Map)['id'] as String,
            name: (e)['name'] as String,
          ),
      ],
      pendingSideshow: () {
        final p = j['pendingSideshow'];
        if (p == null) return null;
        final m = (p as Map).cast<String, dynamic>();
        return PendingSideshowView(
          requesterName: m['requesterName'] as String,
          targetName: m['targetName'] as String,
          youAreTarget: m['youAreTarget'] as bool,
          youAreRequester: m['youAreRequester'] as bool,
        );
      }(),
      scoreLog: (j['scoreLog'] as List?)?.cast<String>() ?? const [],
      standings: [
        for (final e in (j['standings'] as List? ?? const []))
          (
            name: (e as Map)['name'] as String,
            net: (e)['net'] as int,
            won: ((e)['won'] as int?) ?? 0,
            lost: ((e)['lost'] as int?) ?? 0,
            roundsWon: ((e)['roundsWon'] as int?) ?? 0,
          ),
      ],
      sessionRounds: (j['sessionRounds'] as int?) ?? 0,
      seats: (j['seats'] as List).map((e) {
        final s = (e as Map).cast<String, dynamic>();
        return SeatView(
          seat: s['seat'] as int,
          name: s['name'] as String,
          chips: s['chips'] as int,
          folded: s['folded'] as bool,
          seen: s['seen'] as bool,
          isYou: s['isYou'] as bool,
          isTurn: s['isTurn'] as bool,
          status: s['status'] as String,
          hand: (s['hand'] as List?)?.cast<String>(),
          exited: (s['exited'] as bool?) ?? false,
        );
      }).toList(),
    );
