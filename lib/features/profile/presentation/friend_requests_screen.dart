import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../data/profile_repository.dart';
import '../data/models/friendship_model.dart';
import 'other_user_profile_screen.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<FriendUserItem> _friends = [];
  List<FriendRequestItem> _incoming = [];
  List<FriendRequestItem> _outgoing = [];

  bool _isLoading = true;
  bool _isSilentSyncing = false;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Realtime background sync every 3.5 seconds
    _realtimeTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) _syncDataSilently();
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ProfileRepository.instance.getFriendsList(),
        ProfileRepository.instance.getFriendRequests(),
      ]);

      if (mounted) {
        final friends = results[0] as List<FriendUserItem>;
        final reqs = results[1] as Map<String, dynamic>;

        setState(() {
          _friends = friends;
          _incoming = reqs['incoming'] as List<FriendRequestItem>? ?? [];
          _outgoing = reqs['outgoing'] as List<FriendRequestItem>? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncDataSilently() async {
    if (_isSilentSyncing || _isLoading) return;
    _isSilentSyncing = true;
    try {
      final results = await Future.wait([
        ProfileRepository.instance.getFriendsList(),
        ProfileRepository.instance.getFriendRequests(),
      ]);

      if (mounted) {
        final friends = results[0] as List<FriendUserItem>;
        final reqs = results[1] as Map<String, dynamic>;
        final incoming = reqs['incoming'] as List<FriendRequestItem>? ?? [];
        final outgoing = reqs['outgoing'] as List<FriendRequestItem>? ?? [];

        final hasChanges = friends.length != _friends.length ||
            incoming.length != _incoming.length ||
            outgoing.length != _outgoing.length ||
            !_areFriendsEqual(friends, _friends) ||
            !_areRequestsEqual(incoming, _incoming) ||
            !_areRequestsEqual(outgoing, _outgoing);

        if (hasChanges) {
          setState(() {
            _friends = friends;
            _incoming = incoming;
            _outgoing = outgoing;
          });
        }
      }
    } catch (_) {} finally {
      _isSilentSyncing = false;
    }
  }

  bool _areFriendsEqual(List<FriendUserItem> a, List<FriendUserItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].username != b[i].username) return false;
    }
    return true;
  }

  bool _areRequestsEqual(List<FriendRequestItem> a, List<FriendRequestItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].status != b[i].status) return false;
    }
    return true;
  }

  Future<void> _acceptRequest(FriendRequestItem item) async {
    HapticFeedback.selectionClick();
    // Optimistic UI update
    setState(() {
      _incoming.removeWhere((r) => r.id == item.id);
    });
    final ok = await ProfileRepository.instance.acceptFriendRequest(item.id);
    if (ok) {
      _showToast('Permintaan teman dari @${item.otherUser?.username ?? ''} diterima!');
      _syncDataSilently();
    } else {
      _loadData();
    }
  }

  Future<void> _rejectRequest(FriendRequestItem item) async {
    HapticFeedback.selectionClick();
    // Optimistic UI update
    setState(() {
      _incoming.removeWhere((r) => r.id == item.id);
    });
    final ok = await ProfileRepository.instance.rejectFriendRequest(item.id);
    if (ok) {
      _showToast('Permintaan teman ditolak');
      _syncDataSilently();
    } else {
      _loadData();
    }
  }

  Future<void> _cancelRequest(FriendRequestItem item) async {
    HapticFeedback.selectionClick();
    // Optimistic UI update
    setState(() {
      _outgoing.removeWhere((r) => r.id == item.id);
    });
    final ok = await ProfileRepository.instance.cancelFriendRequest(item.id);
    if (ok) {
      _showToast('Permintaan teman dibatalkan');
      _syncDataSilently();
    } else {
      _loadData();
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final borderSide = BorderSide(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      width: 0.6,
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'Teman & Permintaan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.4,
            color: textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: isDark ? Colors.white : Colors.black,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: textPrimary,
              unselectedLabelColor: textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                Tab(text: 'Teman (${_friends.length})'),
                Tab(text: 'Masuk (${_incoming.length})'),
                Tab(text: 'Terkirim (${_outgoing.length})'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CupertinoActivityIndicator(
                color: textPrimary,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(isDark, cardBg, borderSide, textPrimary, textSecondary, textMuted),
                _buildIncomingTab(isDark, cardBg, borderSide, textPrimary, textSecondary, textMuted),
                _buildOutgoingTab(isDark, cardBg, borderSide, textPrimary, textSecondary, textMuted),
              ],
            ),
    );
  }

  Widget _buildFriendsTab(
    bool isDark,
    Color cardBg,
    BorderSide borderSide,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (_friends.isEmpty) {
      return _buildEmpty(
        isDark,
        textPrimary,
        textSecondary,
        textMuted,
        'Belum Ada Teman',
        'Mulai tambahkan teman sesama pecinta anime!',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: textPrimary,
      backgroundColor: cardBg,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final f = _friends[idx];
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSide.color, width: borderSide.width),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => OtherUserProfileScreen(username: f.username),
                  ),
                ).then((_) => _loadData());
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: DecoratedAvatar(
                avatarUrl: f.avatarUrl,
                decorationUrl: f.avatarDecorationUrl,
                radius: 22,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      f.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (f.verifiedBadge) ...[
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                  ],
                ],
              ),
              subtitle: f.bio != null && f.bio!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        f.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    )
                  : null,
              trailing: Icon(CupertinoIcons.chevron_right, size: 15, color: textMuted),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomingTab(
    bool isDark,
    Color cardBg,
    BorderSide borderSide,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (_incoming.isEmpty) {
      return _buildEmpty(
        isDark,
        textPrimary,
        textSecondary,
        textMuted,
        'Tidak Ada Permintaan Masuk',
        'Tidak ada orang yang sedang meminta berteman.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: textPrimary,
      backgroundColor: cardBg,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _incoming.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final req = _incoming[idx];
          final u = req.otherUser;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSide.color, width: borderSide.width),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (u != null) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => OtherUserProfileScreen(username: u.username),
                        ),
                      ).then((_) => _loadData());
                    }
                  },
                  child: Row(
                    children: [
                      DecoratedAvatar(
                        avatarUrl: u?.avatarUrl,
                        decorationUrl: u?.avatarDecorationUrl,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    u?.username ?? 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (u?.verifiedBadge == true) ...[
                                  const SizedBox(width: 4),
                                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                                ],
                              ],
                            ),
                            if (req.message != null && req.message!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '"${req.message}"',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptRequest(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt, size: 16),
                            SizedBox(width: 6),
                            Text('Terima', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectRequest(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.iosRed,
                          side: BorderSide(
                            color: isDark ? AppColors.iosRed.withValues(alpha: 0.5) : AppColors.iosRed.withValues(alpha: 0.3),
                          ),
                          backgroundColor: isDark
                              ? AppColors.iosRed.withValues(alpha: 0.08)
                              : AppColors.iosRed.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.xmark, size: 14),
                            SizedBox(width: 6),
                            Text('Tolak', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutgoingTab(
    bool isDark,
    Color cardBg,
    BorderSide borderSide,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (_outgoing.isEmpty) {
      return _buildEmpty(
        isDark,
        textPrimary,
        textSecondary,
        textMuted,
        'Tidak Ada Permintaan Terkirim',
        'Kamu belum mengirim permintaan pertemanan ke siapapun.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: textPrimary,
      backgroundColor: cardBg,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _outgoing.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final req = _outgoing[idx];
          final u = req.otherUser;
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSide.color, width: borderSide.width),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () {
                if (u != null) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => OtherUserProfileScreen(username: u.username),
                    ),
                  ).then((_) => _loadData());
                }
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: DecoratedAvatar(
                avatarUrl: u?.avatarUrl,
                decorationUrl: u?.avatarDecorationUrl,
                radius: 22,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      u?.username ?? 'User',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (u?.verifiedBadge == true) ...[
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                  ],
                ],
              ),
              subtitle: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.clock_fill, size: 10, color: isDark ? const Color(0xFFFFB340) : const Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          'Menunggu konfirmasi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFFB340) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              trailing: TextButton(
                onPressed: () => _cancelRequest(req),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.iosRed,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    String title,
    String desc,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_2_fill,
                size: 38,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textPrimary,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
