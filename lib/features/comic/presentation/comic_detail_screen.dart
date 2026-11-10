import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/comic_read_progress_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../data/comic_repository.dart';
import '../data/models/comic_model.dart';
import '../../anime/data/models/anime_model.dart' show GenreModel;
import '../../genre/presentation/genre_detail_screen.dart';
import 'comic_reader_screen.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../core/services/onesignal_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../review/presentation/widgets/review_input_dialog.dart';

/// Pure Apple iOS HIG Styled Comic Detail Screen.
/// Features:
/// - Apple Books / Apple TV+ style immersive blurred ambient backdrop
/// - Translucent frosted glass navigation bar with circular blur buttons
/// - Hero squircle poster with 3D elevation and ambient shadow
/// - Clean Apple typography hierarchy with squircle genre chips
/// - Prominent Sakura primary CTA button (Baca / Lanjutkan with page count)
/// - Apple App Store inset grouped stats card with vertical hairline dividers
/// - Apple Books expandable synopsis card
/// - Apple Settings inset grouped detail information
/// - Apple Podcasts / Apple Books unified inset grouped chapter list with
///   reading progress bars, read checkmarks, and Cupertino interactions
class ComicDetailScreen extends StatefulWidget {
  const ComicDetailScreen({
    super.key,
    required this.slug,
    this.comic,
  });

  final String slug;
  final ComicModel? comic;

  static double parseChapterNumber(ChapterModel ch, [int fallback = 0]) {
    final m = RegExp(r'(?:Chapter|Ch|Chap|Bab)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(ch.label);
    if (m != null) {
      final n = double.tryParse(m.group(1)!);
      if (n != null) return n;
    }
    final mId = RegExp(r'(?:chapter|ch|chap|bab)[-_](\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(ch.id);
    if (mId != null) {
      final n = double.tryParse(mId.group(1)!);
      if (n != null) return n;
    }
    final anyDigits = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(ch.label);
    if (anyDigits != null) {
      final n = double.tryParse(anyDigits.group(1)!);
      if (n != null) return n;
    }
    return fallback.toDouble();
  }

  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  final _repo = ComicRepository.instance;
  late Future<ComicDetailModel> _future;
  late final ScrollController _scrollController;
  bool? _isBookmarked;
  bool _bookmarkLoading = false;
  bool? _isProfileLiked;
  bool _profileLikedLoading = false;
  bool _sortNewestFirst = false;
  int _displayCount = 30;
  static const int _pageSize = 30;
  Set<String> _readChapterIdentifiers = {};
  String? _loadedComicTitle;
  ComicReadProgress? _lastReadProgress;

  String get _cleanSlug => ComicModel.extractCleanSlug(widget.slug);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _future = _repo.detail(_cleanSlug);
    _checkBookmark();
    _checkProfileLiked();
    _loadReadChapters();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMoreChapters();
    }
  }

  void _loadMoreChapters() {
    if (mounted) {
      setState(() {
        _displayCount += _pageSize;
      });
    }
  }

  static double parseChapterNumber(ChapterModel ch, [int fallback = 0]) =>
      ComicDetailScreen.parseChapterNumber(ch, fallback);

  List<ChapterModel> _getSortedChapters(List<ChapterModel> raw) {
    if (raw.isEmpty) return raw;
    final list = List<ChapterModel>.from(raw);

    list.sort((a, b) {
      final na = parseChapterNumber(a, -1);
      final nb = parseChapterNumber(b, -1);
      if (na != -1 && nb != -1 && na != nb) {
        return _sortNewestFirst ? nb.compareTo(na) : na.compareTo(nb);
      }
      return 0;
    });

    final hasDistinction = list.any((e) => parseChapterNumber(e, -1) != -1);
    if (!hasDistinction) {
      return _sortNewestFirst ? raw.reversed.toList() : raw;
    }

    return list;
  }

