import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/featured_content_slider.dart';
import '../data/models/zpic_model.dart';
import '../data/zpic_repository.dart';
import 'zpic_player_screen.dart';
import 'zpic_search_screen.dart';

class ZpicHomeScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onToggleMode;

  const ZpicHomeScreen({
    super.key,
    this.isEmbedded = false,
    this.onToggleMode,
  });

  @override
  State<ZpicHomeScreen> createState() => _ZpicHomeScreenState();
}

class _ZpicHomeScreenState extends State<ZpicHomeScreen> {
  final _repo = ZpicRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<ZpicVideoModel> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _errorMessage;
  int _selectedFilterIndex = 0; // 0: Semua, 1: Terbaru, 2: Populer

  final List<String> _filters = ['🔥 Semua Video', '⚡ Terbaru', '👁 Paling Populer'];

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final list = await _repo.getHome(page: 1);
      if (mounted) {
        setState(() {
          _videos = list;
          _isLoading = false;
          _hasMore = list.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data video zPic: $e';
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;

    try {
      final list = await _repo.getHome(page: nextPage);
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          if (list.isNotEmpty) {
            _videos.addAll(list);
            _currentPage = nextPage;
          } else {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _openRandomVideo() async {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mencari video acak...'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final video = await _repo.getRandom();
      if (video != null && mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ZpicPlayerScreen(video: video),
          ),
        );
      }
    } catch (_) {}
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    // Build Featured Carousel Items (Top 6 videos)
    final sliderItems = _videos.take(6).map((item) {
      return FeaturedContentItem(
        title: item.title.isNotEmpty ? item.title : 'zPic Video',
        imageUrl: item.thumbnail,
        eyebrowTag: item.isNsfw ? '18+ NSFW' : 'VIDEO TERBARU',
        subtitle: item.views.isNotEmpty ? '${item.views} views • zPic' : 'zPic Sub Indo',
        badge: item.isNsfw ? 'NSFW' : null,
        actionIcon: CupertinoIcons.play_fill,
        actionLabel: 'Tonton',
        secondaryActionLabel: 'Acak',
        onSecondaryTap: _openRandomVideo,
        accentColor: Colors.redAccent,
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => ZpicPlayerScreen(video: item),
            ),
          );
        },
      );
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 56,
            pinned: true,
            backgroundColor: isDark
                ? AppColors.darkBackground.withValues(alpha: 0.92)
                : AppColors.lightBackground.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            leading: widget.isEmbedded
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildIosActionButton(
                        icon: CupertinoIcons.back,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: 'Kembali',
                        isDark: isDark,
                      ),
                    ),
                  ),
            title: Row(
              children: [
                Text(
                  'zPic',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    '18+ NSFW',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              _buildIosActionButton(
                icon: CupertinoIcons.shuffle,
                onTap: _openRandomVideo,
                tooltip: 'Video Acak',
                isDark: isDark,
              ),
              _buildIosActionButton(
                icon: CupertinoIcons.search,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const ZpicSearchScreen(),
                    ),
                  );
                },
                tooltip: 'Cari Video',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: RefreshIndicator(
          color: Colors.redAccent,
          onRefresh: _loadVideos,
          child: _buildContent(sliderItems, isDark, textPrimary, textMuted),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<FeaturedContentItem> sliderItems,
    bool isDark,
    Color textPrimary,
    Color textMuted,
  ) {
    if (_isLoading) {
      return _buildSkeletonLoader(isDark);
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error, size: 44),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                onPressed: _loadVideos,
                child: const Text('Coba Lagi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.play_rectangle, size: 48, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Belum ada video tersedia.',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 1. Featured Content Slider (Matching Anime style)
        if (sliderItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeaturedContentSlider(
                items: sliderItems,
                isLoading: false,
              ),
            ),
          ),

        // 2. Quick Filter Pills
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(_filters.length, (i) {
                final selected = _selectedFilterIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilterIndex = i);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.redAccent
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? Colors.redAccent
                              : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // 3. Section Title Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Koleksi Video zPic',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_videos.length} Video',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Video Grid (Signature Animeverse Poster Card style)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _videos[index];
                return _buildVideoCard(item, isDark);
              },
              childCount: _videos.length,
            ),
          ),
        ),

        // 5. Loading More Indicator
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CupertinoActivityIndicator(color: Colors.redAccent, radius: 12),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }

  Widget _buildVideoCard(ZpicVideoModel item, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ZpicPlayerScreen(video: item),
          ),
        );
      },
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
              // 1. Thumbnail Image
              CachedNetworkImage(
                imageUrl: item.thumbnail,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 10),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  child: const Center(
                    child: Icon(CupertinoIcons.play_rectangle, color: Colors.grey, size: 30),
                  ),
                ),
              ),

              // 2. Cinematic Gradient Vignette (Animeverse Standard)
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

              // 3. NSFW Badge (Top Left)
              if (item.isNsfw)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      '18+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

              // 4. Views Badge (Top Right)
              if (item.views.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.eye_fill, size: 10, color: Colors.white70),
                        const SizedBox(width: 3.5),
                        Text(
                          item.views,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Play Icon Accent
              Positioned(
                right: 10,
                bottom: 46,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),

              // 6. Title & Subtitle overlay at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        shadows: [
                          Shadow(
                            color: Color(0xCC000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'play.zpic.org',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildSkeletonLoader(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
      highlightColor: isDark ? AppColors.darkCardElevated : Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 240,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                childCount: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
