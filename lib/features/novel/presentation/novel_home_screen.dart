import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/featured_content_slider.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../bookmarks/presentation/unified_bookmarks_screen.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';
import 'novel_daftar_screen.dart';
import 'novel_detail_screen.dart';
import 'novel_search_screen.dart';
import 'novel_genre_detail_screen.dart';
import 'novel_genre_list_screen.dart';
import '../../../shared/widgets/bouncy_tap.dart';

class NovelHomeScreen extends StatefulWidget {
  const NovelHomeScreen({super.key});

  @override
  State<NovelHomeScreen> createState() => _NovelHomeScreenState();
}

class _NovelHomeScreenState extends State<NovelHomeScreen> {
  final _repo = NovelRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<NovelItemModel> _novels = [];
  List<NovelGenreModel> _genres = [];
  List<NovelItemModel> _bookmarks = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  bool _hasNext = true;
  String? _error;
  String? _selectedType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 350) {
      _loadMore();
    }
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final resFuture = _repo.getNovelHome(
        page: 1,
        forceRefresh: forceRefresh,
        type: _selectedType,
        status: _selectedStatus,
      );
      final genresFuture = _repo.getNovelGenres();
      final bookmarksFuture = _repo.getBookmarks();

      final results = await Future.wait([resFuture, genresFuture, bookmarksFuture]);
      final homeData = results[0] as NovelPaginationData<NovelItemModel>;
      final genres = results[1] as List<NovelGenreModel>;
      final bookmarks = results[2] as List<NovelItemModel>;

      if (!mounted) return;
      setState(() {
        _novels = homeData.items;
        _hasNext = homeData.hasNext;
        _genres = genres;
        _bookmarks = bookmarks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar web novel: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final res = await _repo.getNovelHome(
        page: nextPage,
        type: _selectedType,
        status: _selectedStatus,
      );
      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _novels.addAll(res.items);
        _hasNext = res.hasNext;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(NovelItemModel item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelDetailScreen(
          slug: item.slug,
          initialTitle: item.title,
          initialPoster: item.poster,
        ),
      ),
    ).then((_) {
      _repo.getBookmarks().then((bm) {
        if (mounted) setState(() => _bookmarks = bm);
      });
    });
  }

  void _openSearch([String? genre]) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelSearchScreen(initialGenre: genre),
      ),
    );
  }

  void _openGenreDetail(NovelGenreModel genre) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelGenreDetailScreen(genre: genre),
      ),
    );
  }

  void _openGenreList() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const NovelGenreListScreen(),
      ),
    );
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final sliderItems = _novels.take(6).map((n) {
      return FeaturedContentItem(
        title: n.displayTitle,
        imageUrl: n.effectivePosterUrl,
        eyebrowTag: 'WEB NOVEL',
        subtitle: n.latestChapter.isNotEmpty
            ? '${n.latestChapter} • ${n.type.isNotEmpty ? n.type : "Novel"}'
            : (n.type.isNotEmpty ? n.type : 'Terjemahan Baru'),
        badge: n.rating > 0 ? '★ ${n.rating.toStringAsFixed(1)}' : null,
        actionIcon: CupertinoIcons.book_fill,
        actionLabel: 'Baca',
        secondaryActionLabel: 'Detail',
        onSecondaryTap: () => _openDetail(n),
        accentColor: const Color(0xFF0A84FF),
        onTap: () => _openDetail(n),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: RefreshIndicator(
              color: isDark ? Colors.white : Colors.black,
              onRefresh: () => _loadInitialData(forceRefresh: true),
              child: CustomScrollView(
                controller: _scrollController,
                scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Apple iOS Large Title App Bar (Matches Comic)
                  SliverAppBar(
                    expandedHeight: 112,
                    pinned: true,
                    stretch: true,
                    backgroundColor: isDark
                        ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                        : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    leading: Navigator.canPop(context)
                        ? Center(
                            child: _buildIosActionButton(
                              icon: CupertinoIcons.back,
                              tooltip: 'Kembali',
                              onTap: () => Navigator.pop(context),
                            ),
                          )
                        : null,
                    flexibleSpace: LayoutBuilder(
                      builder: (ctx, c) {
                        final shrink = 1 -
                            ((c.maxHeight - kToolbarHeight) / (112 - kToolbarHeight))
                                .clamp(0.0, 1.0);
                        final isShrunk = shrink > 0.6;
                        return FlexibleSpaceBar(
                          centerTitle: isShrunk,
                          titlePadding: EdgeInsets.only(
                            left: isShrunk ? (Navigator.canPop(context) ? 48 : 0) : 16,
                            right: isShrunk ? 0 : 16,
                            bottom: isShrunk ? 13 : 12,
                          ),
                          title: Text(
                            'Web Novel',
                            style: TextStyle(
                              fontSize: isShrunk ? 17 : 32,
                              fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                              color: isDark
                                  ? AppColors.iosTextPrimaryDark
                                  : AppColors.iosTextPrimaryLight,
                              letterSpacing: isShrunk ? -0.4 : -1.0,
                            ),
                          ),
                        );
                      },
                    ),
                    actions: [
                      _buildIosActionButton(
                        icon: CupertinoIcons.search,
                        tooltip: 'Cari Novel',
                        onTap: () => _openSearch(),
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.textformat_abc,
                        tooltip: 'Daftar Novel (A-Z)',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const NovelDaftarScreen(),
                          ),
                        ),
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.bookmark,
                        tooltip: 'Bookmark Novel',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const UnifiedBookmarksScreen(
                              initialType: BookmarkType.novel,
                            ),
                          ),
                        ).then((_) {
                          _repo.getBookmarks().then((bm) {
                            if (mounted) setState(() => _bookmarks = bm);
                          });
                        }),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  // Featured Latest Novel Hero Slider (shown on "Semua")
                  if (_selectedType == null && _selectedStatus == null)
                    SliverToBoxAdapter(
                      child: FeaturedContentSlider(
                        items: sliderItems,
                        isLoading: _loading,
                      ),
                    ),

                  // Quick Genre Discovery (shown on "Semua")
                  if (_selectedType == null && _selectedStatus == null)
                    SliverToBoxAdapter(
                      child: _buildGenreSection(isDark),
                    ),

                  // Bookmarks / Penanda Saya (shown on "Semua")
                  if (_selectedType == null && _selectedStatus == null && _bookmarks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildBookmarksSection(isDark),
                    ),

                  // Rekomendasi & Populer (shown on "Semua")
                  if (_selectedType == null && _selectedStatus == null && _novels.length > 5)
                    SliverToBoxAdapter(
                      child: _buildRecommendedSection(isDark),
                    ),

                  // Header with Segmented Submenu Tabs (Semua | Light Novel | Web Novel | Tamat)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getHeaderTitle(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: isDark
                                            ? AppColors.iosTextPrimaryDark
                                            : AppColors.iosTextPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getHeaderSubtitle(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.iosTextTertiaryDark
                                            : AppColors.iosTextTertiaryLight,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Color(0xFF34C759),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // iOS Segmented Submenu Tabs
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildSubmenuTab('Semua', null, null, isDark),
                                _buildSubmenuTab('Light Novel', 'Light Novel', null, isDark),
                                _buildSubmenuTab('Web Novel', 'Web Novel', null, isDark),
                                _buildSubmenuTab('Tamat', null, 'completed', isDark),
                              ],
                            ),
                          ),

                          // Shortcut to full A-Z Directory
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const NovelDaftarScreen(),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.textformat_abc,
                                      size: 18,
                                      color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Direktori Novel A - Z',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                              color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '350+ judul lengkap berdasarkan abjad dan tipe',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 13,
                                      color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading State (Shimmer matching Comic)
                  if (_loading && _novels.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.gridColumns(context),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const ShimmerPlaceholder(
                            height: 204,
                            borderRadius: 14,
                          ),
                          childCount: 8,
                        ),
                      ),
                    )
                  // Error State
                  else if (_error != null && _novels.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                size: 48,
                                color: Colors.orange.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 18),
                              CupertinoButton(
                                color: isDark ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () => _loadInitialData(forceRefresh: true),
                                child: Text(
                                  'Coba Lagi',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  // Empty State
                  else if (!_loading && _novels.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Tidak ada novel ditemukan untuk kategori ini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  // Novel Items Grid (Matches Comic 1:1)
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.gridColumns(context),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final item = _novels[idx];
                            return PosterCard(
                              title: item.displayTitle,
                              imageUrl: item.effectivePosterUrl,
                              score: item.rating > 0
                                  ? item.rating.toStringAsFixed(1)
                                  : null,
                              badge: item.cleanLatestChapter.isNotEmpty
                                  ? item.cleanLatestChapter
                                  : (item.status.isNotEmpty ? item.status : null),
                              onTap: () => _openDetail(item),
                            );
                          },
                          childCount: _novels.length,
                        ),
                      ),
                    ),

                  // Loading More Indicator
                  if (_loadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CupertinoActivityIndicator(
                            radius: 12,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreSection(bool isDark) {
    const List<Map<String, dynamic>> defaultGenres = [
      {'name': 'Action', 'slug': 'action', 'count': 199},
      {'name': 'Romance', 'slug': 'romance', 'count': 264},
      {'name': 'Fantasy', 'slug': 'fantasy', 'count': 225},
      {'name': 'Comedy', 'slug': 'comedy', 'count': 214},
      {'name': 'Harem', 'slug': 'harem', 'count': 197},
      {'name': 'Adventure', 'slug': 'adventure', 'count': 171},
      {'name': 'School Life', 'slug': 'school-life', 'count': 147},
      {'name': 'Drama', 'slug': 'drama', 'count': 110},
      {'name': 'Slice of Life', 'slug': 'slice-of-life', 'count': 104},
      {'name': 'Shounen', 'slug': 'shounen', 'count': 74},
      {'name': 'Supernatural', 'slug': 'supernatural', 'count': 54},
      {'name': 'Ecchi', 'slug': 'ecchi', 'count': 47},
      {'name': 'Martial Arts', 'slug': 'martial-arts', 'count': 45},
      {'name': 'Seinen', 'slug': 'seinen', 'count': 42},
      {'name': 'Mature', 'slug': 'mature', 'count': 36},
      {'name': 'Psychological', 'slug': 'psychological', 'count': 32},
      {'name': 'Adult', 'slug': 'adult', 'count': 30},
      {'name': 'Mystery', 'slug': 'mystery', 'count': 30},
      {'name': 'Xianxia', 'slug': 'xianxia', 'count': 27},
      {'name': 'Xuanhuan', 'slug': 'xuanhuan', 'count': 19},
      {'name': 'Tragedy', 'slug': 'tragedy', 'count': 18},
      {'name': 'Sci-fi', 'slug': 'sci-fi', 'count': 13},
      {'name': 'Wuxia', 'slug': 'wuxia', 'count': 10},
      {'name': 'Gender Bender', 'slug': 'gender-bender', 'count': 6},
      {'name': 'Horror', 'slug': 'horror', 'count': 5},
      {'name': 'Shoujo', 'slug': 'shoujo', 'count': 3},
      {'name': 'Mecha', 'slug': 'mecha', 'count': 3},
      {'name': 'Smut', 'slug': 'smut', 'count': 2},
      {'name': 'Josei', 'slug': 'josei', 'count': 2},
      {'name': 'Transmigration', 'slug': 'transmigration', 'count': 1},
      {'name': 'Male Protagonist', 'slug': 'male-protagonist', 'count': 1},
      {'name': 'Historical', 'slug': 'historical', 'count': 1},
      {'name': 'Heroes', 'slug': 'heroes', 'count': 1},
      {'name': 'Protagonist Strong from the Start', 'slug': 'protagonist-strong-from-the-start', 'count': 1},
      {'name': 'Yuri', 'slug': 'yuri', 'count': 1},
    ];

    final List<NovelGenreModel> genresToDisplay = _genres.isNotEmpty
        ? _genres
        : defaultGenres
            .map(
              (g) => NovelGenreModel(
                name: g['name'] as String,
                slug: g['slug'] as String,
                count: g['count'] as int,
              ),
            )
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jelajahi Genre',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark
                      ? AppColors.iosTextPrimaryDark
                      : AppColors.iosTextPrimaryLight,
                ),
              ),
              BouncyTap(
                onTap: _openGenreList,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
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
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: genresToDisplay.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final g = genresToDisplay[i];
                return BouncyTap(
                  onTap: () => _openGenreDetail(g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E22)
                          : const Color(0xFFEBEBF0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1D1D1F),
                          ),
                        ),
                        if (g.count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.black.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${g.count}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildBookmarksSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.bookmark_fill, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Bookmark Saya',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: isDark
                          ? AppColors.iosTextPrimaryDark
                          : AppColors.iosTextPrimaryLight,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const UnifiedBookmarksScreen(
                      initialType: BookmarkType.novel,
                    ),
                  ),
                ).then((_) {
                  _repo.getBookmarks().then((bm) {
                    if (mounted) setState(() => _bookmarks = bm);
                  });
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Semua (${_bookmarks.length})',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
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
          const SizedBox(height: 12),
          SizedBox(
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _bookmarks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final b = _bookmarks[i];
                return PosterCard(
                  title: b.displayTitle,
                  imageUrl: b.effectivePosterUrl,
                  width: 140,
                  score: b.rating > 0 ? b.rating.toStringAsFixed(1) : null,
                  badge: b.type.isNotEmpty ? b.type : null,
                  onTap: () => _openDetail(b),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(bool isDark) {
    final recs = _novels.skip(5).take(10).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.flame_fill, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text(
                'Populer & Rekomendasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark
                      ? AppColors.iosTextPrimaryDark
                      : AppColors.iosTextPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = recs[i];
                return PosterCard(
                  title: item.displayTitle,
                  imageUrl: item.effectivePosterUrl,
                  width: 140,
                  score: item.rating > 0 ? item.rating.toStringAsFixed(1) : null,
                  badge: item.status.isNotEmpty ? item.status : null,
                  onTap: () => _openDetail(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    if (_selectedType == 'Light Novel') return 'Daftar Light Novel';
    if (_selectedType == 'Web Novel') return 'Daftar Web Novel';
    if (_selectedStatus == 'completed') return 'Novel Tamat';
    return 'Rilis & Update Terbaru';
  }

  String _getHeaderSubtitle() {
    if (_selectedType == 'Light Novel') return 'Koleksi Light Novel Jepang pilihan terjemahan Indonesia';
    if (_selectedType == 'Web Novel') return 'Koleksi Web Novel terpopuler update terbaru';
    if (_selectedStatus == 'completed') return 'Koleksi serial novel yang sudah tamat & lengkap';
    return 'Chapter novel baru terjemahan Bahasa Indonesia';
  }

  Widget _buildSubmenuTab(String title, String? type, String? status, bool isDark) {
    final isSelected = _selectedType == type && _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onSubmenuChanged(type, status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white54 : Colors.black54),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onSubmenuChanged(String? type, String? status) {
    if (_selectedType == type && _selectedStatus == status) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = type;
      _selectedStatus = status;
    });
    _loadInitialData();
  }
}

