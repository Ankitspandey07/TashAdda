import 'dart:io';

import 'package:flutter/foundation.dart';

/// Debug-only: iOS Simulator on a Mac behind SSL inspection (Zscaler, etc.)
/// cannot verify the relay cert. Release builds keep normal validation.
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (kDebugMode) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }
}

void installDevHttpOverrides() {
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
}
