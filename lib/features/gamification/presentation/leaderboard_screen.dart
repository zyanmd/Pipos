import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/user_decor_resolver.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/decorated_avatar.dart';
import '../../../../shared/widgets/user_profile_card_modal.dart';
import '../data/gamification_repository.dart';
import '../data/models/leaderboard_user_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedPeriod = 'all'; // 'all', 'monthly', 'weekly'
  bool _isLoading = true;
  String? _error;
  List<LeaderboardUserModel> _users = [];
  LeaderboardUserModel? _myRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await GamificationRepository.instance.getLeaderboard(
      period: _selectedPeriod,
      limit: 100,
    );

    if (!mounted) return;

    if (res != null) {
      setState(() {
        _users = res.users;
        _myRank = res.myRank;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = 'Gagal memuat papan peringkat';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedPeriod = period);
    _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: (isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7)).withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Papan Peringkat',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              CupertinoIcons.arrow_clockwise,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadLeaderboard();
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. SEGMENTED PERIOD TABS (Apple Pill Style) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildPeriodSelector(isDark),
            ),

            // ── 2. CONTENT (PODIUM + LIST) ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _error != null
                      ? _buildErrorView(isDark)
                      : _users.isEmpty
                          ? _buildEmptyView(isDark)
                          : RefreshIndicator(
                              onRefresh: _loadLeaderboard,
                              color: const Color(0xFFFF9500),
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: [
                                  // Top 3 Podium
                                  if (_users.length >= 3)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                                        child: _buildPodium(isDark),
                                      ),
                                    ),

                                  // List Header
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      child: Row(
                                        children: [
                                          Text(
                                            _users.length >= 3 ? 'Peringkat Lainnya' : 'Daftar Peringkat',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${_users.length} Petualang',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Ranked List
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      _myRank != null ? 100 : 32,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final listStartIndex = _users.length >= 3 ? 3 : 0;
                                          final actualIndex = listStartIndex + index;
                                          if (actualIndex >= _users.length) return null;

                                          final user = _users[actualIndex];
                                          final isMe = currentUserId != null && currentUserId == user.id;

                                          return _buildRankListItem(user, actualIndex + 1, isDark, isMe);
                                        },
                                        childCount: _users.length >= 3 ? _users.length - 3 : _users.length,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),

            // ── 3. STICKY BOTTOM HUD ("Peringkat Kamu") ──
            if (_myRank != null && !_isLoading)
              _buildMyRankBottomHud(_myRank!, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    const periods = [
      (key: 'all', label: 'Sepanjang Waktu', icon: CupertinoIcons.sparkles),
      (key: 'monthly', label: 'Bulan Ini', icon: CupertinoIcons.calendar),
      (key: 'weekly', label: 'Minggu Ini', icon: CupertinoIcons.flame_fill),
    ];

    final containerBg = isDark ? const Color(0xFF18181C) : const Color(0xFFE5E5EA);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.key;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onPeriodChanged(p.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  border: isSelected
                      ? Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
                          width: 0.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
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
                        p.icon,
                        size: 13.5,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildPodium(bool isDark) {
    final first = _users[0];
    final second = _users[1];
    final third = _users[2];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 Silver (Left)
          Expanded(
            child: _buildPodiumColumn(
              user: second,
              rank: 2,
              height: 120,
              badgeColor: const Color(0xFF9E9E9E),
              gradientColors: [const Color(0xFFB0B0B8), const Color(0xFF8E8E93)],
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // #1 Gold (Center, Highest)
          Expanded(
            child: _buildPodiumColumn(
              user: first,
              rank: 1,
              height: 150,
              badgeColor: const Color(0xFFFF9500),
              gradientColors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
              isCenter: true,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // #3 Bronze (Right)
          Expanded(
            child: _buildPodiumColumn(
              user: third,
              rank: 3,
              height: 105,
              badgeColor: const Color(0xFFCD7F32),
              gradientColors: [const Color(0xFFD78848), const Color(0xFFB86B28)],
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required LeaderboardUserModel user,
    required int rank,
    required double height,
    required Color badgeColor,
    required List<Color> gradientColors,
    bool isCenter = false,
    required bool isDark,
  }) {
    final decor = UserDecorResolver.instance.get(user.username);
    final avatarUrl = decor?.avatarUrl ?? user.avatarUrl;
    final decorUrl = decor?.decorationUrl ?? user.fullAvatarDecorationUrl;
    final decorCode = decor?.decorationCode ?? user.avatarDecorationCode;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        showUserProfileCard(context, username: user.username);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Medal Icon
          if (isCenter)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: const Text('👑', style: TextStyle(fontSize: 22)),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Text(rank == 2 ? '🥈' : '🥉', style: const TextStyle(fontSize: 16)),
            ),

          // Avatar
          DecoratedAvatar(
            avatarUrl: avatarUrl,
            decorationUrl: decorUrl,
            decorationCode: decorCode,
            decorationScale: decor?.decorationScale ?? 1.0,
            offsetX: decor?.decorationOffsetX ?? 0,
            offsetY: decor?.decorationOffsetY ?? 0,
            fallbackName: user.username,
            radius: isCenter ? 28 : 23,
          ),
          const SizedBox(height: 6),

          // Username
          Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCenter ? 13.5 : 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),

          // Level Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Lv. ${user.level}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Podium Pedestal
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientColors[0].withValues(alpha: isDark ? 0.35 : 0.20),
                  gradientColors[1].withValues(alpha: isDark ? 0.15 : 0.08),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Rank number
                Container(
                  width: isCenter ? 32 : 26,
                  height: isCenter ? 32 : 26,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: isCenter ? 15 : 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // XP Amount
                Text(
                  '${user.xp} XP',
                  style: TextStyle(
                    fontSize: isCenter ? 12 : 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),

                // Rank Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    user.rank,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankListItem(LeaderboardUserModel user, int rank, bool isDark, bool isMe) {
    final decor = UserDecorResolver.instance.get(user.username);
    final avatarUrl = decor?.avatarUrl ?? user.avatarUrl;
    final decorUrl = decor?.decorationUrl ?? user.fullAvatarDecorationUrl;
    final decorCode = decor?.decorationCode ?? user.avatarDecorationCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe
            ? (const Color(0xFFFF9500).withValues(alpha: isDark ? 0.15 : 0.08))
            : (isDark ? const Color(0xFF18181C) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? const Color(0xFFFF9500).withValues(alpha: 0.4)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          width: isMe ? 1.0 : 0.6,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: () {
          HapticFeedback.lightImpact();
          showUserProfileCard(context, username: user.username);
        },
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank Number
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Decorated Avatar
            DecoratedAvatar(
              avatarUrl: avatarUrl,
              decorationUrl: decorUrl,
              decorationCode: decorCode,
              decorationScale: decor?.decorationScale ?? 1.0,
              offsetX: decor?.decorationOffsetX ?? 0,
              offsetY: decor?.decorationOffsetY ?? 0,
              fallbackName: user.username,
              radius: 19,
            ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (user.verifiedBadge) ...[
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
            ],
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'KAMU',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Lv. ${user.level}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                user.rank,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.bolt_fill, size: 11, color: Color(0xFFFF9500)),
              const SizedBox(width: 4),
              Text(
                '${user.xp}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyRankBottomHud(LeaderboardUserModel myRank, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1C1C20) : Colors.white).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Position Circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '#${myRank.rankPosition}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Peringkat Kamu',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv. ${myRank.level}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  myRank.rank,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),

          // Total XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${myRank.xp} XP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.rosette, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'Belum ada data peringkat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jadilah petualang pertama yang meraih XP!',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle, size: 42, color: Colors.amber[700]),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFFFF9500),
            onPressed: _loadLeaderboard,
            child: const Text('Coba Lagi', style: TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
