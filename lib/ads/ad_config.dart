import 'package:flutter/foundation.dart';

/// AdMob IDs for TashAdda (Android).
///
/// Debug builds use Google's official test units so ads load while developing.
/// Release builds use your production units from the AdMob console.
const String kAdMobAppId = 'ca-app-pub-8727245587896837~4240325035';

const String _prodBanner = 'ca-app-pub-8727245587896837/8997672162';
const String _prodRewarded = 'ca-app-pub-8727245587896837/8993802735';

const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
const String _testRewarded = 'ca-app-pub-3940256099942544/5354046379';

String get kBannerAdUnitId => kDebugMode ? _testBanner : _prodBanner;
String get kRewardedAdUnitId => kDebugMode ? _testRewarded : _prodRewarded;
