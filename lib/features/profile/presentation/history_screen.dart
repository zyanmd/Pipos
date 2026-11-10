import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/config/api_config.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_episode_player.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_reader_screen.dart';
import '../../novel/data/novel_repository.dart';
import '../../novel/presentation/novel_detail_screen.dart';
import '../../novel/presentation/novel_reader_screen.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/smooth_entrance_transition.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Mode { anime, comic, novel }

class _HistoryScreenState extends State<HistoryScreen> {
  _Mode _mode = _Mode.anime;
  List<Map<String, dynamic>> _animeHistory = [];
  List<Map<String, dynamic>> _comicHistory = [];
  List<Map<String, dynamic>> _novelHistory = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final localAnimeHistory =
          await AnimeWatchProgressService.instance.getRecentAnimeHistoryMaps();

      List<Map<String, dynamic>> remoteAnime = [];
      List<Map<String, dynamic>> remoteComic = [];

      if (auth.isAuthenticated) {
        final results = await Future.wait([
          AnimeRepository.instance.watchHistory().catchError((_) => <Map<String, dynamic>>[]),
          ComicRepository.instance.readHistory().catchError((_) => <Map<String, dynamic>>[]),
        ]);
        remoteAnime = results[0];
        remoteComic = results[1];
      }

      // Gabungkan riwayat anime lokal dan remote secara cerdas:
      final Map<String, Map<String, dynamic>> mergedMap = {};

      // 1. Masukkan semua riwayat dari server (katalog lengkap riwayat akun)
      for (final item in remoteAnime) {
        final rawId = (item['anime_id'] ?? item['id'] ?? '').toString();
        final cleanId = AnimeWatchProgressService.cleanAnimeSlug(rawId).isNotEmpty
            ? AnimeWatchProgressService.cleanAnimeSlug(rawId)
            : rawId.trim().toLowerCase();
        if (cleanId.isNotEmpty) {
          mergedMap[cleanId] = Map<String, dynamic>.from(item);
        }
      }

      // 2. Timpa/update dengan riwayat lokal perangkat (progress detik realtime lokal)
      for (final local in localAnimeHistory) {
        final rawId = (local['anime_id'] ?? local['id'] ?? '').toString();
        final cleanId = AnimeWatchProgressService.cleanAnimeSlug(rawId).isNotEmpty
            ? AnimeWatchProgressService.cleanAnimeSlug(rawId)
            : rawId.trim().toLowerCase();
        if (cleanId.isEmpty) continue;

        if (mergedMap.containsKey(cleanId)) {
          final existing = mergedMap[cleanId]!;
          mergedMap[cleanId] = {
            ...existing,
            ...local,
            // Pertahankan thumbnail/title remote jika di lokal belum sempat terisi lengkap
            'thumbnail': (local['thumbnail'] != null && local['thumbnail'].toString().isNotEmpty)
                ? local['thumbnail']
                : existing['thumbnail'],
            'anime_title': (local['anime_title'] != null &&
                    local['anime_title'].toString().isNotEmpty &&
                    local['anime_title'] != cleanId)
                ? local['anime_title']
                : (existing['anime_title'] ?? cleanId),
          };
        } else {
          mergedMap[cleanId] = Map<String, dynamic>.from(local);
        }
      }

      final List<Map<String, dynamic>> finalAnime = mergedMap.values.toList();
      finalAnime.sort((a, b) {
        final timeA = a['watched_at'] ?? a['updated_at'] ?? a['created_at'];
        final timeB = b['watched_at'] ?? b['updated_at'] ?? b['created_at'];
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.toString().compareTo(timeA.toString());
      });

