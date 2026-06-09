import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ensures [MobileAds.initialize] runs once before any ad loads.
class AdsInit {
  AdsInit._();

  static Future<void>? _future;
  static bool ready = false;

  static Future<void> ensureInitialized() {
    _future ??= MobileAds.instance.initialize().then((_) {
      ready = true;
    });
    return _future!;
  }
}
