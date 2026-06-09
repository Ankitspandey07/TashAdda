import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the player's display name and profile photo locally — no login.
///
/// The chosen image is copied into the app's documents directory so it survives
/// restarts, and the path is remembered in shared preferences. Uninstalling the
/// app (or clearing its data) wipes it automatically, exactly as expected.
class ProfileStore {
  ProfileStore._();

  static const _kName = 'profile_name';
  static const _kImage = 'profile_image';
  static const _kThumb = 'profile_thumb';

  /// Current avatar image file path (null if none set). Listenable so the table
  /// avatar updates immediately.
  static final ValueNotifier<String?> imagePath = ValueNotifier<String?>(null);
  static final ValueNotifier<String> name = ValueNotifier<String>('You');

  /// A tiny (~96px PNG) base64 thumbnail of the avatar, small enough to share
  /// with other players over the network. Null if no photo is set.
  static String? thumbB64;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name.value = prefs.getString(_kName) ?? 'You';
    thumbB64 = prefs.getString(_kThumb);
    final path = prefs.getString(_kImage);
    if (path != null && File(path).existsSync()) {
      imagePath.value = path;
    }
  }

  /// Decodes [source] and re-encodes a small PNG thumbnail for sharing.
  static Future<String?> _makeThumb(String source) async {
    try {
      final bytes = await File(source).readAsBytes();
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: 96);
      final frame = await codec.getNextFrame();
      final png =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return base64Encode(png.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<void> setName(String value) async {
    final v = value.trim().isEmpty ? 'You' : value.trim();
    name.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, v);
  }

  /// Copies [sourcePath] into app storage and remembers it as the avatar.
  static Future<void> setImageFrom(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.img';
    await File(sourcePath).copy(dest);
    imagePath.value = dest;
    thumbB64 = await _makeThumb(dest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kImage, dest);
    if (thumbB64 != null) await prefs.setString(_kThumb, thumbB64!);
  }

  static Future<void> clearImage() async {
    imagePath.value = null;
    thumbB64 = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kImage);
    await prefs.remove(_kThumb);
  }
}

/// Avatars received from other players over the network, keyed by display name.
/// The table looks these up to show opponents' photos.
class RemoteAvatars {
  RemoteAvatars._();
  static final ValueNotifier<Map<String, Uint8List>> byName =
      ValueNotifier<Map<String, Uint8List>>({});

  static void put(String name, Uint8List bytes) {
    final next = Map<String, Uint8List>.from(byName.value);
    next[name] = bytes;
    byName.value = next;
  }

  static void putB64(String name, String b64) {
    try {
      put(name, base64Decode(b64));
    } catch (_) {}
  }

  static void clear() => byName.value = {};
}
