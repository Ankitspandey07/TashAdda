import 'dart:async';

import '../score/scoreboard.dart';
import '../table/table_view.dart';
import '../table/view_codec.dart';
import 'relay_client.dart';
import 'table_chat.dart';

/// Online client over the HTTP-polling relay. Joins by room code, renders the
/// redacted views the host sends, and relays this player's actions back.
/// Implements [TableController] so the shared [TableScreen] drives it unchanged.
class PollingClient extends TableController {
  PollingClient({
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
  TableView _view = TableView.empty;
  List<String> lobbyPlayers = [];
  int? roomBoot;
  int? roomStartChips;
  bool inGame = false;
  String status = 'Joining…';
  SessionSummary? _closedSummary;

  /// Chat/avatar channel; sends frames to the host via the relay.
  late final TableChat chat = TableChat(
      myName: name,
      onSend: (type, data) =>
          relay.send(roomCode, 'host', peerId ?? '', {'t': type, ...data}));

  Timer? _timer;
  bool _busy = false;

  void Function()? onGameStart;
  void Function(String reason)? onClosed;

  @override
  String get title => 'TashAdda · Online';

  @override
  TableView get view => _view;

  @override
  SessionSummary? get sessionSummary {
    if (_closedSummary != null) return _closedSummary;
    if (_view.sessionRounds == 0) return null;
    return SessionSummary.fromStandings(_view.standings, _view.sessionRounds);
  }

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
      // Ignore transient errors; keep polling.
    } finally {
      _busy = false;
    }
  }

  void _onData(Map<String, dynamic> data) {
    switch (data['t']) {
      case 'lobby':
        lobbyPlayers = (data['players'] as List).cast<String>();
        roomBoot = data['boot'] as int?;
        roomStartChips = data['startChips'] as int?;
        notifyListeners();
      case 'view':
        _view = tableViewFromJson(data);
        if (!inGame) {
          inGame = true;
          onGameStart?.call();
        }
        notifyListeners();
      case 'chat':
        chat.receiveText((data['name'] as String?) ?? 'Player',
            (data['text'] as String?) ?? '');
      case 'avatar':
        chat.receiveAvatar((data['name'] as String?) ?? 'Player',
            (data['b64'] as String?) ?? '');
      case 'closed':
        final raw = data['summary'];
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

  void _action(String a, [Map<String, dynamic>? extra]) => relay.send(
      roomCode, 'host', peerId ?? '',
      {'action': a, ...?extra});

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

  void close() => _timer?.cancel();

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
