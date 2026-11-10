import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../data/models/reel_model.dart';
import '../anime_reels_screen.dart';

/// Horizontal tray displaying vertical Anime Reels cards on AnimeHomeScreen.
class AnimeReelsTray extends StatelessWidget {
  final List<ReelModel> reels;
  final bool isLoading;

  const AnimeReelsTray({
    super.key,
    required this.reels,
    this.isLoading = false,
  });

  void _openReels(BuildContext context, [int initialIndex = 0]) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AnimeReelsScreen(
          initialReels: reels,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading && reels.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION HEADER ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2E93), Color(0xFFFF8E3C)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.play_rectangle_fill, size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'REELS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Anime Reels',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _openReels(context, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tonton',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Cuplikan & momen anime seru pilihan',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── HORIZONTAL CAROUSEL ──
          SizedBox(
            height: 220,
            child: isLoading && reels.isEmpty
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => const ShimmerPlaceholder(
                      width: 128,
                      height: 220,
                      borderRadius: 16,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: reels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = reels[index];
                      final cover = item.effectiveCoverUrl;

                      return GestureDetector(
                        onTap: () => _openReels(context, index),
                        child: Container(
                          width: 128,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Poster Image
                              if (cover.isNotEmpty)
                                AppNetworkImage(
                                  url: cover,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 260,
                                  memCacheHeight: 440,
                                )
                              else
                                Container(
                                  color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFE5E5EA),
                                  child: const Icon(CupertinoIcons.film, color: Colors.grey, size: 28),
                                ),

                              // Gradient Vignette
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.3),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.9),
                                    ],
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),

                              // Duration Badge (Top Left)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.timer, size: 9, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${item.clip.duration}s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Likes Badge (Top Right)
                              if (item.likes > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                          size: 9.5,
                                          color: item.isLiked ? const Color(0xFFFF2E93) : Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          item.likes >= 1000 ? '${(item.likes / 1000).toStringAsFixed(1)}k' : '${item.likes}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Play Icon Overlay (Center)
                              Center(
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      CupertinoIcons.play_arrow_solid,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom Title & Episode Info
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.anime.title.isNotEmpty ? item.anime.title : item.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (item.episode.episodeNumber.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ep ${item.episode.episodeNumber}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
