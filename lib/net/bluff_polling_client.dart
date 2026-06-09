import 'dart:async';

import 'bluff_client.dart';
import 'bluff_view.dart';
import 'relay_client.dart';
import 'table_chat.dart';

/// Online Bluff client over the HTTP-polling relay. Joins by code, renders the
/// redacted [BluffView] the host pushes, and relays this player's moves back.
class BluffPollingClient extends BluffClient {
  BluffPollingClient({
    required String serverUrl,
    required this.roomCode,
    required this.name,
    this.peerId,
  }) : relay = RelayClient(serverUrl);

  final RelayClient relay;
  final String roomCode;
  final String name;

  static const Duration pollEvery = Duration(milliseconds: 700);

  String? peerId;
  @override
  BluffView view = BluffView.empty;
  List<String> lobbyPlayers = [];
  bool inGame = false;
  String status = 'Joining…';

  @override
  TableChat? get chat => _chat;
  late final TableChat _chat = TableChat(
      myName: name,
      onSend: (type, data) =>
          relay.send(roomCode, 'host', peerId ?? '', {'t': type, ...data}));

  Timer? _timer;
  bool _busy = false;

  void Function()? onGameStart;
  void Function(String reason)? onClosed;

  Future<void> connect() async {
    if (peerId == null) {
      try {
        peerId = await relay.join(roomCode, name);
      } catch (e) {
        onClosed?.call('$e');
        return;
      }
    }
    status = 'Joined room $roomCode · waiting for host…';
    notifyListeners();
    _timer = Timer.periodic(pollEvery, (_) => _pump());
  }

  Future<void> _pump() async {
    if (_busy || peerId == null) return;
    _busy = true;
    try {
      final msgs = await relay.poll(roomCode, peerId!);
      for (final m in msgs) {
        if (m['type'] == 'msg') {
          final data = (m['data'] as Map?)?.cast<String, dynamic>();
          if (data != null) _onData(data);
        }
      }
    } catch (_) {
      // Keep polling.
    } finally {
      _busy = false;
    }
  }

  void _onData(Map<String, dynamic> data) {
    switch (data['t']) {
      case 'bluffLobby':
        lobbyPlayers = (data['players'] as List).cast<String>();
        notifyListeners();
      case 'bluffView':
        view = bluffViewFromJson(data);
        if (!inGame) {
          inGame = true;
          onGameStart?.call();
        }
        notifyListeners();
      case 'chat':
        _chat.receiveText((data['name'] as String?) ?? 'Player',
            (data['text'] as String?) ?? '');
      case 'avatar':
        _chat.receiveAvatar((data['name'] as String?) ?? 'Player',
            (data['b64'] as String?) ?? '');
    }
  }

  @override
  void play(List<String> cardCodes) => relay.send(
      roomCode, 'host', peerId ?? '', {'action': 'play', 'cards': cardCodes});

  @override
  void callBluff() =>
      relay.send(roomCode, 'host', peerId ?? '', {'action': 'call'});

  @override
  void pass() => relay.send(roomCode, 'host', peerId ?? '', {'action': 'pass'});

  void close() => _timer?.cancel();

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
