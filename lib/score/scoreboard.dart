/// One line in the running online score log.
class ScoreEntry {
  ScoreEntry({
    required this.name,
    required this.delta,
    required this.balance,
    required this.note,
  });

  final String name;
  final int delta;
  final int balance;
  final String note;
}

/// Per-player totals across every round in a room session.
class PlayerSessionSummary {
  PlayerSessionSummary({
    required this.id,
    required this.name,
    required this.totalWon,
    required this.totalLost,
    required this.roundsWon,
  });

  final String id;
  final String name;
  final int totalWon;
  final int totalLost;
  final int roundsWon;

  int get net => totalWon - totalLost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalWon': totalWon,
        'totalLost': totalLost,
        'roundsWon': roundsWon,
      };

  factory PlayerSessionSummary.fromJson(Map<String, dynamic> j) =>
      PlayerSessionSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        totalWon: j['totalWon'] as int,
        totalLost: j['totalLost'] as int,
        roundsWon: j['roundsWon'] as int,
      );
}

/// Full session result shown when leaving or closing a room.
class SessionSummary {
  SessionSummary({
    required this.roundsPlayed,
    required this.players,
  });

  final int roundsPlayed;
  final List<PlayerSessionSummary> players;

  PlayerSessionSummary? get ultimateWinner {
    if (players.isEmpty) return null;
    return players.reduce(
      (a, b) => b.net > a.net
          ? b
          : (b.net == a.net && b.totalWon > a.totalWon ? b : a),
    );
  }

  Map<String, dynamic> toJson() => {
        'roundsPlayed': roundsPlayed,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        roundsPlayed: j['roundsPlayed'] as int,
        players: [
          for (final e in j['players'] as List)
            PlayerSessionSummary.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );

  factory SessionSummary.fromStandings(
    List<({String name, int net, int won, int lost, int roundsWon})> rows,
    int rounds,
  ) =>
      SessionSummary(
        roundsPlayed: rounds,
        players: [
          for (final r in rows)
            PlayerSessionSummary(
              id: r.name,
              name: r.name,
              totalWon: r.won,
              totalLost: r.lost,
              roundsWon: r.roundsWon,
            ),
        ],
      );
}

class _PlayerStats {
  _PlayerStats({required this.id, required this.name});

  final String id;
  String name;
  int totalWon = 0;
  int totalLost = 0;
  int roundsWon = 0;
}

/// Tracks chip profit/loss per player across rounds (online/LAN sessions).
///
/// Each round starts everyone at [roundStartChips]; deltas accumulate here.
class SessionScoreboard {
  SessionScoreboard();

  final Map<String, _PlayerStats> _stats = {};
  final List<ScoreEntry> log = [];
  int roundsPlayed = 0;

  void registerPlayers(List<({String id, String name})> players) {
    for (final p in players) {
      final s = _stats.putIfAbsent(p.id, () => _PlayerStats(id: p.id, name: p.name));
      s.name = p.name;
    }
  }

  void recordRound({
    required int roundStartChips,
    required List<String> winnerIds,
    required int pot,
    required List<({String id, String name, int chips})> seats,
    String? handNote,
  }) {
    for (final p in seats) {
      final s = _stats.putIfAbsent(p.id, () => _PlayerStats(id: p.id, name: p.name));
      s.name = p.name;
      final delta = p.chips - roundStartChips;
      if (delta > 0) {
        s.totalWon += delta;
        if (winnerIds.contains(p.id)) s.roundsWon++;
      } else if (delta < 0) {
        s.totalLost += -delta;
      }
    }

    final share = winnerIds.isEmpty ? 0 : pot ~/ winnerIds.length;
    for (final w in winnerIds) {
      final name = seats.firstWhere((s) => s.id == w).name;
      final bal = seats.firstWhere((s) => s.id == w).chips;
      log.insert(
        0,
        ScoreEntry(
          name: name,
          delta: share,
          balance: bal,
          note: handNote == null ? 'Won $share' : 'Won $share · $handNote',
        ),
      );
    }
    roundsPlayed++;
  }

  /// Net profit/loss across all rounds for each player.
  List<({String name, int net, int won, int lost, int roundsWon})> standings(
      List<({String id, String name, int chips})> seats) {
    return [
      for (final p in seats)
        () {
          final s = _stats[p.id];
          final won = s?.totalWon ?? 0;
          final lost = s?.totalLost ?? 0;
          return (
            name: p.name,
            net: won - lost,
            won: won,
            lost: lost,
            roundsWon: s?.roundsWon ?? 0,
          );
        }(),
    ];
  }

  SessionSummary buildSummary(List<({String id, String name})> seats) {
    final rows = <PlayerSessionSummary>[];
    for (final p in seats) {
      final s = _stats[p.id];
      if (s == null) continue;
      rows.add(PlayerSessionSummary(
        id: s.id,
        name: s.name,
        totalWon: s.totalWon,
        totalLost: s.totalLost,
        roundsWon: s.roundsWon,
      ));
    }
    rows.sort((a, b) {
      final byNet = b.net.compareTo(a.net);
      if (byNet != 0) return byNet;
      return b.totalWon.compareTo(a.totalWon);
    });
    return SessionSummary(roundsPlayed: roundsPlayed, players: rows);
  }

  void clear() {
    _stats.clear();
    log.clear();
    roundsPlayed = 0;
  }
}
