import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper service for handling Sociabuzz donations / creator support.
/// Username: `zanegg`
/// Label: `Beri Dukungan`
class DonationService {
  static const String username = 'zanegg';
  static const String directTribeUrl = 'https://sociabuzz.com/zanegg/tribe';
  static const String profileUrl = 'https://sociabuzz.com/zanegg';

  static Future<void> openDonation(BuildContext context) async {
    final tribeUri = Uri.parse(directTribeUrl);
    try {
      final launched = await launchUrl(
        tribeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(
          Uri.parse(profileUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka halaman donasi: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

