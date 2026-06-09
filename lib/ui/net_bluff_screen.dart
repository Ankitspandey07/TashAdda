import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../engine/bluff_engine.dart' show BluffEngine, bluffRankName;
import '../net/bluff_client.dart';
import '../net/bluff_view.dart';
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

/// Renders a remote Bluff player's [BluffView] (driven by [BluffPollingClient]).
class NetBluffScreen extends StatefulWidget {
  const NetBluffScreen({super.key, required this.client, this.onLeave});
  final BluffClient client;
  final VoidCallback? onLeave;

  @override
  State<NetBluffScreen> createState() => _NetBluffScreenState();
}

class _NetBluffScreenState extends State<NetBluffScreen> {
  final Set<String> _selected = {};
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  bool _celebrated = false;

  BluffClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    if (widget.client.chat != null) {
      Future.delayed(const Duration(milliseconds: 600),
          () => widget.client.chat?.shareAvatar());
    }
  }

  void _onChange() {
    final v = c.view;
    if (!(v.yourTurn) && _selected.isNotEmpty) _selected.clear();
    // Drop selections no longer in hand.
    _selected.removeWhere((code) => !v.yourHand.contains(code));
    if (v.phase == 'roundOver' && v.youWon && !_celebrated) {
      _celebrated = true;
      _confetti.play();
    } else if (v.phase != 'roundOver') {
      _celebrated = false;
    }
    if (mounted) setState(() {});
  }

  void _toggle(String code) {
    setState(() {
      if (_selected.contains(code)) {
        _selected.remove(code);
      } else if (_selected.length < BluffEngine.maxPlayCards) {
        _selected.add(code);
      }
    });
  }

  void _play() {
    final cards = _selected.toList();
    _selected.clear();
    c.play(cards);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = c.view;
    return Scaffold(
      backgroundColor: const Color(0xFF0B142E),
      appBar: AppBar(
        title: const Text('Bluff · Online'),
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
        chat: widget.client.chat,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _opponents(v),
                  Expanded(child: _center(v)),
                  _logLine(v),
                  _bottom(v),
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

  Widget _opponents(BluffView v) {
    final opp = [for (final s in v.seats) if (!s.isYou) s];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: const Color(0xFF0E1B3A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [for (final s in opp) _opponent(s)],
      ),
    );
  }

  Widget _opponent(BluffSeatView s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            for (var k = 0; k < s.handCount.clamp(0, 4); k++)
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
              s.isTurn ? const Color(0xFFFFD54F) : const Color(0xFF2E3A59),
          child: Icon(Icons.person,
              size: 16, color: s.isTurn ? Colors.black : Colors.white),
        ),
        Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 11)),
        Text('${s.handCount} cards',
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _center(BluffView v) {
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
            child: Text('Claim rank:  ${_rankShort(v.requiredRank)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              for (var k = 0; k < v.pileCount.clamp(0, 6); k++)
                Transform.rotate(
                  angle: (k - 3) * 0.18,
                  child: const CardWidget(width: 44),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Pile: ${v.pileCount} cards',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (v.lastClaim != null && v.phase == 'callWindow')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC9A24B)),
              ),
              child: Text(
                '${v.lastClaim!.playerName} claims '
                '${v.lastClaim!.count} × ${bluffRankName(v.lastClaim!.rankValue)}',
                style: const TextStyle(
                    color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
              ),
            ),
          if (v.phase == 'roundOver' && v.winnerName != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                v.youWon ? 'You win! 🎉' : '${v.winnerName} wins',
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logLine(BluffView v) => Container(
        height: 34,
        width: double.infinity,
        alignment: Alignment.center,
        color: Colors.black.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(v.log.isEmpty ? '' : v.log.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );

  Widget _bottom(BluffView v) {
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
              children: [for (final code in v.yourHand) _handCard(code)],
            ),
          ),
          const SizedBox(height: 8),
          _actions(v),
        ],
      ),
    );
  }

  Widget _handCard(String code) {
    final selected = _selected.contains(code);
    return GestureDetector(
      onTap: () => _toggle(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFFFFD54F) : Colors.transparent,
            width: 2,
          ),
        ),
        child: CardWidget(code: code, width: 50),
      ),
    );
  }

  Widget _actions(BluffView v) {
    if (v.phase == 'roundOver') {
      return const Text('Game over',
          style: TextStyle(color: Colors.white70));
    }
    if (v.youMayCall) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: c.callBluff,
            icon: const Icon(Icons.front_hand),
            label: const Text('Call Bluff!'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: c.pass,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Pass'),
          ),
        ],
      );
    }
    if (v.yourTurn) {
      final n = _selected.length;
      return ElevatedButton(
        onPressed: n >= 1 && n <= BluffEngine.maxPlayCards ? _play : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
        child: Text(n == 0
            ? 'Select 1–4 cards to claim ${_rankShort(v.requiredRank)}'
            : 'Play $n as ${bluffRankName(v.requiredRank)}'),
      );
    }
    return const Text('Waiting for other players…',
        style: TextStyle(color: Colors.white60));
  }
}
