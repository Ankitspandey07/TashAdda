import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin client for the TashAdda HTTP-polling relay (see tashadda_vercel/).
///
/// The relay just forwards frames between players; it never holds game state or
/// sees anyone's cards. Works over plain HTTPS, which corporate proxies allow
/// even when they block WebSockets.
class RelayClient {
  RelayClient(String base)
      : base = base.endsWith('/') ? base.substring(0, base.length - 1) : base;

  final String base;

  Uri _u(String p) => Uri.parse('$base/api/$p');
  static const _json = {'content-type': 'application/json'};

  Future<String> create() async {
    final r = await http.post(_u('create'));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw Exception(j['error'] ?? 'Could not create room');
    }
    return j['code'] as String;
  }

  Future<String> join(String code, String name) async {
    final r = await http.post(_u('join'),
        headers: _json, body: jsonEncode({'code': code, 'name': name}));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw Exception(j['error'] ?? 'Could not join room');
    }
    return j['peerId'] as String;
  }

  Future<void> send(
      String code, String to, String from, Map<String, dynamic> data) async {
    await http.post(_u('send'),
        headers: _json,
        body: jsonEncode({'code': code, 'to': to, 'from': from, 'data': data}));
  }

  Future<List<Map<String, dynamic>>> poll(String code, String peer) async {
    final r = await http.post(_u('poll'),
        headers: _json, body: jsonEncode({'code': code, 'peer': peer}));
    if (r.statusCode != 200) return const [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['messages'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }
}
