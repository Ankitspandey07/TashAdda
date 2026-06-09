import 'dart:convert';
import 'dart:io';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

import '../engine/bluff_engine.dart';
import 'bluff_view.dart';
import 'lan_discovery.dart';
import 'table_chat.dart';

/// Authoritative LAN host for Bluff: runs the [BluffEngine] (host is player 0),
/// advertises the room over UDP, accepts TCP clients, and pushes each only its
/// own redacted [BluffView]. Mirrors [NetworkHost] for the betting games.
class BluffNetworkHost extends ChangeNotifier {
  BluffNetworkHost({
    required this.roomName,
    required this.hostName,
    this.maxPlayers = 12,
  });

  final String roomName;
  final String hostName;
  final int maxPlayers;

  static const String hostSeatId = 'host';

  final BluffEngine engine =
      BluffEngine(callTimeout: const Duration(seconds: 8));
  final Map<Socket, int> _clientIndex = {};
  final Map<Socket, String> _buffers = {};

  late final TableChat chat =
      TableChat(myName: '$hostName (Host)', onSend: _chatOut);
  final Map<String, String> _avatars = {};

  ServerSocket? _server;
  RoomBroadcaster? _broadcaster;

  String? localIp;
  int tcpPort = 0;
  bool started = false;

  Future<void> start() async {
    engine.addPlayer(BluffPlayer(id: hostSeatId, name: '$hostName (Host)'));
    localIp = await localIpv4() ?? '0.0.0.0';
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    tcpPort = server.port;
    _broadcaster = RoomBroadcaster(_info());
    await _broadcaster!.start();
    server.listen(_onClient);
    notifyListeners();
  }

  RoomInfo _info() => RoomInfo(
        roomName: roomName,
        players: engine.players.length,
        maxPlayers: maxPlayers,
        hostIp: localIp ?? '0.0.0.0',
        tcpPort: tcpPort,
        gameTag: 'bluff',
        gameTitle: 'Bluff (Cheat)',
      );

  List<String> get lobbyNames => engine.players.map((p) => p.name).toList();

  void _onClient(Socket socket) {
    if (started || engine.players.length >= maxPlayers) {
      socket.write('${jsonEncode({'t': 'full'})}\n');
      socket.close();
      return;
    }
    _buffers[socket] = '';
    socket.listen(
      (data) => _onData(socket, data),
      onDone: () => _onDisconnect(socket),
      onError: (_) => _onDisconnect(socket),
      cancelOnError: true,
    );
  }

  void _onData(Socket socket, List<int> data) {
    var buf = (_buffers[socket] ?? '') + utf8.decode(data);
    var idx = buf.indexOf('\n');
    while (idx != -1) {
      final line = buf.substring(0, idx).trim();
      buf = buf.substring(idx + 1);
      if (line.isNotEmpty) _onMessage(socket, line);
      idx = buf.indexOf('\n');
    }
    _buffers[socket] = buf;
  }

  void _onMessage(Socket socket, String line) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['t']) {
      case 'join':
        if (started || _clientIndex.containsKey(socket)) return;
        final index = engine.players.length;
        final name = (msg['name'] as String?)?.trim();
        engine.addPlayer(BluffPlayer(
          id: 'c$index',
          name: (name == null || name.isEmpty) ? 'Player $index' : name,
        ));
        _clientIndex[socket] = index;
        _broadcaster?.info = _info();
        _sendLobby();
        for (final e in _avatars.entries) {
          _sendFrameTo(socket, 'avatar', {'name': e.key, 'b64': e.value});
        }
        notifyListeners();
      case 'chat':
        final name = (msg['name'] as String?) ?? 'Player';
        final text = (msg['text'] as String?) ?? '';
        chat.receiveText(name, text);
        _broadcastFrame('chat', {'name': name, 'text': text}, exclude: socket);
      case 'avatar':
        final name = (msg['name'] as String?) ?? 'Player';
        final b64 = (msg['b64'] as String?) ?? '';
        _avatars[name] = b64;
        chat.receiveAvatar(name, b64);
        _broadcastFrame('avatar', {'name': name, 'b64': b64}, exclude: socket);
      case 'action':
        final idx = _clientIndex[socket];
        if (idx != null) _applyAction(idx, msg);
    }
  }

  void _chatOut(String type, Map<String, dynamic> data) {
    if (type == 'avatar') {
      _avatars[data['name'] as String] = data['b64'] as String;
    }
    _broadcastFrame(type, data);
  }

  void _sendFrameTo(Socket s, String type, Map<String, dynamic> data) =>
      s.write('${jsonEncode({'t': type, ...data})}\n');

  void _broadcastFrame(String type, Map<String, dynamic> data,
      {Socket? exclude}) {
    for (final s in _clientIndex.keys) {
      if (s != exclude) _sendFrameTo(s, type, data);
    }
  }

  void _applyAction(int idx, Map<String, dynamic> msg) {
    if (!started) return;
    switch (msg['action']) {
      case 'play':
        final codes = (msg['cards'] as List?)?.cast<String>() ?? const [];
        final hand = engine.players[idx].hand;
        final cards = <PlayingCard>[];
        for (final code in codes) {
          final i = hand.indexWhere((c) => c.code == code && !cards.contains(c));
          if (i >= 0) cards.add(hand[i]);
        }
        if (cards.isNotEmpty) engine.playBy(idx, cards);
      case 'call':
        engine.callBy(idx);
      case 'pass':
        engine.passBy(idx);
    }
  }

  void _onDisconnect(Socket socket) {
    _clientIndex.remove(socket);
    _buffers.remove(socket);
    socket.destroy();
    if (!started) {
      _sendLobby();
      notifyListeners();
    }
  }

  void _sendLobby() {
    final payload = jsonEncode({
      't': 'bluffLobby',
      'players': engine.players.map((p) => p.name).toList(),
    });
    for (final socket in _clientIndex.keys) {
      socket.write('$payload\n');
    }
  }

  void startGame() {
    if (started) return;
    var i = 0;
    while (engine.players.length < 3) {
      engine.addPlayer(BluffPlayer(id: 'bot$i', name: 'Bot ${i + 1}', isBot: true));
      i++;
    }
    started = true;
    engine.addListener(_pushViews);
    engine.startGame();
    _pushViews();
    notifyListeners();
  }

  void _pushViews() {
    for (final entry in _clientIndex.entries) {
      final view = buildBluffView(engine, entry.value);
      entry.key.write('${jsonEncode(bluffViewToJson(view))}\n');
    }
  }

  void shutdown() {
    _broadcaster?.stop();
    engine.removeListener(_pushViews);
    for (final s in _clientIndex.keys) {
      s.destroy();
    }
    _clientIndex.clear();
    _server?.close();
    engine.dispose();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
