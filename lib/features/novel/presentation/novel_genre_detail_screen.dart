import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';
import 'novel_detail_screen.dart';

/// Screen for browsing novels of a specific Sakuranovel Genre
/// (e.g. Action, Romance, Fantasy) with continuous pagination.
class NovelGenreDetailScreen extends StatefulWidget {
  final NovelGenreModel genre;

  const NovelGenreDetailScreen({
    super.key,
    required this.genre,
  });

  @override
  State<NovelGenreDetailScreen> createState() => _NovelGenreDetailScreenState();
}

class _NovelGenreDetailScreenState extends State<NovelGenreDetailScreen> {
  final _repo = NovelRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<NovelItemModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _currentPage = 1;
  String? _error;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 350) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final res = await _repo.getNovelsByGenrePaginated(
        widget.genre.slug,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _hasNext = res.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat genre ${widget.genre.name}: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);

    final nextPage = _currentPage + 1;
    try {
      final res = await _repo.getNovelsByGenrePaginated(
        widget.genre.slug,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _navigateToDetail(NovelItemModel item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelDetailScreen(
          slug: item.slug,
          initialTitle: item.title,
          initialPoster: item.poster,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D10) : const Color(0xFFF6F6F9);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: isDark ? Colors.white : Colors.black,
          backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
          onRefresh: _loadInitial,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildSliverAppBar(isDark),
              if (_loading)
                SliverToBoxAdapter(child: _buildLoadingShimmer(isDark))
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorView(isDark),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyView(isDark),
                )
              else ...[
                if (_isGridView)
                  _buildSliverGrid(isDark)
                else
                  _buildSliverList(isDark),
                if (_loadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CupertinoActivityIndicator(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF0D0D10).withValues(alpha: 0.88)
          : const Color(0xFFF6F6F9).withValues(alpha: 0.88),
      expandedHeight: 120,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
        child: BouncyTap(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEBEBF0),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isGridView = !_isGridView);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEBEBF0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isGridView
                        ? CupertinoIcons.rectangle_grid_1x2
                        : CupertinoIcons.square_grid_2x2,
                    size: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isGridView ? 'List' : 'Grid',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                widget.genre.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                ),
              ),
            ),
            if (widget.genre.count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.genre.count}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliverGrid(bool isDark) {
    final cols = Responsive.gridColumns(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = _items[i];
            return BouncyTap(
              onTap: () => _navigateToDetail(item),
              child: PosterCard(
                title: item.title,
                imageUrl: item.poster,
                score: item.rating > 0 ? item.rating.toStringAsFixed(1) : null,
                badge: item.type.isNotEmpty ? item.type : item.status,
                onTap: () => _navigateToDetail(item),
              ),
            );
          },
          childCount: _items.length,
        ),
      ),
    );
  }

  Widget _buildSliverList(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = _items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BouncyTap(
                onTap: () => _navigateToDetail(item),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16161A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 60,
                          height: 84,
                          child: PosterCard(
                            title: '',
                            imageUrl: item.poster,
                            onTap: () => _navigateToDetail(item),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (item.type.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.type,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                if (item.status.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    item.status,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (item.rating > 0) ...[
                                  const Icon(
                                    CupertinoIcons.star_fill,
                                    size: 11,
                                    color: Color(0xFFFFB800),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.rating.toStringAsFixed(1),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: _items.length,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
    final cols = Responsive.gridColumns(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: 8,
        itemBuilder: (_, __) => ShimmerPlaceholder(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 12.0,
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 46,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            BouncyTap(
              onTap: _loadInitial,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEBEBF0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.book,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada novel di genre ${widget.genre.name}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
