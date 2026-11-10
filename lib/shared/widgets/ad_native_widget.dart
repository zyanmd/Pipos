import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/admob_service.dart';

/// Reusable Native Ad Widget using Google Mobile Ads Native Templates.
/// Blends smoothly into feed/reader without obstructing user interaction.
class AdNativeWidget extends StatefulWidget {
  final EdgeInsetsGeometry margin;
  final String? adUnitId;
  final TemplateType templateType;

  const AdNativeWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.adUnitId,
    this.templateType = TemplateType.small,
  });

  @override
  State<AdNativeWidget> createState() => _AdNativeWidgetState();
}

class _AdNativeWidgetState extends State<AdNativeWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nativeAd == null) {
      _loadNativeAd();
    }
  }

  void _loadNativeAd() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _nativeAd = AdMobService.instance.createNativeAd(
      adUnitId: widget.adUnitId,
      templateType: widget.templateType,
      isDark: isDark,
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
            _nativeAd = null;
            _isLoaded = false;
          });
        }
      },
    );
    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = widget.templateType == TemplateType.small;

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 300,
          minHeight: isSmall ? 90 : 320,
          maxHeight: isSmall ? 115 : 360,
          maxWidth: double.infinity,
        ),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}

