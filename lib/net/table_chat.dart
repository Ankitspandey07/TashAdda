import 'package:flutter/foundation.dart';

import '../profile/profile_store.dart';

/// One chat line for the floating-bubble overlay.
class ChatMsg {
  ChatMsg(this.id, this.name, this.text, {this.mine = false});
  final int id;
  final String name;
  final String text;
  final bool mine;
}

/// Serializes an outgoing chat/avatar frame onto whatever transport is in use.
typedef ChatSendFn = void Function(String type, Map<String, dynamic> data);

/// A transport-agnostic chat + avatar channel shared by the table UI and the
/// network layer. The UI calls [sendText]/[shareAvatar]; the network host/client
/// call [receiveText]/[receiveAvatar] when frames arrive. [onSend] pushes a
/// frame to peers (null for single-device play, where chat is local-only).
class TableChat extends ChangeNotifier {
  TableChat({this.onSend, this.myName = 'You'});

  ChatSendFn? onSend;
  String myName;

  /// Newest message to surface as a floating bubble (id increments each time).
  ChatMsg? last;
  int _id = 0;

  void sendText(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _push(myName, t, mine: true);
    onSend?.call('chat', {'name': myName, 'text': t});
  }

  void receiveText(String name, String text) => _push(name, text, mine: false);

  /// Broadcasts this player's avatar thumbnail (if they set one).
  void shareAvatar() {
    final b64 = ProfileStore.thumbB64;
    if (b64 == null) return;
    onSend?.call('avatar', {'name': myName, 'b64': b64});
  }

  void receiveAvatar(String name, String b64) =>
      RemoteAvatars.putB64(name, b64);

  void _push(String name, String text, {required bool mine}) {
    last = ChatMsg(_id++, name, text, mine: mine);
    notifyListeners();
  }
}
