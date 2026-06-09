import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ads_init.dart';
import 'ads/rewarded_ads.dart';
import 'profile/profile_store.dart';
import 'ui/app_background.dart';
import 'ui/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Classic full-width layout — avoids MIUI side inset strips from edge-to-edge.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppBackground.fillColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await ProfileStore.load();
  try {
    await AdsInit.ensureInitialized();
    RewardedAds.load();
  } catch (_) {
    // Ads unavailable — app must still run (bad App ID, no Play Services, etc.).
  }
  runApp(const TeenPattiApp());
}

class TeenPattiApp extends StatelessWidget {
  const TeenPattiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TashAdda',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.2),
            padding: mq.padding.copyWith(left: 0, right: 0),
            viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B7A0B),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppBackground.fillColor,
      ),
      home: const MainMenuScreen(),
    );
  }
}
