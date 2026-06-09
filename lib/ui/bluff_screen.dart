import 'package:card_game_platform/card_game_platform.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../engine/bluff_engine.dart';
import '../net/table_chat.dart';
import 'card_widget.dart';
import 'emoji_chat.dart';
import 'exit_confirm.dart';

String _rankShort(int v) {
  switch (v) {
    case 14:
      return 'A';
    case 13:
      return 'K';
    case 12:
      return 'Q';
    case 11:
      return 'J';
    case 10:
      return '10';
    default:
      return '$v';
  }
}

/// Configure a single-device Bluff game (you + 2–4 bots).
class BluffSetupScreen extends StatefulWidget {
  const BluffSetupScreen({super.key});

  @override
  State<BluffSetupScreen> createState() => _BluffSetupScreenState();
}

class _BluffSetupScreenState extends State<BluffSetupScreen> {
  int _bots = 3;

  void _start() {
    final engine = BluffEngine();
    engine.addPlayer(BluffPlayer(id: 'you', name: 'You'));
    for (var i = 0; i < _bots; i++) {
      engine.addPlayer(
          BluffPlayer(id: 'bot$i', name: 'Bot ${i + 1}', isBot: true));
    }
    engine.startGame();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BluffGameScreen(engine: engine),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluff (Cheat)')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get rid of all your cards first. On your turn play 1–4 cards face '
              'down and claim the required rank — you can lie! Others may call '
              '"Bluff". Whoever is wrong picks up the pile.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                    child: Text('Number of bots',
                        style: TextStyle(color: Colors.white))),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.white),
                  onPressed: _bots > 2 ? () => setState(() => _bots--) : null,
                ),
                Text('$_bots',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon:
                      const Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: _bots < 4 ? () => setState(() => _bots++) : null,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Deal'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF6A1B9A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BluffGameScreen extends StatefulWidget {
  const BluffGameScreen(
      {super.key, required this.engine, this.chat, this.onLeave});
  final BluffEngine engine;
  final TableChat? chat;
  final VoidCallback? onLeave;

  @override
  State<BluffGameScreen> createState() => _BluffGameScreenState();
}

class _BluffGameScreenState extends State<BluffGameScreen> {
  final Set<PlayingCard> _selected = {};
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  bool _celebrated = false;

  BluffEngine get e => widget.engine;

  @override
  void initState() {
    super.initState();
    e.addListener(_onChange);
    if (widget.chat != null) {
      Future.delayed(const Duration(milliseconds: 600),
          () => widget.chat?.shareAvatar());
    }
  }

  void _onChange() {
    // Clear selection whenever it is no longer the human's play turn.
    final myPlay = e.phase == BluffPhase.play && e.turn == e.humanIndex;
    if (!myPlay && _selected.isNotEmpty) _selected.clear();
    if (e.phase == BluffPhase.roundOver && e.winnerId == 'you' && !_celebrated) {
      _celebrated = true;
      _confetti.play();
    } else if (e.phase != BluffPhase.roundOver) {
      _celebrated = false;
    }
    if (mounted) setState(() {});
  }

  void _toggle(PlayingCard card) {
    setState(() {
      if (_selected.contains(card)) {
        _selected.remove(card);
      } else if (_selected.length < BluffEngine.maxPlayCards) {
        _selected.add(card);
      }
    });
  }

  void _play() {
    final cards = List<PlayingCard>.from(_selected);
    _selected.clear();
    e.play(cards);
  }

  @override
  void dispose() {
    e.removeListener(_onChange);
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B142E),
      appBar: AppBar(
        title: const Text('Bluff (Cheat)'),
        backgroundColor: const Color(0xFF0B142E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (widget.onLeave != null) {
                if (await confirmExit(context)) widget.onLeave!();
              } else {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
      body: ChatOverlay(
        chat: widget.chat,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _opponents(),
                  Expanded(child: _center()),
                  _logLine(),
                  _bottom(),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 24,
                  gravity: 0.25,
                  colors: const [
                    Color(0xFFFFD54F),
                    Color(0xFF2E7D32),
                    Color(0xFF1565C0),
                    Color(0xFFC62828),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opponents() {
    final opp = [
      for (var i = 0; i < e.players.length; i++)
        if (i != e.humanIndex) i
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: const Color(0xFF0E1B3A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final i in opp) _opponent(i),
        ],
      ),
    );
  }

  Widget _opponent(int i) {
    final p = e.players[i];
    final isTurn = e.turn == i && e.phase != BluffPhase.roundOver;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            for (var k = 0; k < (p.hand.length.clamp(0, 4)); k++)
              Padding(
                padding: EdgeInsets.only(left: k * 8.0),
                child: const CardWidget(width: 20),
              ),
          ],
        ),
        const SizedBox(height: 2),
        CircleAvatar(
          radius: 16,
          backgroundColor:
              isTurn ? const Color(0xFFFFD54F) : const Color(0xFF2E3A59),
          child: Icon(Icons.person,
              size: 16, color: isTurn ? Colors.black : Colors.white),
        ),
        Text(p.name,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
        Text('${p.hand.length} cards',
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _center() {
    final claim = e.lastClaim;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Claim rank:  ${_rankShort(e.requiredRank)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              for (var k = 0; k < (e.pile.length.clamp(0, 6)); k++)
                Transform.rotate(
                  angle: (k - 3) * 0.18,
                  child: const CardWidget(width: 44),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Pile: ${e.pile.length} cards',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (claim != null && e.phase == BluffPhase.callWindow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC9A24B)),
              ),
              child: Text(
                '${e.players[claim.playerIndex].name} claims '
                '${claim.count} × ${bluffRankName(claim.rankValue)}',
                style: const TextStyle(
                    color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logLine() => Container(
        height: 34,
        width: double.infinity,
        alignment: Alignment.center,
        color: Colors.black.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(e.log.isEmpty ? '' : e.log.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );

  Widget _bottom() {
    final human = e.players[e.humanIndex];
    return Container(
      color: const Color(0xFF0E1B3A),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final card in human.hand) _handCard(card),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _actions(),
        ],
      ),
    );
  }

  Widget _handCard(PlayingCard card) {
    final selected = _selected.contains(card);
    final canSelect =
        e.phase == BluffPhase.play && e.turn == e.humanIndex;
    return GestureDetector(
      onTap: canSelect ? () => _toggle(card) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Opacity(
          opacity: canSelect ? 1 : 0.85,
          child: Stack(
            children: [
              CardWidget(code: card.code, width: 44),
              if (selected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: const Color(0xFFFFD54F), width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    if (e.phase == BluffPhase.roundOver) {
      final winner = e.players.firstWhere((p) => p.id == e.winnerId,
          orElse: () => e.players.first);
      final youWon = e.winnerId == 'you';
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(youWon ? 'You win! 🎉' : '${winner.name} wins',
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () => e.startGame(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Play again'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A)),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Leave'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (e.humanMayCall) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: e.callBluff,
                icon: const Icon(Icons.gavel),
                label: const Text('Call Bluff!'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: e.pass,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Pass'),
              ),
            ),
          ],
        ),
      );
    }

    if (e.phase == BluffPhase.play && e.turn == e.humanIndex) {
      final n = _selected.length;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Text('Select 1–4 cards to claim as ${bluffRankName(e.requiredRank)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: n >= 1 && n <= BluffEngine.maxPlayCards ? _play : null,
                icon: const Icon(Icons.upload),
                label: Text(n == 0
                    ? 'Select cards'
                    : 'Play $n as ${_rankShort(e.requiredRank)}'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text('Waiting for other players…',
          style: TextStyle(color: Colors.white70)),
    );
  }
}
