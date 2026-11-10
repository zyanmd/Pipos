import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../data/comic_repository.dart';
import '../data/models/comic_model.dart';
import 'comic_detail_screen.dart';
import '../../../shared/widgets/ad_banner_widget.dart';

/// Screen for browsing comics alphabetically (A-Z) and filtered by type.
class ComicDaftarScreen extends StatefulWidget {
  const ComicDaftarScreen({
    super.key,
    this.initialTipe,
    this.initialHuruf,
  });

  final String? initialTipe;
  final String? initialHuruf;

  @override
  State<ComicDaftarScreen> createState() => _ComicDaftarScreenState();
}

class _ComicDaftarScreenState extends State<ComicDaftarScreen> {
  final _repo = ComicRepository.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _letterScrollCtrl = ScrollController();

  static const List<String> _alphabet = [
    'Semua',
    '#',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  static const List<Map<String, String?>> _typeOptions = [
    {'label': 'Semua', 'val': null},
    {'label': 'Manga', 'val': 'manga'},
    {'label': 'Manhwa', 'val': 'manhwa'},
    {'label': 'Manhua', 'val': 'manhua'},
  ];

  String? _selectedTipe;
  String? _selectedHuruf; // null means 'Semua'
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalComics = 0;
  bool _hasNext = false;
  bool _hasPrev = false;

  bool _loading = true;
  String? _error;
  List<ComicModel> _items = [];
  List<DaftarLetterModel> _serverLetters = [];
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _selectedTipe = widget.initialTipe;
    _selectedHuruf = widget.initialHuruf;
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _letterScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool resetScroll = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (resetScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    try {
      final res = await _repo.daftarKomik(
        tipe: _selectedTipe,
        huruf: _selectedHuruf,
        halaman: _currentPage,
      );

      if (!mounted) return;
      setState(() {
        _items = res.items;
        _serverLetters = res.letters;
        _totalComics = res.total;
        _currentPage = res.currentPage;
        _totalPages = res.totalPages;
        _hasNext = res.hasNext;
        _hasPrev = res.hasPrev;
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

  void _onTipeSelected(String? tipe) {
    if (_selectedTipe == tipe) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTipe = tipe;
      _currentPage = 1;
    });
    _loadData(resetScroll: true);
  }

  void _onHurufSelected(String? huruf) {
    final target = (huruf == null || huruf == 'Semua') ? null : huruf;
    if (_selectedHuruf == target) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHuruf = target;
      _currentPage = 1;
    });
    _loadData(resetScroll: true);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage || _loading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentPage = page;
    });
    _loadData(resetScroll: true);
  }

  List<ComicModel> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((c) {
      final titleMatch = c.title.toLowerCase().contains(_searchQuery);
      final genreMatch = (c.genre ?? '').toLowerCase().contains(_searchQuery);
      final typeMatch = (c.type ?? '').toLowerCase().contains(_searchQuery);
      return titleMatch || genreMatch || typeMatch;
    }).toList();
  }

  String _formatTotalCount(int count) {
    if (count <= 0) return '';
    final str = count.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayItems = _filteredItems;

    return Scaffold(
      backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isDesktop(context)
                    ? Responsive.maxContentWidth
                    : double.infinity,
              ),
              child: Column(
                children: [
                  // Navigation / App Bar Header
                  _buildTopBar(isDark),

                  // Type Selector (Semua, Manga, Manhwa, Manhua)
                  _buildTypeTabs(isDark),

                  // Horizontal Alphabet strip
                  _buildAlphabetBar(isDark),

                  // Search & View Mode Switcher
                  _buildSearchAndToolsBar(isDark, displayItems.length),

                  // Content Body
                  Expanded(
                    child: RefreshIndicator(
                      color: isDark ? Colors.white : Colors.black,
                      onRefresh: () => _loadData(),
                      child: _buildContent(isDark, displayItems),
                    ),
                  ),

                  // Bottom Banner Ad
                  const AdBannerWidget(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),

                  // Bottom Pagination Bar (if multiple pages or loaded)
                  if (!_loading && _totalPages > 1)
                    _buildPaginationBar(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    final countStr = _formatTotalCount(_totalComics);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
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
                CupertinoIcons.chevron_left,
                size: 18,
                color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daftar Komik',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                  ),
                ),
                Text(
                  countStr.isNotEmpty
                      ? '$countStr komik terdaftar'
                      : 'Katalog komik berdasarkan abjad & tipe',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // View Mode Toggle (Grid vs List)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isGridView = !_isGridView);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
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
                _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
                size: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs(bool isDark) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _typeOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _typeOptions[i];
          final val = opt['val'];
          final isSelected = _selectedTipe == val;

          return GestureDetector(
            onTap: () => _onTipeSelected(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? AppColors.iosCardDark : AppColors.iosCardLight),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
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
                opt['label']!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlphabetBar(bool isDark) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        controller: _letterScrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _alphabet.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final letter = _alphabet[i];
          final isSemua = letter == 'Semua';
          final isSelected = isSemua
              ? _selectedHuruf == null
              : _selectedHuruf?.toUpperCase() == letter.toUpperCase();

          // Find server count if exists
          String? countBadge;
          if (!isSemua && _serverLetters.isNotEmpty) {
            for (final sl in _serverLetters) {
              if (sl.label.trim().toUpperCase() == letter.toUpperCase() ||
                  sl.huruf?.trim().toUpperCase() == letter.toUpperCase()) {
                if (sl.count != '0') {
                  countBadge = sl.count;
                }
                break;
              }
            }
          }

          return GestureDetector(
            onTap: () => _onHurufSelected(isSemua ? null : letter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: isSemua ? 14 : 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(12),
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
                    letter,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight),
                    ),
                  ),
                  if (countBadge != null && !isSelected) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        countBadge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndToolsBar(bool isDark, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.search,
              size: 16,
              color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter komik di halaman ini...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  FocusScope.of(context).unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 16,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count komik',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, List<ComicModel> items) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 12),
            Text(
              'Memuat katalog komik...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 48, color: Colors.amber),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadData(),
                icon: Icon(CupertinoIcons.refresh, size: 16, color: isDark ? Colors.black : Colors.white),
                label: Text('Coba Lagi', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 4,
                  shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.book,
              size: 54,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada komik yang cocok dengan "$_searchQuery"'
                  : 'Tidak ada komik untuk filter ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              TextButton(
                onPressed: () => _searchCtrl.clear(),
                child: const Text('Reset Pencarian'),
              ),
          ],
        ),
      );
    }

    return _isGridView ? _buildGrid(isDark, items) : _buildList(isDark, items);
  }

  Widget _buildGrid(bool isDark, List<ComicModel> items) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.65,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return PosterCard(
          title: item.title,
          imageUrl: item.thumb,
          subtitle: item.genre != null && item.genre!.isNotEmpty
              ? item.genre
              : (item.status ?? item.latestChapter),
          badge: item.type,
          width: double.infinity,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => ComicDetailScreen(
                  slug: item.slug,
                  comic: item,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildList(bool isDark, List<ComicModel> items) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => ComicDetailScreen(
                  slug: item.slug,
                  comic: item,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Cover thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54,
                    height: 76,
                    child: AppNetworkImage(
                      url: item.thumb,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.type != null && item.type!.isNotEmpty)
                            _buildMiniBadge(
                              item.type!,
                              isDark,
                              color: _getTypeColor(item.type!, isDark),
                            ),
                          if (item.genre != null && item.genre!.isNotEmpty)
                            _buildMiniBadge(
                              item.genre!,
                              isDark,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          if (item.status != null && item.status!.isNotEmpty)
                            _buildMiniBadge(
                              item.status!,
                              isDark,
                              color: item.status!.toLowerCase().contains('end') ||
                                      item.status!.toLowerCase().contains('tamat')
                                  ? Colors.teal
                                  : Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge(String text, bool isDark, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'manga':
        return Colors.redAccent;
      case 'manhwa':
        return Colors.deepPurpleAccent;
      case 'manhua':
        return Colors.teal;
      default:
        return isDark ? Colors.white70 : Colors.black87;
    }
  }

  Widget _buildPaginationBar(bool isDark) {
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight)
                .withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              GestureDetector(
                onTap: (_hasPrev || _currentPage > 1) && !_loading
                    ? () => _goToPage(_currentPage - 1)
                    : null,
                child: Opacity(
                  opacity: (_hasPrev || _currentPage > 1) && !_loading ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: 14,
                          color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sebelumnya',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Current page pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Hal. $_currentPage dari $_totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),

              // Next button
              GestureDetector(
                onTap: (_hasNext || _currentPage < _totalPages) && !_loading
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                child: Opacity(
                  opacity: (_hasNext || _currentPage < _totalPages) && !_loading ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Berikutnya',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
