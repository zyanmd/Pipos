import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import 'app_network_image.dart';

/// Data model for an item displayed in the Apple/Netflix-styled FeaturedContentSlider.
class FeaturedContentItem {
  final String title;
  final String? imageUrl;
  final String? posterUrl;
  final String eyebrowTag;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;
  final IconData actionIcon;
  final String actionLabel;
  final String secondaryActionLabel;
  final VoidCallback? onSecondaryTap;
  final Color? accentColor;

  const FeaturedContentItem({
    required this.title,
    this.imageUrl,
    this.posterUrl,
    this.eyebrowTag = '',
    this.subtitle,
    this.badge,
    required this.onTap,
    this.actionIcon = CupertinoIcons.play_fill,
    this.actionLabel = 'Watch',
    this.secondaryActionLabel = 'More',
    this.onSecondaryTap,
    this.accentColor,
  });
}

/// Hero Slider matching Netflix / Crunchyroll modern streaming UI.
/// Displays dynamic featured banners bleeding full to the top,
/// unobstructed character artwork, dark lower gradient fade,
/// clean title and synopsis, Watch and More CTA buttons, and right-aligned indicator capsule.
class FeaturedContentSlider extends StatefulWidget {
  final List<FeaturedContentItem> items;
  final bool isLoading;
  final double? height;

  const FeaturedContentSlider({
    super.key,
    required this.items,
    this.isLoading = false,
    this.height,
  });

  @override
  State<FeaturedContentSlider> createState() => _FeaturedContentSliderState();
}

class _FeaturedContentSliderState extends State<FeaturedContentSlider> {
  late final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FeaturedContentSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (_currentPage >= widget.items.length && widget.items.isNotEmpty) {
        _currentPage = 0;
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.sizeOf(context).height;
    final effectiveHeight = widget.height ?? (screenH * 0.54).clamp(460.0, 520.0);

    if (widget.isLoading) {
      return _buildSkeleton(isDark, effectiveHeight);
    }

    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: effectiveHeight,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.items.length,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
        },
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _FeaturedCard(
            item: item,
            isDark: isDark,
            currentPage: _currentPage,
            totalItems: widget.items.length,
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(bool isDark, double h) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
      highlightColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
      child: Container(
        height: h,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final FeaturedContentItem item;
  final bool isDark;
  final int currentPage;
  final int totalItems;

  const _FeaturedCard({
    required this.item,
    required this.isDark,
    required this.currentPage,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final screenBg = isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Full Cover Background Image (Optimized RAM cache) ──
              AppNetworkImage(
                url: item.imageUrl,
                borderRadius: 0,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                memCacheWidth: 800,
                memCacheHeight: 900,
              ),

              // ── 2. Cinematic Ambient Multi-stop Gradient Overlays ──
              // Top protects status bar/logo; mid is crystal clear; bottom smoothly fades to screen background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.40, 0.68, 0.88, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.50),
                      Colors.black.withValues(alpha: 0.85),
                      screenBg,
                    ],
                  ),
                ),
              ),

              // ── 3. Content Overlay at Bottom ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title (Bold, spacious, never obstructed)
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        letterSpacing: -0.4,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 10,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),

                    // Synopsis / Subtitle
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Action Buttons Row: [ ▶ Watch ]   [ ⌄ More ]   ...   [ • • ━ ]
                    Row(
                      children: [
                        // Watch Button (solid white pill)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            item.onTap();
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.actionIcon,
                                  size: 14,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.actionLabel.isNotEmpty ? item.actionLabel : 'Watch',
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // More Button (dark glass pill)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (item.onSecondaryTap != null) {
                              item.onSecondaryTap!();
                            } else {
                              item.onTap();
                            }
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item.secondaryActionLabel.isNotEmpty
                                      ? item.secondaryActionLabel
                                      : 'More',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Modern Indicator Capsule on the Right (Netflix/Crunchyroll aesthetic)
                        if (totalItems > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                totalItems > 6 ? 6 : totalItems,
                                (i) {
                                  final isActive = (currentPage % (totalItems > 6 ? 6 : totalItems)) == i;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.symmetric(horizontal: 2.2),
                                    width: isActive ? 14 : 4.5,
                                    height: 4.5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2.5),
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.35),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

