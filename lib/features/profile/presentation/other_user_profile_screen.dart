import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../../../core/services/user_decor_resolver.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../auth/data/models/user_model.dart';
import '../data/profile_repository.dart';
import '../data/models/friendship_model.dart';
import '../data/models/user_activity_model.dart';
import '../data/models/profile_font_model.dart';
import 'edit_profile_screen.dart';
import 'friend_requests_screen.dart';
import '../../anime/data/models/genre_role_model.dart';
import '../../anime/presentation/widgets/genre_role_widgets.dart';
import '../../gamification/presentation/widgets/level_xp_card.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String username;
  final UserModel? initialUser;

  const OtherUserProfileScreen({
    super.key,
    required this.username,
    this.initialUser,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  UserModel? _user;
  FriendshipInfo? _friendship;
  bool _isLoadingFriendship = true;
  bool _isFriendActionLoading = false;

  // Stats sama seperti di Profile Card sebelumnya
  int _watchCount = 0;
  int _comicReadCount = 0;
  int _bookmarkCount = 0;
  String _watchDuration = '';
  int _friendCount = 0;
  GenreRoleItem? _equippedGenreRole;

  // Filter bookmark / favorit (0: Semua, 1: Anime, 2: Komik)
  int _favoriteFilterIndex = 0;

  // Activities
  List<UserAnimeFavorite> _animeFavorites = [];
  List<UserComicFavorite> _comicFavorites = [];
  bool _isLoadingFavorites = true;

  List<UserCommentItem> _comments = [];
  bool _isLoadingComments = true;

  List<UserChatItem> _chats = [];
  bool _isLoadingChats = true;

  bool get _isMe {
    try {
      final auth = context.read<AuthProvider>();
      return auth.currentUser?.username.toLowerCase() == widget.username.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  Future<void> _removeProfileFavoriteItem({required int id, required String title, required String type}) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Hapus $type Disukai?'),
        content: Text('Yakin ingin menghapus "$title" dari daftar anime/komik favorit di profil kamu?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ProfileRepository.instance.deleteProfileLiked(id);
      if (ok) {
        _loadFavorites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$title" dihapus dari profil'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _user = widget.initialUser;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadUserProfileAndStats();
    _loadFriendshipStatus();
    _loadFavorites();
    _loadComments();
    _loadChats();
    _loadFriendsCount();
    _loadGenreRole();
  }

  static String _formatSecondsToHuman(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}j ${m}m';
    if (h > 0) return '${h}j';
    return '${m}m';
  }

  Future<void> _loadUserProfileAndStats() async {
    final targetUsername = widget.username;
    try {
      final user = await ProfileRepository.instance.byUsername(targetUsername);
      if (mounted) {
        setState(() => _user = user);
      }
    } catch (_) {}

    int watchCount = 0;
    int bookmarkCount = 0;
    String watchDuration = '';
    int comicReadCount = 0;

    // 1. Fetch public YLnime user stats
    try {
      final ylnimeStatsData = await AnimeRepository.instance.ylnimeUserStats(targetUsername);
      final s = (ylnimeStatsData['stats'] is Map)
          ? ylnimeStatsData['stats'] as Map
          : ylnimeStatsData;

      if (s.isNotEmpty) {
        bookmarkCount = (s['total_bookmarks'] as num?)?.toInt() ??
            (s['bookmarks'] as num?)?.toInt() ??
            0;
        watchCount = (s['total_watched'] as num?)?.toInt() ??
            (s['total_history'] as num?)?.toInt() ??
            (s['total_unique_anime'] as num?)?.toInt() ??
            (s['completed'] as num?)?.toInt() ??
            0;
        final dur = s['total_watch_duration_formatted'] ?? s['total_time_formatted'];
        if (dur != null && dur.toString().isNotEmpty && dur.toString() != '0s') {
          watchDuration = dur.toString();
        } else if (s['total_time'] != null && (s['total_time'] as num) > 0) {
          watchDuration = _formatSecondsToHuman((s['total_time'] as num).toInt());
        } else if (s['total_watch_duration'] != null && (s['total_watch_duration'] as num) > 0) {
          watchDuration = _formatSecondsToHuman((s['total_watch_duration'] as num).toInt());
        }
      }
    } catch (_) {}

    // 2. Fetch public Komik reading stats
    try {
      final comicData = await ComicRepository.instance.publicStats(targetUsername);
      final cd = (comicData.containsKey('data') && comicData['data'] is Map)
          ? comicData['data'] as Map
          : comicData;
      if (cd.isNotEmpty) {
        comicReadCount = (cd['total_history'] as num?)?.toInt() ??
            (cd['unique_comics_read'] as num?)?.toInt() ??
            0;
        final cBm = (cd['total_bookmarks'] as num?)?.toInt() ?? 0;
        bookmarkCount += cBm;
      }
    } catch (_) {}

    // 3. Authenticated self fallback: raw history & bookmarks
    if (_isSelf) {
      try {
        final rawHistory = await AnimeRepository.instance.getWatchHistoryRaw(limit: 100);
        if (rawHistory != null && rawHistory['stats'] is Map) {
          final hs = rawHistory['stats'] as Map;
          final rawCount = (hs['total_unique_anime'] as num?)?.toInt() ??
              (hs['total_entries'] as num?)?.toInt() ??
              0;
          if (rawCount > watchCount) watchCount = rawCount;
          final rawDur = hs['total_watch_time_formatted']?.toString();
          if (rawDur != null && rawDur.isNotEmpty && rawDur != '0s') {
            watchDuration = rawDur;
          }
        }
      } catch (_) {}

      if (comicReadCount == 0) {
        try {
          final cHist = await ComicRepository.instance.readHistory();
          comicReadCount = cHist.length;
        } catch (_) {}
      }

      if (bookmarkCount == 0) {
        try {
          final bms = await AnimeRepository.instance.bookmarks();
          final cBms = await ComicRepository.instance.bookmarks();
          bookmarkCount = bms.length + cBms.length;
        } catch (_) {}
      }
    }

    // 4. Generic stats fallback
    if (watchCount == 0 || comicReadCount == 0 || bookmarkCount == 0) {
      try {
        final genericStats = await ProfileRepository.instance.stats(targetUsername);
        if (watchCount == 0) {
          watchCount = (genericStats['total_anime_watched'] as num?)?.toInt() ??
              (genericStats['total_episodes_watched'] as num?)?.toInt() ??
              (genericStats['anime_watched'] as num?)?.toInt() ??
              (genericStats['total_watched'] as num?)?.toInt() ??
              0;
        }
        if (comicReadCount == 0) {
          comicReadCount = (genericStats['comics_read'] as num?)?.toInt() ??
              (genericStats['total_comic_read'] as num?)?.toInt() ??
              0;
        }
        if (bookmarkCount == 0) {
          bookmarkCount = (genericStats['bookmarks_count'] as num?)?.toInt() ??
              (genericStats['total_bookmarks'] as num?)?.toInt() ??
              0;
        }
        if (watchDuration.isEmpty && genericStats['total_watch_time'] != null && (genericStats['total_watch_time'] as num) > 0) {
          watchDuration = _formatSecondsToHuman((genericStats['total_watch_time'] as num).toInt());
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _watchCount = watchCount;
        _comicReadCount = comicReadCount;
        _bookmarkCount = bookmarkCount;
        _watchDuration = watchDuration;
      });
    }
  }

  Future<void> _loadFriendshipStatus() async {
    if (_isSelf) {
      if (mounted) {
        setState(() {
          _friendship = FriendshipInfo(status: FriendStatus.self);
          _isLoadingFriendship = false;
        });
      }
      return;
    }
    try {
      final info = await ProfileRepository.instance.getFriendStatus(widget.username);
      if (mounted) {
        setState(() {
          _friendship = info;
          _isLoadingFriendship = false;
          final raw = info.raw;
          if (raw != null) {
            final fc = (raw['friends_count'] ?? raw['total_friends'] ?? raw['total']) as num?;
            if (fc != null && fc.toInt() > _friendCount) {
              _friendCount = fc.toInt();
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingFriendship = false);
      }
    }
  }

  Future<void> _loadFriendsCount() async {
    try {
      final friends = await ProfileRepository.instance.getFriendsList(username: widget.username);
      if (mounted) {
        setState(() {
          _friendCount = friends.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGenreRole() async {
    final cached = UserDecorResolver.instance.get(widget.username);
    if (cached?.genreRole != null) {
      if (mounted) setState(() => _equippedGenreRole = cached!.genreRole);
    }
    try {
      final summary = await AnimeRepository.instance.getUserGenreRoles(widget.username);
      final role = summary.primaryRole ??
          summary.pinnedRole ??
          (summary.roles.isNotEmpty ? summary.roles.first : null);
      if (mounted && role != null) {
        setState(() => _equippedGenreRole = role);
      }
    } catch (_) {}
  }

  Future<void> _loadFavorites() async {
    try {
      final res = await ProfileRepository.instance.getUserFavorites(widget.username);
      var anime = res['anime'] as List<UserAnimeFavorite>? ?? [];
      var comics = res['comics'] as List<UserComicFavorite>? ?? [];

      // Fallback untuk akun sendiri: jika belum ada item pilihan disukai, tampilkan bookmark pengguna
      if (anime.isEmpty && comics.isEmpty && _isSelf) {
        try {
          final animeBms = await AnimeRepository.instance.bookmarks();
          anime = animeBms
              .map(
                (b) => UserAnimeFavorite(
                  id: int.tryParse(b.id) ?? 0,
                  animeId: b.id,
                  title: b.title,
                  thumbnail: b.thumb,
                  type: 'ylnime',
                  isProfileLiked: false,
                ),
              )
              .where((e) => e.title.isNotEmpty)
              .toList();
        } catch (_) {}

        try {
          final comicBms = await ComicRepository.instance.bookmarks();
          comics = comicBms
              .map(
                (c) => UserComicFavorite(
                  id: int.tryParse(c.slug) ?? 0,
                  slug: c.slug,
                  title: c.title,
                  thumbnail: c.thumb,
                  isProfileLiked: false,
                ),
              )
              .where((e) => e.title.isNotEmpty)
              .toList();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _animeFavorites = anime;
          _comicFavorites = comics;
          _isLoadingFavorites = false;
          // Sync bookmark count jika lebih akurat dari list aktual
          if (anime.length + comics.length > _bookmarkCount) {
            _bookmarkCount = anime.length + comics.length;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFavorites = false);
    }
  }

  Future<void> _loadComments() async {
    try {
      final res = await ProfileRepository.instance.getUserComments(widget.username);
      if (mounted) {
        setState(() {
          _comments = res;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _loadChats() async {
    try {
      final res = await ProfileRepository.instance.getUserChats(widget.username);
      if (mounted) {
        setState(() {
          _chats = res;
          _isLoadingChats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  bool get _isSelf {
    final currentUsername = context.read<AuthProvider>().user?.username;
    if (currentUsername != null &&
        currentUsername.toLowerCase() == widget.username.toLowerCase()) {
      return true;
    }
    return _friendship?.status == FriendStatus.self;
  }

  ProfileFontModel? get _effectiveFontModel {
    final user = _user;
    final cached = UserDecorResolver.instance.get(widget.username);
    return user?.profileFontData ??
        cached?.profileFontData ??
        ProfileFontModel.fromKey(user?.profileFont);
  }

  TextStyle _heroTextStyle(
    ProfileFontModel? fontModel, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    if (fontModel != null) {
      return fontModel.textStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ─── FRIENDSHIP ACTIONS ───

  void _showAddFriendDialog() {
    final msgCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Kirim Permintaan Teman'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(
                'Kirim permintaan berteman ke @${widget.username}. Kamu juga bisa menambahkan pesan perkenalan singkat.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: msgCtrl,
                placeholder: 'Halo! Salam kenal ya...',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                maxLines: 2,
                maxLength: 100,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendFriendRequest(msgCtrl.text);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String message) async {
    setState(() => _isFriendActionLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final res = await ProfileRepository.instance.sendFriendRequest(
        widget.username,
        message: message,
      );
      if (res['success'] == true) {
        _showToast(res['message']?.toString() ?? 'Permintaan teman berhasil dikirim!');
        await _loadFriendshipStatus();
      } else {
        _showToast(res['error']?.toString() ?? 'Gagal mengirim permintaan');
      }
    } catch (_) {
      _showToast('Terjadi kesalahan saat mengirim permintaan');
    } finally {
      if (mounted) setState(() => _isFriendActionLoading = false);
    }
  }

  Future<void> _acceptFriendRequest() async {
    final reqId = _friendship?.requestId;
    if (reqId == null) return;
    setState(() => _isFriendActionLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final success = await ProfileRepository.instance.acceptFriendRequest(reqId);
      if (success) {
        _showToast('Permintaan pertemanan diterima! Sekarang kalian berteman 🎉');
        await _loadFriendshipStatus();
        _loadFriendsCount();
      } else {
        _showToast('Gagal menerima permintaan');
      }
    } catch (_) {
      _showToast('Terjadi kesalahan');
    } finally {
      if (mounted) setState(() => _isFriendActionLoading = false);
    }
  }

  Future<void> _rejectFriendRequest() async {
    final reqId = _friendship?.requestId;
    if (reqId == null) return;
    setState(() => _isFriendActionLoading = true);
    try {
      final success = await ProfileRepository.instance.rejectFriendRequest(reqId);
      if (success) {
        _showToast('Permintaan pertemanan ditolak');
        await _loadFriendshipStatus();
      }
    } catch (_) {
      _showToast('Terjadi kesalahan');
    } finally {
      if (mounted) setState(() => _isFriendActionLoading = false);
    }
  }

  Future<void> _cancelFriendRequest() async {
    final reqId = _friendship?.requestId;
    if (reqId == null) return;
    setState(() => _isFriendActionLoading = true);
    try {
      final success = await ProfileRepository.instance.cancelFriendRequest(reqId);
      if (success) {
        _showToast('Permintaan pertemanan dibatalkan');
        await _loadFriendshipStatus();
      }
    } catch (_) {
      _showToast('Terjadi kesalahan');
    } finally {
      if (mounted) setState(() => _isFriendActionLoading = false);
    }
  }

  void _showFriendsMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Pertemanan dengan @${widget.username}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToChatWithMention();
            },
            child: const Text('Kirim Pesan / Obrolan'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmUnfriend();
            },
            child: const Text('Hapus Teman (Unfriend)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup'),
        ),
      ),
    );
  }

  void _confirmUnfriend() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Pertemanan?'),
        content: Text('Apakah kamu yakin ingin menghapus @${widget.username} dari daftar teman?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isFriendActionLoading = true);
              try {
                final success = await ProfileRepository.instance.unfriend(widget.username);
                if (success) {
                  _showToast('Berhasil menghapus teman');
                  await _loadFriendshipStatus();
                  _loadFriendsCount();
                }
              } catch (_) {
                _showToast('Gagal menghapus teman');
              } finally {
                if (mounted) setState(() => _isFriendActionLoading = false);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _navigateToChatWithMention() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ChatScreen(initialText: '@${widget.username} '),
      ),
    );
  }

  void _handleFriendsStatTap() {
    HapticFeedback.selectionClick();
    if (_isMe) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const FriendRequestsScreen()),
      ).then((_) => _loadFriendsCount());
    } else {
      _showOtherUserFriendsModal();
    }
  }

  void _showOtherUserFriendsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontModel = _effectiveFontModel;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.person_2_fill, size: 20, color: textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Daftar Teman',
                          style: _heroTextStyle(
                            fontModel,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_friendCount teman',
                      style: _heroTextStyle(
                        fontModel,
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: FutureBuilder<List<FriendUserItem>>(
                  future: ProfileRepository.instance.getFriendsList(username: widget.username),
                  builder: (fCtx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.person_2, size: 40, color: textSecondary),
                              const SizedBox(height: 10),
                              Text(
                                'Belum Memiliki Teman',
                                style: _heroTextStyle(
                                  fontModel,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${widget.username} belum memiliki teman yang terhubung.',
                                textAlign: TextAlign.center,
                                style: _heroTextStyle(
                                  fontModel,
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (lCtx, idx) {
                        final f = friends[idx];
                        final authUser = context.read<AuthProvider>().user;
                        final isSelfFriend = authUser != null &&
                            f.username.toLowerCase() == authUser.username.toLowerCase();
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: DecoratedAvatar(
                            avatarUrl: f.avatarUrl,
                            decorationUrl: f.avatarDecorationUrl,
                            radius: 20,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  f.username,
                                  style: _heroTextStyle(
                                    fontModel,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelfFriend) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Anda',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                              if (f.verifiedBadge) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  size: 14,
                                  color: Color(0xFF007AFF),
                                ),
                              ],
                            ],
                          ),
                          subtitle: f.bio != null && f.bio!.isNotEmpty
                              ? Text(
                                  f.bio!,
                                  style: _heroTextStyle(
                                    fontModel,
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Icon(CupertinoIcons.chevron_forward, size: 14, color: textSecondary),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (!isSelfFriend) {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => OtherUserProfileScreen(username: f.username),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: isDark ? Colors.black : Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: isDark ? Colors.white : const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final fontModel = _effectiveFontModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 290,
              pinned: true,
              backgroundColor: bgColor,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                  child: IconButton(
                    icon: Icon(CupertinoIcons.back, color: isDark ? Colors.white : Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [
                if (!_isSelf)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircleAvatar(
                      backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                      child: IconButton(
                        icon: Icon(CupertinoIcons.chat_bubble_2_fill, color: isDark ? Colors.white : Colors.black, size: 18),
                        tooltip: 'Mention di Chat',
                        onPressed: _navigateToChatWithMention,
                      ),
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildCoverAndAvatarHeader(user, isDark),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildProfileInfoAndActions(user, fontModel, isDark),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: isDark ? Colors.white : Colors.black,
                  indicatorWeight: 2.5,
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                  labelStyle: _heroTextStyle(fontModel, fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(CupertinoIcons.heart_fill, size: 18),
                      text: (_animeFavorites.length + _comicFavorites.length > 0)
                          ? 'Disukai (${_animeFavorites.length + _comicFavorites.length})'
                          : 'Disukai',
                    ),
                    Tab(
                      icon: const Icon(CupertinoIcons.bubble_left_bubble_right_fill, size: 18),
                      text: 'Komentar (${_comments.length})',
                    ),
                    Tab(
                      icon: const Icon(CupertinoIcons.quote_bubble_fill, size: 18),
                      text: 'Chat (${_chats.length})',
                    ),
                  ],
                ),
                backgroundColor: bgColor,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFavoritesTab(fontModel, isDark),
            _buildCommentsTab(fontModel, isDark),
            _buildChatsTab(fontModel, isDark),
          ],
        ),
      ),
    );
  }

  // ─── COVER & AVATAR HEADER (APPLE HIG MINIMALIST DESIGN) ───

  Widget _buildCoverAndAvatarHeader(UserModel? user, bool isDark) {
    final coverUrl = user?.coverUrl;
    final avatarUrl = user?.avatarUrl;
    final decorUrl = user?.avatarDecorationUrl;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Photo
        Positioned.fill(
          child: coverUrl != null && coverUrl.isNotEmpty
              ? CalmGif(
                  source: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: _defaultCoverWidget(isDark),
                )
              : _defaultCoverWidget(isDark),
        ),
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: isDark ? 0.65 : 0.35),
                  bgColor,
                ],
              ),
            ),
          ),
        ),
        // Apple HIG Monochrome Avatar Ring
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                border: (decorUrl != null && decorUrl.isNotEmpty)
                    ? null
                    : Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2.5,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: DecoratedAvatar(
                    avatarUrl: avatarUrl,
                    decorationUrl: decorUrl,
                    radius: 46,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultCoverWidget(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.sparkles,
          size: 48,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        ),
      ),
    );
  }

  // ─── PROFILE INFO & MONOCHROME STYLED USERNAME DENGAN CUSTOM FONT ───

  Widget _buildProfileInfoAndActions(UserModel? user, ProfileFontModel? fontModel, bool isDark) {
    final rawDisplayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.username ?? widget.username);
    final role = user?.role ?? 'Member';
    final bio = user?.bio ?? '';
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Display Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  rawDisplayName,
                  textAlign: TextAlign.center,
                  style: _heroTextStyle(
                    fontModel,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user?.verifiedBadge == true) ...[
                const SizedBox(width: 5),
                const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 20,
                  color: Color(0xFF007AFF),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Stylized Monochrome Username Pill with Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.at, size: 13, color: textSecondary),
                const SizedBox(width: 3),
                Text(
                  user?.username ?? widget.username,
                  style: _heroTextStyle(
                    fontModel,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: user?.username ?? widget.username));
                    _showToast('Username @${user?.username ?? widget.username} disalin!');
                  },
                  child: Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 13,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Role Badge & Anime Badge
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.shield_lefthalf_fill, size: 11, color: textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      role.toUpperCase(),
                      style: _heroTextStyle(
                        fontModel,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (_equippedGenreRole != null)
                GenreRoleBadge(
                  role: _equippedGenreRole!,
                  compact: true,
                  isDark: isDark,
                  onTap: () {
                    showGenreRoleDetailModal(
                      context,
                      _equippedGenreRole!,
                      isDark: isDark,
                      onEquipChanged: _loadAll,
                    );
                  },
                )
              else if (_isMe)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    showGenreRoleCatalogModal(context, isDark: isDark);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.sparkles, size: 11, color: Color(0xFFEAB308)),
                        const SizedBox(width: 4),
                        Text(
                          'PASANG ROLE GENRE',
                          style: _heroTextStyle(
                            fontModel,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Bio in Clean Dialogue Bubble
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text('“', style: TextStyle(fontSize: 20, color: textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bio,
                      style: _heroTextStyle(
                        fontModel,
                        fontSize: 12.5,
                        color: textPrimary,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('”', style: TextStyle(fontSize: 20, color: textSecondary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],

          // Location, Birthday & Website / Social Media meta tags
          () {
            final loc = user?.location?.trim();
            final hasLocation = loc != null && loc.isNotEmpty;
            final bdayText = _formatBirthdayTag(user);
            final web = user?.website?.trim();
            final hasWebsite = web != null && web.isNotEmpty;
            if (!hasLocation && bdayText == null && !hasWebsite) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (hasLocation)
                    _buildMetaTag(
                      icon: CupertinoIcons.location_solid,
                      label: loc,
                      isDark: isDark,
                      fontModel: fontModel,
                    ),
                  if (hasWebsite)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        var target = web;
                        if (!target.startsWith('http://') && !target.startsWith('https://')) {
                          target = 'https://$target';
                        }
                        final uri = Uri.tryParse(target);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: _buildMetaTag(
                        icon: CupertinoIcons.link,
                        label: web,
                        isDark: isDark,
                        fontModel: fontModel,
                      ),
                    ),
                  if (bdayText != null)
                    _buildMetaTag(
                      icon: _isBirthdayToday(user) ? CupertinoIcons.gift_fill : CupertinoIcons.gift,
                      label: bdayText,
                      isDark: isDark,
                      fontModel: fontModel,
                      isFestive: _isBirthdayToday(user),
                    ),
                ],
              ),
            );
          }(),

          const SizedBox(height: 14),

          // Action Buttons: Friend Request & Chat
          _buildFriendActionSection(fontModel, isDark),

          const SizedBox(height: 14),

          // Level & XP Gamification Card
          if (_user != null) ...[
            LevelXpCard(user: _user),
            const SizedBox(height: 14),
          ],

          // ─── STATS BAR: ANIME, KOMIK, BOOKMARK, DURASI ───
          _buildMedsosStatsBar(fontModel, isDark),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFriendActionSection(ProfileFontModel? fontModel, bool isDark) {
    if (_isLoadingFriendship) {
      return const SizedBox(
        height: 44,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_isSelf) {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton.icon(
          onPressed: () {
            final authUser = _user ?? context.read<AuthProvider>().user;
            if (authUser != null) {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => EditProfileScreen(user: authUser)),
              ).then((_) => _loadUserProfileAndStats());
            }
          },
          icon: Icon(CupertinoIcons.pencil, size: 16, color: isDark ? Colors.white : Colors.black),
          label: Text('Edit Profil Saya', style: _heroTextStyle(fontModel, color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      );
    }

    final status = _friendship?.status ?? FriendStatus.none;

    if (_isFriendActionLoading) {
      return const SizedBox(
        height: 44,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    switch (status) {
      case FriendStatus.friends:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _showFriendsMenu,
                icon: Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: isDark ? Colors.white : Colors.black),
                label: Text('Berteman', style: _heroTextStyle(fontModel, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToChatWithMention,
                icon: Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: isDark ? Colors.black : Colors.white),
                label: Text('Pesan', style: _heroTextStyle(fontModel, color: isDark ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        );

      case FriendStatus.pendingSent:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelFriendRequest,
                icon: Icon(CupertinoIcons.clock_fill, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                label: Text('Menunggu Persetujuan (Batalkan)', style: _heroTextStyle(fontModel, color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black26, width: 0.8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        );

      case FriendStatus.pendingReceived:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.8),
              ),
              child: Text(
                _friendship?.message?.isNotEmpty == true
                    ? 'Pesan: "${_friendship!.message}"'
                    : '@${widget.username} mengirim permintaan berteman untukmu!',
                style: _heroTextStyle(fontModel, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptFriendRequest,
                    icon: Icon(CupertinoIcons.person_badge_plus_fill, size: 16, color: isDark ? Colors.black : Colors.white),
                    label: Text('Terima', style: _heroTextStyle(fontModel, color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _rejectFriendRequest,
                    icon: Icon(CupertinoIcons.xmark, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                    label: Text('Tolak', style: _heroTextStyle(fontModel, color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case FriendStatus.none:
      default:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _showAddFriendDialog,
                icon: Icon(CupertinoIcons.person_badge_plus_fill, size: 16, color: isDark ? Colors.black : Colors.white),
                label: Text('Tambah Teman', style: _heroTextStyle(fontModel, color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToChatWithMention,
                icon: Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: isDark ? Colors.white : Colors.black),
                label: Text('Chat', style: _heroTextStyle(fontModel, color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  elevation: 0,
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        );
    }
  }

  // ─── STATS BAR: ANIME, KOMIK, BOOKMARK, DURASI (PERSIS PROFILE CARD) ───

  Widget _buildMedsosStatsBar(ProfileFontModel? fontModel, bool isDark) {
    final totalLikes = _animeFavorites.length + _comicFavorites.length;
    final likedCount = totalLikes > 0 ? totalLikes : _bookmarkCount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // 1. Tontonan Anime
          Expanded(
            child: _buildStatItem(
              icon: CupertinoIcons.play_circle_fill,
              value: '$_watchCount',
              label: 'Anime',
              fontModel: fontModel,
              isDark: isDark,
            ),
          ),
          _statsDivider(isDark),

          // 2. Bacaan Komik
          Expanded(
            child: _buildStatItem(
              icon: CupertinoIcons.book_fill,
              value: '$_comicReadCount',
              label: 'Komik',
              fontModel: fontModel,
              isDark: isDark,
            ),
          ),
          _statsDivider(isDark),

          // 3. Jumlah Teman (angka jumlah temannya)
          Expanded(
            child: _buildStatItem(
              icon: CupertinoIcons.person_2_fill,
              value: '$_friendCount',
              label: 'Teman',
              fontModel: fontModel,
              isDark: isDark,
              onTap: _handleFriendsStatTap,
            ),
          ),

          // 4. Disukai / Favorit (Hanya tampil jika likedCount > 0!)
          if (likedCount > 0) ...[
            _statsDivider(isDark),
            Expanded(
              child: _buildStatItem(
                icon: CupertinoIcons.heart_fill,
                value: '$likedCount',
                label: 'Disukai',
                fontModel: fontModel,
                isDark: isDark,
                onTap: () {
                  if (_tabController.length > 0) {
                    _tabController.animateTo(0);
                  }
                },
              ),
            ),
          ],

          _statsDivider(isDark),

          // 5. Durasi / Status
          Expanded(
            child: _buildStatItem(
              icon: CupertinoIcons.bolt_fill,
              value: _watchDuration.isNotEmpty
                  ? _watchDuration
                  : (_user?.role?.toUpperCase() ?? 'AKTIF'),
              label: _watchDuration.isNotEmpty ? 'Durasi' : 'Status',
              fontModel: fontModel,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsDivider(bool isDark) {
    return Container(
      width: 0.8,
      height: 28,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required ProfileFontModel? fontModel,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: _heroTextStyle(
                  fontModel,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: _heroTextStyle(
            fontModel,
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: col,
      );
    }
    return col;
  }

  // ─── TAB 1: ANIME & KOMIK DISUKAI (VERTIKAL KE BAWAH) ───

  Widget _buildFavoritesTab(ProfileFontModel? fontModel, bool isDark) {
    if (_isLoadingFavorites) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final totalAnime = _animeFavorites.length;
    final totalComics = _comicFavorites.length;
    final totalAll = totalAnime + totalComics;

    if (totalAll == 0) {
      final isMe = _isMe;
      return _buildEmptyState(
        CupertinoIcons.heart_fill,
        isMe ? 'Belum Ada Favorit Disukai' : 'Belum Ada Favorit Disukai',
        isMe
            ? 'Pamerkan anime dan komik favoritmu di sini! Buka anime atau komik pilihanmu dan ketuk tombol hati "Suka" untuk menampilkannya di profil.'
            : '@${widget.username} belum memilih anime atau komik favorit untuk ditampilkan di profilnya.',
        fontModel,
        isDark,
      );
    }

    // Filter item yang akan dirender ke bawah
    final List<dynamic> itemsToShow = [];
    if (_favoriteFilterIndex == 0) {
      itemsToShow.addAll(_animeFavorites);
      itemsToShow.addAll(_comicFavorites);
    } else if (_favoriteFilterIndex == 1) {
      itemsToShow.addAll(_animeFavorites);
    } else {
      itemsToShow.addAll(_comicFavorites);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Filter Chips (Semua, Anime, Komik)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua ($totalAll)',
                icon: CupertinoIcons.sparkles,
                selected: _favoriteFilterIndex == 0,
                fontModel: fontModel,
                isDark: isDark,
                onTap: () => setState(() => _favoriteFilterIndex = 0),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Anime ($totalAnime)',
                icon: CupertinoIcons.film_fill,
                selected: _favoriteFilterIndex == 1,
                fontModel: fontModel,
                isDark: isDark,
                onTap: () => setState(() => _favoriteFilterIndex = 1),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Komik ($totalComics)',
                icon: CupertinoIcons.book_fill,
                selected: _favoriteFilterIndex == 2,
                fontModel: fontModel,
                isDark: isDark,
                onTap: () => setState(() => _favoriteFilterIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Grid Kartu Vertikal Disusun Ke Bawah
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.65,
          ),
          itemCount: itemsToShow.length,
          itemBuilder: (ctx, idx) {
            final item = itemsToShow[idx];
            if (item is UserAnimeFavorite) {
              return _buildAnimeBookmarkCard(item, fontModel, isDark);
            } else if (item is UserComicFavorite) {
              return _buildComicBookmarkCard(item, fontModel, isDark);
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ProfileFontModel? fontModel,
    required bool isDark,
  }) {
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeFg = isDark ? Colors.black : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inactiveFg = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeBg
                : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08)),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? activeFg : inactiveFg,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: _heroTextStyle(
                fontModel,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? activeFg : inactiveFg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeBookmarkCard(UserAnimeFavorite a, ProfileFontModel? fontModel, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => AnimeDetailScreen(animeId: a.animeId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster Anime
              if (a.thumbnail != null && a.thumbnail!.isNotEmpty)
                CalmGif(
                  source: a.thumbnail!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: isDark ? const Color(0xFF1B202E) : const Color(0xFFE5E5EA),
                  child: Icon(CupertinoIcons.film, color: isDark ? Colors.white30 : Colors.black26, size: 36),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Type Badge (ANIME) - Monochrome Apple Pill
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.play_circle_fill, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        'ANIME',
                        style: _heroTextStyle(
                          fontModel,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Like / Favorite Heart Badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _isMe ? () => _removeProfileFavoriteItem(id: a.id, title: a.title, type: 'Anime') : null,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white30,
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Title and Info
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTextStyle(
                    fontModel,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComicBookmarkCard(UserComicFavorite c, ProfileFontModel? fontModel, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ComicDetailScreen(slug: c.slug),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster Komik
              if (c.thumbnail != null && c.thumbnail!.isNotEmpty)
                CalmGif(
                  source: c.thumbnail!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: isDark ? const Color(0xFF1B202E) : const Color(0xFFE5E5EA),
                  child: Icon(CupertinoIcons.book, color: isDark ? Colors.white30 : Colors.black26, size: 36),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Type Badge (KOMIK) - Monochrome Apple Pill
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.book_fill, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        'KOMIK',
                        style: _heroTextStyle(
                          fontModel,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Like / Favorite Heart Badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _isMe ? () => _removeProfileFavoriteItem(id: c.id, title: c.title, type: 'Komik') : null,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white30,
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Chapter badge if available
              if (c.chapterNumber != null)
                Positioned(
                  top: 36,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: Text(
                      'Ch. ${c.chapterNumber}',
                      style: _heroTextStyle(
                        fontModel,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Title and Info
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTextStyle(
                    fontModel,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 2: KOMENTAR ANIME ───

  Widget _buildCommentsTab(ProfileFontModel? fontModel, bool isDark) {
    if (_isLoadingComments) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_comments.isEmpty) {
      return _buildEmptyState(
        CupertinoIcons.bubble_left_bubble_right,
        'Belum Ada Komentar',
        '@${widget.username} belum pernah berkomentar di episode anime.',
        fontModel,
        isDark,
      );
    }

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final c = _comments[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Anime & Episode info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.play_circle_fill, size: 14, color: textPrimary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Episode ${c.episodeNumber} • ${c.animeId}',
                            style: _heroTextStyle(
                              fontModel,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.createdAt != null)
                    Text(
                      _formatDate(c.createdAt!),
                      style: _heroTextStyle(fontModel, fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Content
              if (c.isSpoiler)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 0.5),
                  ),
                  child: Text('SPOILER', style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold)),
                ),
              Text(
                c.content,
                style: _heroTextStyle(fontModel, fontSize: 13, color: isDark ? Colors.white : Colors.black87, height: 1.35),
              ),

              // Attached Media
              if (c.mediaUrl != null && c.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CalmGif(
                    source: c.mediaUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 10),
              // Footer Likes & Replies
              Row(
                children: [
                  Icon(CupertinoIcons.heart_fill, size: 13, color: textSecondary),
                  const SizedBox(width: 4),
                  Text('${c.likesCount}', style: _heroTextStyle(fontModel, fontSize: 11, color: textSecondary)),
                  const SizedBox(width: 14),
                  Icon(CupertinoIcons.reply, size: 13, color: textSecondary),
                  const SizedBox(width: 4),
                  Text('${c.repliesCount}', style: _heroTextStyle(fontModel, fontSize: 11, color: textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TAB 3: CHAT KOMUNITAS ───

  Widget _buildChatsTab(ProfileFontModel? fontModel, bool isDark) {
    if (_isLoadingChats) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_chats.isEmpty) {
      return _buildEmptyState(
        CupertinoIcons.quote_bubble,
        'Belum Ada Riwayat Chat',
        '@${widget.username} belum mengirim pesan di chat komunitas publik.',
        fontModel,
        isDark,
      );
    }

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final m = _chats[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.chat_bubble_text_fill, size: 13, color: textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Pesan Komunitas',
                        style: _heroTextStyle(fontModel, fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                      ),
                    ],
                  ),
                  if (m.createdAt != null)
                    Text(
                      _formatDate(m.createdAt!),
                      style: _heroTextStyle(fontModel, fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (m.message.isNotEmpty)
                Text(
                  m.message,
                  style: _heroTextStyle(fontModel, fontSize: 13, color: isDark ? Colors.white : Colors.black87, height: 1.35),
                ),
              if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CalmGif(
                    source: m.mediaUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── HELPERS ───

  Widget _buildEmptyState(IconData icon, String title, String desc, ProfileFontModel? fontModel, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              title,
              style: _heroTextStyle(fontModel, fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: _heroTextStyle(fontModel, fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaTag({
    required IconData icon,
    required String label,
    required bool isDark,
    ProfileFontModel? fontModel,
    bool isFestive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: isFestive
            ? (isDark ? const Color(0xFF381524) : const Color(0xFFFFEBF0))
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFestive
              ? const Color(0xFFFF2D55).withValues(alpha: 0.55)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.07)),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isFestive
                ? const Color(0xFFFF2D55)
                : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: _heroTextStyle(
              fontModel,
              fontSize: 12,
              fontWeight: isFestive ? FontWeight.w700 : FontWeight.w500,
              color: isFestive
                  ? (isDark ? const Color(0xFFFF6482) : const Color(0xFFD81B60))
                  : (isDark ? Colors.white70 : Colors.black87),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  bool _isBirthdayToday(UserModel? user) {
    if (user == null) return false;
    if (user.isBirthdayToday) return true;
    final dobStr = user.tanggalLahir;
    if (dobStr == null || dobStr.trim().isEmpty) return false;
    final dt = DateTime.tryParse(dobStr.trim());
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.month == now.month && dt.day == now.day;
  }

  String? _formatBirthdayTag(UserModel? user) {
    if (user == null) return null;
    if (user.isBirthdayPrivate) {
      return null; // Jika privasi, jangan tampilkan apapun!
    }
    final isToday = _isBirthdayToday(user);
    final hasDob = user.tanggalLahir != null && user.tanggalLahir!.trim().isNotEmpty;
    final hasAge = user.age != null;
    final hasZodiac = user.zodiac != null && user.zodiac!.trim().isNotEmpty;

    if (!hasDob && !hasAge && !hasZodiac) return null;

    if (user.isBirthdayAgeOnly) {
      if (isToday) {
        return '🎂 Ultah Hari Ini! (${hasAge ? '${user.age} thn' : ''})';
      }
      if (hasAge && hasZodiac) {
        return '${user.age} thn • ${user.zodiac}';
      } else if (hasAge) {
        return '${user.age} thn';
      } else if (hasZodiac) {
        return user.zodiac!;
      }
      return null;
    }

    String datePart = user.tanggalLahir?.trim() ?? '';
    if (datePart.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(datePart);
        if (dt != null) {
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agt',
            'Sep',
            'Okt',
            'Nov',
            'Des',
          ];
          datePart = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
        }
      } catch (_) {}
    }

    if (isToday) {
      final ageStr = hasAge ? ' ke-${user.age}' : '';
      return '🎂 Ultah Hari Ini$ageStr!';
    }
    final List<String> parts = [];
    if (datePart.isNotEmpty) parts.add(datePart);
    if (hasAge) parts.add('${user.age} thn');
    if (hasZodiac) parts.add(user.zodiac!);
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar || oldDelegate.backgroundColor != backgroundColor;
  }
}
