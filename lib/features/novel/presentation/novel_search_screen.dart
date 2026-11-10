import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';
import 'novel_detail_screen.dart';

class NovelSearchScreen extends StatefulWidget {
  final String? initialGenre;

  const NovelSearchScreen({super.key, this.initialGenre});

  @override
  State<NovelSearchScreen> createState() => _NovelSearchScreenState();
}

class _NovelSearchScreenState extends State<NovelSearchScreen> {
  final _repo = NovelRepository.instance;
  final _searchController = TextEditingController();

  List<NovelItemModel> _results = [];
  List<NovelGenreModel> _genres = [];
  String? _selectedGenre;
  bool _loading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialGenre;
    _loadGenres();
    if (_selectedGenre != null && _selectedGenre!.isNotEmpty) {
      _fetchByGenre(_selectedGenre!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    final list = await _repo.getNovelGenres();
    if (mounted) {
      setState(() => _genres = list);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      if (_selectedGenre != null) {
        _fetchByGenre(_selectedGenre!);
      } else {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.searchNovels(query);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Pencarian gagal: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchByGenre(String genreSlug) async {
    setState(() {
      _selectedGenre = genreSlug;
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.getNovelsByGenre(genreSlug);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat genre: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter = _searchController.text.isNotEmpty || _selectedGenre != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isDesktop(context)
                    ? Responsive.maxContentWidth
                    : double.infinity,
              ),
              child: Column(
                children: [
                  // ── Apple Header & Spotlight Search Box ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.maybePop(context);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : Colors.transparent,
                                    width: 0.5,
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.chevron_back,
                                  size: 18,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Cari Web Novel',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            if (hasActiveFilter) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _searchController.clear();
                                  setState(() {
                                    _selectedGenre = null;
                                    _results.clear();
                                    _error = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.18 : 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Apple Spotlight Search Bar
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.transparent,
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
                                  autofocus: widget.initialGenre == null,
                                  onChanged: _onSearchChanged,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Cari judul web novel...',
                                    hintStyle: TextStyle(
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 18,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── GENRE FILTER CHIPS ──
                  if (_genres.isNotEmpty) ...[
                    Container(
                      height: 42,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _genres.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final g = _genres[idx];
                          final isSelected = _selectedGenre == g.slug;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (isSelected) {
                                setState(() {
                                  _selectedGenre = null;
                                  _results = [];
                                });
                              } else {
                                _fetchByGenre(g.slug);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: 0.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.15 : 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                g.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── RESULTS LIST ──
                  Expanded(
                    child: _loading
                        ? Center(
                            child: CupertinoActivityIndicator(
                              radius: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : _results.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.book,
                                          size: 48,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchController.text.isNotEmpty
                                              ? 'Tidak ada novel yang cocok dengan "${_searchController.text}"'
                                              : 'Ketik judul atau pilih genre untuk mencari novel',
                                          style: TextStyle(
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _results.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (ctx, idx) {
                                      final item = _results[idx];
                                      return _buildNovelSearchCard(item, isDark);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNovelSearchCard(
    NovelItemModel item,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => NovelDetailScreen(
              slug: item.slug,
              initialTitle: item.title,
              initialPoster: item.poster,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
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
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 75,
                height: 105,
                child: AppNetworkImage(
                  url: item.effectivePosterUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.type,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.latestChapter.isNotEmpty)
                      Text(
                        item.latestChapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.status.toLowerCase().contains('ongoing') ? AppColors.brandGreen : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
