import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../data/anime_repository.dart';
import '../data/models/anime_model.dart';
import '../data/models/ylnime_extra_models.dart';
import 'anime_detail_screen.dart';

/// Top 20 Anime Terpopuler Screen — Clean, Minimalist, iOS-styled.
class AnimeHyperScreen extends StatefulWidget {
  const AnimeHyperScreen({super.key});

  @override
  State<AnimeHyperScreen> createState() => _AnimeHyperScreenState();
}

class _AnimeHyperScreenState extends State<AnimeHyperScreen> {
  final _repo = AnimeRepository.instance;
  bool _loading = true;
  String? _error;
  HyperPageData? _data;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.getHyper();
      if (!mounted) return;
      setState(() {
        _data = res;
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

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    String? tooltip,
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

  void _openDetail(String title, String? cover, String? url, String? seriesKey) {
    HapticFeedback.selectionClick();
    final effectiveId = seriesKey ?? url ?? title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailScreen(
          animeId: effectiveId,
          anime: AnimeModel(
            id: effectiveId,
            title: title,
            thumb: cover,
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank, bool isDark) {
    if (rank == 1) return const Color(0xFFFFD60A); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  }

  Widget _buildRankNumber(int rank, bool isDark) {
    final color = _getRankColor(rank, isDark);
    final isTop3 = rank <= 3;

    return SizedBox(
      width: 38,
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: rank >= 10 ? 22 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: color,
            shadows: isTop3
                ? [
                    Shadow(
                      color: color.withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawRankings = _data?.rankings ?? [];

    // Synthesize rankings list: ensure Champion (#1) is represented without duplication
    final List<HyperRankingModel> fullRankings = [];
    if (_data?.champion != null) {
      final champ = _data!.champion!;
      final alreadyPresent = rawRankings.any(
        (r) => r.title.toLowerCase() == champ.title.toLowerCase() || r.rank == 1,
      );
      if (!alreadyPresent) {
        fullRankings.add(
          HyperRankingModel(
            rank: 1,
            title: champ.title,
            cover: champ.cover ?? champ.backdrop,
            views: champ.views,
            url: champ.url,
            seriesKey: champ.seriesKey,
          ),
        );
      }
    }
    fullRankings.addAll(rawRankings);

    final top20List = fullRankings.take(20).toList();

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          color: isDark ? Colors.white : Colors.black,
          edgeOffset: 112,
          onRefresh: _load,
          child: CustomScrollView(
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
                    icon: _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
                    tooltip: _isGridView ? 'Tampilan List' : 'Tampilan Grid',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isGridView = !_isGridView);
                    },
                    isDark: isDark,
                  ),
                  _buildIosActionButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    tooltip: 'Muat Ulang',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _load();
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
                    final shrinkProgress = (1 - ((currentHeight - minHeight) / (maxHeight - minHeight))).clamp(0.0, 1.0);
                    final isShrunk = shrinkProgress > 0.6;

                    return FlexibleSpaceBar(
                      centerTitle: isShrunk,
                      titlePadding: EdgeInsets.only(
                        left: isShrunk ? 0 : 16,
                        right: isShrunk ? 0 : 16,
                        bottom: isShrunk ? 13 : 12,
                      ),
                      title: Text(
                        'Top 20 Anime',
                        style: TextStyle(
                          fontSize: isShrunk ? 17 : 28,
                          fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: isShrunk ? -0.4 : -0.8,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Clean Subtitle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Row(
                    children: [
                      Text(
                        'Anime terpopuler & paling banyak ditonton',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      if (_data?.period != null && _data!.period.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _data!.period,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Content Area
              if (_loading)
                _buildShimmerList(isDark)
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 44,
                            color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            onPressed: _load,
                            child: Text(
                              'Coba Lagi',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (top20List.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Belum ada data anime populer saat ini.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                      ),
                    ),
                  ),
                )
              else if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final anime = top20List[index];
                        final rank = (anime.rank > 0 && anime.rank <= 20) ? anime.rank : (index + 1);
                        return _buildCleanGridCard(context, anime, rank, isDark);
                      },
                      childCount: top20List.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final anime = top20List[index];
                        final rank = (anime.rank > 0 && anime.rank <= 20) ? anime.rank : (index + 1);
                        return _buildCleanListCard(context, anime, rank, isDark);
                      },
                      childCount: top20List.length,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.bottomNavPadding(context) + 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanListCard(
    BuildContext context,
    HyperRankingModel anime,
    int rank,
    bool isDark,
  ) {
    final isTop3 = rank <= 3;
    final rankAccent = _getRankColor(rank, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.iosCardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop3
              ? rankAccent.withValues(alpha: isDark ? 0.35 : 0.40)
              : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
          width: isTop3 ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(
            anime.title,
            anime.cover,
            anime.url,
            anime.seriesKey,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                // Rank number
                _buildRankNumber(rank, isDark),
                const SizedBox(width: 8),

                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 60,
                    height: 84,
                    child: anime.cover != null && anime.cover!.isNotEmpty
                        ? AppNetworkImage(
                            url: anime.cover!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                            child: Icon(
                              CupertinoIcons.film,
                              color: isDark ? Colors.white24 : Colors.black26,
                              size: 22,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          if (anime.popularityPercent != null && anime.popularityPercent! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759))
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${anime.popularityPercent!.toStringAsFixed(0)}% Populer',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF30D158) : const Color(0xFF34C759),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (anime.views != null && anime.views! > 0) ...[
                            Icon(
                              CupertinoIcons.eye,
                              size: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.views} views',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing chevron
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanGridCard(
    BuildContext context,
    HyperRankingModel anime,
    int rank,
    bool isDark,
  ) {
    final isTop3 = rank <= 3;
    final rankAccent = _getRankColor(rank, isDark);

    return GestureDetector(
      onTap: () => _openDetail(
        anime.title,
        anime.cover,
        anime.url,
        anime.seriesKey,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isTop3
              ? Border.all(color: rankAccent.withValues(alpha: 0.5), width: 1.0)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster
              anime.cover != null && anime.cover!.isNotEmpty
                  ? AppNetworkImage(
                      url: anime.cover!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade300,
                      child: Icon(
                        CupertinoIcons.film,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),

              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.45, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // Top-left Rank Badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTop3
                        ? rankAccent
                        : Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isTop3 ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),

              // Bottom Title
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const ShimmerPlaceholder(
              borderRadius: 12,
            ),
            childCount: 6,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ShimmerPlaceholder(
              height: 100,
              borderRadius: 14,
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}
