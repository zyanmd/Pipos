import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/admob_service.dart';
import 'adsterra_banner_widget.dart';

class AdBannerWidget extends StatefulWidget {
  final EdgeInsetsGeometry margin;
  final String? adUnitId;
  final bool fallbackToSmartlink;

  const AdBannerWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.adUnitId,
    this.fallbackToSmartlink = true,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = AdMobService.instance.createBannerAd(
      adUnitId: widget.adUnitId,
      onLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onFailed: (ad, err) {
        ad.dispose();
        if (mounted) {
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        }
      },
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Container(
        margin: widget.margin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }

    // Jika AdMob belum selesai load atau no fill (gagal), tampilkan fallback Smartlink agar iklan selalu terlihat oleh semua user
    if (widget.fallbackToSmartlink) {
      return AdsterraBannerWidget(
        margin: widget.margin,
        isDismissible: true,
      );
    }

    return const SizedBox.shrink();
  }
}

