import '../engine/bluff_engine.dart';

/// One seat as seen by a remote Bluff player. Opponent hands are never sent —
/// only their counts — so the relay/clients can't peek at cards.
class BluffSeatView {
  const BluffSeatView({
    required this.name,
    required this.handCount,
    required this.isYou,
    required this.isTurn,
  });
  final String name;
  final int handCount;
  final bool isYou;
  final bool isTurn;
}

class BluffClaimView {
  const BluffClaimView({
    required this.playerName,
    required this.count,
    required this.rankValue,
  });
  final String playerName;
  final int count;
  final int rankValue;
}

/// Redacted snapshot of a Bluff game for one viewer.
class BluffView {
  const BluffView({
    required this.seats,
    required this.yourHand,
    required this.requiredRank,
    required this.pileCount,
    required this.phase,
    required this.yourTurn,
    required this.youMayCall,
    required this.log,
    this.lastClaim,
    this.winnerName,
    this.youWon = false,
  });

  final List<BluffSeatView> seats;
  final List<String> yourHand; // card codes for the viewer only
  final int requiredRank;
  final int pileCount;
  final String phase; // BluffPhase.name
  final bool yourTurn;
  final bool youMayCall;
  final List<String> log;
  final BluffClaimView? lastClaim;
  final String? winnerName;
  final bool youWon;

  static const empty = BluffView(
    seats: [],
    yourHand: [],
    requiredRank: 14,
    pileCount: 0,
    phase: 'play',
    yourTurn: false,
    youMayCall: false,
    log: [],
  );
}

/// Builds the redacted view that the viewer at [viewerIndex] is allowed to see.
BluffView buildBluffView(BluffEngine e, int viewerIndex) {
  final claim = e.lastClaim;
  final me = e.players[viewerIndex];
  return BluffView(
    seats: [
      for (var i = 0; i < e.players.length; i++)
        BluffSeatView(
          name: e.players[i].name,
          handCount: e.players[i].hand.length,
          isYou: i == viewerIndex,
          isTurn: e.turn == i && e.phase != BluffPhase.roundOver,
        ),
    ],
    yourHand: me.hand.map((c) => c.code).toList(),
    requiredRank: e.requiredRank,
    pileCount: e.pile.length,
    phase: e.phase.name,
    yourTurn: e.phase == BluffPhase.play && e.turn == viewerIndex,
    youMayCall: e.mayCall(viewerIndex),
    log: e.log.take(8).toList(),
    lastClaim: claim == null
        ? null
        : BluffClaimView(
            playerName: e.players[claim.playerIndex].name,
            count: claim.count,
            rankValue: claim.rankValue,
          ),
    winnerName: e.winnerId == null
        ? null
        : e.players.firstWhere((p) => p.id == e.winnerId).name,
    youWon: e.winnerId != null && e.winnerId == me.id,
  );
}

Map<String, dynamic> bluffViewToJson(BluffView v) => {
      't': 'bluffView',
      'requiredRank': v.requiredRank,
      'pileCount': v.pileCount,
      'phase': v.phase,
      'yourTurn': v.yourTurn,
      'youMayCall': v.youMayCall,
      'yourHand': v.yourHand,
      'log': v.log,
      'winnerName': v.winnerName,
      'youWon': v.youWon,
      'lastClaim': v.lastClaim == null
          ? null
          : {
              'playerName': v.lastClaim!.playerName,
              'count': v.lastClaim!.count,
              'rankValue': v.lastClaim!.rankValue,
            },
      'seats': [
        for (final s in v.seats)
          {
            'name': s.name,
            'handCount': s.handCount,
            'isYou': s.isYou,
            'isTurn': s.isTurn,
          }
      ],
    };

BluffView bluffViewFromJson(Map<String, dynamic> j) {
  final claim = (j['lastClaim'] as Map?)?.cast<String, dynamic>();
  return BluffView(
    requiredRank: j['requiredRank'] as int,
    pileCount: j['pileCount'] as int,
    phase: j['phase'] as String,
    yourTurn: j['yourTurn'] as bool,
    youMayCall: j['youMayCall'] as bool,
    yourHand: (j['yourHand'] as List).cast<String>(),
    log: (j['log'] as List).cast<String>(),
    winnerName: j['winnerName'] as String?,
    youWon: (j['youWon'] as bool?) ?? false,
    lastClaim: claim == null
        ? null
        : BluffClaimView(
            playerName: claim['playerName'] as String,
            count: claim['count'] as int,
            rankValue: claim['rankValue'] as int,
          ),
    seats: (j['seats'] as List).map((e) {
      final s = (e as Map).cast<String, dynamic>();
      return BluffSeatView(
        name: s['name'] as String,
        handCount: s['handCount'] as int,
        isYou: s['isYou'] as bool,
        isTurn: s['isTurn'] as bool,
      );
    }).toList(),
  );
}
