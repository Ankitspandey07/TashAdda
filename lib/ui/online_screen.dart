import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/catalog.dart';
import '../net/bluff_polling_client.dart';
import '../net/bluff_polling_host.dart';
import '../net/polling_client.dart';
import '../net/polling_host.dart';
import '../net/relay_client.dart';
import 'bluff_screen.dart' show BluffGameScreen;
import 'local_play_screen.dart' show GamePicker;
import 'net_bluff_screen.dart';
import 'table_rules_config.dart';
import 'table_screen.dart';

/// Production relay — baked in at build time so players only need a room code.
const String kOnlineServerUrl = 'https://tashadda.vercel.app';

/// Entry point for internet play: create a room (get a code to share) or join
/// a friend's room by code. Server URL is fixed; no setup required.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final _nameCtrl = TextEditingController(text: 'Player');
  final _codeCtrl = TextEditingController();
  GameEntry _game = kGameCatalog.first;
  int _boot = 10;
  int _startChips = 1000;

  String get _name =>
      _nameCtrl.text.trim().isEmpty ? 'Player' : _nameCtrl.text.trim();

  void _create() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _game.isBluff
          ? BluffOnlineLobbyScreen(serverUrl: kOnlineServerUrl, name: _name)
          : OnlineLobbyScreen(
              serverUrl: kOnlineServerUrl,
              name: _name,
              game: _game,
              boot: _boot,
              startChips: _startChips,
            ),
    ));
  }

  void _join() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnlineWaitScreen(
        serverUrl: kOnlineServerUrl,
        roomCode: code,
        name: _name,
      ),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play Online')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Play with friends anywhere — just share the 6-letter room code.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Text('Host a room',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Create room & get code'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF6A1B9A)),
            ),
            const Divider(height: 36),
            const Text('Join a friend',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseFormatter(),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Room code',
                hintText: 'ABC123',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _join,
              icon: const Icon(Icons.login),
              label: const Text('Join room'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1565C0)),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Host lobby: shows the shareable room code and joined players, then starts.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({
    super.key,
    required this.serverUrl,
    required this.name,
    required this.game,
    this.boot = 10,
    this.startChips = 1000,
  });

  final String serverUrl;
  final String name;
  final GameEntry game;
  final int boot;
  final int startChips;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  late final PollingHost _host;

  @override
  void initState() {
    super.initState();
    _host = PollingHost(
      serverUrl: widget.serverUrl,
      hostName: widget.name,
      game: widget.game.game!,
      boot: widget.boot,
      startChips: widget.startChips,
    );
    _host.start();
  }

  void _start() {
    _host.startGame();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TableScreen(
        controller: _host.hostController!,
        chat: _host.chat,
        onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ));
  }

  @override
  void dispose() {
    _host.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.title} · Host')),
      body: AnimatedBuilder(
        animation: _host,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white10,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Text('ROOM CODE',
                            style: TextStyle(
                                color: Colors.white54, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        SelectableText(
                          _host.roomCode ?? '······',
                          style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6),
                        ),
                        const SizedBox(height: 4),
                        Text(_host.status,
                            style: const TextStyle(color: Colors.white60)),
                        TableRulesBanner(
                          boot: widget.boot,
                          startChips: widget.startChips,
                        ),
                        if (_host.roomCode != null)
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _host.roomCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy code'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Players',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final name in _host.lobbyNames)
                        Card(
                          color: Colors.white10,
                          child: ListTile(
                            leading: const Icon(Icons.person,
                                color: Colors.amber),
                            title: Text(name),
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Empty seats are filled with bots (min 3) when you start.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _host.roomCode == null ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start game'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _host.closeRoom();
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
            ),
          );
        },
      ),
    );
  }
}

/// Client wait screen: connects, joins by code, then opens the table.
class OnlineWaitScreen extends StatefulWidget {
  const OnlineWaitScreen({
    super.key,
    required this.serverUrl,
    required this.roomCode,
    required this.name,
  });

  final String serverUrl;
  final String roomCode;
  final String name;

  @override
  State<OnlineWaitScreen> createState() => _OnlineWaitScreenState();
}

class _OnlineWaitScreenState extends State<OnlineWaitScreen> {
  final List<String> _lobby = [];
  String _status = 'Joining…';
  String? _peerId;
  Timer? _detect;
  bool _busy = false;
  bool _navigated = false;

