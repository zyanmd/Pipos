import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../comic/data/comic_repository.dart';
import 'genre_detail_screen.dart';

enum GenreType { anime, comic }

class UnifiedGenreScreen extends StatefulWidget {
  final GenreType initialType;

  const UnifiedGenreScreen({
    super.key,
    this.initialType = GenreType.anime,
  });

  @override
  State<UnifiedGenreScreen> createState() => _UnifiedGenreScreenState();
}

class _UnifiedGenreScreenState extends State<UnifiedGenreScreen> {
  late GenreType _selectedType;
  final TextEditingController _searchController = TextEditingController();

  List<GenreModel> _animeGenres = [];
  List<GenreModel> _comicGenres = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadGenres();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        AnimeRepository.instance.genres().catchError((_) => <GenreModel>[]),
        ComicRepository.instance.genres().catchError((_) => <GenreModel>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _animeGenres = results[0];
        _comicGenres = results[1];
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

  List<GenreModel> get _currentList {
    final raw = _selectedType == GenreType.anime ? _animeGenres : _comicGenres;
    if (_searchQuery.trim().isEmpty) return raw;
    final query = _searchQuery.toLowerCase();
    return raw.where((g) => g.name.toLowerCase().contains(query)).toList();
  }

  IconData _getGenreIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('action') || n.contains('martial') || n.contains('aksi')) {
      return CupertinoIcons.bolt_fill;
    }
    if (n.contains('adventure') || n.contains('petualang')) {
      return CupertinoIcons.compass_fill;
    }
    if (n.contains('comedy') || n.contains('komedi') || n.contains('humor')) {
      return CupertinoIcons.smiley_fill;
    }
    if (n.contains('romance') || n.contains('love') || n.contains('romantis')) {
      return CupertinoIcons.heart_fill;
    }
    if (n.contains('fantasy') || n.contains('magic') || n.contains('fantasi')) {
      return CupertinoIcons.sparkles;
    }
    if (n.contains('horror') || n.contains('thriller') || n.contains('horor')) {
      return CupertinoIcons.moon_stars_fill;
    }
    if (n.contains('sci-fi') || n.contains('space') || n.contains('mecha')) {
      return CupertinoIcons.rocket_fill;
    }
    if (n.contains('school') || n.contains('sekolah')) {
      return CupertinoIcons.book_fill;
    }
    if (n.contains('sport') || n.contains('olahraga')) {
      return CupertinoIcons.sportscourt_fill;
    }
    if (n.contains('music') || n.contains('musik')) {
      return CupertinoIcons.music_note_2;
    }
    if (n.contains('mystery') || n.contains('misteri') || n.contains('detective')) {
      return CupertinoIcons.search;
    }
    if (n.contains('slice') || n.contains('kehidupan') || n.contains('santai')) {
      return CupertinoIcons.sun_max_fill;
    }
    if (n.contains('drama')) {
      return CupertinoIcons.film_fill;
    }
    if (n.contains('supernatural') || n.contains('super') || n.contains('gaib')) {
      return CupertinoIcons.waveform_path_ecg;
    }
    if (n.contains('game') || n.contains('permainan')) {
      return CupertinoIcons.gamecontroller_fill;
    }
    if (n.contains('historical') || n.contains('sejarah') || n.contains('samurai')) {
      return CupertinoIcons.shield_fill;
    }
    return CupertinoIcons.square_grid_2x2_fill;
  }

  Color _getGenreColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('action') || n.contains('martial')) return const Color(0xFFFF2D55);
    if (n.contains('adventure')) return const Color(0xFFFF9500);
    if (n.contains('comedy')) return const Color(0xFFFFCC00);
    if (n.contains('romance')) return const Color(0xFFFF375F);
    if (n.contains('fantasy') || n.contains('magic')) return const Color(0xFFAF52DE);
    if (n.contains('horror') || n.contains('thriller')) return const Color(0xFFFF453A);
    if (n.contains('sci-fi') || n.contains('mecha')) return const Color(0xFF0A84FF);
    if (n.contains('school')) return const Color(0xFF30D158);
    if (n.contains('sports') || n.contains('sport')) return const Color(0xFF34C759);
    if (n.contains('music')) return const Color(0xFFBF5AF2);
    if (n.contains('slice')) return const Color(0xFF5E5CE6);
    return const Color(0xFF5E5CE6);
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
    final displayList = _currentList;

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
              onRefresh: _loadGenres,
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
                      _loadGenres();
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
                        'Jelajah Genre',
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

              // Segmented Control (Anime vs Komik)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                    child: CupertinoSlidingSegmentedControl<GenreType>(
                      groupValue: _selectedType,
                      backgroundColor: Colors.transparent,
                      thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      children: {
                        GenreType.anime: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.play_circle_fill,
                                size: 15,
                                color: _selectedType == GenreType.anime
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Anime (${_animeGenres.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedType == GenreType.anime
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GenreType.comic: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.book_fill,
                                size: 15,
                                color: _selectedType == GenreType.comic
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Komik (${_comicGenres.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedType == GenreType.comic
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null && val != _selectedType) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = val);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Spotlight Search Field
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 18,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari genre ${_selectedType == GenreType.anime ? "anime" : "komik"}...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              CupertinoIcons.clear_thick_circled,
                              size: 17,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content Area
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(
                        context,
                        mobile: 2,
                        tablet: 3,
                        desktop: 4,
                        wideDesktop: 5,
                      ),
                      childAspectRatio: 2.15,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => ShimmerPlaceholder(
                        width: double.infinity,
                        height: 64,
                        borderRadius: 14,
                      ),
                      childCount: 14,
                    ),
                  ),
                )
              else if (_error != null && displayList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ErrorState(
                      message: _error!,
                      onRetry: _loadGenres,
                    ),
                  ),
                )
              else if (displayList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.search,
                      title: 'Genre tidak ditemukan',
                      subtitle: 'Coba kata kunci lain atau bersihkan kotak pencarian.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(
                        context,
                        mobile: 2,
                        tablet: 3,
                        desktop: 4,
                        wideDesktop: 5,
                      ),
                      childAspectRatio: 2.15,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = displayList[index];
                        final tintColor = _getGenreColor(g.name);
                        final icon = _getGenreIcon(g.name);
                        final isComic = _selectedType == GenreType.comic;

                        return RepaintBoundary(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => GenreDetailScreen(
                                      genre: g,
                                      isAnime: !isComic,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Tinted Icon Squircle
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: tintColor.withValues(alpha: isDark ? 0.16 : 0.10),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: tintColor.withValues(alpha: isDark ? 0.30 : 0.20),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: tintColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Genre Name & Count
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            g.count != null && g.count!.isNotEmpty
                                                ? '${g.count} judul'
                                                : (isComic ? 'Koleksi Komik' : 'Koleksi Anime'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: displayList.length,
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
