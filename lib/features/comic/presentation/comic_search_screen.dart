import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import 'comic_detail_screen.dart';
import '../../../shared/widgets/ad_banner_widget.dart';

class ComicSearchScreen extends StatefulWidget {
  const ComicSearchScreen({super.key});

  @override
  State<ComicSearchScreen> createState() => _ComicSearchScreenState();
}

class _ComicSearchScreenState extends State<ComicSearchScreen> {
  final _controller = TextEditingController();
  final _repo = ComicRepository.instance;
  List<ComicModel> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  List<String> _history = [];

  static const String _historyKey = 'recent_comic_searches';
  static const List<String> _popularTags = [
    'Manhwa',
    'Manga',
    'Manhua',
    'Action',
    'Romance',
    'Fantasy',
    'Isekai',
    'Comedy',
    'Martial Arts',
    'Horor',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _history.remove(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > 10) {
      _history = _history.sublist(0, 10);
    }
    await prefs.setStringList(_historyKey, _history);
    if (mounted) setState(() {});
  }

  Future<void> _removeFromHistory(String item) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    _history.remove(item);
    await prefs.setStringList(_historyKey, _history);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) {
      setState(() {
        _history.clear();
      });
    }
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;

    if (query != null) {
      _controller.text = query;
    }
    _addToHistory(q);
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final res = await _repo.search(q);
      if (!mounted) return;
      setState(() {
        _results = res;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: Column(
          children: [
            // Apple Header & Spotlight Search Box
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
                        onTap: () => Navigator.maybePop(context),
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
                          'Cari Komik',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (_hasSearched) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _controller.clear();
                            setState(() {
                              _results.clear();
                              _hasSearched = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFF0A84FF),
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
                            controller: _controller,
                            onSubmitted: (val) => _search(),
                            textInputAction: TextInputAction.search,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari manga, manhwa, manhua, genre...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                CupertinoIcons.clear_thick_circled,
                                size: 17,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _search();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              'Cari',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Body: Suggestions / History OR Search Results
            Expanded(
              child: _loading
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.gridColumns(context),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.60,
                      ),
                      itemCount: 6,
                      itemBuilder: (c, i) => const AnimeCardSkeleton(),
                    )
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: () => _search())
                      : _hasSearched
                          ? _results.isEmpty
                              ? EmptyState(
                                  icon: CupertinoIcons.search,
                                  title: 'Komik tidak ditemukan',
                                  subtitle: 'Coba gunakan kata kunci lain atau pilih rekomendasi kategori.',
                                )
                              : _buildResultsList(isDark)
                          : _buildSearchSuggestions(isDark),
            ),
            const AdBannerWidget(
              margin: EdgeInsets.fromLTRB(16, 4, 16, 8),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildSearchSuggestions(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches Section
        if (_history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.clock_fill, size: 16, color: Color(0xFF0A84FF)),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Pencarian',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _history.map((item) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _search(item);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeFromHistory(item),
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 15,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Popular Comic Tags & Categories
        Row(
          children: [
            const Icon(CupertinoIcons.flame_fill, size: 16, color: Color(0xFF0A84FF)),
            const SizedBox(width: 8),
            Text(
              'Kategori & Genre Populer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: _popularTags.map((tag) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _search(tag);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.30 : 0.20),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFF0A84FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),
        // Apple Comic Info Callout Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.book_fill, color: Color(0xFF0A84FF), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koleksi Komik Lengkap',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Temukan ribuan chapter manga hitam-putih, manhwa berwarna, dan manhua terupdate setiap hari.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Ditemukan ${_results.length} komik untuk "${_controller.text}"',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.gridColumns(context),
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            itemCount: _results.length,
            itemBuilder: (ctx, i) {
              final c = _results[i];
              return PosterCard(
                title: c.title,
                imageUrl: c.thumb,
                subtitle: c.type ?? c.latestChapter,
                badge: c.rating != null ? '★ ${c.rating}' : null,
                width: double.infinity,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => ComicDetailScreen(
                        slug: c.slug,
                        comic: c,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
