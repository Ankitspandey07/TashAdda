import 'package:flutter/material.dart';

import '../net/bluff_network_client.dart';
import '../net/lan_discovery.dart';
import '../net/network_client.dart';
import 'net_bluff_screen.dart';
import 'table_rules_config.dart';
import 'table_screen.dart';

/// Client flow: listen on UDP 7777, list discovered rooms, then connect over TCP.
class SearchRoomsScreen extends StatefulWidget {
  const SearchRoomsScreen({super.key});

  @override
  State<SearchRoomsScreen> createState() => _SearchRoomsScreenState();
}

class _SearchRoomsScreenState extends State<SearchRoomsScreen> {
  final _nameCtrl = TextEditingController(text: 'Player');
  final RoomScanner _scanner = RoomScanner();
  List<RoomInfo> _rooms = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      await _scanner.start();
      _scanner.rooms.listen((rooms) {
        if (mounted) setState(() => _rooms = rooms);
      });
    } catch (e) {
      setState(() => _error = 'Could not listen for rooms: $e');
    }
  }

  void _join(RoomInfo room) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ClientWaitScreen(
        room: room,
        name: _nameCtrl.text.trim().isEmpty ? 'Player' : _nameCtrl.text.trim(),
      ),
    ));
  }

  @override
  void dispose() {
    _scanner.stop();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Local Rooms')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Scanning UDP port 7777… (${_rooms.length} found)',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _rooms.isEmpty
                  ? const Center(
                      child: Text(
                          'No rooms yet.\nMake sure the host is on the same Wi-Fi/hotspot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54)))
                  : ListView(
                      children: [
                        for (final room in _rooms)
                          Card(
                            color: Colors.white10,
                            child: ListTile(
                              leading: Icon(
                                  room.isBluff
                                      ? Icons.theater_comedy
                                      : Icons.casino,
                                  color: Colors.amber),
                              title: Text(room.roomName),
                              subtitle: Text(
                                  '${room.gameTitle} · ${room.players}/${room.maxPlayers} players · ${room.hostIp}'),
                              trailing: ElevatedButton(
                                onPressed: () => _join(room),
                                child: const Text('Join'),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connects to the chosen room and waits in the lobby until the host starts.
class _ClientWaitScreen extends StatefulWidget {
  const _ClientWaitScreen({required this.room, required this.name});

  final RoomInfo room;
  final String name;

  @override
  State<_ClientWaitScreen> createState() => _ClientWaitScreenState();
}

class _ClientWaitScreenState extends State<_ClientWaitScreen> {
  NetworkClient? _client;
  BluffNetworkClient? _bluffClient;
  String _status = 'Connecting…';
  bool _navigated = false;

  bool get _isBluff => widget.room.isBluff;
  Listenable get _listenable => (_client ?? _bluffClient)!;
  List<String> get _lobby =>
      _client?.lobbyPlayers ?? _bluffClient?.lobbyPlayers ?? const [];

  @override
  void initState() {
    super.initState();
    if (_isBluff) {
      _bluffClient = BluffNetworkClient(
        hostIp: widget.room.hostIp,
        tcpPort: widget.room.tcpPort,
        name: widget.name,
      )
        ..onGameStart = _goToGame
        ..onClosed = _onClosed;
    } else {
      _client = NetworkClient(
        hostIp: widget.room.hostIp,
        tcpPort: widget.room.tcpPort,
        name: widget.name,
      )
        ..onGameStart = _goToGame
        ..onClosed = _onClosed;
    }
    _connect();
  }

  Future<void> _connect() async {
    try {
      if (_bluffClient != null) {
        await _bluffClient!.connect();
      } else {
        await _client!.connect();
      }
      setState(() => _status = 'Joined. Waiting for host to start…');
    } catch (e) {
      setState(() => _status = 'Could not connect: $e');
    }
  }

  void _goToGame() {
    if (_navigated || !mounted) return;
    _navigated = true;
    void leave() => Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _bluffClient != null
          ? NetBluffScreen(client: _bluffClient!, onLeave: leave)
          : TableScreen(controller: _client!, chat: _client!.chat, onLeave: leave),
    ));
  }

  void _onClosed(String reason) {
    if (!mounted || _navigated) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(reason)));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!_navigated) {
      _client?.close();
      _bluffClient?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.roomName)),
      body: Center(
        child: AnimatedBuilder(
          animation: _listenable,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Colors.white70)),
              if (_client?.roomBoot != null && _client?.roomStartChips != null)
                TableRulesBanner(
                  boot: _client!.roomBoot!,
                  startChips: _client!.roomStartChips!,
                ),
              const SizedBox(height: 16),
              for (final p in _lobby)
                Text(p, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
