import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ads_init.dart';

/// Loads and shows the rewarded interstitial ad unit.
class RewardedAds {
  RewardedAds._();

  static RewardedInterstitialAd? _ad;
  static bool _loading = false;

  static Future<void> load() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_loading || _ad != null) return;
    _loading = true;
    try {
      await AdsInit.ensureInitialized();
    } catch (_) {
      _loading = false;
      return;
    }
    RewardedInterstitialAd.load(
      adUnitId: kRewardedAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad if one is ready. Returns true when the user earned
  /// the reward (watched to completion).
  static Future<bool> show() async {
    final ad = _ad;
    if (ad == null) {
      load();
      return false;
    }
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (d) {
        d.dispose();
        _ad = null;
        load();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (d, _) {
        d.dispose();
        _ad = null;
        load();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, reward) => earned = true);
    return completer.future;
  }
}
