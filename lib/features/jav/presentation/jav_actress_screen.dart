import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../data/models/jav_model.dart';
import '../data/jav_repository.dart';
import 'jav_player_screen.dart';

class JavActressScreen extends StatefulWidget {
  final String actressSlug;
  final String? initialName;
  final String? initialAvatar;

  const JavActressScreen({
    super.key,
    required this.actressSlug,
    this.initialName,
    this.initialAvatar,
  });

  @override
  State<JavActressScreen> createState() => _JavActressScreenState();
}

class _JavActressScreenState extends State<JavActressScreen> {
  final _repo = JavRepository.instance;
  final ScrollController _scrollCtrl = ScrollController();

  JavActressDetailModel? _detail;
  List<JavVideoModel> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _errorMessage;

  String? _selectedVideoType; // null, 'censored', 'uncensored', 'reducing_mosaic'
  String? _selectedSort; // null, 'popular', 'added_week', 'added_month'

  final List<Map<String, String?>> _typeFilters = const [
    {'label': 'Semua', 'type': null},
    {'label': '🎬 Censored', 'type': 'censored'},
    {'label': '✨ Uncensored', 'type': 'uncensored'},
    {'label': '💎 Reducing Mosaic', 'type': 'reducing_mosaic'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 350 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (!AdultContentService.instance.is18Unlocked) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final res = await _repo.getActressDetail(
        slug: widget.actressSlug,
        page: 1,
        videoType: _selectedVideoType,
        sort: _selectedSort,
      );

      if (!mounted) return;
      if (res != null) {
        setState(() {
          _detail = res;
          _videos = res.videos;
          _isLoading = false;
          _hasMore = res.videos.isNotEmpty;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat profil aktris';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    try {
      final res = await _repo.getActressDetail(
        slug: widget.actressSlug,
        page: nextPage,
        videoType: _selectedVideoType,
        sort: _selectedSort,
      );

      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        if (res != null && res.videos.isNotEmpty) {
          _videos.addAll(res.videos);
          _currentPage = nextPage;
        } else {
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onTypeFilterChanged(String? type) {
    if (_selectedVideoType == type) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedVideoType = type);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D12) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF8E8E93);

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
                Text('Aktifkan Mode 18+ di Profil untuk melihat profil ini.', textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13)),
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

    final displayName = _detail?.name.isNotEmpty == true
        ? _detail!.name
        : (widget.initialName ?? 'Aktris');
    final avatarUrl = _detail?.avatar.isNotEmpty == true
        ? _detail!.avatar
        : (widget.initialAvatar ?? '');

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── APP BAR ──
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            backgroundColor: isDark
                ? AppColors.iosBackgroundDark.withValues(alpha: 0.9)
                : AppColors.iosBackgroundLight.withValues(alpha: 0.9),
            surfaceTintColor: Colors.transparent,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Icon(CupertinoIcons.back, color: textPrimary),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image blur if available
                  if (avatarUrl.isNotEmpty)
                    AppNetworkImage(
                      url: avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
                          bg,
                        ],
                      ),
                    ),
                  ),

                  // Center Profile Info
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar with glowing border
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF2D55), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2D55).withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? AppNetworkImage(
                                    url: avatarUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(CupertinoIcons.person_fill, color: Colors.white54, size: 40),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name & Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_detail != null) ...[
                                Row(
                                  children: [
                                    if (_detail!.subscribers.isNotEmpty)
                                      Text(
                                        _detail!.subscribers,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFF2D55),
                                        ),
                                      ),
                                    if (_detail!.videosCount.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '• ${_detail!.videosCount} Video',
                                        style: TextStyle(fontSize: 12, color: textMuted),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── FILTER CHIPS ──
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _typeFilters.map((f) {
                  final isSelected = _selectedVideoType == f['type'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BouncyTap(
                      onTap: () => _onTypeFilterChanged(f['type']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF2D55)
                              : (isDark ? const Color(0xFF1E1E28) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          f['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── VIDEOS GRID / LOADING / ERROR ──
          if (_isLoading)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: Center(child: CupertinoActivityIndicator(radius: 14)),
              ),
            )
          else if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF453A), size: 36),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, style: TextStyle(color: textPrimary, fontSize: 13)),
                      const SizedBox(height: 12),
                      BouncyTap(
                        onTap: _loadData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _videos[index];
                    return _buildVideoCard(item, isDark, cardBg, textPrimary, textMuted);
                  },
                  childCount: _videos.length,
                ),
              ),
            ),

          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnail.isNotEmpty)
                      AppNetworkImage(
                        url: item.thumbnail,
                        fit: BoxFit.cover,
                        memCacheWidth: 350,
                      )
                    else
                      Container(color: isDark ? const Color(0xFF1F1F28) : const Color(0xFFE5E5EA)),

                    // Duration badge bottom right
                    if (item.duration.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Quality badge top left
                    if (item.quality.isNotEmpty)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
              ),

              // Title and views
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const SizedBox(height: 4),
                    if (item.views.isNotEmpty)
                      Text(
                        item.views,
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
