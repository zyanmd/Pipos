import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/ios_capsule_search_bar.dart';
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
  static const List<Map<String, dynamic>> _popularGenres = [
    {'name': 'Manhwa', 'icon': '🇰🇷', 'color': Color(0xFF0EA5E9)},
    {'name': 'Manga', 'icon': '🇯🇵', 'color': Color(0xFFEF4444)},
    {'name': 'Manhua', 'icon': '🇨🇳', 'color': Color(0xFFF59E0B)},
    {'name': 'Action', 'icon': '🔥', 'color': Color(0xFFDC2626)},
    {'name': 'Romance', 'icon': '🌸', 'color': Color(0xFFEC4899)},
    {'name': 'Fantasy', 'icon': '🔮', 'color': Color(0xFF8B5CF6)},
    {'name': 'Isekai', 'icon': '🌀', 'color': Color(0xFF06B6D4)},
    {'name': 'Comedy', 'icon': '🎭', 'color': Color(0xFF10B981)},
    {'name': 'Martial Arts', 'icon': '🥋', 'color': Color(0xFFD97706)},
    {'name': 'Horor', 'icon': '👻', 'color': Color(0xFF6366F1)},
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
            // Modern Capsule Search Bar Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              child: IosCapsuleSearchBar(
                controller: _controller,
                hintText: 'Cari manga, manhwa, manhua...',
                autoFocus: true,
                onSubmitted: (val) => _search(),
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _controller.clear();
                  setState(() {
                    _results.clear();
                    _hasSearched = false;
                  });
                },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Recent Searches Section
        if (_history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.clock_fill,
                      size: 13,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Pencarian',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Hapus Semua',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161622) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeFromHistory(item),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
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

        // Popular Comic Genres
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.flame_fill,
                size: 13,
                color: Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Kategori & Genre Populer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 9,
          children: _popularGenres.map((genre) {
            final name = genre['name'] as String;
            final icon = genre['icon'] as String;
            final color = genre['color'] as Color;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _search(name);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: isDark ? 0.28 : 0.20),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 26),
        // Modern Spotlight Discovery Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF0EA5E9).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.book_fill,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koleksi Komik Lengkap',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Temukan ribuan chapter manga hitam-putih, manhwa berwarna, dan manhua terupdate setiap hari.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white54 : Colors.black54,
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
        // Result summary pill
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.sparkles,
                      size: 13,
                      color: Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_results.length} Komik Ditemukan',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'untuk "${_controller.text}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_results.isEmpty)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.search,
                          size: 26,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tidak Ada Komik Ditemukan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Coba periksa ejaan judul atau pilih salah satu kategori populer di atas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
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
