import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final r = await _post('create', retries: 3);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw Exception(j['error'] ?? 'Could not create room');
    }
    return j['code'] as String;
  }

  Future<String> join(String code, String name) async {
    final r = await _post('join',
        retries: 3,
        body: jsonEncode({'code': code, 'name': name}));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw Exception(j['error'] ?? 'Could not join room');
    }
    return j['peerId'] as String;
  }

  Future<void> send(
      String code, String to, String from, Map<String, dynamic> data) async {
    await _post('send',
        body: jsonEncode({'code': code, 'to': to, 'from': from, 'data': data}));
  }

  Future<List<Map<String, dynamic>>> poll(String code, String peer) async {
    final r = await _post('poll',
        body: jsonEncode({'code': code, 'peer': peer}));
    if (r.statusCode != 200) return const [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['messages'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<http.Response> _post(String path, {String? body, int retries = 1}) async {
    Object? last;
    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        return await http
            .post(_u(path), headers: _json, body: body)
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        last = e;
        if (attempt < retries - 1) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    throw Exception(friendlyNetworkError(last));
  }

  /// Turns low-level TLS/socket errors into something actionable in the lobby.
  static String friendlyNetworkError(Object? error) {
    final msg = error.toString();
    if (error is HandshakeException ||
        msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('Handshake error')) {
      return 'Secure connection failed. Try mobile data (not office/school Wi‑Fi), '
          'turn off VPN, and check your phone date & time are correct.';
    }
    if (error is SocketException || msg.contains('Failed host lookup')) {
      return 'No internet connection. Check Wi‑Fi or mobile data and try again.';
    }
    if (error is TimeoutException || msg.contains('TimeoutException')) {
      return 'Server timed out. Check your connection and try again.';
    }
    return msg;
  }
}