  Future<void> _loadReadChapters({String? comicTitle}) async {
    try {
      final local = await ComicReadProgressService.instance.getLastReadChapter(_cleanSlug);
      if (mounted) {
        setState(() => _lastReadProgress = local);
      }
    } catch (_) {}
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    try {
      final list = await _repo.readHistory();
      final set = <String>{};
      final currentSlug = _cleanSlug.toLowerCase();
      final currentTitle = (comicTitle ?? _loadedComicTitle ?? widget.comic?.title ?? '')
          .trim()
          .toLowerCase();

      for (final item in list) {
        final rawItemSlug = (item['comic_slug'] ?? item['slug'] ?? '').toString();
        final itemCleanSlug = ComicModel.extractCleanSlug(rawItemSlug).toLowerCase();
        final itemTitle = (item['comic_title'] ?? item['title'] ?? '').toString().trim().toLowerCase();

        final bool slugMatches = itemCleanSlug.isNotEmpty && itemCleanSlug == currentSlug;
        final bool titleMatches = currentTitle.isNotEmpty && itemTitle.isNotEmpty && currentTitle == itemTitle;

        if (slugMatches || titleMatches) {
          final chSlug = (item['chapter_slug'] ?? item['chapter_id'])?.toString();
          if (chSlug != null && chSlug.isNotEmpty) {
            set.add(chSlug.toLowerCase());
            final clean = ChapterModel.extractCleanSlug(chSlug).toLowerCase();
            if (clean.isNotEmpty) set.add(clean);
          }
          final chNum = (item['chapter_number'] ?? item['chapter_num'])?.toString();
          if (chNum != null && chNum.isNotEmpty && chNum != '0') {
            set.add('ch_$chNum');
          }
          final chTitle = (item['chapter_title'] ?? item['chapter_label'])?.toString();
          if (chTitle != null && chTitle.isNotEmpty) {
            final m = RegExp(r'(?:Chapter|Ch|Chap)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(chTitle);
            if (m != null) set.add('ch_${m.group(1)!}');
          }
        }
      }
      if (mounted) {
        setState(() => _readChapterIdentifiers = set);
      }
    } catch (_) {}
  }

  bool _isChapterRead(ChapterModel chapter) {
    if (_readChapterIdentifiers.isEmpty) return false;
    final chId = chapter.id.toLowerCase();
    if (chId.isNotEmpty && _readChapterIdentifiers.contains(chId)) return true;

    final clean = ChapterModel.extractCleanSlug(chapter.id).toLowerCase();
    if (clean.isNotEmpty && _readChapterIdentifiers.contains(clean)) return true;

    final idNumMatch = RegExp(r'(?:chapter|ch|chap)[-_]?(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(chapter.id);
    if (idNumMatch != null && _readChapterIdentifiers.contains('ch_${idNumMatch.group(1)}')) {
      return true;
    }

    final numMatch = RegExp(r'(?:Chapter|Ch|Chap)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(chapter.label);
    if (numMatch != null && _readChapterIdentifiers.contains('ch_${numMatch.group(1)}')) {
      return true;
    }

    final cleanLabel = chapter.label.trim().toLowerCase();
    if (cleanLabel.isNotEmpty && _readChapterIdentifiers.contains(cleanLabel)) {
      return true;
    }
    return false;
  }

  Future<void> _checkBookmark() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    final v = await _repo.isBookmarked(_cleanSlug);
    if (mounted) setState(() => _isBookmarked = v);
  }

  Future<void> _toggleBookmark(ComicDetailModel d) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menyimpan bookmark'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _bookmarkLoading = true);
    try {
      if (_isBookmarked == true) {
        await _repo.removeBookmark(_cleanSlug);
        OneSignalService.syncComicBookmarkCache(_cleanSlug, false);
        setState(() => _isBookmarked = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dihapus dari bookmark'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await _repo.addBookmark(
          comicSlug: _cleanSlug,
          title: d.title,
          thumb: d.thumb,
          type: d.type,
        );
        OneSignalService.syncComicBookmarkCache(_cleanSlug, true);
        setState(() => _isBookmarked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ditambahkan ke bookmark'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_repo.errorMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  Future<void> _checkProfileLiked() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    final liked = await ProfileRepository.instance.checkProfileLiked(
      itemType: 'comic',
      itemId: _cleanSlug,
    );
    if (mounted) setState(() => _isProfileLiked = liked);
  }

  Future<void> _toggleProfileLiked(ComicDetailModel d) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menyukai komik ini di profil'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _profileLikedLoading = true);
    try {
      final res = await ProfileRepository.instance.toggleProfileLiked(
        itemType: 'comic',
        itemId: _cleanSlug,
        title: d.title,
        thumbnail: d.thumb,
      );
      if (res['success'] == true) {
        final isLiked = res['is_liked'] == true;
        setState(() => _isProfileLiked = isLiked);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ??
                    (isLiked ? 'Disukai dan dipajang di profil!' : 'Dihapus dari favorit profil'),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: isLiked ? const Color(0xFFFF2E93) : null,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Gagal memproses favorit profil'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profileLikedLoading = false);
    }
  }

  void _shareComic(ComicDetailModel d) {
    HapticFeedback.selectionClick();
    final text = '${d.title} - Baca komik di Moko!';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Teks komik berhasil disalin untuk dibagikan!'),
          ],
        ),
      ),
    );
  }

  void _readChapter({
    required ChapterModel chapter,
    required List<ChapterModel> chapters,
    required ComicDetailModel detail,
    int? initialPage,
  }) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ComicReaderScreen(
          chapterId: chapter.id,
          chapterLabel: chapter.label,
          comicSlug: widget.slug,
          comicTitle: detail.title,
          comicThumb: detail.thumb,
          chapters: chapters,
          initialPage: initialPage,
        ),
      ),
    );
    _loadReadChapters();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context) ? Responsive.maxContentWidth : double.infinity,
          ),
          child: FutureBuilder<ComicDetailModel>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _loadingView();
              }
              if (snap.hasError) {
                return ErrorState(
                  message: _repo.errorMessage(snap.error!),
                  onRetry: () => setState(() {
                    _future = _repo.detail(_cleanSlug);
                  }),
                );
              }
              final d = snap.data!;
              if (_loadedComicTitle != d.title) {
                _loadedComicTitle = d.title;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadReadChapters(comicTitle: d.title);
                });
              }
              return _buildContent(d, isDark);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ComicDetailModel d, bool isDark) {
    final chapters = _getSortedChapters(d.chapters);
    final visibleChapters = chapters.take(_displayCount).toList();
    final thumb = d.thumb ?? widget.comic?.thumb;

    // Find resume or first chapter
    ChapterModel? targetChapter;
    int? resumePage;

    if (_lastReadProgress != null) {
      final lastCleanId = ChapterModel.extractCleanSlug(_lastReadProgress!.chapterId).toLowerCase();
      final lastCleanLabel = _lastReadProgress!.chapterLabel?.trim().toLowerCase();

      for (final ch in chapters) {
        final cleanId = ChapterModel.extractCleanSlug(ch.id).toLowerCase();
        final label = ch.label.trim().toLowerCase();
        if (cleanId == lastCleanId || (lastCleanLabel != null && label == lastCleanLabel)) {
          if (!_lastReadProgress!.isCompleted) {
            targetChapter = ch;
            resumePage = _lastReadProgress!.pageIndex;
          }
          break;
        }
      }
    }

    if (targetChapter == null && chapters.isNotEmpty) {
      // Find first unread chapter in story order
      final storyOrder = List<ChapterModel>.from(d.chapters);
      storyOrder.sort((a, b) {
        final na = parseChapterNumber(a, -1);
        final nb = parseChapterNumber(b, -1);
        if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
        return 0;
      });
      for (final ch in storyOrder) {
        if (!_isChapterRead(ch)) {
          targetChapter = ch;
          break;
        }
      }
      targetChapter ??= chapters.first;
    }

    final isResuming = targetChapter != null &&
        (resumePage != null || _readChapterIdentifiers.isNotEmpty || _lastReadProgress != null);

    final rawThumb = thumb != null && thumb.isNotEmpty ? ComicModel.normalizeThumbnailUrl(thumb) : null;
    final cleanThumb = rawThumb != null && rawThumb.isNotEmpty
        ? (rawThumb.startsWith('http') ? rawThumb : '${ApiConfig.baseUrl}$rawThumb')
        : null;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── 1. APPLE TV+ PARALLAX BLUR BACKDROP APP BAR ────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          automaticallyImplyLeading: false,
          backgroundColor: (isDark ? AppColors.darkBackground : AppColors.lightBackground)
              .withValues(alpha: 0.85),
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Center(
              child: _circleGlassIcon(
                icon: CupertinoIcons.chevron_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: _isProfileLiked == true
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                iconColor: _isProfileLiked == true ? const Color(0xFFFF2E93) : Colors.white70,
                loading: _profileLikedLoading,
                onTap: () => _toggleProfileLiked(d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: _isBookmarked == true
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                iconColor: _isBookmarked == true ? Colors.white : Colors.white70,
                loading: _bookmarkLoading,
                onTap: () => _toggleBookmark(d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: CupertinoIcons.square_pencil,
                iconColor: Colors.white,
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login untuk menulis ulasan')),
                    );
                    return;
                  }
                  final res = await ReviewInputDialog.show(
                    context,
                    itemType: 'comic',
                    targetId: _cleanSlug,
                    targetTitle: d.title,
                    targetCover: d.thumb,
                  );
                  if (res != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ulasan berhasil disimpan!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _circleGlassIcon(
                icon: CupertinoIcons.share,
                onTap: () => _shareComic(d),
              ),
            ),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (ctx, constraints) {
              final currentH = constraints.maxHeight;
              const minH = kToolbarHeight + 40;
              const maxH = 240.0;
              final t = (1 - ((currentH - minH) / (maxH - minH))).clamp(0.0, 1.0);
              final isCollapsed = t > 0.65;

              return FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                centerTitle: true,
                titlePadding: const EdgeInsets.only(left: 56, right: 96, bottom: 14),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Ambient backdrop image
                    if (cleanThumb != null)
                      Image.network(
                        cleanThumb,
                        headers: const {
                          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                          'Referer': 'https://komiku.org/',
                        },
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: AppColors.darkHeroGradient),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: AppColors.darkHeroGradient),
                        ),
                      ),

                    // Multi-layer frosted glass blur
                    RepaintBoundary(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.60),
                                  (isDark ? AppColors.darkBackground : AppColors.lightBackground)
                                      .withValues(alpha: 0.95),
                                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                                ],
                                stops: const [0.0, 0.45, 0.80, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ── 2. HERO POSTER & IDENTITY CARD (Apple Books Layout) ────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floating Squircle Poster
                    Hero(
                      tag: 'comic_${widget.slug}',
                      child: Container(
                        width: 114,
                        height: 164,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.20)
                                : Colors.black.withValues(alpha: 0.10),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: cleanThumb != null
                              ? Image.network(
                                  cleanThumb,
                                  headers: const {
                                    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                                    'Referer': 'https://komiku.org/',
                                  },
                                  fit: BoxFit.cover,
                                  cacheWidth: 350,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? AppColors.darkCard : Colors.white12,
                                    child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCard : Colors.white12,
                                  child: const Icon(Icons.book_rounded, color: Colors.white38),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title & Essential Metadata Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),

                          // Genre Capsules
                          if (d.genres.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: d.genres.take(4).map((g) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final slug = g.toLowerCase().replaceAll(' ', '-');
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GenreDetailScreen(
                                          genre: GenreModel(slug: slug, name: g),
                                          isAnime: false,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 8),

                          // Large iOS Title - generous lines, no arbitrary cut-off
                          Text(
                            d.title,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              letterSpacing: -0.4,
                              height: 1.22,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Metadata Subtitle Dot-Separated
                          Text(
                            [
                              if (d.type != null && d.type!.isNotEmpty) d.type!,
                              if (d.chapters.isNotEmpty) '${d.chapters.length} Bab',
                              if (d.status != null && d.status!.isNotEmpty) d.status!,
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Rating Pill with Star
                          if (d.rating != null && d.rating!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.star_fill, size: 12, color: Color(0xFFFF9500)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${d.rating} / 10',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF9500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                  const SizedBox(height: 18),

                  // ── 3. PRIMARY READ CTA BUTTON (Apple Books Style) ───────
                  if (targetChapter != null)
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Colors.white, Color(0xFFE5E5EA)]
                              : const [Color(0xFF000000), Color(0xFF2C2C2E)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.15 : 0.38),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _readChapter(
                            chapter: targetChapter!,
                            chapters: chapters,
                            detail: d,
                            initialPage: resumePage,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.book_fill,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isResuming
                                        ? 'Lanjutkan: ${targetChapter.label}${resumePage != null ? ' (Hal ${resumePage + 1})' : ''}'
                                        : 'Mulai Membaca (${targetChapter.label})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Secondary Quick Action Pills Row
                  Row(
                    children: [
                      // Profile Liked Action Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: _isProfileLiked == true
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          label: _isProfileLiked == true ? 'Disukai' : 'Suka',
                          isActive: _isProfileLiked == true,
                          activeColor: const Color(0xFFFF2E93),
                          activeTextColor: Colors.white,
                          iconColor: _isProfileLiked == true ? Colors.white : const Color(0xFFFF2E93),
                          isDark: isDark,
                          onTap: () => _toggleProfileLiked(d),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bookmark Action Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: _isBookmarked == true
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          label: _isBookmarked == true ? 'Tersimpan' : 'Simpan',
                          isActive: _isBookmarked == true,
                          isDark: isDark,
                          onTap: () => _toggleBookmark(d),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Chapter Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: CupertinoIcons.arrow_up_arrow_down,
                          label: _sortNewestFirst ? 'Terbaru' : 'Terlama',
                          isActive: false,
                          isDark: isDark,
                          onTap: () => _showSortActionSheet(context),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Share Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: CupertinoIcons.share,
                          label: 'Bagikan',
                          isActive: false,
                          isDark: isDark,
                          onTap: () => _shareComic(d),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── 4. APPLE APP STORE INSET GROUPED STATS CARD ──────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildStatsCol(
                          top: '★ ${d.rating ?? '-'}',
                          label: 'SKOR',
                          topColor: const Color(0xFFFF9500),
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: '${d.chapters.length}',
                          label: 'TOTAL BAB',
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: d.status ?? 'Ongoing',
                          label: 'STATUS',
                          topColor: (d.status?.toLowerCase().contains('selesai') == true ||
                                  d.status?.toLowerCase().contains('completed') == true)
                              ? const Color(0xFF34C759)
                              : (isDark ? Colors.white : Colors.black),
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: d.type ?? 'Manga',
                          label: 'TIPE',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ── 5. SYNOPSIS SECTION (Apple Books Inset Grouped) ───────
                  if (d.synopsis != null && d.synopsis!.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _buildSectionHeader('Sinopsis', isDark),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _ExpandableText(text: d.synopsis!.trim()),
                    ),
                  ],


                  // ── 6. METADATA DETAILS (Apple Settings Inset Grouped) ───
                  if (d.author != null || d.releaseYear != null || d.artist != null || d.readingDirection != null) ...[
                    const SizedBox(height: 22),
                    _buildSectionHeader('Informasi Detail', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (d.author != null && d.author!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.pen,
                              label: 'Penulis',
                              value: d.author!,
                              isDark: isDark,
                              showDivider: d.artist != null || d.releaseYear != null || d.readingDirection != null,
                            ),
                          if (d.artist != null && d.artist!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.paintbrush,
                              label: 'Artis',
                              value: d.artist!,
                              isDark: isDark,
                              showDivider: d.releaseYear != null || d.readingDirection != null,
                            ),
                          if (d.releaseYear != null && d.releaseYear!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.calendar,
                              label: 'Tahun Rilis',
                              value: d.releaseYear!,
                              isDark: isDark,
                              showDivider: d.readingDirection != null,
                            ),
                          if (d.readingDirection != null && d.readingDirection!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.arrow_right_arrow_left,
                              label: 'Arah Baca',
                              value: d.readingDirection!,
                              isDark: isDark,
                              showDivider: false,
                            ),
                        ],
                      ),
                    ),
                  ],


                  // ── 7. CHAPTERS LIST (Apple Podcasts Inset Grouped) ──────
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSectionHeader('Daftar Chapter', isDark),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${d.chapters.length}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildSortFilterPill(isDark),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Unified Inset Grouped Card for all chapters
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: chapters.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Center(
                                child: Text(
                                  'Belum ada chapter tersedia',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: visibleChapters.length,
                                  separatorBuilder: (ctx, i) => Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 68,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                  itemBuilder: (ctx, i) {
                                    final ch = visibleChapters[i];
                                    final isRead = _isChapterRead(ch);
                                    final realIndex = chapters.indexOf(ch) + 1;

                                    // Check if this chapter has saved progress
                                    int? savedPage;
                                    int? totalPgs;
                                    if (_lastReadProgress != null) {
                                      final lastClean = ChapterModel.extractCleanSlug(_lastReadProgress!.chapterId).toLowerCase();
                                      final thisClean = ChapterModel.extractCleanSlug(ch.id).toLowerCase();
                                      if (lastClean == thisClean && !_lastReadProgress!.isCompleted && _lastReadProgress!.pageIndex > 0) {
                                        savedPage = _lastReadProgress!.pageIndex;
                                        totalPgs = _lastReadProgress!.totalPages;
                                      }
                                    }

                                    return RepaintBoundary(
                                      child: _AppleChapterTile(
                                        chapter: ch,
                                        index: realIndex,
                                        isRead: isRead,
                                        savedPageIndex: savedPage,
                                        totalPages: totalPgs,
                                        isDark: isDark,
                                        onTap: () => _readChapter(
                                          chapter: ch,
                                          chapters: chapters,
                                          detail: d,
                                          initialPage: savedPage,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (visibleChapters.length < chapters.length)
                                  _buildLazyLoadFooter(
                                    currentCount: visibleChapters.length,
                                    totalCount: chapters.length,
                                    itemLabel: 'chapter',
                                    isDark: isDark,
                                    onLoadMore: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _displayCount += _pageSize;
                                      });
                                    },
                                    onShowAll: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _displayCount = chapters.length;
                                      });
                                    },
                                  ),
                              ],
                            ),
                    ),
                  ),

                  // ── BOTTOM BANNER AD ──
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: AdBannerWidget(),
                  ),

                  SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ],
      );
    }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildSortFilterPill(bool isDark) {
    final label = _sortNewestFirst ? 'Terbaru ke Terlama' : 'Terlama ke Terbaru';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSortActionSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
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
                CupertinoIcons.arrow_up_arrow_down,
                size: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                CupertinoIcons.chevron_down,
                size: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return CupertinoActionSheet(
          title: const Text(
            'Urutkan Chapter',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          message: const Text('Pilih urutan daftar chapter'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              isDefaultAction: _sortNewestFirst,
              onPressed: () {
                Navigator.pop(ctx);
                if (!_sortNewestFirst) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _sortNewestFirst = true;
                    _displayCount = _pageSize;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sortNewestFirst) ...[
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Terbaru ke Terlama',
                    style: TextStyle(
                      fontWeight: _sortNewestFirst ? FontWeight.w700 : FontWeight.w500,
                      color: _sortNewestFirst ? (isDark ? Colors.white : Colors.black) : null,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              isDefaultAction: !_sortNewestFirst,
              onPressed: () {
                Navigator.pop(ctx);
                if (_sortNewestFirst) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _sortNewestFirst = false;
                    _displayCount = _pageSize;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_sortNewestFirst) ...[
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Terlama ke Terbaru',
                    style: TextStyle(
                      fontWeight: !_sortNewestFirst ? FontWeight.w700 : FontWeight.w500,
                      color: !_sortNewestFirst ? (isDark ? Colors.white : Colors.black) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        );
      },
    );
  }

  Widget _buildLazyLoadFooter({
    required int currentCount,
    required int totalCount,
    required String itemLabel,
    required bool isDark,
    required VoidCallback onLoadMore,
    required VoidCallback onShowAll,
  }) {
    final remaining = totalCount - currentCount;
    final nextBatch = remaining > _pageSize ? _pageSize : remaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.015),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Menampilkan $currentCount dari $totalCount $itemLabel (sisa $remaining)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onLoadMore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_down_circle_fill, size: 14, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(width: 6),
                        Text(
                          'Muat $nextBatch Lagi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onShowAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Tampilkan Semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
    Color? activeColor,
    Color? activeTextColor,
    Color? iconColor,
  }) {
    final effectiveActiveBg = activeColor ?? (isDark ? Colors.white : Colors.black);
    final effectiveActiveFg = activeTextColor ?? (isDark ? Colors.black : Colors.white);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? effectiveActiveBg
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? effectiveActiveBg
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06)),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? effectiveActiveFg
                    : (iconColor ?? (isDark ? Colors.white70 : const Color(0xFF1C1C1E))),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? effectiveActiveFg
                      : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCol({
    required String top,
    required String label,
    Color? topColor,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: topColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E)),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalHairline(bool isDark) {
    return Container(
      width: 0.5,
      height: 30,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 44,
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _circleGlassIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool loading = false,
  }) {
    return RepaintBoundary(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.7,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(icon, color: iconColor ?? Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _loadingView() {
    return const Center(
      child: CupertinoActivityIndicator(radius: 16),
    );
  }
}

/// Inset Apple Podcasts styled Chapter Tile
class _AppleChapterTile extends StatelessWidget {
  const _AppleChapterTile({
    required this.chapter,
    required this.index,
    required this.onTap,
    required this.isRead,
    this.savedPageIndex,
    this.totalPages,
    required this.isDark,
  });

  final ChapterModel chapter;
  final int index;
  final VoidCallback onTap;
  final bool isRead;
  final int? savedPageIndex;
  final int? totalPages;
  final bool isDark;

  static final RegExp _chRegex1 = RegExp(r'(?:Chapter|Ch|Chap)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false);
  static final RegExp _chRegex2 = RegExp(r'(?:chapter|ch|chap)[-_](\d+(?:\.\d+)?)', caseSensitive: false);
  static final RegExp _chRegexDigits = RegExp(r'\b(\d+(?:\.\d+)?)\b');
  static final RegExp _chTitlePrefixRegex = RegExp(r'^(?:Chapter|Ch|Chap)\.?\s*\d+', caseSensitive: false);

  static final Map<String, String> _chNumCache = {};
  static final Map<String, String> _chTitleCache = {};

  String get _chapterNumber {
    final key = '${chapter.id}_${chapter.label}_$index';
    final cached = _chNumCache[key];
    if (cached != null) return cached;

    String res = '$index';
    final m = _chRegex1.firstMatch(chapter.label);
    if (m != null) {
      res = m.group(1)!;
    } else {
      final mId = _chRegex2.firstMatch(chapter.id);
      if (mId != null) {
        res = mId.group(1)!;
      } else {
        final anyDigits = _chRegexDigits.firstMatch(chapter.label);
        if (anyDigits != null) {
          res = anyDigits.group(1)!;
        }
      }
    }
    _chNumCache[key] = res;
    return res;
  }

  String get _displayTitle {
    final numStr = _chapterNumber;
    final key = '${chapter.id}_${chapter.label}_$numStr';
    final cached = _chTitleCache[key];
    if (cached != null) return cached;

    final labelTrimmed = chapter.label.trim();
    String res;
    if (labelTrimmed.isEmpty) {
      res = 'Chapter $numStr';
    } else if (_chTitlePrefixRegex.hasMatch(labelTrimmed)) {
      res = labelTrimmed;
    } else {
      res = 'Chapter $numStr: $labelTrimmed';
    }
    _chTitleCache[key] = res;
    return res;
  }

  @override
  Widget build(BuildContext context) {
    const greenAccent = Color(0xFF34C759);
    final chNum = _chapterNumber;
    final hasProgress = savedPageIndex != null && savedPageIndex! > 0;
    final double progressRatio = (hasProgress && totalPages != null && totalPages! > 0)
        ? ((savedPageIndex! + 1) / totalPages!).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Chapter Squircle Badge - Clean & Minimalist
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isRead
                      ? greenAccent.withValues(alpha: isDark ? 0.12 : 0.08)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRead
                        ? greenAccent.withValues(alpha: isDark ? 0.40 : 0.30)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.10)),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    chNum,
                    maxLines: 1,
                    style: TextStyle(
                      color: isRead
                          ? (isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745))
                          : (isDark ? Colors.white : Colors.black),
                      fontSize: chNum.length >= 4 ? 11 : (chNum.length >= 3 ? 13 : 16),
                      fontWeight: isRead ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, & Reading Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isRead
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : (isDark ? Colors.white : AppColors.lightTextPrimary),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: greenAccent.withValues(alpha: isDark ? 0.12 : 0.09),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: greenAccent.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 9.5,
                                  color: isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745),
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  'Dibaca',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745),
                                    letterSpacing: -0.1,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Subtitle / Page or Date
                    Row(
                      children: [
                        if (hasProgress) ...[
                          Flexible(
                            child: Text(
                              'Tersimpan di Hal ${savedPageIndex! + 1}${totalPages != null ? '/$totalPages' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (chapter.uploadedOn != null && chapter.uploadedOn!.isNotEmpty)
                            Flexible(
                              child: Text(
                                ' • ${chapter.uploadedOn!}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                        ] else if (chapter.uploadedOn != null && chapter.uploadedOn!.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              chapter.uploadedOn!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              'Chapter $chNum',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Reading progress bar
                    if (hasProgress && progressRatio > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 3,
                          width: double.infinity,
                          color: isDark ? Colors.white12 : Colors.black12,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressRatio,
                            child: Container(color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing Read Icon in Circular Glass
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isRead
                      ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
                      : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.book_fill,
                  size: 12.5,
                  color: isRead
                      ? (isDark ? Colors.white38 : Colors.black26)
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable text with animated crossfade and Cupertino chevron
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          secondChild: Text(
            widget.text,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _expanded ? 'Sembunyikan' : 'Selengkapnya',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                size: 12,
                color: isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
