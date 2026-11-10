import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../data/anime_repository.dart';
import '../data/models/ylnime_extra_models.dart';
import 'anime_search_screen.dart';
import 'widgets/duel_podium_widget.dart';

/// Polling & Duel Karakter Screen (GET /api/ylnime/polling?k=...)
/// Replicates AnimeScheduleScreen design language:
/// - AmbientBackground + iOS Large Title SliverAppBar (112pt)
/// - Category capsule pills matching Jadwal Rilis
/// - Interactive Duel Arena (Card A vs Card B)
/// - Responsive PosterCard SliverGrid for Leaderboard
class AnimePollingScreen extends StatefulWidget {
  final String? initialCategory;
  const AnimePollingScreen({super.key, this.initialCategory});

  @override
  State<AnimePollingScreen> createState() => _AnimePollingScreenState();
}

class _AnimePollingScreenState extends State<AnimePollingScreen> {
  final _repo = AnimeRepository.instance;
  late String _selectedCategory;
  bool _loading = true;
  String? _error;
  PollingPageData? _data;
  String? _votedCardId;

  static const _categories = [
    {'key': 'cantik', 'label': 'Cantik', 'icon': '🌸'},
    {'key': 'tampan', 'label': 'Tampan', 'icon': '✨'},
    {'key': 'kuat', 'label': 'Kuat', 'icon': '⚡'},
    {'key': 'pasangan', 'label': 'Pasangan', 'icon': '💑'},
    {'key': 'anime', 'label': 'Top Anime', 'icon': '🏆'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'cantik';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _votedCardId = null;
    });
    try {
      final res = await _repo.getPolling(kategori: _selectedCategory);
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

  void _onCategorySelected(String key) {
    if (_selectedCategory == key) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = key;
    });
    _load();
  }

  void _onVote(String? id, String name) {
    if (id == null && name.isEmpty) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _votedCardId = id ?? name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Memilih $name!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
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

  Widget _buildDuelFighter(PollingDuelCard card, bool isDark) {
    final isVoted = _votedCardId == (card.id ?? card.nama);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVoted
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
          width: isVoted ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: card.img != null && card.img!.isNotEmpty
                  ? AppNetworkImage(
                      url: card.img!,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(CupertinoIcons.person_fill, color: Colors.white38),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.nama,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          if (card.anime != null && card.anime!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              card.anime!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _onVote(card.id, card.nama),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isVoted
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  isVoted ? '✓ TERPILIH' : 'VOTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isVoted
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardA = _data?.cardA;
    final cardB = _data?.cardB;
    final leaderboard = _data?.leaderboard ?? [];

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
              onRefresh: _load,
              child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // iOS Large Title SliverAppBar matching AnimeScheduleScreen
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
                      title: Text(
                        'Duel Karakter',
                        style: TextStyle(
                          fontSize: isShrunk ? 17 : 32,
                          fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: isShrunk ? -0.4 : -1.0,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Category Capsule Pills matching AnimeScheduleScreen
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final key = cat['key']!;
                        final label = cat['label']!;
                        final isSelected = _selectedCategory == key;

                        return GestureDetector(
                          onTap: () => _onCategorySelected(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat['icon']!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.black : Colors.white)
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              if (_loading)
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
                      (context, index) => const ShimmerPlaceholder(
                        borderRadius: 12,
                      ),
                      childCount: 6,
                    ),
                  ),
                )
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
                            size: 48,
                            color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            onPressed: _load,
                            child: Text('Coba Lagi', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Duel Arena Card A vs Card B
                if (cardA != null && cardB != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_data?.pertanyaan != null) ...[
                              Text(
                                _data!.pertanyaan!,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(child: _buildDuelFighter(cardA, isDark)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Center(
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                          border: Border.all(
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: _buildDuelFighter(cardB, isDark)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Leaderboard Section: Epic 3D Podium for Top 3 + Grid for Remaining Ranks
                if (leaderboard.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Belum ada peringkat leaderboard.',
                        style: TextStyle(
                          color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Grand Podium Juara (Top 3)
                  SliverToBoxAdapter(
                    child: DuelPodiumWidget(
                      leaderboard: leaderboard.take(3).toList(),
                      isDark: isDark,
                      isCompact: false,
                      onSelect: (row) {
                        if (row.subtitle != null && row.subtitle!.isNotEmpty) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => AnimeSearchScreen(initialQuery: row.subtitle!),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // Remaining Leaderboard (Rank 4+)
                  if (leaderboard.length > 3) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Peringkat Selanjutnya (#4 - #${leaderboard.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              '${leaderboard.length - 3} Karakter',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          (context, index) {
                            final row = leaderboard[index + 3];
                            final rank = row.rank ?? (index + 4);

                            return PosterCard(
                              title: row.name,
                              imageUrl: row.img,
                              badge: '#$rank',
                              subtitle: row.score != null ? 'Skor: ${row.score}' : row.subtitle,
                              onTap: () {
                                if (row.subtitle != null && row.subtitle!.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => AnimeSearchScreen(initialQuery: row.subtitle!),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          childCount: leaderboard.length - 3,
                        ),
                      ),
                    ),
                  ],
                ],
              ],

              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.bottomNavPadding(context) + 16),
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
