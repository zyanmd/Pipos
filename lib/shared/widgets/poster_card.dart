import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'app_network_image.dart';
import 'bouncy_tap.dart';

/// Anime / Comic poster card with tactile bouncy feedback.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.score,
    this.width = 140,
    this.height,
    this.aspectRatio = 2 / 3,
    this.heroTag,
    this.overlayInfo = true,
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final String? badge;
  final String? score;
  final VoidCallback onTap;
  final double width;
  final double? height;
  final double aspectRatio;
  final String? heroTag;
  final bool overlayInfo;

  static String cleanDisplayLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var s = raw.trim();
    final prefixRegex = RegExp(r'^(?:(?:episodes?|eps?\.?|ch\.?|chapter)\s*[:.-]?\s*)+', caseSensitive: false);
    final hadPrefix = prefixRegex.hasMatch(s);
    final stripped = s.replaceFirst(prefixRegex, '').trim();
    final trailingRegex = RegExp(r'\s*(?:episodes?|eps?\.?)\s*$', caseSensitive: false);
    final cleaned = stripped.replaceFirst(trailingRegex, '').trim();
    if (cleaned.isNotEmpty && (RegExp(r'^\d+').hasMatch(cleaned) || hadPrefix)) {
      return 'Ep $cleaned';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final cleanBadge = (badge != null && badge!.isNotEmpty) ? cleanDisplayLabel(badge) : null;
    var cleanSubtitle = (subtitle != null && subtitle!.isNotEmpty) ? cleanDisplayLabel(subtitle) : null;
    if (cleanBadge != null && cleanSubtitle != null && cleanBadge.toLowerCase() == cleanSubtitle.toLowerCase()) {
      cleanSubtitle = null;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardHeight = height ?? (width == double.infinity ? null : (overlayInfo ? 204.0 : null));

    if (overlayInfo) {
      return RepaintBoundary(
        child: BouncyTap(
          scaleDown: 0.94,
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: cardHeight,
            child: Hero(
              tag: heroTag ?? 'poster_${title}_${imageUrl.hashCode}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                  border: Border.all(
                    color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: imageUrl,
                        borderRadius: 0,
                        fit: BoxFit.cover,
                        memCacheWidth: (width.isFinite && width > 0)
                            ? (width * 2.0).toInt().clamp(160, 480)
                            : 320,
                        memCacheHeight: (cardHeight != null && cardHeight.isFinite && cardHeight > 0)
                            ? (cardHeight * 2.0).toInt().clamp(240, 720)
                            : 480,
                      ),
                      // Smooth iOS gradient vignette
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x22000000),
                              Color(0xCC000000),
                              Color(0xF0000000),
                            ],
                            stops: [0.35, 0.60, 0.85, 1.0],
                          ),
                        ),
                      ),
                      // Rating Badge (Top Left - Vibrant Green Pill matching Reference UI)
                      if (score != null && score!.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.45),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              score!.replaceAll('★', '').trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      // Episode / Status Badge (Top Right - Crisp Red Pill without expensive GPU blur)
                      if (cleanBadge != null && cleanBadge.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.iosRed.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 90),
                              child: Text(
                                cleanBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Bottom Title & Subtitle Info (Apple HIG Typography)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  height: 1.22,
                                ),
                              ),
                              if (cleanSubtitle != null && cleanSubtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  cleanSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Classic style: title below image
    return RepaintBoundary(
      child: BouncyTap(
        scaleDown: 0.94,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: heroTag ?? 'poster_${title}_${imageUrl.hashCode}',
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13.5),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(
                            url: imageUrl,
                            borderRadius: 0,
                            fit: BoxFit.cover,
                            memCacheWidth: (width.isFinite && width > 0)
                                ? (width * 2.0).toInt().clamp(160, 480)
                                : 320,
                          ),
                          if (cleanBadge != null && cleanBadge.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.iosRed.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  cleanBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                  height: 1.25,
                ),
              ),
              if (cleanSubtitle != null && cleanSubtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  cleanSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Schedule card (used in Today's Schedule on Home, Apple iOS HIG card).
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.time,
    this.width = 130,
    this.height = 175,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback onTap;
  final String? time;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                  border: Border.all(
                    color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: imageUrl,
                        borderRadius: 0,
                        fit: BoxFit.cover,
                        memCacheWidth: (width * 2.0).toInt().clamp(140, 360),
                        memCacheHeight: (height * 2.0).toInt().clamp(180, 480),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xCC000000),
                            ],
                            stops: [0.55, 1.0],
                          ),
                        ),
                      ),
                      if (time != null && time!.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.iosRed.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              time!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide hero card for featured content (home screen top, Apple TV aesthetic).
class FeaturedHeroCard extends StatelessWidget {
  const FeaturedHeroCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.subtitle,
    this.score,
    this.episode,
    this.tag = 'Tonton',
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final String? score;
  final String? episode;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'featured_${title}_${imageUrl.hashCode}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: imageUrl,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    memCacheHeight: 400,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x33000000),
                          Color(0xDD000000),
                        ],
                        stops: [0.3, 0.65, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (score != null && score!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    width: 0.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.star_fill,
                                      size: 11,
                                      color: Color(0xFFFFD60A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      score!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (episode != null && episode!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.iosRed.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  PosterCard.cleanDisplayLabel(episode),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
