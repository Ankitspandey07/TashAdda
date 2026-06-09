import 'package:flutter/foundation.dart';

import 'bluff_view.dart';
import 'table_chat.dart';

/// Shared interface for a remote Bluff player (LAN or online), so the
/// view-driven [NetBluffScreen] can drive either transport unchanged.
abstract class BluffClient extends ChangeNotifier {
  BluffView get view;

  /// Networked chat/avatars; null for transports without chat wired yet.
  TableChat? get chat => null;

  /// Play the given cards (by code) as a claim of the current required rank.
  void play(List<String> cardCodes);

  /// Call "Bluff!" on the pending claim.
  void callBluff();

  /// Decline to call.
  void pass();
}
