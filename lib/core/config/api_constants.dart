import 'package:flutter/foundation.dart';

/// The mobile app uses the same API as the HawuPay website.
/// For a physical device, set LAN_IP to the computer's local network address.
class ApiConstants {
  static const bool useDemoMode =
      bool.fromEnvironment('DEMO', defaultValue: false);
  static const String lanIp = String.fromEnvironment('LAN_IP');

  static String get _host {
    if (lanIp.isNotEmpty) return lanIp; // perangkat fisik / Wi-Fi lokal
    if (kIsWeb) return '127.0.0.1';
    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
  }

  static String get baseUrl => 'http://$_host:8001/api';
  static String get wsUrl => 'ws://$_host:8001/api/ws';
}
