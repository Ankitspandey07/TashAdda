import 'dart:convert';
import 'dart:io';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

import '../engine/game_engine.dart';
import '../table/local_controller.dart';
import '../table/view_codec.dart';
import 'lan_discovery.dart';
import 'table_chat.dart';

/// Authoritative LAN host: one device runs the [GameEngine], advertises the room
/// over UDP, accepts TCP clients, and pushes each client only the redacted view
/// it is allowed to see. The host is also a player (seat 0).
class NetworkHost extends ChangeNotifier {
  NetworkHost({
    required this.roomName,
    required this.hostName,
    ICardGame? game,
    this.maxPlayers = 5,
    this.boot = 10,
    this.startChips = 1000,
  }) : game = game ?? const TeenPattiGame();

  final String roomName;
  final String hostName;
  final ICardGame game;
  final int maxPlayers;
  final int boot;
  final int startChips;

  static const String hostSeatId = 'host';

  late final GameEngine engine =
      GameEngine(boot: boot, startChips: startChips, game: game);
  final Map<Socket, String> _clientSeat = {};
  final Map<Socket, String> _buffers = {};

  /// Chat/avatar channel for the host's own table view.
  late final TableChat chat =
      TableChat(myName: '$hostName (Host)', onSend: _chatOut);

  /// Latest avatar (base64) per player name, resent to late joiners.
  final Map<String, String> _avatars = {};

  ServerSocket? _server;
  RoomBroadcaster? _broadcaster;

  String? localIp;
  int tcpPort = 0;
  bool started = false;
  bool closed = false;

  LocalController? hostController;

  Future<void> start() async {
    localIp = await localIpv4() ?? '0.0.0.0';
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    tcpPort = server.port;

    engine.addSeat(Seat(
      player: Player(
          id: hostSeatId, name: '$hostName (Host)', seat: 0, chips: startChips),
    ));

    _broadcaster = RoomBroadcaster(RoomInfo(
      roomName: roomName,
      players: engine.seats.length,
      maxPlayers: maxPlayers,
      hostIp: localIp!,
      tcpPort: tcpPort,
    ));
    await _broadcaster!.start();

    server.listen(_onClient);
    notifyListeners();
  }

  /// Names currently in the lobby (host + joined clients), for the lobby UI.
  List<String> get lobbyNames => engine.seats.map((s) => s.name).toList();

  void _onClient(Socket socket) {
    if (started || engine.seats.length >= maxPlayers) {
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
        if (started || _clientSeat.containsKey(socket)) return;
        final seatIndex = engine.seats.length;
        final seatId = 'c$seatIndex';
        final name = (msg['name'] as String?)?.trim();
        engine.addSeat(Seat(
          player: Player(
            id: seatId,
            name: (name == null || name.isEmpty) ? 'Player $seatIndex' : name,
            seat: seatIndex,
            chips: startChips,
          ),
        ));
        _clientSeat[socket] = seatId;
        _broadcaster?.info = RoomInfo(
          roomName: roomName,
          players: engine.seats.length,
          maxPlayers: maxPlayers,
          hostIp: localIp!,
          tcpPort: tcpPort,
        );
        _sendLobby();
        // Catch the newcomer up on avatars shared so far.
        for (final e in _avatars.entries) {
          _sendFrameTo(socket, 'avatar', {'name': e.key, 'b64': e.value});
        }
        notifyListeners();
      case 'action':
        final seatId = _clientSeat[socket];
        if (seatId != null) _applyAction(seatId, msg);
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
    for (final s in _clientSeat.keys) {
      if (s != exclude) _sendFrameTo(s, type, data);
    }
  }

  void _applyAction(String seatId, Map<String, dynamic> msg) {
    if (!started) return;
    final action = msg['action'] as String?;
    final seat = engine.seats.firstWhere((s) => s.id == seatId);
    if (action == 'see') {
      engine.see(seat);
      return;
    }
    if (action == 'sideshowRespond') {
      engine.respondSideshow(seat, msg['accept'] == true);
      return;
    }
    if (action == 'sideshowRequest') {
      if (engine.current.id != seatId) return;
      final targetId = msg['targetId'] as String?;
      if (targetId != null) engine.requestSideshow(seat, targetId);
      return;
    }
    if (action == 'exit') {
      engine.markExited(seat);
      return;
    }
    if (engine.phase == RoundPhase.sideshowPending) return;
    if (!engine.isBettingPhase) return;
    if (engine.current.id != seatId) return;
    switch (action) {
      case 'call':
        engine.bet(seat, raise: false);
      case 'raise':
        engine.bet(seat, raise: true);
      case 'fold':
        engine.fold(seat);
      case 'show':
        engine.show(seat);
    }
  }

  void _onDisconnect(Socket socket) {
    final seatId = _clientSeat.remove(socket);
    _buffers.remove(socket);
    if (seatId != null && started) {
      final seat = engine.seats.firstWhere((s) => s.id == seatId);
      engine.markExited(seat);
    } else if (seatId != null) {
      engine.seats.removeWhere((s) => s.id == seatId);
      _sendLobby();
      notifyListeners();
    }
    socket.destroy();
  }

  void _sendLobby() {
    final payload = jsonEncode({
      't': 'lobby',
      'room': roomName,
      'players': engine.seats.map((s) => s.name).toList(),
      'started': started,
      'boot': boot,
      'startChips': startChips,
    });
    for (final socket in _clientSeat.keys) {
      socket.write('$payload\n');
    }
  }

  /// Starts the game. Fills empty seats with bots up to the Teen Patti minimum
  /// of 3 so a host + single client can still play.
  void startGame() {
    if (started) return;
    var i = 0;
    while (engine.seats.length < 3) {
      engine.addSeat(Seat(
        player: Player(
            id: 'bot$i',
            name: 'Bot ${i + 1}',
            seat: engine.seats.length,
            chips: startChips),
        isBot: true,
      ));
      i++;
    }
    started = true;
    engine.scoreboard.registerPlayers([
      for (final s in engine.seats) (id: s.id, name: s.name),
    ]);
    hostController = LocalController(
      engine,
      viewerSeatId: hostSeatId,
      title: '${game.name} · LAN Host',
      isHost: true,
      onCloseRoom: closeRoom,
    );
    engine.addListener(_pushViews);
    engine.startRound();
    _pushViews();
    notifyListeners();
  }

  void _pushViews() {
    for (final entry in _clientSeat.entries) {
      final view = buildTableView(engine, entry.value);
      entry.key.write('${jsonEncode(tableViewToJson(view))}\n');
    }
  }

  /// Ends the room for everyone and sends final session totals.
  void closeRoom() {
    if (closed) return;
    closed = true;
    final summary = engine.scoreboard.buildSummary([
      for (final s in engine.seats) (id: s.id, name: s.name),
    ]);
    final payload = jsonEncode({
      't': 'closed',
      'summary': summary.toJson(),
    });
    for (final socket in _clientSeat.keys) {
      socket.write('$payload\n');
      socket.destroy();
    }
    _clientSeat.clear();
    engine.scoreboard.clear();
    shutdown();
    notifyListeners();
  }

  void shutdown() {
    _broadcaster?.stop();
    engine.removeListener(_pushViews);
    for (final s in _clientSeat.keys) {
      s.destroy();
    }
    _clientSeat.clear();
    _server?.close();
    hostController?.dispose();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
