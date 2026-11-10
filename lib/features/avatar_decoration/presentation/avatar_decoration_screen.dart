import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/admob_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/smooth_avatar_decoration.dart';
import '../data/avatar_decoration_repository.dart';
import '../data/models/avatar_decoration_model.dart';

/// Apple iOS HIG Avatar Decoration Screen.
/// Provides live interactive preview, category filters, search,
/// and smooth equipping / removal of Discord-style avatar frames.
class AvatarDecorationScreen extends StatefulWidget {
  const AvatarDecorationScreen({super.key});

  @override
  State<AvatarDecorationScreen> createState() => _AvatarDecorationScreenState();
}

class _AvatarDecorationScreenState extends State<AvatarDecorationScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  static const int _pageSize = 24;
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;

  List<AvatarDecorationModel> _decorations = [];
  List<AvatarDecorationCategoryModel> _categories = [];
  UserActiveDecorationModel? _currentActiveDecoration;

  AvatarDecorationModel? _previewDecoration;

  String _selectedCategory = 'all';
  bool _showOnlyOwned = false;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasNextPage) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 220) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNextPage || _loading) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    try {
      final decsData = await AvatarDecorationRepository.instance.getDecorations(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        ownedOnly: _showOnlyOwned,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        page: nextPage,
        perPage: _pageSize,
      );

      if (!mounted) return;

      final newItems = List<AvatarDecorationModel>.from(decsData['decorations'] as List);
      final hasNext = decsData['has_next'] == true;
      final total = decsData['total'] is int
          ? decsData['total'] as int
          : (_decorations.length + newItems.length);

      setState(() {
        _decorations.addAll(newItems);
        _currentPage = nextPage;
        _hasNextPage = hasNext;
        _totalCount = total;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _getActiveCode(dynamic user) {
    if (_currentActiveDecoration != null && _currentActiveDecoration!.code.isNotEmpty) {
      return _currentActiveDecoration!.code.trim();
    }
    if (user?.avatarDecorationCode != null && (user.avatarDecorationCode as String).isNotEmpty) {
      return (user.avatarDecorationCode as String).trim();
    }
    final url = _currentActiveDecoration?.imageUrl ?? user?.avatarDecorationUrl as String?;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : url.split('/').last;
      return seg.replaceAll('.png', '').replaceAll('.webp', '').replaceAll('.gif', '').trim();
    }
    return '';
  }

  bool _isItemEquipped(AvatarDecorationModel item, dynamic user) {
    final activeCode = _getActiveCode(user);
    if (activeCode.isNotEmpty && activeCode.toLowerCase() == item.code.toLowerCase()) {
      return true;
    }
    final activeId = _currentActiveDecoration?.id ?? (user?.avatarDecorationId is int ? user.avatarDecorationId as int : null);
    if (activeId != null && activeId > 0 && item.id > 0 && activeId == item.id) {
      return true;
    }
    return false;
  }

  Future<void> _initData() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
      _hasNextPage = true;
      _isLoadingMore = false;
    });

    try {
      final catsFuture = AvatarDecorationRepository.instance.getCategories();
      final decsFuture = AvatarDecorationRepository.instance.getDecorations(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        ownedOnly: _showOnlyOwned,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        page: 1,
        perPage: _pageSize,
      );

      final results = await Future.wait([catsFuture, decsFuture]);
      final cats = results[0] as List<AvatarDecorationCategoryModel>;
      final decsData = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _categories = cats;
        _decorations = List<AvatarDecorationModel>.from(decsData['decorations'] as List);
        _hasNextPage = decsData['has_next'] == true;
        _totalCount = decsData['total'] is int ? decsData['total'] as int : _decorations.length;
        _currentActiveDecoration = decsData['current_decoration'] as UserActiveDecorationModel?;
        final activeCode = _getActiveCode(context.read<AuthProvider>().user);
        if (_previewDecoration == null && activeCode.isNotEmpty) {
          try {
            _previewDecoration = _decorations.firstWhere(
              (d) => d.code.toLowerCase() == activeCode.toLowerCase(),
              orElse: () => _currentActiveDecoration != null
                  ? AvatarDecorationModel(
                      id: _currentActiveDecoration!.id,
                      code: _currentActiveDecoration!.code,
                      name: _currentActiveDecoration!.name,
                      imageUrl: _currentActiveDecoration!.imageUrl,
                    )
                  : _decorations.first,
            );
          } catch (_) {}
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat katalog bingkai avatar';
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchDecorationsOnly() async {
    setState(() {
      _loading = true;
      _currentPage = 1;
      _hasNextPage = true;
      _isLoadingMore = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    final decsData = await AvatarDecorationRepository.instance.getDecorations(
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      ownedOnly: _showOnlyOwned,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      page: 1,
      perPage: _pageSize,
    );

    if (!mounted) return;
    setState(() {
      _decorations = List<AvatarDecorationModel>.from(decsData['decorations'] as List);
      _hasNextPage = decsData['has_next'] == true;
      _totalCount = decsData['total'] is int ? decsData['total'] as int : _decorations.length;
      if (decsData['current_decoration'] != null) {
        _currentActiveDecoration = decsData['current_decoration'] as UserActiveDecorationModel;
      }
      _loading = false;
    });
  }

  Future<void> _equipDecoration(AvatarDecorationModel item) async {
    HapticFeedback.mediumImpact();
    AdMobService.instance.showRewardedAd(
      onRewardEarned: () async {
        setState(() => _actionLoading = true);

        final res = await AvatarDecorationRepository.instance.selectDecoration(
          decorationId: item.id > 0 ? item.id : null,
          code: item.code,
          name: item.name,
          imageUrl: item.fullImageUrl,
          scale: 1.0,
        );

        if (!mounted) return;
        setState(() => _actionLoading = false);

        setState(() {
          _currentActiveDecoration = res;
          _previewDecoration = item;
        });

        // Update AuthProvider current user state so profile updates immediately
        final auth = context.read<AuthProvider>();
        if (auth.user != null) {
          auth.setUser(
            auth.user!.copyWith(
              avatarDecorationId: res.id,
              avatarDecorationCode: res.code,
              avatarDecorationUrl: res.imageUrl,
              avatarDecorationScale: 1.0,
              avatarDecorationOffsetX: 0,
              avatarDecorationOffsetY: 0,
            ),
          );
        }

        _showNotification('Bingkai "${item.name}" berhasil digunakan!');
      },
    );
  }

  Future<void> _removeDecoration() async {
    HapticFeedback.selectionClick();
    setState(() => _actionLoading = true);

    final ok = await AvatarDecorationRepository.instance.removeActiveDecoration();

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (ok) {
      setState(() {
        _currentActiveDecoration = null;
        _previewDecoration = null;
      });

      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        auth.setUser(
          auth.user!.copyWith(
            clearAvatarDecoration: true,
            avatarDecorationUrl: '',
            avatarDecorationCode: '',
          ),
        );
      }

      _showNotification('Bingkai avatar berhasil dilepas');
    } else {
      _showNotification('Gagal melepas bingkai avatar', isError: true);
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? CupertinoColors.destructiveRed : const Color(0xFF34C759),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.checkmark_alt_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.username.isNotEmpty == true ? user!.username : 'Pengguna');

    final activeCode = _getActiveCode(user);
    final hasActiveDec = activeCode.isNotEmpty;
    final isPreviewEquipped = _previewDecoration != null && _isItemEquipped(_previewDecoration!, user);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Bingkai Avatar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        actions: [
          if (hasActiveDec)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: _actionLoading ? null : _removeDecoration,
              child: const Text(
                'Lepas',
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Interactive Hero Preview Section
          _buildHeroPreviewSection(isDark, user, displayName, isPreviewEquipped),

          // Categories & Filter Tabs
          _buildCategoryFilters(isDark),

          // Search Field
          _buildSearchBar(isDark),

          // Catalog Grid
          Expanded(
            child: _buildGridContent(isDark, user),
          ),

          // AdMob Banner
          const AdBannerWidget(
            margin: EdgeInsets.fromLTRB(16, 4, 16, 8),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPreviewSection(
    bool isDark,
    dynamic user,
    String displayName,
    bool isPreviewEquipped,
  ) {
    final previewUrl = _previewDecoration?.fullImageUrl ??
        (_currentActiveDecoration != null ? _currentActiveDecoration!.fullImageUrl : user?.fullAvatarDecorationUrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Live Avatar with frame overlay
          DecoratedAvatar(
            radius: 54,
            avatarUrl: user?.avatarUrl,
            decorationUrl: previewUrl,
            decorationCode: _previewDecoration?.code ?? (_currentActiveDecoration?.code ?? user?.avatarDecorationCode),
            decorationScale: 1.0,
            fallbackName: displayName,
            borderWidth: 2,
            borderColor: isDark ? AppColors.darkBorder : Colors.white,
          ),
          const SizedBox(height: 12),

          // Decoration info name
          Text(
            _previewDecoration != null
                ? _previewDecoration!.name
                : (_currentActiveDecoration != null ? _currentActiveDecoration!.name : 'Tanpa Bingkai'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _previewDecoration != null
                ? 'Kategori: ${_previewDecoration!.category.toUpperCase()}'
                : (_totalCount > 0
                    ? 'Pilih salah satu dari $_totalCount bingkai di bawah'
                    : 'Pilih salah satu dari koleksi bingkai di bawah'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Equip Button & Controls
          if (_previewDecoration != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPreviewEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF34C759), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF34C759), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Sedang Digunakan',
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(22),
                    onPressed: _actionLoading ? null : () => _equipDecoration(_previewDecoration!),
                    child: _actionLoading
                        ? CupertinoActivityIndicator(color: isDark ? Colors.black : Colors.white)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.checkmark_alt, size: 16, color: isDark ? Colors.black : Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Gunakan Bingkai Ini',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                if (_previewDecoration != null) ...[
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(22),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _previewDecoration = null;
                      });
                    },
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(bool isDark) {
    final totalCount = _categories.fold<int>(0, (sum, c) => sum + c.count);

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildCategoryPill(
            isDark,
            id: 'all',
            label: totalCount > 0 ? 'Semua ($totalCount)' : 'Semua',
          ),
          _buildCategoryPill(isDark, id: 'owned', label: 'Dimiliki', isSpecialOwned: true),
          ..._categories.map(
            (c) => _buildCategoryPill(
              isDark,
              id: c.name,
              label: '${c.name[0].toUpperCase()}${c.name.substring(1)} (${c.count})',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(
    bool isDark, {
    required String id,
    required String label,
    bool isSpecialOwned = false,
  }) {
    final isSelected = isSpecialOwned ? _showOnlyOwned : (!_showOnlyOwned && _selectedCategory == id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSpecialOwned) {
              _showOnlyOwned = !_showOnlyOwned;
            } else {
              _showOnlyOwned = false;
              _selectedCategory = id;
            }
          });
          _fetchDecorationsOnly();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? AppColors.darkCard : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Cari nama bingkai...',
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        onSubmitted: (_) {
          HapticFeedback.selectionClick();
          _fetchDecorationsOnly();
        },
        onSuffixTap: () {
          _searchController.clear();
          _fetchDecorationsOnly();
        },
      ),
    );
  }

  Widget _buildGridContent(bool isDark, dynamic user) {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }

    if (_error != null && _decorations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.wifi_slash, size: 42, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _initData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_decorations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.sparkles, size: 46, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Tidak ada bingkai ditemukan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    final total = _totalCount > 0 ? _totalCount : _decorations.length;
    final remaining = (total - _decorations.length).clamp(0, total);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _decorations[index];
                final isSelected = _previewDecoration?.code == item.code;
                final isEquipped = _isItemEquipped(item, user);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _previewDecoration = item;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isEquipped
                                ? const Color(0xFF34C759)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isSelected ? 0.18 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Frame Preview on circle dummy
                            SizedBox(
                              width: 68,
                              height: 68,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.person_fill,
                                      size: 26,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                  ),
                                  SmoothAvatarDecoration(
                                    decorationUrl: item.fullImageUrl,
                                    decorationCode: item.code,
                                    size: 66,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Equipped Badge
                        if (isEquipped)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF34C759),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.checkmark,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Owned Pill
                        if (item.isOwned && !isEquipped)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Milik',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _decorations.length,
            ),
          ),
        ),

        // Lazy load loading indicator at bottom
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(radius: 9),
                    SizedBox(width: 8),
                    Text(
                      'Memuat bingkai lainnya...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_hasNextPage)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _loadMore,
                  child: Text(
                    remaining > 0
                        ? 'Muat Lebih Banyak ($remaining tersisa)'
                        : 'Muat Lebih Banyak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (_decorations.length > _pageSize)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'Semua ${_decorations.length} bingkai telah dimuat',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
      ],
    );
  }
}
