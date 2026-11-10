import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  // Production Ad Unit IDs provided by user
  static const String appId = 'ca-app-pub-9977009856498771~9420958319';
  static const String bannerUnitId = 'ca-app-pub-9216620667388797/6913982969';
  static const String rewardUnitId = 'ca-app-pub-9977009856498771/6343815949';
  static const String chatBannerUnitId = 'ca-app-pub-9216620667388797/6913982969';
  static const String nativeUnitId = 'ca-app-pub-9977009856498771/4740540334';

  bool _initialized = false;

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (_initialized || !isSupportedPlatform) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('[AdMob] Init error: $e');
    }
  }

  /// Preloads a Rewarded Ad so it is ready immediately when user taps.
  void preloadRewardedAd() {
    // Rewarded ads disabled per user instruction
  }

  /// Rewarded video ads are disabled per user instruction to avoid interrupting the experience.
  /// Executes [onRewardEarned] directly so the user gets unlocked features without video ads.
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onDismissed,
  }) {
    onRewardEarned();
  }

  /// Creates a BannerAd instance using production ad units (no test ads).
  BannerAd? createBannerAd({
    String? adUnitId,
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError err) onFailed,
  }) {
    if (!isSupportedPlatform) return null;
    final effectiveId = adUnitId ?? bannerUnitId;
    return BannerAd(
      adUnitId: effectiveId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, err) {
          debugPrint('[AdMob] Banner ($effectiveId) failed: ${err.message} (code ${err.code})');
          onFailed(ad, err);
        },
      ),
    );
  }

  /// Creates a NativeAd instance with NativeTemplateStyle.
  NativeAd? createNativeAd({
    String? adUnitId,
    TemplateType templateType = TemplateType.small,
    bool isDark = true,
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError err) onFailed,
  }) {
    if (!isSupportedPlatform) return null;

    final bgColor = isDark ? const Color(0xFF16161A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return NativeAd(
      adUnitId: adUnitId ?? nativeUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: templateType,
        mainBackgroundColor: bgColor,
        cornerRadius: 14.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFFF2D55),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: textColor,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          size: 12.0,
        ),
      ),
    );
  }
}
