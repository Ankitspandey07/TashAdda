import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/material.dart';

import '../engine/bluff_engine.dart';
import '../engine/game_engine.dart';
import '../games/catalog.dart';
import '../table/local_controller.dart';
import 'bluff_screen.dart';
import 'table_rules_config.dart';
import 'table_screen.dart';

/// Configure and start a single-device game: you plus 2–4 bots.
class LocalPlayScreen extends StatefulWidget {
  const LocalPlayScreen({super.key});

  @override
  State<LocalPlayScreen> createState() => _LocalPlayScreenState();
}

class _LocalPlayScreenState extends State<LocalPlayScreen> {
  GameEntry _game = kGameCatalog.first;
  int _bots = 3;
  int _chips = 1000;
  int _boot = 10;

  void _startBluff() {
    final engine = BluffEngine();
    engine.addPlayer(BluffPlayer(id: 'you', name: 'You'));
    for (var i = 0; i < _bots; i++) {
      engine.addPlayer(
          BluffPlayer(id: 'bot$i', name: 'Bot ${i + 1}', isBot: true));
    }
    engine.startGame();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BluffGameScreen(engine: engine),
    ));
  }

  void _start() {
    if (_game.isBluff) {
      _startBluff();
      return;
    }
    final engine = GameEngine(
        boot: _boot, startChips: _chips, game: _game.game);
    engine.addSeat(Seat(
      player: Player(id: 'you', name: 'You', seat: 0, chips: _chips),
    ));
    for (var i = 0; i < _bots; i++) {
      engine.addSeat(Seat(
        player: Player(
            id: 'bot$i', name: 'Bot ${i + 1}', seat: i + 1, chips: _chips),
        isBot: true,
      ));
    }
    engine.startRound();
    final controller = LocalController(engine,
        viewerSeatId: 'you', title: '${_game.title} · vs Bots');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TableScreen(
        controller: controller,
        closeGameOnExit: true,
        onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totalPlayers = _bots + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Play vs Bots')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a game',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            GamePicker(
              selected: _game,
              onSelect: (g) => setState(() => _game = g),
            ),
            const Divider(height: 28),
            _stepper('Number of bots (table: $totalPlayers players)', _bots,
                min: 2, max: 4, onChanged: (v) => setState(() => _bots = v)),
            if (!_game.isBluff)
              TableRulesSteppers(
                boot: _boot,
                startChips: _chips,
                onBootChanged: (v) => setState(() => _boot = v),
                onStartChipsChanged: (v) => setState(() => _chips = v),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: Text('Deal · ${_game.title}'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(String label, int value,
      {required int min,
      required int max,
      int step = 1,
      required ValueChanged<int> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: value > min ? () => onChanged(value - step) : null,
          ),
          SizedBox(
              width: 56,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: value < max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

/// Horizontal selector of catalog games. Playable games are selectable;
/// placeholders show a "Soon" badge.
class GamePicker extends StatelessWidget {
  const GamePicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.entries,
  });

  final GameEntry selected;
  final ValueChanged<GameEntry> onSelect;

  /// Optional subset of the catalog to show (e.g. hand-ranking games only for
  /// network modes). Defaults to the full catalog.
  final List<GameEntry>? entries;

  @override
  Widget build(BuildContext context) {
    final list = entries ?? kGameCatalog;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final g = list[i];
          final isSel = g.title == selected.title;
          return GestureDetector(
            onTap: g.playable
                ? () => onSelect(g)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${g.title} is coming soon.')),
                    ),
            child: Opacity(
              opacity: g.playable ? 1 : 0.5,
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF2E7D32) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isSel ? const Color(0xFFFFD54F) : Colors.white24,
                      width: isSel ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(g.icon, color: Colors.white, size: 20),
                        const Spacer(),
                        if (!g.playable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Soon',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 9)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(g.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(g.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
