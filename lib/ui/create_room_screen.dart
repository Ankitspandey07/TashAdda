import 'package:flutter/material.dart';

import '../games/catalog.dart';
import '../net/bluff_network_host.dart';
import '../net/network_host.dart';
import 'bluff_screen.dart' show BluffGameScreen;
import 'local_play_screen.dart' show GamePicker;
import 'table_rules_config.dart';
import 'table_screen.dart';

/// Host flow: enter a room name, broadcast it over UDP, wait for players in the
/// lobby, then start the game.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _roomCtrl = TextEditingController(text: 'My Table');
  final _nameCtrl = TextEditingController(text: 'Host');
  GameEntry _game = kGameCatalog.first;
  int _boot = 10;
  int _startChips = 1000;
  NetworkHost? _host;
  BluffNetworkHost? _bluffHost;
  String? _error;

  bool get _started => _host != null || _bluffHost != null;
  String get _roomName => _host?.roomName ?? _bluffHost?.roomName ?? '';
  String? get _ip => _host?.localIp ?? _bluffHost?.localIp;
  int get _port => _host?.tcpPort ?? _bluffHost?.tcpPort ?? 0;
  List<String> get _names =>
      _host?.lobbyNames ?? _bluffHost?.lobbyNames ?? const [];
  Listenable get _listenable => (_host ?? _bluffHost)!;

  Future<void> _create() async {
    final room =
        _roomCtrl.text.trim().isEmpty ? 'Table' : _roomCtrl.text.trim();
    final host = _nameCtrl.text.trim().isEmpty ? 'Host' : _nameCtrl.text.trim();
    try {
      if (_game.isBluff) {
        final h = BluffNetworkHost(roomName: room, hostName: host);
        await h.start();
        setState(() => _bluffHost = h);
      } else {
        final h = NetworkHost(
          roomName: room,
          hostName: host,
          game: _game.game,
          boot: _boot,
          startChips: _startChips,
        );
        await h.start();
        setState(() => _host = h);
      }
    } catch (e) {
      setState(() => _error = 'Could not start host: $e');
    }
  }

  void _startGame() {
    if (_bluffHost != null) {
      _bluffHost!.startGame();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BluffGameScreen(
          engine: _bluffHost!.engine,
          chat: _bluffHost!.chat,
          onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ));
      return;
    }
    final host = _host!;
    host.startGame();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TableScreen(
        controller: host.hostController!,
        chat: host.chat,
        onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ));
  }

  @override
  void dispose() {
    _host?.shutdown();
    _bluffHost?.shutdown();
    _roomCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Local Room')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: !_started ? _setupForm() : _lobby(),
      ),
    );
  }

  Widget _setupForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCtrl,
            decoration: const InputDecoration(labelText: 'Room name'),
          ),
          const SizedBox(height: 16),
          const Text('Game', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          GamePicker(
              selected: _game,
              entries: kOnlineGames,
              onSelect: (g) => setState(() => _game = g)),
          if (!_game.isBluff) ...[
            const SizedBox(height: 12),
            TableRulesSteppers(
              boot: _boot,
              startChips: _startChips,
              onBootChanged: (v) => setState(() => _boot = v),
              onStartChipsChanged: (v) => setState(() => _startChips = v),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Everyone must be on the same Wi-Fi or mobile hotspot. The room is '
            'broadcast on UDP port 7777.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Create & broadcast'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      );

  Widget _lobby() {
    return AnimatedBuilder(
      animation: _listenable,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white10,
              child: ListTile(
                leading: const Icon(Icons.wifi_tethering, color: Colors.green),
                title: Text(_roomName),
                subtitle: Text(
                  _host != null
                      ? 'Broadcasting · $_ip:$_port\nUDP discovery on port 7777\n${_host!.boot} boot · ${_host!.startChips} chips/round'
                      : 'Broadcasting · $_ip:$_port\nUDP discovery on port 7777',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Players in lobby',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final name in _names)
                    Card(
                      color: Colors.white10,
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.amber),
                        title: Text(name),
                      ),
                    ),
                ],
              ),
            ),
            const Text(
              'Empty seats are filled with bots (min 3 players) when you start.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start game'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                _host?.closeRoom();
                _bluffHost?.shutdown();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              icon: const Icon(Icons.close),
              label: const Text('Close room'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
