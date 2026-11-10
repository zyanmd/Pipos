import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../data/anime_repository.dart';
import '../data/models/anime_model.dart';
import 'anime_detail_screen.dart';

/// Apple iOS HIG Catalog Screen for Newly Uploaded Anime (GET /ylnime/new-releases).
/// Features real API pagination, search filter, grid/list view toggle, and hero card styling.
class AnimeNewReleasesScreen extends StatefulWidget {
  const AnimeNewReleasesScreen({super.key});

  @override
  State<AnimeNewReleasesScreen> createState() => _AnimeNewReleasesScreenState();
}

class _AnimeNewReleasesScreenState extends State<AnimeNewReleasesScreen> {
  final _repo = AnimeRepository.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<AnimeModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _currentPage = 1;
  int _totalPages = 1;
  String _title = 'Baru Diupload';
  String _description =
      'Episode & anime paling gres yang baru masuk — tonton duluan sebelum yang lain!';
  String? _error;
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_loading &&
        !_loadingMore &&
        _hasNext) {
      _loadMore();
    }
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.newReleases(page: page);
      if (!mounted) return;

      setState(() {
        _items = res.animeList;
        _currentPage = res.currentPage;
        _totalPages = res.totalPages;
        _hasNext = res.hasNext || (res.animeList.isNotEmpty && res.currentPage < res.totalPages);
        if (res.title.isNotEmpty) _title = res.title;
        if (res.description != null && res.description!.isNotEmpty) {
          _description = res.description!;
        }
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final res = await _repo.newReleases(page: nextPage);
      if (!mounted) return;

      setState(() {
        if (res.animeList.isEmpty) {
          _hasNext = false;
        } else {
          // Deduplicate by id or title
          final seen = _items.map((e) => e.id.isNotEmpty ? e.id : e.title).toSet();
          final newItems = res.animeList.where((e) {
            final key = e.id.isNotEmpty ? e.id : e.title;
            return !seen.contains(key);
          }).toList();

          _items.addAll(newItems);
          _currentPage = res.currentPage;
          _totalPages = res.totalPages;
          _hasNext = res.hasNext;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<AnimeModel> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items
        .where((a) => a.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
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
              size: 18,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          color: isDark ? Colors.white : Colors.black,
          edgeOffset: 112,
          onRefresh: () => _loadPage(1),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // iOS Large Title SliverAppBar
              SliverAppBar(
                expandedHeight: 112,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                    : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                leading: Navigator.canPop(context)
                    ? CupertinoNavigationBarBackButton(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null,
                actions: [
                  _buildIosActionButton(
                    icon: _isGridView
                        ? CupertinoIcons.list_bullet
                        : CupertinoIcons.square_grid_2x2,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isGridView = !_isGridView);
                    },
                    isDark: isDark,
                  ),
                  _buildIosActionButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _loadPage(1);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final currentHeight = constraints.maxHeight;
                    const minHeight = kToolbarHeight;
                    const maxHeight = 112.0;
                    final shrinkProgress = (1 -
                            ((currentHeight - minHeight) / (maxHeight - minHeight)))
                        .clamp(0.0, 1.0);
                    final isShrunk = shrinkProgress > 0.6;

                    return FlexibleSpaceBar(
                      centerTitle: isShrunk,
                      titlePadding: EdgeInsets.only(
                        left: isShrunk ? 56 : 16,
                        right: 16,
                        bottom: 14,
                      ),
                      title: Text(
                        _title,
                        style: TextStyle(
                          fontSize: isShrunk ? 17 : 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: isShrunk ? -0.3 : -0.7,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Subtitle & Info Pill Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E).withValues(alpha: 0.75)
                          : const Color(0xFFF2F2F7).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34C759), Color(0xFF30D158)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.sparkles,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _description,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : Colors.black87,
                                ),
                              ),
                              if (_items.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Halaman $_currentPage dari $_totalPages (${_items.length} anime)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.black45,
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

              // Search Bar Filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.iosHairlineDark
                            : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari di anime baru diupload...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          size: 17,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),

              // Ad Banner Section
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: AdBannerWidget(),
                ),
              ),

              // Content List or Grid
              if (_loading && _items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) => const AnimeCardSkeleton(),
                      childCount: 12,
                    ),
                  ),
                )
              else if (_error != null && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ErrorState(
                      message: _error!,
                      onRetry: () => _loadPage(1),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.film,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Tidak ada anime dengan kata kunci "$_searchQuery"'
                                : 'Belum ada anime baru diupload saat ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final a = filtered[idx];
                        return PosterCard(
                          title: a.title,
                          imageUrl: a.thumb,
                          badge: a.episode != null
                              ? AnimeModel.formatEpisode(a.episode)
                              : 'Baru',
                          score: a.score,
                          subtitle: a.status ?? 'Rilis Baru',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => AnimeDetailScreen(animeId: a.id),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final a = filtered[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => AnimeDetailScreen(animeId: a.id),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 65,
                                      height: 90,
                                      child: AppNetworkImage(
                                        url: a.thumb,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (a.episode != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2,),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF34C759)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  AnimeModel.formatEpisode(a.episode),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF34C759),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 6),
                                            Text(
                                              a.status ?? 'Rilis Baru',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),

              // Bottom Loading Indicator for Infinite Scroll
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  ),
                ),

              // Safe bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
