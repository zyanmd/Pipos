import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service untuk mengelola Smartlink Adsterra monetisasi
class AdsterraService {
  AdsterraService._();

  /// URL Smartlink Adsterra resmi dari konfigurasi pengguna
  static const String smartlinkUrl =
      'https://www.profitableratecpmnetwork.com/m99jt2v49?key=dd5dc1ad31ba7b3a1ad06c15c21de149';

  /// Buka smartlink di browser eksternal
  static Future<bool> openSmartlink() async {
    try {
      final uri = Uri.parse(smartlinkUrl);
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        debugPrint('[Adsterra] Could not launch $smartlinkUrl in external application');
      }
      return ok;
    } catch (e) {
      debugPrint('[Adsterra] Error launching smartlink: $e');
      return false;
    }
  }
}

