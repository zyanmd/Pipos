import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/ios_capsule_search_bar.dart';
import '../data/models/zpic_model.dart';
import '../data/zpic_repository.dart';
import 'zpic_player_screen.dart';

class ZpicSearchScreen extends StatefulWidget {
  const ZpicSearchScreen({super.key});

  @override
  State<ZpicSearchScreen> createState() => _ZpicSearchScreenState();
}

class _ZpicSearchScreenState extends State<ZpicSearchScreen> {
  final _repo = ZpicRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ZpicVideoModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.search(q);
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal melakukan pencarian ($e)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Capsule Search Bar Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              color: bg,
              child: IosCapsuleSearchBar(
                controller: _searchController,
                hintText: 'Cari video di zPic...',
                autoFocus: true,
                onSubmitted: _performSearch,
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _results.clear();
                    _hasSearched = false;
                  });
                },
              ),
            ),
            // Body Content
            Expanded(
              child: _buildBody(isDark, cardBg, textPrimary, textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color cardBg, Color textPrimary, Color textMuted) {
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
              const Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? Colors.white24 : Colors.black12,
                onPressed: () => _performSearch(_searchController.text),
                child: Text('Coba Lagi', style: TextStyle(color: textPrimary, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      final suggestions = [
        {'title': 'Trending', 'icon': '🔥', 'query': 'trending'},
        {'title': 'Populer', 'icon': '⚡', 'query': 'populer'},
        {'title': 'HD 1080p', 'icon': '✨', 'query': '1080p'},
        {'title': 'Terbaru', 'icon': '🕒', 'query': 'terbaru'},
        {'title': 'Shorts', 'icon': '🎬', 'query': 'shorts'},
      ];

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.flame_fill,
                  size: 13,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Kategori Populer',
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
            runSpacing: 10,
            children: suggestions.map((s) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _searchController.text = s['query']!;
                    _performSearch(s['query']!);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.28 : 0.20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s['icon']!, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          s['title']!,
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
          // Discovery Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
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
                        'Pencarian Video zPic',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Temukan ribuan klip dan video pilihan berdasarkan judul atau kata kunci.',
                        style: TextStyle(
                          fontSize: 12,
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

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.play_rectangle,
                  size: 28,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tidak Ada Video Ditemukan',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Coba gunakan kata kunci pencarian yang lain.',
                style: TextStyle(color: textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return _buildVideoCard(item, isDark, cardBg, textPrimary, textMuted);
      },
    );
  }

  Widget _buildVideoCard(
    ZpicVideoModel item,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ZpicPlayerScreen(video: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with aspect ratio
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Center(
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: Icon(CupertinoIcons.play_rectangle, color: textMuted),
                    ),
                  ),
                  // Play button overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // NSFW badge
                  if (item.isNsfw)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '18+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Views overlay
                  if (item.views.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.views,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
