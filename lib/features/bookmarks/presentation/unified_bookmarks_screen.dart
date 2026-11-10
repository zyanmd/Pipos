import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../novel/data/models/novel_model.dart';
import '../../novel/data/novel_repository.dart';
import '../../novel/presentation/novel_detail_screen.dart';
import '../../../core/services/onesignal_service.dart';
import '../../../shared/widgets/smooth_entrance_transition.dart';

enum BookmarkType { anime, comic, novel }
typedef _Type = BookmarkType;

class UnifiedBookmarksScreen extends StatefulWidget {
  final BookmarkType initialType;
  const UnifiedBookmarksScreen({super.key, this.initialType = BookmarkType.anime});

  @override
  State<UnifiedBookmarksScreen> createState() => _UnifiedBookmarksScreenState();
}

class _UnifiedBookmarksScreenState extends State<UnifiedBookmarksScreen> {
  late BookmarkType _type;
  List<AnimeModel> _anime = [];
  List<ComicModel> _comic = [];
  List<NovelItemModel> _novel = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      // Even if not logged in, user can have local novel bookmarks
      try {
        final novelList = await NovelRepository.instance.getBookmarks();
        if (mounted) {
          setState(() {
            _novel = novelList;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AnimeRepository.instance.bookmarks().catchError((_) => <AnimeModel>[]),
        ComicRepository.instance.bookmarks().catchError((_) => <ComicModel>[]),
        NovelRepository.instance.getBookmarks().catchError((_) => <NovelItemModel>[]),
      ]);
      if (!mounted) return;
      final animeList = results[0] as List<AnimeModel>;
      final bookmarkKeys = <String>[];
      for (final a in animeList) {
        bookmarkKeys.add(a.id);
        if (a.url != null && a.url!.isNotEmpty) {
          final sKey = a.url!.split('series=').last.split('&').first;
          if (sKey.isNotEmpty) bookmarkKeys.add(sKey);
        }
      }
      OneSignalService.syncAllBookmarks(bookmarkKeys);

      final comicList = results[1] as List<ComicModel>;
      final comicSlugs = <String>[];
      for (final c in comicList) {
        if (c.slug.isNotEmpty) comicSlugs.add(c.slug);
      }
      OneSignalService.syncAllComicBookmarks(comicSlugs);

      final novelList = results[2] as List<NovelItemModel>;

      setState(() {
        _anime = animeList;
        _comic = comicList;
        _novel = novelList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _removeNovel(NovelItemModel n) async {
    HapticFeedback.lightImpact();
    try {
      await NovelRepository.instance.removeBookmark(n.slug);
      setState(() => _novel.removeWhere((x) => x.slug == n.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmark novel berhasil dihapus'),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _removeAnime(AnimeModel a) async {
    HapticFeedback.lightImpact();
    try {
      await AnimeRepository.instance.removeBookmark(a.id);
      OneSignalService.syncBookmarkCache(a.id, false);
      if (a.url != null) {
        final sKey = a.url!.split('series=').last.split('&').first;
        if (sKey.isNotEmpty) OneSignalService.syncBookmarkCache(sKey, false);
      }
      setState(() => _anime.removeWhere((x) => x.id == a.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmark anime berhasil dihapus'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(AnimeRepository.instance.errorMessage(e)),
          ),
        );
      }
    }
  }

  Future<void> _removeComic(ComicModel c) async {
    HapticFeedback.lightImpact();
    try {
      await ComicRepository.instance.removeBookmark(c.slug);
      OneSignalService.syncComicBookmarkCache(c.slug, false);
      setState(() => _comic.removeWhere((x) => x.slug == c.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmark komik berhasil dihapus'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(ComicRepository.instance.errorMessage(e)),
          ),
        );
      }
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
    final currentListLength = _type == _Type.anime
        ? _anime.length
        : (_type == _Type.comic ? _comic.length : _novel.length);

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SmoothEntranceTransition(
          child: RefreshIndicator(
          color: isDark ? Colors.white : Colors.black,
          edgeOffset: 112,
          onRefresh: _load,
          child: CustomScrollView(
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
                      _load();
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
                          Text(
                            'Bookmark',
                            style: TextStyle(
                              fontSize: isShrunk ? 17 : 32,
                              fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: isShrunk ? -0.4 : -1.0,
                            ),
                          ),
                          if (!isShrunk && currentListLength > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '$currentListLength',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Segmented Control (Anime vs Komik vs Novel)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CupertinoSlidingSegmentedControl<_Type>(
                      groupValue: _type,
                      backgroundColor: Colors.transparent,
                      thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      children: {
                        _Type.anime: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.play_circle_fill,
                                size: 14,
                                color: _type == _Type.anime
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Anime (${_anime.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _type == _Type.anime
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Type.comic: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.book_fill,
                                size: 14,
                                color: _type == _Type.comic
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Komik (${_comic.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _type == _Type.comic
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Type.novel: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.text_quote,
                                size: 14,
                                color: _type == _Type.novel
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Novel (${_novel.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _type == _Type.novel
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null && val != _type) {
                          HapticFeedback.selectionClick();
                          setState(() => _type = val);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Content Area
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ErrorState(message: _error!, onRetry: _load),
                  ),
                )
              else if (_type == _Type.anime && _anime.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.bookmark,
                      title: 'Belum ada bookmark anime',
                      subtitle: 'Tambahkan anime favoritmu ke bookmark untuk menyimpannya.',
                    ),
                  ),
                )
              else if (_type == _Type.comic && _comic.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.bookmark,
                      title: 'Belum ada bookmark komik',
                      subtitle: 'Tambahkan komik favoritmu ke bookmark untuk membaca nanti.',
                    ),
                  ),
                )
              else if (_type == _Type.novel && _novel.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.text_quote,
                      title: 'Belum ada bookmark novel',
                      subtitle: 'Tambahkan web novel favoritmu ke bookmark untuk melanjutkan nanti.',
                    ),
                  ),
                )
              else if (_type == _Type.anime)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final a = _anime[i];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PosterCard(
                              title: a.title,
                              imageUrl: a.thumb,
                              subtitle: a.status,
                              score: a.score,
                              width: double.infinity,
                              height: double.infinity,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => AnimeDetailScreen(animeId: a.id, anime: a),
                                  ),
                                );
                                _load();
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _removeAnime(a),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: _anime.length,
                    ),
                  ),
                )
              else if (_type == _Type.comic)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final c = _comic[i];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PosterCard(
                              title: c.title,
                              imageUrl: c.thumb,
                              subtitle: c.type ?? c.latestChapter,
                              score: c.rating,
                              width: double.infinity,
                              height: double.infinity,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => ComicDetailScreen(slug: c.slug, comic: c),
                                  ),
                                );
                                _load();
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _removeComic(c),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: _comic.length,
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
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final n = _novel[i];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PosterCard(
                              title: n.title,
                              imageUrl: n.effectivePosterUrl,
                              subtitle: n.latestChapter.isNotEmpty ? n.latestChapter : n.type,
                              score: n.rating > 0 ? n.rating.toStringAsFixed(1) : null,
                              width: double.infinity,
                              height: double.infinity,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => NovelDetailScreen(
                                      slug: n.slug,
                                      initialTitle: n.title,
                                      initialPoster: n.poster,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _removeNovel(n),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: _novel.length,
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
  );
  }
}
