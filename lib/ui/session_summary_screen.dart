import 'dart:typed_data';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../profile/profile_store.dart';
import '../score/scoreboard.dart';
import 'profile_widget.dart';

/// Session totals shown when a player leaves or the host closes the room.
class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.summary,
    this.celebrate = false,
  });

  final SessionSummary summary;
  final bool celebrate;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.celebrate && widget.summary.roundsPlayed > 0) {
      Sfx.instance.win();
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    RemoteAvatars.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.summary.ultimateWinner;
    final celebrate = widget.celebrate && winner != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B142E),
      appBar: AppBar(
        title: const Text('Session results'),
        backgroundColor: const Color(0xFF0B142E),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (celebrate) ...[
                    Text(
                      '🎉 Ultimate winner 🎉',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      winner.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '+${winner.net} chips · ${winner.roundsWon} round${winner.roundsWon == 1 ? '' : 's'} won',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    '${widget.summary.roundsPlayed} round${widget.summary.roundsPlayed == 1 ? '' : 's'} played',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Card(
                        color: Colors.white10,
                        child: Column(
                          children: [
                            const ListTile(
                              title: Text(
                                'Player',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                'Won / Lost / Net',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            for (final p in widget.summary.players)
                              ListTile(
                                leading: _Avatar(name: p.name),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${p.roundsWon} round${p.roundsWon == 1 ? '' : 's'} won',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: Text(
                                  '+${p.totalWon} / -${p.totalLost} / ${p.net >= 0 ? '+' : ''}${p.net}',
                                  style: TextStyle(
                                    color: p.net >= 0
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFFE57373),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
          if (celebrate)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                gravity: 0.15,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Uint8List>>(
      valueListenable: RemoteAvatars.byName,
      builder: (context, map, _) {
        final bytes = map[name];
        if (bytes != null) {
          return CircleAvatar(
            backgroundColor: const Color(0xFF3A66C4),
            backgroundImage: MemoryImage(bytes),
          );
        }
        return const ProfileAvatar(radius: 20);
      },
    );
  }
}
