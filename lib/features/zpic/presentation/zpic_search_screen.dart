import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
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
          placeholder: 'Cari video di zPic...',
          style: TextStyle(color: textPrimary, fontSize: 14),
          placeholderStyle: TextStyle(color: textMuted, fontSize: 14),
          prefixIcon: Icon(CupertinoIcons.search, color: textMuted, size: 18),
          suffixIcon: Icon(CupertinoIcons.xmark_circle_fill, color: textMuted, size: 18),
          onSubmitted: _performSearch,
          autofocus: true,
        ),
      ),
      body: _buildBody(isDark, cardBg, textPrimary, textMuted),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search, size: 48, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Ketik judul atau kata kunci untuk mencari video',
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
            Icon(CupertinoIcons.tray, size: 48, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Tidak ada video yang ditemukan.',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ],
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
