import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/featured_content_slider.dart';
import '../data/models/jav_model.dart';
import '../data/jav_repository.dart';
import 'jav_player_screen.dart';
import 'jav_search_screen.dart';
import 'jav_reels_screen.dart';
import 'jav_actress_screen.dart';
import 'widgets/jav_reels_tray.dart';

class JavHomeScreen extends StatefulWidget {
  const JavHomeScreen({super.key});

  @override
  State<JavHomeScreen> createState() => _JavHomeScreenState();
}

class _JavHomeScreenState extends State<JavHomeScreen> {
  final _repo = JavRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<JavVideoModel> _videos = [];
  List<JavVideoModel> _featuredVideos = [];
  List<JavVideoModel> _reels = [];
  List<JavActressModel> _actresses = [];
  List<JavCategoryModel> _categories = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _errorMessage;

  // Filters
  int _selectedFilterIndex = 0;
  final List<_FilterItem> _filterItems = const [
    _FilterItem(label: '🔥 Rekomendasi', type: null, isHome: true),
    _FilterItem(label: '⚡ Terbaru', type: null, isHome: false),
    _FilterItem(label: '💎 Reducing Mosaic', type: 'reducing-mosaic', isHome: false),
    _FilterItem(label: '✨ Uncensored', type: 'uncensored', isHome: false),
    _FilterItem(label: '🎬 Censored', type: 'censored', isHome: false),
  ];