  // Built once we know which game the host is running.
  PollingClient? _ranking;
  BluffPollingClient? _bluff;

  late final RelayClient _relay = RelayClient(widget.serverUrl);

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      _peerId = await _relay.join(widget.roomCode, widget.name);
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not join: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _status = 'Joined · waiting for host to start…');
    // Detect the game type from the first frame the host sends.
    _detect = Timer.periodic(const Duration(milliseconds: 700), (_) => _peek());
  }

  Future<void> _peek() async {
    if (_busy || _peerId == null) return;
    _busy = true;
    try {
      final msgs = await _relay.poll(widget.roomCode, _peerId!);
      for (final m in msgs) {
        if (m['type'] != 'msg') continue;
        final data = (m['data'] as Map?)?.cast<String, dynamic>();
        final t = data?['t'];
        if (t == 'lobby' || t == 'view') {
          _route(bluff: false);
          return;
        } else if (t == 'bluffLobby' || t == 'bluffView') {
          _route(bluff: true);
          return;
        }
      }
    } catch (_) {
      // Retry next tick.
    } finally {
      _busy = false;
    }
  }

  void _route({required bool bluff}) {
    _detect?.cancel();
    if (bluff) {
      final c = BluffPollingClient(
        serverUrl: widget.serverUrl,
        roomCode: widget.roomCode,
        name: widget.name,
        peerId: _peerId,
      )..onClosed = _onClosed;
      c.onGameStart = () => _go(NetBluffScreen(
            client: c,
            onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ));
      _bluff = c;
      c.connect();
    } else {
      final c = PollingClient(
        serverUrl: widget.serverUrl,
        roomCode: widget.roomCode,
        name: widget.name,
        peerId: _peerId,
      )..onClosed = _onClosed;
      c.onGameStart = () => _go(TableScreen(
            controller: c,
            chat: c.chat,
            onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ));
      _ranking = c;
      c.connect();
    }
    if (mounted) setState(() => _status = 'In lobby · waiting for host…');
  }

  void _go(Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  void _onClosed(String reason) {
    if (!mounted || _navigated) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _detect?.cancel();
    if (!_navigated) {
      _ranking?.close();
      _bluff?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _ranking;
    if (client != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Room ${widget.roomCode}')),
        body: AnimatedBuilder(
          animation: client,
          builder: (context, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_status, style: const TextStyle(color: Colors.white70)),
                if (client.roomBoot != null && client.roomStartChips != null)
                  TableRulesBanner(
                    boot: client.roomBoot!,
                    startChips: client.roomStartChips!,
                  ),
                const SizedBox(height: 16),
                for (final p in client.lobbyPlayers)
                  Text(p, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Room ${widget.roomCode}')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            for (final p in _lobby)
              Text(p, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Host lobby for online Bluff: shows the shareable code, then starts the game
/// and opens the host's own table (the host only ever sees its own hand).
class BluffOnlineLobbyScreen extends StatefulWidget {
  const BluffOnlineLobbyScreen({
    super.key,
    required this.serverUrl,
    required this.name,
  });

  final String serverUrl;
  final String name;

  @override
  State<BluffOnlineLobbyScreen> createState() => _BluffOnlineLobbyScreenState();
}

class _BluffOnlineLobbyScreenState extends State<BluffOnlineLobbyScreen> {
  late final BluffPollingHost _host;

  @override
  void initState() {
    super.initState();
    _host = BluffPollingHost(serverUrl: widget.serverUrl, hostName: widget.name);
    _host.start();
  }

  void _start() {
    _host.startGame();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BluffGameScreen(
        engine: _host.engine,
        chat: _host.chat,
        onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ));
  }

  @override
  void dispose() {
    _host.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluff · Host')),
      body: AnimatedBuilder(
        animation: _host,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white10,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Text('ROOM CODE',
                            style: TextStyle(
                                color: Colors.white54, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        SelectableText(
                          _host.roomCode ?? '······',
                          style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6),
                        ),
                        const SizedBox(height: 4),
                        Text(_host.status,
                            style: const TextStyle(color: Colors.white60)),
                        if (_host.roomCode != null)
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _host.roomCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy code'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Players',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final name in _host.lobbyNames)
                        Card(
                          color: Colors.white10,
                          child: ListTile(
                            leading:
                                const Icon(Icons.person, color: Colors.amber),
                            title: Text(name),
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Empty seats are filled with bots (min 3) when you start.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _host.roomCode == null ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start game'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
