import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';
import 'novel_reader_screen.dart';
import 'novel_genre_detail_screen.dart';
import '../../../shared/widgets/bouncy_tap.dart';

/// Pure Apple iOS HIG Styled Novel Detail Screen.
/// Matches ComicDetailScreen aesthetics:
/// - Apple TV+ style immersive blurred ambient backdrop
/// - Translucent frosted glass circular navigation buttons
/// - Hero squircle poster with 3D elevation and ambient shadow
/// - Clean Apple typography hierarchy with genre capsules
/// - Prominent primary CTA button (Mulai Membaca / Lanjutkan)
/// - Secondary Action Pills Row (Bookmark, Urutkan, Bagikan)
/// - Apple App Store inset grouped stats card with vertical hairline dividers
/// - Apple Books expandable synopsis card
/// - Apple Settings inset grouped detail information
/// - Apple Podcasts / Apple Books unified chapter list with search bar
class NovelDetailScreen extends StatefulWidget {
  final String slug;
  final String? initialTitle;
  final String? initialPoster;

  const NovelDetailScreen({
    super.key,
    required this.slug,
    this.initialTitle,
    this.initialPoster,
  });

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final _repo = NovelRepository.instance;
  final ScrollController _scrollController = ScrollController();

  NovelDetailModel? _detail;
  bool _loading = true;
  String? _error;

  bool _isBookmarked = false;
  bool _bookmarkLoading = false;
  Map<String, dynamic>? _lastRead;