  @override
  void initState() {
    super.initState();
    AdultContentService.instance.addListener(_onAdultStatusChanged);
    if (AdultContentService.instance.is18Unlocked) {
      _loadInitialData();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    AdultContentService.instance.removeListener(_onAdultStatusChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAdultStatusChanged() {
    if (!mounted) return;
    if (!AdultContentService.instance.is18Unlocked) {
      setState(() {
        _videos.clear();
        _featuredVideos.clear();
        _reels.clear();
        _actresses.clear();
        _categories.clear();
      });
    } else {
      _loadInitialData();
    }
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

  Future<void> _loadInitialData() async {
    if (!AdultContentService.instance.is18Unlocked) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final futures = await Future.wait([
        _repo.getHome(),
        _repo.getReels(page: 1),
        _repo.getActresses(),
        _repo.getCategories(),
      ]);

      if (!mounted) return;

      final homeList = futures[0] as List<JavVideoModel>;
      final reelsList = futures[1] as List<JavVideoModel>;
      final actressesList = futures[2] as List<JavActressModel>;
      final categoriesList = futures[3] as List<JavCategoryModel>;

      setState(() {
        _videos = homeList;
        _featuredVideos = homeList.take(6).toList();
        _reels = reelsList.isNotEmpty ? reelsList : homeList.where((v) => v.previewVideo.isNotEmpty).toList();
        _actresses = actressesList;
        _categories = categoriesList;
        _isLoading = false;
        _hasMore = homeList.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat konten JAV ($e)';
      });
    }
  }

  Future<void> _onFilterSelected(int index) async {
    if (_selectedFilterIndex == index) return;
    HapticFeedback.selectionClick();

    setState(() {
      _selectedFilterIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _videos = [];
    });

    final filter = _filterItems[index];

    try {
      List<JavVideoModel> list;
      if (filter.isHome) {
        list = await _repo.getHome();
      } else {
        list = await _repo.getVideos(
          page: 1,
          type: filter.type,
        );
      }

      if (!mounted) return;
      setState(() {
        _videos = list;
        _isLoading = false;
        _hasMore = list.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat video ($e)';
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final filter = _filterItems[_selectedFilterIndex];

    try {
      final list = await _repo.getVideos(
        page: nextPage,
        type: filter.type,
      );

      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        if (list.isNotEmpty) {
          _videos.addAll(list);
          _currentPage = nextPage;
        } else {
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _openActressDetail(JavActressModel actress) {
    HapticFeedback.lightImpact();
    // Extract slug from URL if needed
    var slug = actress.url.replaceAll(RegExp(r'.*\/actress\/'), '').replaceAll(RegExp(r'\/.*'), '').trim();
    if (slug.isEmpty) {
      slug = actress.name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => JavActressScreen(
          actressSlug: slug,
          initialName: actress.name,
          initialAvatar: actress.image,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D12) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161F) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1F);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF8E8E93);

    if (!AdultContentService.instance.is18Unlocked) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Icon(CupertinoIcons.back, color: textPrimary),
          ),
        ),
        body: _buildLockedView(isDark),
      );
    }

    // Hero slider items
    final sliderItems = _featuredVideos.map((v) {
      return FeaturedContentItem(
        title: v.title,
        imageUrl: v.thumbnail.isNotEmpty ? v.thumbnail : v.image,
        posterUrl: v.image.isNotEmpty ? v.image : v.thumbnail,
        eyebrowTag: v.type.isNotEmpty ? v.type.toUpperCase() : 'UNGGULAN 18+',
        subtitle: v.duration.isNotEmpty
            ? '${v.duration} • ${v.views.isNotEmpty ? v.views : "HD"}'
            : (v.views.isNotEmpty ? v.views : 'Koleksi Populer'),
        badge: v.quality.isNotEmpty ? v.quality : 'FHD',
        actionIcon: CupertinoIcons.play_fill,
        actionLabel: 'Watch',
        accentColor: const Color(0xFFFF2D55),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => JavPlayerScreen(video: v),
            ),
          );
        },
      );
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── 1. iOS LARGE TITLE APP BAR (Matches AnimeHomeScreen) ──
          SliverAppBar(
            expandedHeight: 112,
            pinned: true,
            stretch: true,
            backgroundColor: isDark
                ? AppColors.iosBackgroundDark.withValues(alpha: 0.88)
                : AppColors.iosBackgroundLight.withValues(alpha: 0.88),
            surfaceTintColor: Colors.transparent,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Icon(CupertinoIcons.back, color: textPrimary),
            ),
            flexibleSpace: LayoutBuilder(
              builder: (ctx, c) {
                final shrink = 1 -
                    ((c.maxHeight - kToolbarHeight) / (112 - kToolbarHeight))
                        .clamp(0.0, 1.0);
                final isShrunk = shrink > 0.6;
                return FlexibleSpaceBar(
                  centerTitle: isShrunk,
                  titlePadding: EdgeInsets.only(
                    left: isShrunk ? 0 : 48,
                    right: isShrunk ? 0 : 16,
                    bottom: isShrunk ? 13 : 12,
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'JAV',
                        style: TextStyle(
                          fontSize: isShrunk ? 17 : 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: isShrunk ? -0.4 : -0.8,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '18+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              // Reels quick button
              BouncyTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(
                      builder: (_) => JavReelsScreen(initialVideos: _reels),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E26) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.play_rectangle_fill, size: 20, color: Color(0xFFFF2D55)),
                ),
              ),
              // Search button
              BouncyTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const JavSearchScreen(),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E26) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.search, size: 20, color: textPrimary),
                ),
              ),
            ],
          ),

          // ── 2. PULL TO REFRESH ──
          CupertinoSliverRefreshControl(
            onRefresh: _loadInitialData,
          ),

          // ── 3. FEATURED HERO CAROUSEL (Top Slider) ──
          if (_selectedFilterIndex == 0 && sliderItems.isNotEmpty)
            SliverToBoxAdapter(
              child: FeaturedContentSlider(
                items: sliderItems,
                isLoading: _isLoading,
              ),
            ),

          // ── 4. QUICK NAV DISCOVERY BAR (Filter Pills) ──
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Reels Pill
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BouncyTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context, rootNavigator: true).push(
                          CupertinoPageRoute(
                            builder: (_) => JavReelsScreen(initialVideos: _reels),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D55).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.play_rectangle_fill, size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Reels JAV',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Filter Items
                  ..._filterItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedFilterIndex == idx;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: BouncyTap(
                        onTap: () => _onFilterSelected(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF2D55)
                                : (isDark ? const Color(0xFF191922) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── 5. JAV REELS TRAY (Horizontal preview clips) ──
          if (_selectedFilterIndex == 0 && _reels.isNotEmpty)
            SliverToBoxAdapter(
              child: JavReelsTray(
                reels: _reels,
                isLoading: _isLoading,
              ),
            ),

          // ── 6. POPULAR ACTRESSES SECTION ──
          if (_actresses.isNotEmpty && _selectedFilterIndex == 0)
            SliverToBoxAdapter(
              child: _buildActressesSection(isDark, cardBg, textPrimary, textMuted),
            ),

          // ── 7. CATEGORIES SECTION ──
          if (_categories.isNotEmpty && _selectedFilterIndex == 0)
            SliverToBoxAdapter(
              child: _buildCategoriesSection(isDark, cardBg, textPrimary, textMuted),
            ),

          // ── 8. SECTION TITLE FOR MAIN GRID ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.film_fill, color: Color(0xFFFF2D55), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _filterItems[_selectedFilterIndex].label,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 9. MAIN VIDEO GRID ──
          if (_isLoading)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(
                  child: CupertinoActivityIndicator(
                    color: isDark ? Colors.white : Colors.black,
                    radius: 14,
                  ),
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Color(0xFFFF453A),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textPrimary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      BouncyTap(
                        onTap: _loadInitialData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Muat Ulang',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _videos[index];
                    return _buildVideoCard(item, isDark, cardBg, textPrimary, textMuted);
                  },
                  childCount: _videos.length,
                ),
              ),
            ),

          // ── 10. PAGINATION LOADING ──
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // ── ACTRESSES HORIZONTAL SECTION ──
  Widget _buildActressesSection(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.heart_fill, color: Color(0xFFFF2D55), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Aktris Populer',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '${_actresses.length} Aktris',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _actresses.length,
            itemBuilder: (context, index) {
              final actress = _actresses[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: BouncyTap(
                  onTap: () => _openActressDetail(actress),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF2D55), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: actress.image.isNotEmpty
                              ? AppNetworkImage(
                                  url: actress.image,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(CupertinoIcons.person_fill, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 78,
                        child: Text(
                          actress.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  // ── CATEGORIES SECTION ──
  Widget _buildCategoriesSection(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Icon(CupertinoIcons.square_grid_2x2_fill, color: Color(0xFFFF2D55), size: 18),
              const SizedBox(width: 8),
              Text(
                'Kategori & Genre',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: BouncyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => JavSearchScreen(initialQuery: cat.name),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A24) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                      ),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── MODERN VIDEO CARD ──
  Widget _buildVideoCard(
    JavVideoModel item,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => JavPlayerScreen(video: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnail.isNotEmpty)
                      AppNetworkImage(
                        url: item.thumbnail,
                        fit: BoxFit.cover,
                        memCacheWidth: 350,
                      )
                    else
                      Container(color: isDark ? const Color(0xFF1F1F28) : const Color(0xFFE5E5EA)),

                    // Duration badge bottom right
                    if (item.duration.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Quality badge top left
                    if (item.quality.isNotEmpty)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.quality,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Play preview icon hint
                    if (item.previewVideo.isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.play_circle_fill,
                            color: Color(0xFFFF2D55),
                            size: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Title and views metadata
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item.views.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.views,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          ),
                        if (item.timeAgo.isNotEmpty)
                          Text(
                            item.timeAgo,
                            style: TextStyle(fontSize: 9.5, color: textMuted),
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

  Widget _buildLockedView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                CupertinoIcons.lock_shield_fill,
                color: Color(0xFFFF2D55),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Mode 18+ Terkunci',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Fitur JAV hanya aktif saat Mode 18+ dinyalakan. Silakan aktifkan Mode 18+ di menu Profil untuk mengakses konten ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            BouncyTap(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_left, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Kembali ke Beranda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterItem {
  final String label;
  final String? type;
  final bool isHome;

  const _FilterItem({
    required this.label,
    required this.type,
    required this.isHome,
  });
}
