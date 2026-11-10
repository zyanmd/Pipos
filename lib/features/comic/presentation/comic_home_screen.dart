import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../comic/presentation/comic_search_screen.dart';
import '../../comic/presentation/comic_daftar_screen.dart';
import '../../novel/presentation/novel_home_screen.dart';
import '../../anime/data/models/anime_model.dart' show GenreModel;
import '../../genre/presentation/unified_genre_screen.dart';
import '../../genre/presentation/genre_detail_screen.dart';
import '../../../shared/widgets/featured_content_slider.dart';
import '../../chat/presentation/widgets/chat_marquee_banner.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../notifications/presentation/widgets/universal_notification_button.dart';
import '../../announcement/presentation/widgets/announcement_banner.dart';

class ComicHomeScreen extends StatefulWidget {
  const ComicHomeScreen({super.key});

  @override
  State<ComicHomeScreen> createState() => _ComicHomeScreenState();
}

class _ComicHomeScreenState extends State<ComicHomeScreen> {
  static const List<Map<String, String>> _popularComicGenres = [
    {'name': 'Romance', 'slug': 'romance'},
    {'name': 'Action', 'slug': 'action'},
    {'name': 'Shounen', 'slug': 'shounen'},
    {'name': 'Manhwa', 'slug': 'manhwa'},
    {'name': 'Fantasy', 'slug': 'fantasy'},
    {'name': 'Reincarnation', 'slug': 'reincarnation'},
    {'name': 'Supernatural', 'slug': 'supernatural'},
    {'name': 'School Life', 'slug': 'school-life'},
    {'name': 'Comedy', 'slug': 'comedy'},
  ];

  final _repo = ComicRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<ComicModel> _populer = [];
  List<ComicModel> _terbaru = [];
  List<GenreModel> _allGenres = [];

