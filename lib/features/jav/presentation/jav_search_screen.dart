import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../data/models/jav_model.dart';
import '../data/jav_repository.dart';
import 'jav_player_screen.dart';

class JavSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const JavSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<JavSearchScreen> createState() => _JavSearchScreenState();
}

class _JavSearchScreenState extends State<JavSearchScreen> {
  final _repo = JavRepository.instance;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  List<JavVideoModel> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _errorMessage;

  String _selectedSort = 'relevant';
  final Map<String, String> _sortOptions = {
    'relevant': 'Relevan',
    'views': 'Terpopuler',
    'latest': 'Terbaru',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!, page: 1);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _performSearch(String query, {int page = 1}) async {
    if (!AdultContentService.instance.is18Unlocked) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final q = query.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _currentPage = page;
    });

    try {
      final list = await _repo.search(
        q,
        page: page,
        sort: _selectedSort,
      );
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
          _hasMore = list.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal melakukan pencarian: $e';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final q = _searchController.text.trim();
    if (q.isEmpty || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;

    try {
      final list = await _repo.search(
        q,
        page: nextPage,
        sort: _selectedSort,
      );
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          if (list.isNotEmpty) {
            _results.addAll(list);
            _currentPage = nextPage;
          } else {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSortChanged(String sort) {
    if (_selectedSort == sort) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedSort = sort);
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text.trim(), page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D12) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF15151D) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1F);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E8E93);

    if (!AdultContentService.instance.is18Unlocked) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(CupertinoIcons.back, color: textPrimary),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock_shield_fill, color: Color(0xFFFF2D55), size: 54),
                const SizedBox(height: 16),
                Text('Mode 18+ Terkunci', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Aktifkan Mode 18+ di Profil untuk mencari konten ini.', textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  child: const Text('Tutup'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(CupertinoIcons.back, color: textPrimary),
        ),
        title: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Cari video JAV, aktris, kode film...',
          style: TextStyle(color: textPrimary, fontSize: 14),
          placeholderStyle: TextStyle(color: textMuted, fontSize: 14),
          prefixIcon: Icon(CupertinoIcons.search, color: textMuted, size: 18),
          suffixIcon: Icon(CupertinoIcons.xmark_circle_fill, color: textMuted, size: 18),
          onSubmitted: (q) => _performSearch(q, page: 1),
          autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
        ),
      ),
      body: Column(
        children: [
          // Filter sort chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _sortOptions.entries.map((e) {
                final isSelected = _selectedSort == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BouncyTap(
                    onTap: () => _onSortChanged(e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF2D55)
                            : (isDark ? const Color(0xFF1C1C24) : Colors.black.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textMuted,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Main Search Content
          Expanded(
            child: _buildContent(isDark, cardBg, textPrimary, textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    if (_isLoading) {
      return Center(
        child: CupertinoActivityIndicator(
          color: isDark ? Colors.white : Colors.black,
          radius: 14,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Color(0xFFFF453A),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              BouncyTap(
                onTap: () => _performSearch(_searchController.text, page: 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search, size: 54, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Cari film JAV berdasarkan judul, kode, atau aktris',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.film, size: 54, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Tidak ada video JAV yang ditemukan.',
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba kata kunci lain atau periksa ejaan.',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoActivityIndicator(),
            ),
          );
        }
        final item = _results[i];
        return _buildVideoCard(item, isDark, cardBg, textPrimary, textMuted);
      },
    );
  }

  Widget _buildVideoCard(
    JavVideoModel item,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => JavPlayerScreen(video: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFE5E5EA),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(CupertinoIcons.film, color: Colors.white24),
                    ),
                  ),
                  if (item.quality.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (item.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.views.isNotEmpty)
                        Text(
                          item.views,
                          style: TextStyle(color: textMuted, fontSize: 10),
                        ),
                      if (item.timeAgo.isNotEmpty)
                        Text(
                          item.timeAgo,
                          style: TextStyle(color: textMuted, fontSize: 9),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
