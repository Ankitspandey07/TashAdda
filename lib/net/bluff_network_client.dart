import 'dart:convert';
import 'dart:io';

import 'bluff_client.dart';
import 'bluff_view.dart';
import 'table_chat.dart';

/// LAN Bluff client over TCP. Renders the redacted [BluffView] the host sends
/// and relays this player's moves back. Drives the shared [NetBluffScreen].
class BluffNetworkClient extends BluffClient {
  BluffNetworkClient(
      {required this.hostIp, required this.tcpPort, required this.name});

  final String hostIp;
  final int tcpPort;
  final String name;

  Socket? _socket;
  String _buffer = '';

  BluffView _view = BluffView.empty;
  List<String> lobbyPlayers = [];
  bool inGame = false;

  @override
  TableChat? get chat => _chat;
  late final TableChat _chat =
      TableChat(myName: name, onSend: (type, data) => _send({'t': type, ...data}));

  void Function()? onGameStart;
  void Function(String reason)? onClosed;

  @override
  BluffView get view => _view;

  Future<void> connect() async {
    final socket = await Socket.connect(hostIp, tcpPort,
        timeout: const Duration(seconds: 8));
    _socket = socket;
    _send({'t': 'join', 'name': name});
    socket.listen(
      _onData,
      onDone: () => onClosed?.call('Host closed the connection'),
      onError: (_) => onClosed?.call('Connection error'),
      cancelOnError: true,
    );
  }

  void _onData(List<int> data) {
    _buffer += utf8.decode(data);
    var idx = _buffer.indexOf('\n');
    while (idx != -1) {
      final line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);
      if (line.isNotEmpty) _onMessage(line);
      idx = _buffer.indexOf('\n');
    }
  }

  void _onMessage(String line) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['t']) {
      case 'bluffLobby':
        lobbyPlayers = (msg['players'] as List).cast<String>();
        notifyListeners();
      case 'bluffView':
        _view = bluffViewFromJson(msg);
        if (!inGame) {
          inGame = true;
          onGameStart?.call();
        }
        notifyListeners();
      case 'chat':
        _chat.receiveText(
            (msg['name'] as String?) ?? 'Player', (msg['text'] as String?) ?? '');
      case 'avatar':
        _chat.receiveAvatar(
            (msg['name'] as String?) ?? 'Player', (msg['b64'] as String?) ?? '');
      case 'full':
        onClosed?.call('Room is full');
    }
  }

  void _send(Map<String, dynamic> msg) =>
      _socket?.write('${jsonEncode(msg)}\n');

  @override
  void play(List<String> cardCodes) =>
      _send({'t': 'action', 'action': 'play', 'cards': cardCodes});

  @override
  void callBluff() => _send({'t': 'action', 'action': 'call'});

  @override
  void pass() => _send({'t': 'action', 'action': 'pass'});

  void close() => _socket?.destroy();

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
