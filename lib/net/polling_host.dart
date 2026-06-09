import 'dart:async';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

import '../engine/game_engine.dart';
import '../table/local_controller.dart';
import '../table/view_codec.dart';
import 'relay_client.dart';
import 'table_chat.dart';

/// Authoritative online host over the HTTP-polling relay. Runs the [GameEngine]
/// locally and pushes each peer only its own redacted view. Mirrors the LAN
/// host, but reaches friends over the internet through the relay.
class PollingHost extends ChangeNotifier {
  PollingHost({
    required String serverUrl,
    required this.hostName,
    required this.game,
    this.boot = 10,
    this.startChips = 1000,
    this.maxPlayers = 5,
  }) : relay = RelayClient(serverUrl);

  final RelayClient relay;
  final String hostName;
  final ICardGame game;
  final int boot;
  final int startChips;
  final int maxPlayers;

  static const String hostSeatId = 'host';
  static const Duration pollEvery = Duration(milliseconds: 700);

  late final GameEngine engine =
      GameEngine(boot: boot, startChips: startChips, game: game);
  final Map<String, String> _peerSeat = {}; // relay peerId -> engine seat id

  /// Chat/avatar channel for the host's own table view.
  late final TableChat chat =
      TableChat(myName: '$hostName (Host)', onSend: _chatOut);
  final Map<String, String> _avatars = {}; // name -> base64 thumb

  String? roomCode;
  bool started = false;
  bool closed = false;
  String status = 'Connecting…';
  LocalController? hostController;

  Timer? _timer;
  bool _busy = false;

  Future<void> start() async {
    engine.addSeat(Seat(
      player: Player(
          id: hostSeatId, name: '$hostName (Host)', seat: 0, chips: startChips),
    ));
    try {
      roomCode = await relay.create();
      status = 'Room ready · share the code';
    } catch (e) {
      status = 'Server error: $e';
      notifyListeners();
      return;
    }
    notifyListeners();
    _timer = Timer.periodic(pollEvery, (_) => _pump());
  }

  List<String> get lobbyNames => engine.seats.map((s) => s.name).toList();

  Future<void> _pump() async {
    if (_busy || roomCode == null) return;
    _busy = true;
    try {
      final msgs = await relay.poll(roomCode!, hostSeatId);
      for (final m in msgs) {
        _handle(m);
      }
    } catch (_) {
      // Transient network blips are fine; next tick retries.
    } finally {
      _busy = false;
    }
  }

  void _handle(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'peerJoined':
        if (started || engine.seats.length >= maxPlayers) return;
        final peerId = m['peerId'] as String;
        if (_peerSeat.containsKey(peerId)) return;
        final name = (m['name'] as String?)?.trim();
        final seatIndex = engine.seats.length;
        final seatId = 'c$seatIndex';
        engine.addSeat(Seat(
          player: Player(
            id: seatId,
            name: (name == null || name.isEmpty) ? 'Player $seatIndex' : name,
            seat: seatIndex,
            chips: startChips,
          ),
        ));
        _peerSeat[peerId] = seatId;
        _sendLobby();
        // Catch the newcomer up on avatars shared so far.
        for (final e in _avatars.entries) {
          relay.send(roomCode!, peerId, hostSeatId,
              {'t': 'avatar', 'name': e.key, 'b64': e.value});
        }
        notifyListeners();
      case 'msg':
        final from = m['from'] as String?;
        final data = (m['data'] as Map?)?.cast<String, dynamic>();
        if (from == null || data == null) return;
        final t = data['t'];
        if (t == 'chat') {
          final name = (data['name'] as String?) ?? 'Player';
          final text = (data['text'] as String?) ?? '';
          chat.receiveText(name, text);
          _chatBroadcast('chat', {'name': name, 'text': text}, exclude: from);
        } else if (t == 'avatar') {
          final name = (data['name'] as String?) ?? 'Player';
          final b64 = (data['b64'] as String?) ?? '';
          _avatars[name] = b64;
          chat.receiveAvatar(name, b64);
          _chatBroadcast('avatar', {'name': name, 'b64': b64}, exclude: from);
        } else {
          _onPeerAction(from, data);
        }
    }
  }

  void _chatOut(String type, Map<String, dynamic> data) {
    if (type == 'avatar') {
      _avatars[data['name'] as String] = data['b64'] as String;
    }
    _chatBroadcast(type, data);
  }

  void _chatBroadcast(String type, Map<String, dynamic> data,
      {String? exclude}) {
    if (roomCode == null) return;
    for (final peer in _peerSeat.keys) {
      if (peer != exclude) {
        relay.send(roomCode!, peer, hostSeatId, {'t': type, ...data});
      }
    }
  }

  void _onPeerAction(String peerId, Map<String, dynamic> data) {
    final seatId = _peerSeat[peerId];
    if (seatId == null || !started) return;
    final seat = engine.seats.firstWhere((s) => s.id == seatId);
    final action = data['action'] as String?;
    if (action == 'see') {
      engine.see(seat);
      return;
    }
    if (action == 'sideshowRespond') {
      engine.respondSideshow(seat, data['accept'] == true);
      return;
    }
    if (action == 'sideshowRequest') {
      if (engine.current.id != seatId) return;
      final targetId = data['targetId'] as String?;
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

  void _sendLobby() {
    final data = {
      't': 'lobby',
      'players': engine.seats.map((s) => s.name).toList(),
      'boot': boot,
      'startChips': startChips,
    };
    for (final peerId in _peerSeat.keys) {
      relay.send(roomCode!, peerId, hostSeatId, data);
    }
  }

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
      title: '${game.name} · Online Host',
      isHost: true,
      onCloseRoom: closeRoom,
    );
    engine.addListener(_pushViews);
    engine.startRound();
    _pushViews();
    notifyListeners();
  }

  void _pushViews() {
    for (final entry in _peerSeat.entries) {
      final view = buildTableView(engine, entry.value);
      relay.send(roomCode!, entry.key, hostSeatId, tableViewToJson(view));
    }
  }

  /// Ends the room for everyone and sends final session totals.
  void closeRoom() {
    if (closed || roomCode == null) return;
    closed = true;
    final summary = engine.scoreboard.buildSummary([
      for (final s in engine.seats) (id: s.id, name: s.name),
    ]);
    final payload = {'t': 'closed', 'summary': summary.toJson()};
    for (final peerId in _peerSeat.keys) {
      relay.send(roomCode!, peerId, hostSeatId, payload);
    }
    engine.scoreboard.clear();
    shutdown();
    notifyListeners();
  }

  void shutdown() {
    _timer?.cancel();
    engine.removeListener(_pushViews);
    hostController?.dispose();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
