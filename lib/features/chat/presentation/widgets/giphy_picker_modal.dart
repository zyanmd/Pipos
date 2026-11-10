import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/giphy_service.dart';

class GiphyPickerModal extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final bool? isDark;

  const GiphyPickerModal({
    super.key,
    required this.onSelected,
    this.isDark,
  });

  @override
  State<GiphyPickerModal> createState() => _GiphyPickerModalState();
}

class _GiphyPickerModalState extends State<GiphyPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _categories = [
    '🔥 Trending',
    'Anime',
    'Reaksi',
    'Waku Waku',
    'Spy x Family',
    'Jujutsu Kaisen',
    'One Piece',
    'Naruto',
    'Lucu',
    'Kucing',
    'Love',
    'Sad',
    'Meme',
  ];

  String _selectedCategory = '🔥 Trending';
  List<GiphyItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadGifs();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGifs({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<GiphyItem> results;
      final q = (query ?? _searchController.text).trim();

      if (q.isEmpty || _selectedCategory == '🔥 Trending' && q.isEmpty) {
        results = await GiphyService.instance.getTrending(limit: 30);
      } else {
        results = await GiphyService.instance.search(query: q, limit: 30);
      }

      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat GIF. Periksa koneksi internet.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 380), () {
      final query = val.trim();
      setState(() {
        if (query.isEmpty) {
          _selectedCategory = '🔥 Trending';
        } else {
          _selectedCategory = '';
        }
      });
      _loadGifs(query: query);
    });
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      if (category == '🔥 Trending') {
        _searchController.clear();
        _loadGifs(query: '');
      } else {
        _searchController.text = category;
        _loadGifs(query: category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    final bgColor = isDark ? const Color(0xFF16161A) : Colors.white;
    final topBorderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final searchBg = isDark ? const Color(0xFF222228) : const Color(0xFFF2F2F7);
    final searchBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF8E8E93);
    final iconColor = isDark ? Colors.white60 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: topBorderColor, width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FF99), Color(0xFF00CCFF), Color(0xFF9933FF)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'GIPHY',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih GIF',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(CupertinoIcons.clear_thick_circled, size: 22),
                      color: isDark ? Colors.white54 : Colors.black45,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: searchBorder, width: 0.8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    cursorColor: isDark ? Colors.white : Colors.black,
                    style: TextStyle(color: textColor, fontSize: 14),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) => _loadGifs(query: val),
                    decoration: InputDecoration(
                      hintText: 'Cari jutaan GIF di GIPHY...',
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: iconColor,
                        size: 18,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                              color: iconColor,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Categories Chips
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategory == cat;

                    final chipBg = isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? const Color(0xFF25252B) : const Color(0xFFE5E5EA));
                    final chipTextColor = isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1C1C1E));
                    final chipBorder = isSelected
                        ? Border.all(color: isDark ? Colors.white : Colors.black, width: 1.0)
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 0.8,
                          );

                    return GestureDetector(
                      onTap: () => _onCategorySelected(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(20),
                          border: chipBorder,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: chipTextColor,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Body: Grid / Loader / Error
              Expanded(
                child: _buildBody(context, scrollController, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ScrollController scrollController, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(
              radius: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(height: 12),
            Text(
              'Memuat GIF...',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
            Icon(
              CupertinoIcons.wifi_exclamationmark,
              size: 40,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _loadGifs(),
              icon: const Icon(CupertinoIcons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (_items.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 40,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              'Tidak ada GIF ditemukan.',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba kata kunci lain atau pilih kategori di atas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return GridView.builder(
    controller: scrollController,
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.25,
    ),
    itemCount: _items.length,
    itemBuilder: (context, index) {
      final item = _items[index];
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final targetUrl = item.originalUrl.isNotEmpty ? item.originalUrl : item.previewUrl;
          widget.onSelected(targetUrl);
          Navigator.of(context).pop();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: item.previewUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  placeholder: (context, url) => Container(
                    color: isDark ? const Color(0xFF222228) : const Color(0xFFE5E5EA),
                    child: Center(
                      child: CupertinoActivityIndicator(
                        radius: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? const Color(0xFF222228) : const Color(0xFFE5E5EA),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
                if (item.title.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

