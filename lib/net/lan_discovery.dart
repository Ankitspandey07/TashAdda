import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Magic tag so we ignore unrelated UDP traffic on the port.
const String kDiscoveryApp = 'teenpatti-v1';

/// Dedicated local discovery port (per spec).
const int kDiscoveryPort = 7777;

/// A room advertised on the LAN, as seen by a scanning client.
class RoomInfo {
  RoomInfo({
    required this.roomName,
    required this.players,
    required this.maxPlayers,
    required this.hostIp,
    required this.tcpPort,
    this.gameTag = 'ranking',
    this.gameTitle = 'TashAdda',
  });

  final String roomName;
  final int players;
  final int maxPlayers;
  final String hostIp;
  final int tcpPort;

  /// 'ranking' for the betting-engine games, 'bluff' for Bluff. Lets a scanning
  /// client pick the right client/screen before connecting.
  final String gameTag;
  final String gameTitle;

  bool get isBluff => gameTag == 'bluff';

  String get key => '$hostIp:$tcpPort';

  factory RoomInfo.fromJson(Map<String, dynamic> j) => RoomInfo(
        roomName: j['room'] as String,
        players: j['players'] as int,
        maxPlayers: j['max'] as int,
        hostIp: j['ip'] as String,
        tcpPort: j['port'] as int,
        gameTag: (j['game'] as String?) ?? 'ranking',
        gameTitle: (j['title'] as String?) ?? 'TashAdda',
      );

  Map<String, dynamic> toJson() => {
        'app': kDiscoveryApp,
        'room': roomName,
        'players': players,
        'max': maxPlayers,
        'ip': hostIp,
        'port': tcpPort,
        'game': gameTag,
        'title': gameTitle,
      };
}

/// Best-effort local IPv4 address (prefers a hotspot/Wi-Fi style 192.168.* or
/// 10.* address). Returns null if none found.
Future<String?> localIpv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  String? fallback;
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      fallback ??= addr.address;
      if (addr.address.startsWith('192.168.') ||
          addr.address.startsWith('10.') ||
          addr.address.startsWith('172.')) {
        return addr.address;
      }
    }
  }
  return fallback;
}

/// Broadcasts a [RoomInfo] packet every 1.5s on the discovery port so scanning
/// clients can find this host with zero configuration.
class RoomBroadcaster {
  RoomBroadcaster(this.info);

  RoomInfo info;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    final socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _send());
    _send();
  }

  void _send() {
    final s = _socket;
    if (s == null) return;
    final data = utf8.encode(jsonEncode(info.toJson()));
    s.send(data, InternetAddress('255.255.255.255'), kDiscoveryPort);
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
  }
}

/// Listens on the discovery port and surfaces a de-duplicated list of rooms.
class RoomScanner {
  final _controller = StreamController<List<RoomInfo>>.broadcast();
  final Map<String, _Timestamped> _rooms = {};
  RawDatagramSocket? _socket;
  Timer? _sweep;

  Stream<List<RoomInfo>> get rooms => _controller.stream;

  Future<void> start() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kDiscoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final json = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        if (json['app'] != kDiscoveryApp) return;
        final info = RoomInfo.fromJson(json);
        _rooms[info.key] = _Timestamped(info, DateTime.now());
        _emit();
      } catch (_) {
        // Ignore malformed packets.
      }
    });
    // Drop rooms we haven't heard from in 5s (host left / out of range).
    _sweep = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      _rooms.removeWhere(
          (_, v) => now.difference(v.seen) > const Duration(seconds: 5));
      _emit();
    });
  }

  void _emit() =>
      _controller.add(_rooms.values.map((e) => e.info).toList(growable: false));

  void stop() {
    _sweep?.cancel();
    _socket?.close();
    _socket = null;
    _controller.close();
  }
}

class _Timestamped {
  _Timestamped(this.info, this.seen);
  final RoomInfo info;
  final DateTime seen;
}