  bool _synopsisExpanded = false;
  String _chapterSearchQuery = '';
  bool _sortNewestFirst = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _checkBookmarkAndHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBookmarkAndHistory() async {
    final bookmarked = await _repo.isBookmarked(widget.slug);
    final lastRead = await _repo.getLastReadChapter(widget.slug);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarked;
        _lastRead = lastRead;
      });
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.getNovelDetail(widget.slug);
      if (!mounted) return;
      setState(() {
        _detail = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat detail web novel: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_detail == null || _bookmarkLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _bookmarkLoading = true);

    try {
      final isNowBookmarked = !_isBookmarked;
      setState(() => _isBookmarked = isNowBookmarked);
      await _repo.toggleBookmark(_detail!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowBookmarked ? '✓ Ditambahkan ke Penanda Novel' : 'Dihapus dari Penanda Novel'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  void _shareNovel() {
    HapticFeedback.selectionClick();
    final title = _detail?.displayTitle ?? widget.initialTitle ?? 'Web Novel';
    final link = DeepLinkService.buildNovelLink(
      slug: widget.slug,
      title: title,
    );
    final text = 'Baca $title di MOKO!\n$link';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Tautan novel berhasil disalin ke clipboard!')),
          ],
        ),
      ),
    );
  }

  void _openReader(NovelChapterModel chapter) {
    if (_detail == null) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelReaderScreen(
          chapterSlug: chapter.slug,
          novelSlug: _detail!.slug,
          novelTitle: _detail!.displayTitle,
          novelPoster: _detail!.poster,
          chapters: _detail!.chapters,
        ),
      ),
    ).then((_) {
      _checkBookmarkAndHistory();
    });
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
                          strokeWidth: 2,
                          color: Colors.white,
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
          child: _loading && _detail == null
              ? _buildLoadingView(isDark)
              : _error != null && _detail == null
                  ? _buildErrorView(isDark)
                  : _buildContent(isDark),
        ),
      ),
    );
  }

  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 14, color: isDark ? Colors.white : Colors.black),
          const SizedBox(height: 16),
          Text(
            'Memuat detail novel...',
            style: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Terjadi kesalahan saat memuat novel',
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
              onPressed: _loadDetail,
              child: Text(
                'Coba Lagi',
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final d = _detail!;
    final posterUrl = d.effectivePosterUrl;

    // Filter and sort chapters
    var chapters = List<NovelChapterModel>.from(d.chapters);
    if (!_sortNewestFirst) {
      chapters = chapters.reversed.toList();
    }

    if (_chapterSearchQuery.trim().isNotEmpty) {
      final q = _chapterSearchQuery.trim().toLowerCase();
      chapters = chapters.where((c) => c.title.toLowerCase().contains(q) || c.displayTitle.toLowerCase().contains(q)).toList();
    }

    // Determine target chapter to read / resume
    NovelChapterModel? targetChapter;
    bool isResuming = false;

    if (_lastRead != null && _lastRead!['chapter_slug'] != null) {
      final lastSlug = _lastRead!['chapter_slug'].toString();
      final found = d.chapters.where((c) => c.slug == lastSlug);
      if (found.isNotEmpty) {
        targetChapter = found.first;
        isResuming = true;
      }
    }
    // Default to first chapter (which is at the end of the descending Sakuranovel list)
    targetChapter ??= d.chapters.isNotEmpty ? d.chapters.last : null;

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
                icon: _isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                iconColor: _isBookmarked ? Colors.amber : Colors.white70,
                loading: _bookmarkLoading,
                onTap: _toggleBookmark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _circleGlassIcon(
                icon: CupertinoIcons.share,
                onTap: _shareNovel,
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
                    d.displayTitle,
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
                    if (posterUrl.isNotEmpty)
                      AppNetworkImage(
                        url: posterUrl,
                        fit: BoxFit.cover,
                      ),
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
                      tag: 'novel_${widget.slug}',
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
                          child: posterUrl.isNotEmpty
                              ? AppNetworkImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCard : Colors.white12,
                                  child: const Icon(CupertinoIcons.text_quote, color: Colors.white38),
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
                              children: d.genres.take(6).map((g) {
                                final slug = g.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
                                return BouncyTap(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (_) => NovelGenreDetailScreen(
                                          genre: NovelGenreModel(name: g.trim(), slug: slug),
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

                          // Large iOS Title
                          Text(
                            d.displayTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              letterSpacing: -0.4,
                              height: 1.25,
                            ),
                          ),

                          // Alternative Title (if available)
                          if (d.altTitle.isNotEmpty && d.displayAltTitle.toLowerCase() != d.displayTitle.toLowerCase()) ...[
                            const SizedBox(height: 4),
                            Text(
                              d.displayAltTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Metadata Subtitle Dot-Separated
                          Text(
                            [
                              d.type.isNotEmpty ? d.type : 'Web Novel',
                              if (d.chapters.isNotEmpty) '${d.chapters.length} Bab',
                              d.status,
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Rating Pill with Star
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                                  '${d.ratingString} / 5',
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
                        onTap: () => _openReader(targetChapter!),
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
                                      ? 'Lanjutkan: ${targetChapter.displayTitle}'
                                      : 'Mulai Membaca (${targetChapter.displayTitle})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontSize: 14.5,
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

                // Secondary Quick Action Pills Row (Matches Comic)
                Row(
                  children: [
                    // Bookmark Action Pill
                    Expanded(
                      child: _buildSecondaryActionPill(
                        icon: _isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                        label: _isBookmarked ? 'Tersimpan' : 'Simpan',
                        isActive: _isBookmarked,
                        isDark: isDark,
                        onTap: _toggleBookmark,
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
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _sortNewestFirst = !_sortNewestFirst);
                        },
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
                        onTap: _shareNovel,
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
                        top: '★ ${d.ratingString}',
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
                        top: d.status,
                        label: 'STATUS',
                        topColor: d.status.toLowerCase().contains('ongoing')
                            ? const Color(0xFF34C759)
                            : (isDark ? Colors.white : Colors.black),
                        isDark: isDark,
                      ),
                      _buildVerticalHairline(isDark),
                      _buildStatsCol(
                        top: d.country.isNotEmpty ? d.country : 'Sakuranovel',
                        label: 'NEGARA',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // ── 5. SYNOPSIS SECTION (Apple Books Inset Grouped) ───────
                if (d.synopsis.isNotEmpty) ...[
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.synopsis,
                          maxLines: _synopsisExpanded ? null : 4,
                          overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (d.synopsis.length > 200)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _synopsisExpanded = !_synopsisExpanded);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _synopsisExpanded ? 'Tutup' : 'Baca Selengkapnya',
                                style: const TextStyle(
                                  color: Color(0xFF0A84FF),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // ── 6. DETAIL INFORMASI (Apple Settings Inset Grouped) ────
                const SizedBox(height: 22),
                _buildSectionHeader('Informasi Novel', isDark),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
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
                      _buildInfoRow(
                        icon: CupertinoIcons.person_fill,
                        label: 'Penulis',
                        value: d.author,
                        isDark: isDark,
                      ),
                      _buildInfoRow(
                        icon: CupertinoIcons.globe,
                        label: 'Negara',
                        value: d.country,
                        isDark: isDark,
                      ),
                      _buildInfoRow(
                        icon: CupertinoIcons.doc_plaintext,
                        label: 'Tipe',
                        value: d.type,
                        isDark: isDark,
                      ),
                      _buildInfoRow(
                        icon: CupertinoIcons.check_mark_circled,
                        label: 'Status',
                        value: d.status,
                        isDark: isDark,
                        showDivider: d.tags.isNotEmpty,
                      ),
                      if (d.tags.isNotEmpty)
                        _buildTagsRow(
                          tags: d.tags,
                          isDark: isDark,
                        ),
                    ],
                  ),
                ),

                // ── 7. CHAPTERS LIST HEADER & SEARCH ─────────────────────
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Daftar Chapter (${d.chapters.length})', isDark),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _sortNewestFirst = !_sortNewestFirst);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_up_arrow_down,
                              size: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortNewestFirst ? 'Terbaru' : 'Terlama',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Chapter Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _chapterSearchQuery = v),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari nomor atau judul chapter...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 13,
                      ),
                      icon: Icon(
                        CupertinoIcons.search,
                        size: 16,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── 8. CHAPTERS INSET GROUPED LIST ──────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 60),
          sliver: chapters.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _chapterSearchQuery.isNotEmpty
                            ? 'Tidak ada chapter yang cocok dengan pencarian.'
                            : 'Belum ada chapter tersedia untuk novel ini.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final ch = chapters[idx];
                      final isLastRead = _lastRead != null && _lastRead!['chapter_slug'] == ch.slug;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isLastRead
                              ? const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.12 : 0.08)
                              : (isDark ? AppColors.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLastRead
                                ? const Color(0xFF0A84FF).withValues(alpha: 0.4)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: 0.6,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openReader(ch),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Prominent Chapter / Episode Number Badge
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 46),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isLastRead
                                          ? const Color(0xFF0A84FF).withValues(alpha: 0.22)
                                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isLastRead
                                            ? const Color(0xFF0A84FF).withValues(alpha: 0.55)
                                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                        width: 0.7,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      ch.chapterBadge,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isLastRead
                                            ? const Color(0xFF0A84FF)
                                            : (isDark ? Colors.white : Colors.black87),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ch.cleanSubtitle(_detail?.displayTitle ?? widget.initialTitle ?? ''),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isLastRead ? FontWeight.w700 : FontWeight.w600,
                                            color: isLastRead ? const Color(0xFF0A84FF) : (isDark ? Colors.white : Colors.black87),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        if (ch.date.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.calendar,
                                                size: 11,
                                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                ch.date,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isLastRead) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Terakhir',
                                        style: TextStyle(
                                          color: Color(0xFF0A84FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 14,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: chapters.length,
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
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildSecondaryActionPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0A84FF)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? const Color(0xFF0A84FF)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
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
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: topColor ?? (isDark ? Colors.white : Colors.black),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalHairline(bool isDark) {
    return Container(
      width: 0.7,
      height: 28,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildTagsRow({
    required String tags,
    required bool isDark,
  }) {
    final list = tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  CupertinoIcons.tag_fill,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tag Populer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: list.map((tag) {
              final slug = tag.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
              return BouncyTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => NovelGenreDetailScreen(
                        genre: NovelGenreModel(name: tag, slug: slug),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value.isNotEmpty ? value : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.6,
            thickness: 0.6,
            indent: 52,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
      ],
    );
  }
}
