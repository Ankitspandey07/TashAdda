import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Tiny sound-effects helper. Plays bundled WAVs for dealing, betting, folding
/// and winning. All calls are fire-and-forget and fail silently (e.g. in tests
/// where the audio plugin isn't available), so callers never need to await.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  /// Toggled by the in-game mute button.
  static final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  final List<AudioPlayer> _pool = [];
  int _i = 0;

  AudioPlayer _next() {
    if (_pool.length < 4) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    _i = (_i + 1) % _pool.length;
    return _pool[_i];
  }

  Future<void> _play(String asset, {double volume = 1.0}) async {
    if (muted.value) return;
    try {
      final p = _next();
      await p.stop();
      await p.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // No audio device / plugin (e.g. unit tests) — ignore.
    }
  }

  void deal() => _play('sfx/deal.wav', volume: 0.7);
  void fold() => _play('sfx/fold.wav', volume: 0.85);
  void bet() => _play('sfx/bet.wav', volume: 0.9);
  void raise() => _play('sfx/raise.wav', volume: 0.85);
  void chat() => _play('sfx/chat.wav', volume: 0.8);
  void win() => _play('sfx/win.wav', volume: 0.9);
}
