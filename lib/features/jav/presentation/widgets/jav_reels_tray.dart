import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/bouncy_tap.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../data/models/jav_model.dart';
import '../jav_reels_screen.dart';

/// Horizontal tray displaying vertical JAV preview clips on JavHomeScreen.
class JavReelsTray extends StatelessWidget {
  final List<JavVideoModel> reels;
  final bool isLoading;

  const JavReelsTray({
    super.key,
    required this.reels,
    this.isLoading = false,
  });

  void _openReels(BuildContext context, [int initialIndex = 0]) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => JavReelsScreen(
          initialVideos: reels,
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
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF8E8E93);

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
                          colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
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
                      'Klip & Reels JAV',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                BouncyTap(
                  onTap: () => _openReels(context, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tonton',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 13,
                        color: textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── REELS CAROUSEL ──
          SizedBox(
            height: 200,
            child: isLoading
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ShimmerPlaceholder(
                        width: 115,
                        height: 200,
                        borderRadius: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: reels.length,
                    itemBuilder: (ctx, index) {
                      final item = reels[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: BouncyTap(
                          onTap: () => _openReels(context, index),
                          child: Container(
                            width: 115,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Poster / Thumbnail
                                  if (item.thumbnail.isNotEmpty)
                                    AppNetworkImage(
                                      url: item.thumbnail,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 260,
                                      memCacheHeight: 400,
                                    )
                                  else
                                    Container(
                                      color: isDark ? const Color(0xFF1A1A22) : const Color(0xFFE5E5EA),
                                    ),

                                  // Gradient Overlay
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.15),
                                            Colors.black.withValues(alpha: 0.85),
                                          ],
                                          stops: const [0.35, 0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Center Play Icon Button
                                  Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF2D55).withValues(alpha: 0.88),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF2D55).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.play_fill,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),

                                  // Quality or Duration Badge at Top
                                  if (item.quality.isNotEmpty || item.duration.isNotEmpty)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.duration.isNotEmpty ? item.duration : item.quality,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Title Bottom
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 8,
                                    child: Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                        shadows: [
                                          Shadow(color: Colors.black, blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
