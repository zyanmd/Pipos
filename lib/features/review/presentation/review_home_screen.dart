import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_decor_resolver.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../anime/presentation/anime_episode_player.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../data/models/user_review_model.dart';
import '../data/review_repository.dart';
import 'widgets/review_comments_sheet.dart';
import 'widgets/review_input_dialog.dart';
import 'widgets/review_target_picker_sheet.dart';

/// Layar utama Tab "Ulas" (Feed Komunitas & Ulasan Pribadi)
/// Mengikuti Apple iOS HIG monochrome design language Animeverse.
class ReviewHomeScreen extends StatefulWidget {
  const ReviewHomeScreen({super.key});

  @override
  State<ReviewHomeScreen> createState() => _ReviewHomeScreenState();
}

class _ReviewHomeScreenState extends State<ReviewHomeScreen> {
  String _selectedScope = 'community'; // 'community' atau 'mine'
  String _selectedType = 'all'; // 'all', 'anime', 'comic'
  String _selectedSort = 'latest'; // 'latest', 'popular', 'random'
  List<UserReviewModel> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final data = await ReviewRepository.instance.getReviews(
      scope: _selectedScope,
      itemType: _selectedType == 'all' ? null : _selectedType,
      sort: _selectedSort,
    );
    if (mounted) {
      setState(() {
        _reviews = data;
        _isLoading = false;
      });
      UserDecorResolver.instance.resolveUsers(data.map((r) => r.username));
    }
  }

  void _onScopeChanged(String scope) {
    if (_selectedScope == scope) return;
    HapticFeedback.selectionClick();
    final auth = context.read<AuthProvider>();
    if ((scope == 'mine' || scope == 'friends') && !auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            scope == 'friends'
                ? 'Login untuk melihat ulasan teman'
                : 'Login untuk melihat ulasan Anda',
          ),
        ),
      );
      return;
    }
    setState(() => _selectedScope = scope);
    _loadReviews();
  }

  void _onFilterChanged(String type) {
    if (_selectedType == type) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedType = type);
    _loadReviews();
  }

  void _onSortChanged(String sort) {
    if (_selectedSort == sort && sort != 'random') return;
    HapticFeedback.selectionClick();
    setState(() => _selectedSort = sort);
    _loadReviews();
  }

  String get _sortLabel {
    switch (_selectedSort) {
      case 'popular':
        return 'Terpopuler';
      case 'random':
        return 'Acak';
      default:
        return 'Terbaru';
    }
  }

  void _showSortSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Urutkan Ulasan'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _selectedSort == 'latest',
            onPressed: () {
              Navigator.pop(ctx);
              _onSortChanged('latest');
            },
            child: const Text('Terbaru'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _selectedSort == 'popular',
            onPressed: () {
              Navigator.pop(ctx);
              _onSortChanged('popular');
            },
            child: const Text('Terpopuler'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _selectedSort == 'random',
            onPressed: () {
              Navigator.pop(ctx);
              _onSortChanged('random');
            },
            child: const Text('Acak'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _toggleLike(UserReviewModel item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Login untuk menyukai ulasan'),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Optimistic Update
    final newLiked = !item.userLiked;
    final newCount = newLiked ? item.likesCount + 1 : (item.likesCount > 0 ? item.likesCount - 1 : 0);

    setState(() {
      final idx = _reviews.indexWhere((r) => r.id == item.id);
      if (idx != -1) {
        _reviews[idx] = _reviews[idx].copyWith(
          userLiked: newLiked,
          likesCount: newCount,
        );
      }
    });

    final res = await ReviewRepository.instance.toggleLike(item.id);
    if (res != null && mounted) {
      setState(() {
        final idx = _reviews.indexWhere((r) => r.id == item.id);
        if (idx != -1) {
          _reviews[idx] = _reviews[idx].copyWith(
            userLiked: res['liked'] == true,
            likesCount: res['likes_count'] as int? ?? newCount,
          );
        }
      });
    }
  }

  Future<void> _openComments(UserReviewModel item) async {
    HapticFeedback.lightImpact();
    final newCount = await ReviewCommentsSheet.show(
      context,
      reviewId: item.id,
      reviewTitle: item.targetTitle,
    );
    if (newCount != null && mounted) {
      setState(() {
        final idx = _reviews.indexWhere((r) => r.id == item.id);
        if (idx != -1) {
          _reviews[idx] = _reviews[idx].copyWith(commentsCount: newCount);
        }
      });
    }
  }

  void _showOwnerActions(UserReviewModel item) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(item.targetTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = await ReviewInputDialog.show(
                context,
                itemType: item.itemType,
                targetId: item.targetId,
                targetTitle: item.targetTitle,
                targetCover: item.targetCover,
                subId: item.subId,
                subTitle: item.subTitle,
                initialReview: item,
              );
              if (updated != null) {
                _loadReviews();
              }
            },
            child: const Text('Edit Catatan'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReview(item);
            },
            child: const Text('Hapus Ulasan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _openCreateReviewPicker() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menulis ulasan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final newReview = await ReviewTargetPickerSheet.show(context);
    if (newReview != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ulasan berhasil disimpan!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_selectedScope != 'mine') {
        setState(() => _selectedScope = 'mine');
      }
      _loadReviews();
    }
  }

  Future<void> _deleteReview(UserReviewModel item) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Ulasan'),
        content: Text('Hapus catatan ulasan untuk "${item.targetTitle}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ReviewRepository.instance.deleteReview(item.id);
      if (success) {
        setState(() {
          _reviews.removeWhere((r) => r.id == item.id);
        });
      }
    }
  }

  void _navigateToTarget(UserReviewModel item) {
    HapticFeedback.lightImpact();
    if (item.itemType == 'anime') {
      if (item.subId != null && item.subId!.isNotEmpty) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => AnimeEpisodePlayerScreen(
              episodeId: item.subId!,
              episodeLabel: item.subTitle ?? 'Episode',
              animeId: item.targetId,
              animeTitle: item.targetTitle,
              animeThumb: item.targetCover,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => AnimeDetailScreen(animeId: item.targetId),
          ),
        );
      }
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => ComicDetailScreen(slug: item.targetId),
        ),
      );
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    return AppDateUtils.formatTimeAgo(dt);
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
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
              icon,
              size: 17,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeSwitcher(bool isDark) {
    const scopes = [
      (
        key: 'community',
        label: 'Komunitas',
        icon: CupertinoIcons.sparkles,
      ),
      (
        key: 'friends',
        label: 'Teman',
        icon: CupertinoIcons.person_2_fill,
      ),
      (
        key: 'mine',
        label: 'Saya',
        icon: CupertinoIcons.bookmark_fill,
      ),
    ];

    final containerBg = isDark
        ? const Color(0xFF141416)
        : const Color(0xFFEBEBF0);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        children: scopes.map((item) {
          final isSelected = _selectedScope == item.key;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onScopeChanged(item.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF28282C) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 0.6,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 14.5,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      const SizedBox(width: 5.5),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String type, String label, bool isDark) {
    final isSelected = _selectedType == type;
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeFg = isDark ? Colors.black : Colors.white;
    final inactiveBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final inactiveFg = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onFilterChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white10 : Colors.black12),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeFg : inactiveFg,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showSortSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_up_arrow_down,
              size: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            const SizedBox(width: 4.5),
            Text(
              _sortLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              CupertinoIcons.chevron_down,
              size: 9.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: RefreshIndicator(
              color: isDark ? Colors.white : Colors.black,
              edgeOffset: 112,
              onRefresh: _loadReviews,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Apple iOS Large Title App Bar (Matches Anime & Comic Tab)
                  SliverAppBar(
                    expandedHeight: 112,
                    pinned: true,
                    stretch: true,
                    backgroundColor: isDark
                        ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                        : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    flexibleSpace: LayoutBuilder(
                      builder: (ctx, c) {
                        final shrink = 1 -
                            ((c.maxHeight - kToolbarHeight) / (112 - kToolbarHeight))
                                .clamp(0.0, 1.0);
                        final isShrunk = shrink > 0.6;
                        return FlexibleSpaceBar(
                          centerTitle: isShrunk,
                          titlePadding: EdgeInsets.only(
                            left: isShrunk ? 0 : 16,
                            right: isShrunk ? 0 : 16,
                            bottom: isShrunk ? 13 : 12,
                          ),
                          title: Text(
                            'Ulas',
                            style: TextStyle(
                              fontSize: isShrunk ? 17 : 32,
                              fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: isShrunk ? -0.4 : -1.0,
                            ),
                          ),
                        );
                      },
                    ),
                    actions: [
                      _buildIosActionButton(
                        icon: CupertinoIcons.square_pencil,
                        tooltip: 'Tulis Ulasan',
                        isDark: isDark,
                        onTap: _openCreateReviewPicker,
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.arrow_clockwise,
                        tooltip: 'Segarkan',
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _loadReviews();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Sleek Scope Switcher: [ Komunitas | Teman | Saya ]
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _buildScopeSwitcher(isDark),
                    ),
                  ),

                  // Filter Pills & Sort Dropdown
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Semua', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('anime', 'Anime', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('comic', 'Komik', isDark),
                          const Spacer(),
                          _buildSortButton(isDark),
                        ],
                      ),
                    ),
                  ),

                  // Review Feed Content
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator(radius: 14)),
                    )
                  else if (_reviews.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isDark),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      sliver: AnimatedBuilder(
                        animation: UserDecorResolver.instance,
                        builder: (context, _) {
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _reviews[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _buildReviewCard(item, isDark),
                                );
                              },
                              childCount: _reviews.length,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(UserReviewModel item, bool isDark) {
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isOwner = currentUserId != null && currentUserId == item.userId;

    final decor = UserDecorResolver.instance.get(item.username);
    final avatarUrl = decor?.avatarUrl ?? item.userAvatar;
    final decorUrl = decor?.decorationUrl ?? item.userDecorationUrl;
    final decorCode = decor?.decorationCode ?? item.userDecorationCode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. HEADER USER REVIEWER ──
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final uname = item.username;
                      if (uname != null && uname.isNotEmpty) {
                        showUserProfileCard(context, username: uname);
                      }
                    },
                    child: Row(
                      children: [
                        DecoratedAvatar(
                          avatarUrl: avatarUrl,
                          decorationUrl: decorUrl,
                          decorationCode: decorCode,
                          decorationScale: decor?.decorationScale ?? 1.0,
                          offsetX: decor?.decorationOffsetX ?? 0,
                          offsetY: decor?.decorationOffsetY ?? 0,
                          fallbackName: item.username ?? 'Pengguna',
                          radius: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.username ?? 'Pengguna',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _timeAgo(item.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge (Apple Squircle Pill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    item.statusDisplay,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),

                // More Menu if owner
                if (isOwner) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showOwnerActions(item),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      ),
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── 2. INFO KONTEN (Cover + Title + Subtitle + Rating) ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToTarget(item),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 46,
                        height: 60,
                        color: isDark ? Colors.white12 : Colors.black12,
                        child: item.targetCover != null
                            ? AppNetworkImage(
                                url: item.targetCover!,
                                width: 46,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                item.itemType == 'anime'
                                    ? CupertinoIcons.play_circle
                                    : CupertinoIcons.book,
                                size: 22,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  item.itemType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              if (item.rating > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.targetTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.subTitle != null && item.subTitle!.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              item.subTitle!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 13,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. ISI ULASAN TEKS ──
            if (item.content != null && item.content!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.content!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  letterSpacing: -0.1,
                  color: isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF1C1C1E),
                ),
              ),
            ],

            // ── 4. LAMPIRAN GAMBAR / GIF ──
            if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppNetworkImage(
                  url: item.mediaUrl!,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 14),
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),

            // ── 5. BARIS AKSI SOSIAL: LIKE & KOMEN & BUKA ──
            Row(
              children: [
                // Tombol Like
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _toggleLike(item);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.userLiked
                          ? const Color(0xFFFF2D55).withValues(alpha: 0.12)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.userLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          size: 16,
                          color: item.userLiked
                              ? const Color(0xFFFF2D55)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${item.likesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: item.userLiked
                                ? const Color(0xFFFF2D55)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tombol Komentar
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openComments(item);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_fill,
                          size: 15,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${item.commentsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Tombol Pintas: Buka Konten (Apple HIG Style Pill)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _navigateToTarget(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.itemType == 'anime'
                              ? CupertinoIcons.play_arrow_solid
                              : CupertinoIcons.book_fill,
                          size: 11,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.itemType == 'anime' ? 'Tonton' : 'Baca',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    if (_selectedScope == 'friends') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.person_2_fill,
                    size: 30,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Belum Ada Ulasan Teman',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teman-temanmu belum membagikan ulasan atau kamu belum memiliki teman. Jelajahi ulasan dari komunitas!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _onScopeChanged('community');
                },
                icon: const Icon(CupertinoIcons.sparkles, size: 14),
                label: const Text('Buka Ulasan Komunitas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isMine = _selectedScope == 'mine';
    if (isMine) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.bookmark_fill,
                    size: 28,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Belum Ada Ulasan Saya',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buka anime atau komik pilihanmu, lalu ketuk tombol "Tandai / Ulas" untuk menyimpan ulasan pribadimu di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openCreateReviewPicker,
                    icon: const Icon(CupertinoIcons.square_pencil, size: 14),
                    label: const Text('Tulis Ulasan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _onScopeChanged('community');
                    },
                    icon: const Icon(CupertinoIcons.globe, size: 14),
                    label: const Text('Jelajahi Feed Komunitas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.bubble_left_bubble_right_fill,
                  size: 28,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Belum Ada Ulasan Komunitas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada ulasan dari pengguna lain. Jadilah yang pertama membuat ulasan untuk dibagikan ke komunitas!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openCreateReviewPicker,
              icon: const Icon(CupertinoIcons.square_pencil, size: 14),
              label: const Text('Tulis Ulasan Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
