import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/anime_repository.dart';
import '../data/models/anime_model.dart';
import 'anime_detail_screen.dart';

class AnimeListScreen extends StatefulWidget {
  const AnimeListScreen({super.key, this.initialLetter = 'A'});

  final String initialLetter;

  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen> {
  final _repo = AnimeRepository.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _letterScrollCtrl = ScrollController();

  static const List<String> _letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  late String _selectedLetter;
  final Map<String, YlnimeAnimeListResponse> _cache = {};
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _selectedLetter = widget.initialLetter;
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _loadLetter(_selectedLetter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _letterScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLetter(String letter, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(letter)) {
      setState(() {
        _selectedLetter = letter;
        _error = null;
      });
      return;
    }

    setState(() {
      _selectedLetter = letter;
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _repo.ylnimeAnimeList(letter: letter);
      if (!mounted) return;
      _cache[letter] = resp;
      setState(() {
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

  List<YlnimeAnimeListItem> _getFilteredItems() {
    final curResponse = _cache[_selectedLetter];
    if (curResponse == null) return [];
    if (_searchQuery.isEmpty) return curResponse.animeList;
    return curResponse.animeList.where((item) {
      return item.title.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final curResponse = _cache[_selectedLetter];
    final items = _getFilteredItems();

    return Scaffold(
      backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight,
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
                  // Top Header
                  _buildHeader(isDark, curResponse),

                  // Horizontal A-Z Selector
                  _buildLetterBar(isDark),

                  // Search bar & view toggle
                  _buildSearchBar(isDark, items.length),

                  // Main content
                  Expanded(
                    child: _buildBody(isDark, items),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, YlnimeAnimeListResponse? response) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                CupertinoIcons.chevron_back,
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
                Row(
                  children: [
                    Text(
                      'Daftar Anime A-Z',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedLetter,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  response != null
                      ? (response.letterDisplay ?? '${response.totalAnime} judul tersedia')
                      : 'Katalog lengkap semua judul anime',
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
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isGridView = !_isGridView;
              });
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

  Widget _buildLetterBar(bool isDark) {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        controller: _letterScrollCtrl,
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final letter = _letters[i];
          final isSelected = letter == _selectedLetter;

          return GestureDetector(
            onTap: () {
              if (_selectedLetter != letter) {
                HapticFeedback.selectionClick();
                _loadLetter(letter);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              alignment: Alignment.center,
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
                letter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, int resultCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari di huruf $_selectedLetter...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 16,
                    color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 16,
                            color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
              '$resultCount judul',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, List<YlnimeAnimeListItem> items) {
    if (_loading && !_cache.containsKey(_selectedLetter)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_cache.containsKey(_selectedLetter)) {
      return ErrorState(
        message: _error!,
        onRetry: () => _loadLetter(_selectedLetter, forceRefresh: true),
      );
    }

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.movie_outlined,
        title: _searchQuery.isNotEmpty
            ? 'Tidak ada hasil pencarian'
            : 'Tidak ada anime dengan awalan "$_selectedLetter"',
        subtitle: _searchQuery.isNotEmpty
            ? 'Coba kata kunci lain atau hapus pencarian.'
            : 'Pilih huruf lain dari daftar di atas.',
      );
    }

    return RefreshIndicator(
      color: isDark ? Colors.white : Colors.black,
      onRefresh: () => _loadLetter(_selectedLetter, forceRefresh: true),
      child: _isGridView ? _buildGrid(items) : _buildList(isDark, items),
    );
  }

  Widget _buildGrid(List<YlnimeAnimeListItem> items) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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
          imageUrl: item.effectiveCover,
          badge: (item.type != null && item.type!.isNotEmpty) ? item.type : null,
          width: double.infinity,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnimeDetailScreen(
                  animeId: item.seriesKey,
                  anime: item.toAnimeModel(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildList(bool isDark, List<YlnimeAnimeListItem> items) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimeDetailScreen(
                    animeId: item.seriesKey,
                    anime: item.toAnimeModel(),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 58,
                      height: 80,
                      child: AppNetworkImage(
                        url: item.effectiveCover,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.firstLetter ?? _selectedLetter,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            if (item.type != null && item.type!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.type!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              'Lihat Episode',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.iosTextSecondaryDark : AppColors.iosTextSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