      List<Map<String, dynamic>> localNovel = [];
      try {
        localNovel = await NovelRepository.instance.getReadingHistory();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _animeHistory = finalAnime;
        _comicHistory = remoteComic;
        _novelHistory = localNovel;
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

  Future<void> _removeItem(String id, int index) async {
    HapticFeedback.lightImpact();
    try {
      if (_mode == _Mode.anime) {
        await AnimeWatchProgressService.instance.removeAnimeHistory(id);
        AnimeRepository.instance.removeFromHistory(id).catchError((_) {});
        setState(() => _animeHistory.removeAt(index));
      } else if (_mode == _Mode.comic) {
        await ComicRepository.instance.removeFromHistory(id);
        setState(() => _comicHistory.removeAt(index));
      } else {
        await NovelRepository.instance.removeHistory(id);
        setState(() => _novelHistory.removeAt(index));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Riwayat berhasil dihapus'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  String _formatRelativeTime(String? raw) {
    return AppDateUtils.formatTimeAgo(raw);
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
    final currentList = _mode == _Mode.anime
        ? _animeHistory
        : (_mode == _Mode.comic ? _comicHistory : _novelHistory);

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SmoothEntranceTransition(
          child: Center(
            child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxProfileWidth
                  : double.infinity,
            ),
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
                            'Riwayat',
                            style: TextStyle(
                              fontSize: isShrunk ? 17 : 32,
                              fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: isShrunk ? -0.4 : -1.0,
                            ),
                          ),
                          if (!isShrunk && currentList.isNotEmpty) ...[
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
                                '${currentList.length}',
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
                    child: CupertinoSlidingSegmentedControl<_Mode>(
                      groupValue: _mode,
                      backgroundColor: Colors.transparent,
                      thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      children: {
                        _Mode.anime: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.play_circle_fill,
                                size: 14,
                                color: _mode == _Mode.anime
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Anime (${_animeHistory.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _mode == _Mode.anime
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Mode.comic: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.book_fill,
                                size: 14,
                                color: _mode == _Mode.comic
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Komik (${_comicHistory.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _mode == _Mode.comic
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Mode.novel: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.text_quote,
                                size: 14,
                                color: _mode == _Mode.novel
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Novel (${_novelHistory.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _mode == _Mode.novel
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null && val != _mode) {
                          HapticFeedback.selectionClick();
                          setState(() => _mode = val);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Banner Ad
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: AdBannerWidget(),
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
              else if (currentList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.clock,
                      title: 'Belum ada riwayat',
                      subtitle: _mode == _Mode.anime
                          ? 'Tonton episode anime untuk menyimpannya di sini.'
                          : (_mode == _Mode.comic
                              ? 'Baca chapter komik untuk menyimpannya di sini.'
                              : 'Baca chapter web novel untuk menyimpannya di sini.'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final item = currentList[index];
                        return _buildHistoryTile(item, index, isDark);
                      },
                      childCount: currentList.length,
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
),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item, int index, bool isDark) {
    if (_mode == _Mode.anime) {
      final m = AnimeHistoryModel.fromJson(item);
      final thumb = m.thumbnail;
      final timeStr = _formatRelativeTime(m.watchedAt);
      final hasProgress = m.durationProgressText.isNotEmpty;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              HapticFeedback.selectionClick();

              // Clean episodeId: never default to animeId as that breaks URL resolution
              String epId = '';
              if (m.episodeId != null &&
                  m.episodeId!.isNotEmpty &&
                  m.episodeId != m.animeId) {
                epId = m.episodeId!;
              } else if (m.episodeNumber != null &&
                  m.episodeNumber!.isNotEmpty &&
                  m.episodeNumber != '0') {
                epId = m.episodeNumber!;
              }

              if (!mounted) return;
              await Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => AnimeEpisodePlayerScreen(
                    episodeId: epId,
                    episodeLabel: m.formattedEpisode,
                    episodeUrl: m.episodeUrl,
                    animeId: m.animeId,
                    animeTitle: m.animeTitle,
                    animeThumb: thumb,
                    startAt: m.currentTime > 0 ? Duration(seconds: m.currentTime) : Duration.zero,
                  ),
                ),
              );
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 68,
                          height: 92,
                          child: thumb != null && thumb.isNotEmpty
                              ? Image.network(
                                  thumb.startsWith('http') ? thumb : '${ApiConfig.baseUrl}$thumb',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                                    child: const Icon(CupertinoIcons.film, color: Colors.grey, size: 24),
                                  ),
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                                  child: const Icon(CupertinoIcons.film, color: Colors.grey, size: 24),
                                ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Detail Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.animeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Episode Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.sakuraGradient),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.play_circle_fill, size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                m.formattedEpisode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Progress / Time Info
                        Row(
                          children: [
                            if (hasProgress) ...[
                              Icon(
                                CupertinoIcons.time,
                                size: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                m.durationProgressText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing Action Buttons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.play_arrow_solid,
                          color: isDark ? Colors.white : Colors.black,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _removeItem(m.animeId, index),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
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
    } else if (_mode == _Mode.comic) {
      final m = ComicHistoryModel.fromJson(item);
      final thumb = (m.comicThumbnail != null && m.comicThumbnail!.isNotEmpty)
          ? m.comicThumbnail!
          : (ComicModel.extractThumbnail(item) ?? '');
      final timeStr = _formatRelativeTime(m.readAt);
      final hasPage = m.pageProgress.isNotEmpty;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              HapticFeedback.selectionClick();
              await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => ComicReaderScreen(
                    chapterId: ComicModel.extractCleanSlug(m.chapterSlug ?? ''),
                    chapterLabel: m.formattedChapter,
                    comicSlug: ComicModel.extractCleanSlug(m.comicSlug),
                    comicTitle: m.comicTitle,
                    comicThumb: thumb,
                    initialPage: m.lastPage > 1 ? (m.lastPage - 1) : null,
                  ),
                ),
              );
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 68,
                          height: 92,
                          child: thumb.isNotEmpty
                              ? AppNetworkImage(
                                  url: thumb,
                                  width: 68,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  borderRadius: 10,
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                                  child: const Icon(CupertinoIcons.book, color: Colors.grey, size: 24),
                                ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.book_fill, color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Detail Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.comicTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Chapter Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.40),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.book_fill, size: 11, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 4),
                              Text(
                                m.formattedChapter,
                                style: const TextStyle(
                                  color: Color(0xFF06B6D4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Progress / Time Info
                        Row(
                          children: [
                            if (hasPage) ...[
                              Icon(
                                CupertinoIcons.bookmark,
                                size: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                m.pageProgress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing Action Buttons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.book_solid,
                          color: Color(0xFF06B6D4),
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _removeItem(m.comicSlug, index),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
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
    } else {
      final novelTitle = item['novel_title']?.toString() ?? 'Web Novel';
      final novelSlug = item['novel_slug']?.toString() ?? '';
      final chapterTitle = item['chapter_title']?.toString() ?? '';
      final chapterSlug = item['chapter_slug']?.toString() ?? '';
      final posterRaw = item['novel_poster']?.toString() ?? '';
      final thumb = ApiEndpoints.novelImageUrl(posterRaw);
      final timeStr = _formatRelativeTime(item['updated_at']?.toString());
      final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
      final progressPercent = (progress * 100).toInt();

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              HapticFeedback.selectionClick();
              if (chapterSlug.isNotEmpty) {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => NovelReaderScreen(
                      chapterSlug: chapterSlug,
                      novelSlug: novelSlug,
                      novelTitle: novelTitle,
                      novelPoster: posterRaw,
                    ),
                  ),
                );
              } else {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => NovelDetailScreen(
                      slug: novelSlug,
                      initialTitle: novelTitle,
                      initialPoster: posterRaw,
                    ),
                  ),
                );
              }
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 68,
                          height: 92,
                          child: thumb.isNotEmpty
                              ? AppNetworkImage(
                                  url: thumb,
                                  width: 68,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  borderRadius: 10,
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                                  child: const Icon(CupertinoIcons.text_quote, color: Colors.grey, size: 24),
                                ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.book_fill, color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Detail Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          novelTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Chapter Pill Badge
                        if (chapterTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.35),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.text_quote, size: 11, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),

                        // Progress / Time Info
                        Row(
                          children: [
                            if (progressPercent > 0) ...[
                              Icon(
                                CupertinoIcons.chart_bar_alt_fill,
                                size: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing Action Buttons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.book_solid,
                          color: Colors.blueAccent,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _removeItem(novelSlug, index),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
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
}
