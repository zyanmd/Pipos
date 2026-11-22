import '../../../../core/constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/bouncy_tap.dart';
import '../../../../shared/widgets/calm_gif.dart';
import '../../../../shared/widgets/ios_capsule_search_bar.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../chat/services/chat_theme_service.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../data/forum_repository.dart';
import '../data/models/forum_thread_model.dart';
import 'create_thread_sheet.dart';
import 'thread_detail_screen.dart';

class ForumFeedScreen extends StatefulWidget {
  final bool isEmbedded;
  final String? filterCategory;
  final String? filterAnimeTitle;

  const ForumFeedScreen({
    super.key,
    this.isEmbedded = false,
    this.filterCategory,
    this.filterAnimeTitle,
  });

  @override
  State<ForumFeedScreen> createState() => _ForumFeedScreenState();
}

class _ForumFeedScreenState extends State<ForumFeedScreen> {
  final _searchController = TextEditingController();
  List<ForumThreadModel> _threads = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';
  String _selectedSort = 'trending'; // 'trending', 'latest', 'top'

  final List<String> _categories = [
    'Semua',
    'Teori Manga',
    'Fan Art',
    'Rekomendasi',
    'Review',
    'Spoiler',
    'Diskusi Umum',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.filterCategory != null) {
      _selectedCategory = widget.filterCategory!;
    }
    if (widget.filterAnimeTitle != null) {
      _searchController.text = widget.filterAnimeTitle!;
    }
    _loadThreads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    final res = await ForumRepository.instance.getThreads(
      category: _selectedCategory,
      query: _searchController.text,
      sort: _selectedSort,
    );
    if (mounted) {
      setState(() {
        _threads = res;
        _isLoading = false;
      });
    }
  }

  void _openCreateThread() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateThreadSheet(
        prefillCategory: _selectedCategory != 'Semua' ? _selectedCategory : null,
        prefillAnimeTitle: widget.filterAnimeTitle,
        onThreadCreated: (newThread) {
          _loadThreads();
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => ThreadDetailScreen(thread: newThread),
            ),
          );
        },
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Teori Manga':
        return const Color(0xFF8B5CF6);
      case 'Fan Art':
        return const Color(0xFFEC4899);
      case 'Rekomendasi':
        return const Color(0xFF10B981);
      case 'Review':
        return const Color(0xFFF59E0B);
      case 'Spoiler':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF007AFF);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textMuted = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    Widget content = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadThreads(isBackground: true),
        ),

        // Standalone App Bar (if not embedded)
        if (!widget.isEmbedded)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Forum Diskusi',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: textPrimary,
                    ),
                  ),
                  BouncyTap(
                    onTap: _openCreateThread,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Buat Thread',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Search Bar & Filter Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: IosCapsuleSearchBar(
                    controller: _searchController,
                    showCancelButton: false,
                    hintText: 'Cari teori, judul anime, fan art...',
                    onChanged: (val) {
                      _loadThreads(isBackground: true);
                    },
                    onClear: () {
                      _loadThreads();
                    },
                  ),
                ),
                if (widget.isEmbedded) ...[
                  const SizedBox(width: 10),
                  BouncyTap(
                    onTap: _openCreateThread,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Thread',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Category Filter Chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                      _loadThreads();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isSel
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? const Color(0xFF1E1E28) : const Color(0xFFEAEAEE)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Sort Row (Trending, Terbaru, Teratas)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_threads.length} Thread Diskusi',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted),
                ),
                Row(
                  children: [
                    _buildSortPill('Trending', 'trending', isDark),
                    const SizedBox(width: 6),
                    _buildSortPill('Terbaru', 'latest', isDark),
                    const SizedBox(width: 6),
                    _buildSortPill('Paling Ramai', 'top', isDark),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Threads Feed List
        if (_isLoading) ...[
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          ),
        ] else if (_threads.isEmpty) ...[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chat_bubble_2, size: 44, color: textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada thread untuk kategori ini',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mulai diskusi baru sekarang dan bagikan pemikiranmu!',
                    style: TextStyle(fontSize: 12.5, color: textMuted),
                  ),
                  const SizedBox(height: 16),
                  BouncyTap(
                    onTap: _openCreateThread,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Buat Thread Pertama',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final thread = _threads[index];
                  return _buildThreadCard(thread, isDark, cardBg, textPrimary, textMuted, borderColor);
                },
                childCount: _threads.length,
              ),
            ),
          ),
        ],
      ],
    );

    final activeBgUrl = ChatThemeService.instance.activeBackgroundUrl;

    Widget bodyWithBackground = Stack(
      children: [
        if (activeBgUrl != null && activeBgUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.12 : 0.06,
              child: CalmGif(
                source: activeBgUrl,
                fit: BoxFit.cover,
                speed: ChatThemeService.instance.animSpeed,
              ),
            ),
          ),
        content,
      ],
    );

    if (widget.isEmbedded) {
      return Container(
        color: bg,
        child: bodyWithBackground,
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: bodyWithBackground),
    );
  }

  Widget _buildSortPill(String label, String value, bool isDark) {
    final isSel = _selectedSort == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSort = value);
        _loadThreads();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? const Color(0xFF2C2C3E) : const Color(0xFFDCDCE2))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(
    ForumThreadModel thread,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
    Color borderColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => ThreadDetailScreen(thread: thread),
              ),
            ).then((_) => _loadThreads(isBackground: true));
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Author & Tag Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      backgroundImage: thread.authorAvatar != null
                          ? NetworkImage(thread.authorAvatar!)
                          : null,
                      child: thread.authorAvatar == null
                          ? Text(
                              thread.authorName.isNotEmpty
                                  ? thread.authorName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF007AFF),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      thread.authorName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Lv. ${thread.authorLevel}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_formatTime(thread.createdAt)}',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _categoryColor(thread.category).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        thread.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _categoryColor(thread.category),
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Related Anime / Komik Tag (if any)
                if (thread.hasTag) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (thread.isComicTag) {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => ComicDetailScreen(
                              slug: thread.relatedSlug ?? thread.relatedTitle!,
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => AnimeDetailScreen(
                              animeId: thread.relatedSlug ?? thread.relatedTitle!,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: (thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                              .withValues(alpha: 0.25),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            thread.isComicTag ? CupertinoIcons.book : CupertinoIcons.film,
                            size: 11,
                            color: thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              thread.isComicTag ? 'Komik' : 'Anime',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              thread.relatedTitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(CupertinoIcons.chevron_right, size: 10, color: textMuted),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // 3. Title
                Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    height: 1.35,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 6),

                // 4. Content Snippet
                Text(
                  thread.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),

                // 5. Video Preview / Image Preview
                if (thread.hasVideo) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.8,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover Image / Fallback
                          if (thread.imageUrl != null && thread.imageUrl!.isNotEmpty)
                            AppNetworkImage(
                              url: thread.imageUrl!,
                              fit: BoxFit.cover,
                            )
                          else if (thread.relatedPoster != null && thread.relatedPoster!.isNotEmpty)
                            AppNetworkImage(
                              url: thread.relatedPoster!,
                              fit: BoxFit.cover,
                            )
                          else
                            Container(
                              color: const Color(0xFF161622),
                              child: const Center(
                                child: Icon(CupertinoIcons.film, size: 36, color: Colors.white24),
                              ),
                            ),
                          // Dark gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          // Play Button Badge
                          Center(
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white70, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Reels Tag in Top-Left
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.play_rectangle_fill, size: 10, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reels Video',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Duration in Bottom-Right
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                thread.videoDuration != null && thread.videoDuration! > 0
                                    ? '00:${thread.videoDuration!.toString().padLeft(2, '0')}'
                                    : 'Video',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (thread.imageUrl != null && thread.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppNetworkImage(
                      url: thread.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 170,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 6. Action Bar (Reddit Style Upvote / Comment / Share)
                Row(
                  children: [
                    // Upvote Pill
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20202E) : const Color(0xFFEFEFF4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await ForumRepository.instance.toggleVote(thread.id, 1);
                              _loadThreads(isBackground: true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Icon(
                                CupertinoIcons.arrow_up,
                                size: 14,
                                color: thread.userVote == 1
                                    ? const Color(0xFFFF4500)
                                    : textMuted,
                              ),
                            ),
                          ),
                          Text(
                            '${thread.upvotes}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: thread.userVote == 1
                                  ? const Color(0xFFFF4500)
                                  : textPrimary,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await ForumRepository.instance.toggleVote(thread.id, -1);
                              _loadThreads(isBackground: true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Icon(
                                CupertinoIcons.arrow_down,
                                size: 14,
                                color: thread.userVote == -1
                                    ? const Color(0xFF7193FF)
                                    : textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Comments Pill
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20202E) : const Color(0xFFEFEFF4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.chat_bubble_2, size: 13, color: textMuted),
                          const SizedBox(width: 5),
                          Text(
                            '${thread.commentCount}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Share Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: '${thread.title}\n\nMoko Forum'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tautan thread disalin'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(CupertinoIcons.share, size: 15, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
