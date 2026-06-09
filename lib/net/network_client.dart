import 'dart:convert';
import 'dart:io';

import '../score/scoreboard.dart';
import '../table/table_view.dart';
import '../table/view_codec.dart';
import 'table_chat.dart';

/// Connects to a LAN host over TCP, renders the redacted views it receives, and
/// sends the local player's actions back. Implements [TableController] so the
/// shared [TableScreen] can drive it directly.
class NetworkClient extends TableController {
  NetworkClient({required this.hostIp, required this.tcpPort, required this.name});

  final String hostIp;
  final int tcpPort;
  final String name;

  Socket? _socket;
  String _buffer = '';

  TableView _view = TableView.empty;
  List<String> lobbyPlayers = [];
  int? roomBoot;
  int? roomStartChips;
  bool inGame = false;
  SessionSummary? _closedSummary;

  /// Chat/avatar channel; sends frames to the host.
  late final TableChat chat =
      TableChat(myName: name, onSend: (type, data) => _send({'t': type, ...data}));

  /// Fired once the host starts the game and the first view arrives.
  void Function()? onGameStart;

  /// Fired if the connection drops or is rejected.
  void Function(String reason)? onClosed;

  @override
  String get title => 'Teen Patti · LAN';

  @override
  TableView get view => _view;

  @override
  SessionSummary? get sessionSummary {
    if (_closedSummary != null) return _closedSummary;
    if (_view.sessionRounds == 0) return null;
    return SessionSummary.fromStandings(_view.standings, _view.sessionRounds);
  }

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
      case 'lobby':
        lobbyPlayers = (msg['players'] as List).cast<String>();
        roomBoot = msg['boot'] as int?;
        roomStartChips = msg['startChips'] as int?;
        notifyListeners();
      case 'view':
        _view = tableViewFromJson(msg);
        if (!inGame) {
          inGame = true;
          onGameStart?.call();
        }
        notifyListeners();
      case 'chat':
        chat.receiveText(
            (msg['name'] as String?) ?? 'Player', (msg['text'] as String?) ?? '');
      case 'avatar':
        chat.receiveAvatar(
            (msg['name'] as String?) ?? 'Player', (msg['b64'] as String?) ?? '');
      case 'full':
        onClosed?.call('Room is full');
      case 'closed':
        final raw = msg['summary'];
        if (raw is Map) {
          _closedSummary =
              SessionSummary.fromJson(raw.cast<String, dynamic>());
          if (_closedSummary != null) {
            onSessionEnd?.call(_closedSummary!);
          }
        }
        close();
        onClosed?.call('Host closed the room');
    }
  }

  void _send(Map<String, dynamic> msg) =>
      _socket?.write('${jsonEncode(msg)}\n');

  void _action(String a, [Map<String, dynamic>? extra]) =>
      _send({'t': 'action', 'action': a, ...?extra});

  @override
  void see() => _action('see');
  @override
  void call() => _action('call');
  @override
  void raise() => _action('raise');
  @override
  void fold() => _action('fold');
  @override
  void show() => _action('show');
  @override
  void requestSideshow(String targetId) =>
      _action('sideshowRequest', {'targetId': targetId});
  @override
  void respondSideshow(bool accept) =>
      _action('sideshowRespond', {'accept': accept});
  @override
  void leaveTable() => _action('exit');

  void close() => _socket?.destroy();

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
