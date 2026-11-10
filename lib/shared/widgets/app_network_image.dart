import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/api_config.dart';
import 'shimmer_placeholder.dart';

/// Network image loader with in-memory caching (RAM only by default to avoid
/// filling up permanent local disk storage), shimmer placeholder, and fallback error handling.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    this.placeholder,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.alignment = Alignment.center,
    this.useDiskCache = false,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double borderRadius;
  final Widget? placeholder;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;
  /// If false (default), images are cached only in RAM (ImageCache) and
  /// NOT saved permanently to device local storage.
  final bool useDiskCache;

  /// Clears any cached image files previously written to local disk storage.
  static Future<void> clearDiskCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _placeholder(context);
    }

    var raw = url!.trim();
    if (raw.contains('thumbnail.komiku.to')) {
      raw = raw.replaceAll('thumbnail.komiku.to', 'thumbnail.komiku.org');
    }
    final String u;
    if (raw.startsWith('http')) {
      u = raw;
    } else if (raw.startsWith('//')) {
      u = 'https:$raw';
    } else if (raw.startsWith('/img/upload/')) {
      u = 'https://thumbnail.komiku.org$raw';
    } else {
      u = '${ApiConfig.baseUrl}$raw';
    }

    const imageHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://komiku.org/',
    };

    final screenW = MediaQuery.sizeOf(context).width;
    // Clamp effective ratio to max 2.0 to save up to 4x RAM on 3.5x/4.0x DPI devices with zero perceived quality loss
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final hasExplicitWidth = width != null && width!.isFinite && width! > 0;
    final targetW = hasExplicitWidth ? width! : screenW;

    final int cacheW = memCacheWidth ??
        (hasExplicitWidth
            ? (targetW * pixelRatio).toInt().clamp(80, 720)
            : (screenW * 1.5).toInt().clamp(200, 720));
    final int? cacheH = memCacheHeight ??
        ((height != null && height!.isFinite && height! > 0)
            ? (height! * pixelRatio).toInt().clamp(80, 960)
            : null);

    Widget imageWidget;
    if (useDiskCache) {
      imageWidget = CachedNetworkImage(
        imageUrl: u,
        httpHeaders: imageHeaders,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        memCacheWidth: cacheW,
        memCacheHeight: cacheH,
        fadeInDuration: const Duration(milliseconds: 140),
        fadeOutDuration: const Duration(milliseconds: 80),
        placeholder: (c, s) => _placeholder(context),
        errorWidget: (c, s, e) => _error(context),
      );
    } else {
      // Pure in-memory cache: zero bytes saved permanently to local storage!
      // Decoded image stays in Flutter's RAM imageCache during app session.
      imageWidget = Image.network(
        u,
        headers: imageHeaders,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return _placeholder(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _placeholder(context);
        },
        errorBuilder: (context, error, stackTrace) => _error(context),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      ),
    );
  }

  Widget _placeholder(BuildContext ctx) {
    return placeholder ??
        ShimmerPlaceholder(
          width: width,
          height: height ?? 100,
          borderRadius: borderRadius,
        );
  }

  Widget _error(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        size: 32,
      ),
    );
  }
}