  bool _loading = true;
  bool _loadingTerbaru = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Filter parameters for /comic/terbaru
  String? _selectedTipe; // null (semua), 'manga', 'manhwa', 'manhua'
  String? _selectedStatus; // null (semua), 'ongoing', 'end'
  String _selectedOrderby = 'modified'; // 'modified' (terupdate), 'date' (terbaru)
  String? _selectedGenre; // genre slug
  String? _selectedGenreName;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingTerbaru || _loadingMore || !_hasMore) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 350) {
      _loadMoreTerbaru();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        _repo.populer(),
        _repo.terbaru(
          tipe: _selectedTipe,
          genre: _selectedGenre,
          status: _selectedStatus,
          orderby: _selectedOrderby,
          page: 1,
        ),
        _repo.genres(),
      ]);
      if (!mounted) return;
      setState(() {
        _populer = results[0] as List<ComicModel>;
        _terbaru = results[1] as List<ComicModel>;
        _allGenres = results[2] as List<GenreModel>;
        _hasMore = _terbaru.length >= 10;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _repo.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadTerbaru({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _loadingTerbaru = true;
      });
    }
    try {
      final list = await _repo.terbaru(
        tipe: _selectedTipe,
        genre: _selectedGenre,
        status: _selectedStatus,
        orderby: _selectedOrderby,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _terbaru = list;
        _hasMore = list.length >= 10;
        _loadingTerbaru = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTerbaru = false;
      });
    }
  }

  Future<void> _loadMoreTerbaru() async {
    if (_loadingMore || !_hasMore || _loadingTerbaru) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final more = await _repo.terbaru(
        tipe: _selectedTipe,
        genre: _selectedGenre,
        status: _selectedStatus,
        orderby: _selectedOrderby,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        if (more.isEmpty) {
          _hasMore = false;
        } else {
          final existingSlugs = _terbaru.map((c) => c.slug).toSet();
          final uniqueNew = more.where((c) => !existingSlugs.contains(c.slug)).toList();
          _terbaru.addAll(uniqueNew);
          if (more.length < 10) {
            _hasMore = false;
          }
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _onTipeChanged(String? newTipe) {
    if (_selectedTipe == newTipe) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTipe = newTipe;
    });
    _loadTerbaru(reset: true);
  }

  void _onStatusChanged(String? newStatus) {
    if (_selectedStatus == newStatus) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStatus = newStatus;
    });
    _loadTerbaru(reset: true);
  }

  void _onOrderbyChanged(String newOrderby) {
    if (_selectedOrderby == newOrderby) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOrderby = newOrderby;
    });
    _loadTerbaru(reset: true);
  }

  void _onGenreSelected(String? slug, String? name) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGenre = slug;
      _selectedGenreName = name;
    });
    _loadTerbaru(reset: true);
  }

  void _resetAllFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTipe = null;
      _selectedStatus = null;
      _selectedOrderby = 'modified';
      _selectedGenre = null;
      _selectedGenreName = null;
    });
    _loadTerbaru(reset: true);
  }

  bool get _hasActiveFilters =>
      _selectedTipe != null ||
      _selectedStatus != null ||
      _selectedGenre != null ||
      _selectedOrderby != 'modified';

  // Action Sheet for Status Filter
  void _showStatusActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Pilih Status Komik'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _selectedStatus == null,
            onPressed: () {
              Navigator.pop(ctx);
              _onStatusChanged(null);
            },
            child: const Text('Semua Status'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _selectedStatus == 'ongoing',
            onPressed: () {
              Navigator.pop(ctx);
              _onStatusChanged('ongoing');
            },
            child: const Text('Ongoing (Berjalan)'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _selectedStatus == 'end',
            onPressed: () {
              Navigator.pop(ctx);
              _onStatusChanged('end');
            },
            child: const Text('Tamat (Completed)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  // Action Sheet for Order By Filter
  void _showOrderbyActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Urutkan Komik'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _selectedOrderby == 'modified',
            onPressed: () {
              Navigator.pop(ctx);
              _onOrderbyChanged('modified');
            },
            child: const Text('Terupdate (Modified)'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _selectedOrderby == 'date',
            onPressed: () {
              Navigator.pop(ctx);
              _onOrderbyChanged('date');
            },
            child: const Text('Terbaru Rilis (Date)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  // Modal Sheet for Genre Picker with Search
  void _showGenrePickerSheet(BuildContext context, bool isDark) {
    HapticFeedback.selectionClick();
    final genresToDisplay = _allGenres.isNotEmpty
        ? _allGenres
        : _popularComicGenres.map((e) => GenreModel(name: e['name']!, slug: e['slug']!)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => _GenrePickerModal(
        isDark: isDark,
        genres: genresToDisplay,
        currentGenreSlug: _selectedGenre,
        onSelected: (genre) {
          Navigator.pop(ctx);
          if (genre == null) {
            _onGenreSelected(null, null);
          } else {
            _onGenreSelected(genre.slug, genre.name);
          }
        },
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

    final featuredComics = _terbaru.isNotEmpty ? _terbaru : _populer;
    final sliderItems = featuredComics.take(6).map((c) {
      final isNew = _terbaru.contains(c);
      return FeaturedContentItem(
        title: c.title,
        imageUrl: c.thumb,
        eyebrowTag: isNew ? 'RILISAN TERBARU' : 'KOMIK POPULER',
        subtitle: c.latestChapter != null
            ? '${c.latestChapter} • ${c.type ?? "Komik"}'
            : (c.type ?? 'Rilisan Baru'),
        badge: c.rating != null && c.rating!.isNotEmpty ? '★ ${c.rating}' : null,
        actionIcon: CupertinoIcons.book_fill,
        actionLabel: 'Baca',
        secondaryActionLabel: 'Detail',
        onSecondaryTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ComicDetailScreen(slug: c.slug, comic: c),
          ),
        ),
        accentColor: isNew ? const Color(0xFF0A84FF) : const Color(0xFFFFD60A),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ComicDetailScreen(slug: c.slug, comic: c),
          ),
        ),
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
              onRefresh: _load,
              child: CustomScrollView(
            controller: _scrollController,
            scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Apple iOS Large Title App Bar
              SliverAppBar(
                expandedHeight: 112,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                    : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: LayoutBuilder(
                  builder: (ctx, c) {
                    final shrink = 1 -
                        ((c.maxHeight - kToolbarHeight) / (112 - kToolbarHeight))
                            .clamp(0.0, 1.0);
                    final isShrunk = shrink > 0.6;
                    return FlexibleSpaceBar(
                      centerTitle: isShrunk,
                      titlePadding: EdgeInsets.only(
                        left: isShrunk ? 0 : 16,
                        right: isShrunk ? 0 : 16,
                        bottom: isShrunk ? 13 : 12,
                      ),
                      title: Text(
                        'Komik',
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
                  const UniversalNotificationButton(),
                  _buildIosActionButton(
                    icon: CupertinoIcons.search,
                    tooltip: 'Cari Komik',
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const ComicSearchScreen(),
                      ),
                    ),
                  ),
                  _buildIosActionButton(
                    icon: CupertinoIcons.textformat_abc,
                    tooltip: 'Daftar Komik (A-Z)',
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const ComicDaftarScreen(),
                      ),
                    ),
                  ),
                  _buildIosActionButton(
                    icon: CupertinoIcons.text_quote,
                    tooltip: 'Web Novel',
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const NovelHomeScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),

              // Featured Latest Comic Hero Slider
              SliverToBoxAdapter(
                child: FeaturedContentSlider(
                  items: sliderItems,
                  isLoading: _loading,
                ),
              ),

              // Pemberitahuan / Announcement Banner
              const SliverToBoxAdapter(
                child: AnnouncementBanner(),
              ),

              // Chat Komunitas Running Text Banner
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: ChatMarqueeBanner(),
                ),
              ),

              // Quick Web Novel Gateway
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const NovelHomeScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14141A) : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.text_quote,
                              size: 16,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Web Novel',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'BARU',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Jelajahi ribuan novel terjemahan Bahasa Indonesia',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 15,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Genre Discovery
              SliverToBoxAdapter(
                child: Padding(
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
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const UnifiedGenreScreen(initialType: GenreType.comic),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lihat Semua',
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
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularComicGenres.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final g = _popularComicGenres[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => GenreDetailScreen(
                                    genre: GenreModel(slug: g['slug']!, name: g['name']!),
                                    isAnime: false,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.iosCardDark
                                      : AppColors.iosCardLight,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.iosHairlineDark
                                        : AppColors.iosHairlineLight,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    g['name']!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                      color: isDark
                                          ? AppColors.iosTextPrimaryDark
                                          : AppColors.iosTextPrimaryLight,
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
                ),
              ),

              // Banner / CTA Daftar Komik A-Z
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const ComicDaftarScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  AppColors.iosCardDark,
                                  const Color(0xFF1F1B2E),
                                ]
                              : [
                                  Colors.white,
                                  const Color(0xFFF3F0FA),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? const [Colors.white, Color(0xFFE5E5EA)]
                                    : const [Color(0xFF000000), Color(0xFF2C2C2E)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.15 : 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              CupertinoIcons.textformat_abc,
                              color: isDark ? Colors.black : Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Komik A-Z',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: isDark
                                        ? AppColors.iosTextPrimaryDark
                                        : AppColors.iosTextPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Jelajahi seluruh manga, manhwa & manhua',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.iosTextSecondaryDark
                                        : AppColors.iosTextSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),


              if (_loading) ...[
                const SliverToBoxAdapter(child: SectionHeader(title: 'Populer')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (c, i) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: AnimeCardSkeleton(),
                      ),
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                SliverToBoxAdapter(
                  child: ErrorState(message: _error!, onRetry: _load),
                ),
              ] else ...[
                // Komik Populer Carousel
                if (_populer.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Komik Populer',
                          subtitle: 'Banyak dibaca minggu ini',
                        ),
                        SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _populer.length,
                            itemBuilder: (ctx, i) {
                              final c = _populer[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ComicCard(
                                  comic: c,
                                  badge: c.rating != null
                                      ? '★ ${c.rating}'
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),


                // Rilisan Terbaru Header & Interactive Filter Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rilisan Terbaru',
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
                                  'Chapter baru rilis dengan filter lengkap',
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
                            if (_hasActiveFilters)
                              GestureDetector(
                                onTap: _resetAllFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.clear_circled_solid, size: 12, color: Color(0xFFFF3B30)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Reset',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFF3B30),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Tipe Segmented Control (Semua, Manga, Manhwa, Manhua)
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
                              _buildTipeTab('Semua', null, isDark),
                              _buildTipeTab('Manga', 'manga', isDark),
                              _buildTipeTab('Manhwa', 'manhwa', isDark),
                              _buildTipeTab('Manhua', 'manhua', isDark),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Sub-filter Chips: Status, Order By, Genre
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Order By Chip
                              _buildFilterChip(
                                label: _selectedOrderby == 'modified' ? 'Terupdate' : 'Terbaru (Rilis)',
                                icon: CupertinoIcons.arrow_up_arrow_down,
                                isActive: _selectedOrderby != 'modified',
                                isDark: isDark,
                                onTap: () => _showOrderbyActionSheet(context),
                              ),

                              const SizedBox(width: 8),

                              // Status Chip
                              _buildFilterChip(
                                label: _selectedStatus == null
                                    ? 'Status'
                                    : (_selectedStatus == 'ongoing' ? 'Ongoing' : 'Tamat'),
                                icon: CupertinoIcons.check_mark_circled,
                                isActive: _selectedStatus != null,
                                isDark: isDark,
                                onTap: () => _showStatusActionSheet(context),
                                onClear: _selectedStatus != null ? () => _onStatusChanged(null) : null,
                              ),

                              const SizedBox(width: 8),

                              // Genre Chip
                              _buildFilterChip(
                                label: _selectedGenreName ?? 'Genre',
                                icon: CupertinoIcons.slider_horizontal_3,
                                isActive: _selectedGenre != null,
                                isDark: isDark,
                                onTap: () => _showGenrePickerSheet(context, isDark),
                                onClear: _selectedGenre != null ? () => _onGenreSelected(null, null) : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                // Grid of Latest Comics with live filter updates
                if (_loadingTerbaru)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => const AnimeCardSkeleton(),
                        childCount: 6,
                      ),
                    ),
                  )
                else if (_terbaru.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.book,
                            size: 44,
                            color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tidak Ada Komik Ditemukan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coba ubah kombinasi tipe, status, atau genre yang dipilih.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _resetAllFilters,
                            child: Text(
                              'Reset Filter',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
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
                        (ctx, i) {
                          final c = _terbaru[i];
                          return ComicCard(
                            comic: c,
                            width: double.infinity,
                          );
                        },
                        childCount: _terbaru.length,
                      ),
                    ),
                  ),

                // Infinite Scroll Loading / End Indicator
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 12),
                      ),
                    ),
                  )
                else if (!_hasMore && _terbaru.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Semua komik telah ditampilkan',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],

              const SliverToBoxAdapter(
                child: AdBannerWidget(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: Responsive.bottomNavPadding(context))),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  // Segmented Tab for Tipe
  Widget _buildTipeTab(String title, String? value, bool isDark) {
    final isSelected = _selectedTipe == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTipeChanged(value),
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
              style: TextStyle(
                fontSize: 13,
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

  // Filter Pill Chip
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? AppColors.iosCardDark : AppColors.iosCardLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight),
                letterSpacing: -0.2,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 13,
                  color: isActive ? (isDark ? Colors.black54 : Colors.white70) : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet for selecting Comic Genres with live instant search
class _GenrePickerModal extends StatefulWidget {
  final bool isDark;
  final List<GenreModel> genres;
  final String? currentGenreSlug;
  final ValueChanged<GenreModel?> onSelected;

  const _GenrePickerModal({
    required this.isDark,
    required this.genres,
    required this.currentGenreSlug,
    required this.onSelected,
  });

  @override
  State<_GenrePickerModal> createState() => _GenrePickerModalState();
}

class _GenrePickerModalState extends State<_GenrePickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<GenreModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.genres;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.genres;
      } else {
        _filtered = widget.genres
            .where((g) => g.name.toLowerCase().contains(query) || g.slug.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Title & Reset Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Genre Komik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (widget.currentGenreSlug != null)
                  GestureDetector(
                    onTap: () => widget.onSelected(null),
                    child: const Text(
                      'Hapus Pilihan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSearchTextField(
              controller: _searchCtrl,
              placeholder: 'Cari genre komik...',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Genre List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                thickness: 0.5,
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (ctx, i) {
                final g = _filtered[i];
                final isSelected = widget.currentGenreSlug == g.slug;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  title: Text(
                    g.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (widget.isDark ? Colors.white : Colors.black)
                          : (widget.isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(CupertinoIcons.checkmark_alt, color: widget.isDark ? Colors.white : Colors.black, size: 18)
                      : null,
                  onTap: () => widget.onSelected(g),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact comic card using PosterCard.
class ComicCard extends StatelessWidget {
  const ComicCard({
    super.key,
    required this.comic,
    this.subtitle,
    this.badge,
    this.width = 140,
  });

  final ComicModel comic;
  final String? subtitle;
  final String? badge;
  final double width;

  @override
  Widget build(BuildContext context) {
    String? displaySubtitle = subtitle ?? comic.latestChapter ?? comic.type;
    if (displaySubtitle != null && displaySubtitle.startsWith('Terbaru:')) {
      displaySubtitle = displaySubtitle.replaceFirst('Terbaru:', '').trim();
    }
    if (displaySubtitle != null && displaySubtitle.startsWith('Awal:')) {
      displaySubtitle = displaySubtitle.replaceFirst('Awal:', '').trim();
    }

    String? displayBadge = badge ?? comic.type;
    String? scoreBadge;
    if (comic.timeAgo != null && comic.timeAgo!.isNotEmpty) {
      scoreBadge = comic.timeAgo;
    } else if (comic.rating != null && comic.rating!.isNotEmpty) {
      scoreBadge = '★ ${comic.rating}';
    }

    return PosterCard(
      title: comic.title,
      imageUrl: comic.thumb,
      subtitle: displaySubtitle,
      badge: displayBadge,
      score: scoreBadge,
      width: width,
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ComicDetailScreen(slug: comic.slug, comic: comic),
        ),
      ),
    );
  }
}
