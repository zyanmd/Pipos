import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_detail_screen.dart';

class GenreDetailScreen extends StatefulWidget {
  final GenreModel genre;
  final bool isAnime;

  const GenreDetailScreen({
    super.key,
    required this.genre,
    this.isAnime = true,
  });

  @override
  State<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends State<GenreDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  List<AnimeModel> _animeItems = [];
  List<ComicModel> _comicItems = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

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
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasMore) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });

    try {
      if (widget.isAnime) {
        final list = await AnimeRepository.instance.byGenre(widget.genre.slug, page: 1);
        if (!mounted) return;
        setState(() {
          _animeItems = list;
          _hasMore = list.isNotEmpty;
          _loading = false;
        });
      } else {
        final list = await ComicRepository.instance.byGenre(widget.genre.slug, page: 1);
        if (!mounted) return;
        setState(() {
          _comicItems = list;
          _hasMore = list.isNotEmpty;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.isAnime
            ? AnimeRepository.instance.errorMessage(e)
            : ComicRepository.instance.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      if (widget.isAnime) {
        final list = await AnimeRepository.instance.byGenre(widget.genre.slug, page: nextPage);
        if (!mounted) return;
        setState(() {
          if (list.isEmpty) {
            _hasMore = false;
          } else {
            _page = nextPage;
            _animeItems.addAll(list);
          }
          _loadingMore = false;
        });
      } else {
        final list = await ComicRepository.instance.byGenre(widget.genre.slug, page: nextPage);
        if (!mounted) return;
        setState(() {
          if (list.isEmpty) {
            _hasMore = false;
          } else {
            _page = nextPage;
            _comicItems.addAll(list);
          }
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 12),
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
    final totalCount = widget.isAnime ? _animeItems.length : _comicItems.length;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: RefreshIndicator(
              color: isDark ? Colors.white : Colors.black,
              edgeOffset: 112,
              onRefresh: _loadInitial,
              child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // iOS Large Title SliverAppBar matching AnimeHomeScreen
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
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _loadInitial();
                    },
                    isDark: isDark,
                  ),
                ],
                flexibleSpace: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final currentHeight = constraints.maxHeight;
                    const minHeight = kToolbarHeight;
                    const maxHeight = 112.0;
                    final shrinkProgress = (1 - ((currentHeight - minHeight) / (maxHeight - minHeight))).clamp(0.0, 1.0);
                    final isShrunk = shrinkProgress > 0.6;

                    return FlexibleSpaceBar(
                      centerTitle: isShrunk,
                      titlePadding: EdgeInsets.only(
                        left: isShrunk ? 0 : 16,
                        right: isShrunk ? 0 : 16,
                        bottom: isShrunk ? 13 : 12,
                      ),
                      title: Row(
                        mainAxisSize: isShrunk ? MainAxisSize.min : MainAxisSize.max,
                        children: [
                          Flexible(
                            child: Text(
                              widget.genre.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isShrunk ? 17 : 32,
                                fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                letterSpacing: isShrunk ? -0.4 : -1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: widget.isAnime
                                  ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.20 : 0.12)
                                  : const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.isAnime
                                    ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35)
                                    : const Color(0xFF0A84FF).withValues(alpha: 0.35),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              widget.isAnime ? 'Anime' : 'Komik',
                              style: TextStyle(
                                color: widget.isAnime ? (isDark ? Colors.white : Colors.black) : const Color(0xFF0A84FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Content Area
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      childAspectRatio: 0.70,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const ShimmerPlaceholder(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 14,
                      ),
                      childCount: 8,
                    ),
                  ),
                )
              else if (_error != null && totalCount == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ErrorState(
                      message: _error!,
                      onRetry: _loadInitial,
                    ),
                  ),
                )
              else if (totalCount == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.film,
                      title: 'Tidak ada konten',
                      subtitle: 'Belum ada ${widget.isAnime ? "anime" : "komik"} untuk genre ini.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      childAspectRatio: 0.70,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (widget.isAnime) {
                          final item = _animeItems[index];
                          return PosterCard(
                            width: double.infinity,
                            title: item.title,
                            imageUrl: item.thumb,
                            badge: item.episode != null && item.episode!.isNotEmpty
                                ? 'Ep ${item.episode}'
                                : (item.status ?? 'Anime'),
                            score: item.score,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => AnimeDetailScreen(
                                    animeId: item.id,
                                    anime: item,
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          final item = _comicItems[index];
                          return PosterCard(
                            width: double.infinity,
                            title: item.title,
                            imageUrl: item.thumb,
                            badge: item.latestChapter ?? item.type,
                            score: item.rating,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => ComicDetailScreen(
                                    slug: ComicModel.extractCleanSlug(item.slug),
                                    comic: item,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                      childCount: totalCount,
                    ),
                  ),
                ),

              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  ),
                ),

              // Bottom clearance for floating navbar
              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.bottomNavPadding(context)),
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
