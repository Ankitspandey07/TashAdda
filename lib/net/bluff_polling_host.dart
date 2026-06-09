import 'dart:async';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/foundation.dart';

import '../engine/bluff_engine.dart';
import 'bluff_view.dart';
import 'relay_client.dart';
import 'table_chat.dart';

/// Authoritative online host for Bluff over the HTTP-polling relay. Runs the
/// [BluffEngine] locally (host is player 0) and pushes each remote player only
/// its own redacted [BluffView]. The host renders its own seat straight from
/// the engine (it only ever sees its own hand).
class BluffPollingHost extends ChangeNotifier {
  BluffPollingHost({
    required String serverUrl,
    required this.hostName,
    this.maxPlayers = 12,
  }) : relay = RelayClient(serverUrl);

  final RelayClient relay;
  final String hostName;
  final int maxPlayers;

  static const String hostPeer = 'host';
  static const Duration pollEvery = Duration(milliseconds: 700);

  final BluffEngine engine =
      BluffEngine(callTimeout: const Duration(seconds: 8));

  /// relay peerId -> engine player index.
  final Map<String, int> _peerIndex = {};

  late final TableChat chat =
      TableChat(myName: '$hostName (Host)', onSend: _chatOut);
  final Map<String, String> _avatars = {};

  String? roomCode;
  bool started = false;
  String status = 'Connecting…';

  Timer? _timer;
  bool _busy = false;

  Future<void> start() async {
    engine.addPlayer(BluffPlayer(id: hostPeer, name: '$hostName (Host)'));
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

  List<String> get lobbyNames => engine.players.map((p) => p.name).toList();

  Future<void> _pump() async {
    if (_busy || roomCode == null) return;
    _busy = true;
    try {
      final msgs = await relay.poll(roomCode!, hostPeer);
      for (final m in msgs) {
        _handle(m);
      }
    } catch (_) {
      // Retry next tick.
    } finally {
      _busy = false;
    }
  }

  void _handle(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'peerJoined':
        if (started || engine.players.length >= maxPlayers) return;
        final peerId = m['peerId'] as String;
        if (_peerIndex.containsKey(peerId)) return;
        final name = (m['name'] as String?)?.trim();
        final index = engine.players.length;
        engine.addPlayer(BluffPlayer(
          id: peerId,
          name: (name == null || name.isEmpty) ? 'Player $index' : name,
        ));
        _peerIndex[peerId] = index;
        _sendLobby();
        for (final e in _avatars.entries) {
          relay.send(roomCode!, peerId, hostPeer,
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
    for (final peer in _peerIndex.keys) {
      if (peer != exclude) {
        relay.send(roomCode!, peer, hostPeer, {'t': type, ...data});
      }
    }
  }

  void _onPeerAction(String peerId, Map<String, dynamic> data) {
    final idx = _peerIndex[peerId];
    if (idx == null || !started) return;
    switch (data['action']) {
      case 'play':
        final codes = (data['cards'] as List?)?.cast<String>() ?? const [];
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

  void _sendLobby() {
    final data = {
      't': 'bluffLobby',
      'players': engine.players.map((p) => p.name).toList(),
    };
    for (final peerId in _peerIndex.keys) {
      relay.send(roomCode!, peerId, hostPeer, data);
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
    for (final entry in _peerIndex.entries) {
      final view = buildBluffView(engine, entry.value);
      relay.send(roomCode!, entry.key, hostPeer, bluffViewToJson(view));
    }
  }

  void shutdown() {
    _timer?.cancel();
    engine.removeListener(_pushViews);
    engine.dispose();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
