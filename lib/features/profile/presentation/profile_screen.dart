import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/admob_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../features/auth/presentation/welcome_screen.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/bookmarks/presentation/unified_bookmarks_screen.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import '../../anime/data/anime_repository.dart';
import '../../comic/data/comic_repository.dart';
import 'edit_profile_screen.dart';
import 'history_screen.dart';
import 'other_user_profile_screen.dart';
import 'friend_requests_screen.dart';
import 'comment_background_settings_screen.dart';
import '../../chat/presentation/chat_background_screen.dart';
import '../../community/presentation/forum_feed_screen.dart';
import '../../notifications/presentation/universal_notification_modal.dart';
import '../../notifications/services/universal_notification_service.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../avatar_decoration/data/avatar_decoration_repository.dart';
import '../../avatar_decoration/presentation/avatar_decoration_screen.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../data/models/profile_font_model.dart';
import '../../gamification/presentation/widgets/level_xp_card.dart';
import '../../gamification/presentation/leaderboard_screen.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/glass_container.dart';
import 'settings_screen.dart';
import '../../anime/data/models/genre_role_model.dart';
import '../../anime/presentation/widgets/genre_role_widgets.dart';
import '../../update/data/models/app_update_model.dart';
import '../../update/presentation/app_update_dialog.dart';
import '../../update/services/app_update_service.dart';
import '../../zpic/presentation/zpic_home_screen.dart';
import '../../jav/presentation/jav_home_screen.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../core/services/mal_service.dart';
import '../../mal/presentation/mal_integration_screen.dart';

/// Clean Modern Frosted Profile & Settings Screen matching AnimeHomeScreen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  final ValueNotifier<bool> _isScrolledPastHeader = ValueNotifier<bool>(false);

  // User stats
  int _watchCount = 0;
  int _comicReadCount = 0;
  int _bookmarkCount = 0;
  String _watchDuration = '';
  int _friendCount = 0;
  UserGenreSummary? _genreSummary;
  AppUpdateModel? _availableUpdate;
  int _nameTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _availableUpdate = AppUpdateService.instance.availableUpdate;
    AppUpdateService.instance.availableUpdateNotifier.addListener(_onUpdateChanged);
    AdultContentService.instance.addListener(_onAdultModeChanged);
    _loadProfile();
    _checkUpdateStatus();
  }

  void _onAdultModeChanged() {
    if (mounted) setState(() {});
  }

  void _onNameTapped() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _nameTapCount = 1;
    } else {
      _nameTapCount++;
    }
    _lastTapTime = now;

    if (_nameTapCount >= 5) {
      _nameTapCount = 0;
      HapticFeedback.heavyImpact();
      final current = AdultContentService.instance.is18Unlocked;
      final newStatus = !current;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      AdultContentService.instance.set18Unlocked(newStatus, userId: authProvider.user?.id);

      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
          elevation: 8,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(
                newStatus ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill,
                color: newStatus ? const Color(0xFFFF2D55) : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newStatus ? 'Mode 18+ Terbuka!' : 'Mode 18+ Terkunci',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      newStatus
                          ? 'Menu zPic sekarang tersedia di Profil.'
                          : 'Menu 18+ telah disembunyikan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      setState(() {});
    } else {
      HapticFeedback.selectionClick();
      if (_nameTapCount >= 3) {
        final remaining = 5 - _nameTapCount;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFF333333),
            duration: const Duration(milliseconds: 1000),
            content: Text(
              'Tekan $remaining kali lagi untuk membuka Mode 18+...',
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _onUpdateChanged() {
    if (mounted) {
      setState(() {
        _availableUpdate = AppUpdateService.instance.availableUpdate;
      });
    }
  }

  Future<void> _checkUpdateStatus() async {
    try {
      final config = await AppUpdateService.instance.fetchVersionConfig();
      if (config != null && mounted) {
        final hasUpdate = AppUpdateService.isUpdateAvailable(config);
        setState(() {
          _availableUpdate = hasUpdate ? config : null;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    AdultContentService.instance.removeListener(_onAdultModeChanged);
    AppUpdateService.instance.availableUpdateNotifier.removeListener(_onUpdateChanged);
    _isScrolledPastHeader.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      await auth.bootstrap();
    }
    if (!auth.isAuthenticated) return;
    try {
      final u = await ProfileRepository.instance.me();
      if (u.username.isNotEmpty) {
        UserModel merged = u;
        if (merged.avatarDecorationUrl == null || merged.avatarDecorationUrl!.isEmpty) {
          final localDec = await AvatarDecorationRepository.instance.getLocalActiveDecoration();
          if (localDec != null) {
            merged = merged.copyWith(
              avatarDecorationId: localDec.id,
              avatarDecorationUrl: localDec.imageUrl,
              avatarDecorationScale: localDec.scale,
              avatarDecorationOffsetX: localDec.offsetX,
              avatarDecorationOffsetY: localDec.offsetY,
            );
          }
        }
        auth.setUser(merged);

        // Fetch user stats for the stats bar
        _fetchUserStats(merged.username);

        // Fetch friend count
        try {
          final fl = await ProfileRepository.instance.getFriendsList();
          if (mounted) setState(() => _friendCount = fl.length);
        } catch (_) {}
      }
    } catch (_) {}
    _checkUpdateStatus();
  }

  static String _formatSecondsToHuman(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}j ${m}m';
    if (h > 0) return '${h}j';
    return '${m}m';
  }

  Future<void> _fetchUserStats(String username) async {
    int watchCount = 0;
    int comicReadCount = 0;
    int bookmarkCount = 0;
    String watchDuration = '';

    // 1. Anime stats from YLnime
    try {
      final ylnimeStatsData = await AnimeRepository.instance.ylnimeUserStats(username);
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

    // 2. Comic reading stats
    try {
      final cStats = await ComicRepository.instance.publicStats(username);
      final cd = (cStats.containsKey('data') && cStats['data'] is Map)
          ? cStats['data'] as Map
          : cStats;
      if (cd.isNotEmpty) {
        comicReadCount = (cd['total_history'] as num?)?.toInt() ??
            (cd['unique_comics_read'] as num?)?.toInt() ??
            0;
        final cBm = (cd['total_bookmarks'] as num?)?.toInt() ?? 0;
        bookmarkCount += cBm;
      }
    } catch (_) {}

    // 3. Fallbacks: Authenticated user raw stats & history
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

    if (watchCount == 0) {
      try {
        final history = await AnimeRepository.instance.watchHistory();
        watchCount = history.length;
      } catch (_) {}
    }
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

    // Genre roles summary
    UserGenreSummary? genreSummary;
    try {
      genreSummary = await AnimeRepository.instance.getGenreRoles();
      if (!genreSummary.hasRoles && genreSummary.roles.isEmpty) {
        final publicSummary = await AnimeRepository.instance.getUserGenreRoles(username);
        if (publicSummary.hasRoles || publicSummary.roles.isNotEmpty) {
          genreSummary = publicSummary;
        }
      }
    } catch (_) {
      try {
        genreSummary = await AnimeRepository.instance.getUserGenreRoles(username);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _watchCount = watchCount;
        _comicReadCount = comicReadCount;
        _bookmarkCount = bookmarkCount;
        _watchDuration = watchDuration;
        if (genreSummary != null) {
          _genreSummary = genreSummary;
        }
      });
    }
  }

  void _viewFullCover(BuildContext context, String coverUrl) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text(
              'Foto Sampul',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          body: Center(
            child: (coverUrl.toLowerCase().contains('.gif') || coverUrl.toLowerCase().contains('.webp'))
                ? CalmGif(
                    source: coverUrl,
                    fit: BoxFit.contain,
                    errorWidget: Image.network(
                      coverUrl,
                      fit: BoxFit.contain,
                      cacheWidth: 800,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                      ),
                    ),
                  )
                : PhotoView(
                    imageProvider: NetworkImage(coverUrl),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3.0,
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                    loadingBuilder: (_, __) => const Center(
                      child: CupertinoActivityIndicator(color: Colors.white),
                    ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _handleLogout() {
    HapticFeedback.selectionClick();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Keluar dari Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun MOKO?'),
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
              final auth = context.read<AuthProvider>();
              setState(() => _loading = true);
              await auth.logout();
              if (mounted) {
                setState(() => _loading = false);
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }


  void _showBirthdayVisibilitySheet(UserModel user) {
    final currentVis = user.birthdayVisibility ?? 'public';
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Privasi Tanggal Lahir'),
        message: const Text('Pilih siapa saja yang dapat melihat informasi tanggal lahir Anda di profil.'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: currentVis == 'public',
            onPressed: () async {
              Navigator.pop(ctx);
              if (currentVis != 'public') {
                await _updateBirthdayVisibility('public');
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentVis == 'public') ...[
                  const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  const SizedBox(width: 8),
                ],
                const Text('Publik (Tanggal, Umur, Zodiak)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: currentVis == 'age_only',
            onPressed: () async {
              Navigator.pop(ctx);
              if (currentVis != 'age_only') {
                await _updateBirthdayVisibility('age_only');
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentVis == 'age_only') ...[
                  const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  const SizedBox(width: 8),
                ],
                const Text('Hanya Umur & Zodiak'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: currentVis == 'private',
            onPressed: () async {
              Navigator.pop(ctx);
              if (currentVis != 'private') {
                await _updateBirthdayVisibility('private');
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentVis == 'private') ...[
                  const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  const SizedBox(width: 8),
                ],
                const Text('Pribadi (Disembunyikan)'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _updateBirthdayVisibility(String newVis) async {
    try {
      HapticFeedback.lightImpact();
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        auth.setUser(auth.user!.copyWith(birthdayVisibility: newVis));
      }
      await ProfileRepository.instance.setBirthdayVisibility(newVis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privasi tanggal lahir berhasil diperbarui'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kendala: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool onCover = false,
  }) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(right: 10),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onCover
                ? Colors.black.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08)),
            border: Border.all(
              color: onCover
                  ? Colors.white.withValues(alpha: 0.35)
                  : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: onCover
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverBadge(BuildContext context, String coverImage) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _viewFullCover(context, coverImage),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(CupertinoIcons.eye_fill, size: 11, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Sampul',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required bool isDark,
    required UserModel? user,
    required String coverImage,
    required bool isGif,
    required String avatarImage,
    required String displayName,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    const coverHeight = 180.0;

    return RepaintBoundary(
      child: SizedBox(
        height: coverHeight,
        child: Stack(
          children: [
            // 1. Full-bleed Cover Image
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _viewFullCover(context, coverImage),
                child: isGif
                    ? CalmGif(
                        source: coverImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        speed: 1.0,
                        minFrameDurationMs: 20,
                        placeholder: Container(
                          color: isDark ? const Color(0xFF141418) : const Color(0xFFE5E5EA),
                        ),
                        errorWidget: Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 800,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF141418) : const Color(0xFFE5E5EA),
                          ),
                        ),
                      )
                    : Image.network(
                        coverImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 800,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF141418) : const Color(0xFFE5E5EA),
                        ),
                      ),
              ),
            ),

            // 2. Smooth gradient fade on cover bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.5),
                        isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 3. "Sampul" badge bottom-right (placed above the overlapping Bento card)
            Positioned(
              bottom: 48,
              right: 14,
              child: _buildCoverBadge(context, coverImage),
            ),

            // 4. iOS Top Action Buttons (Back, Settings, Refresh)
            Positioned(
              top: topPadding + 6,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    _buildIosActionButton(
                      icon: CupertinoIcons.chevron_back,
                      onTap: () => Navigator.maybePop(context),
                      isDark: isDark,
                      onCover: true,
                    )
                  else
                    const Spacer(),
                  if (Navigator.canPop(context)) const Spacer(),
                  _buildIosActionButton(
                    icon: CupertinoIcons.gear_alt_fill,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    isDark: isDark,
                    onCover: true,
                  ),
                  _buildIosActionButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _loadProfile();
                    },
                    isDark: isDark,
                    onCover: true,
                  ),
                ],
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

    final coverImage = user?.coverUrl ??
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1200&auto=format&fit=crop&q=80';
    final avatarImage = user?.avatarUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&size=200&background=FF2D55&color=fff';
    final cleanCover = coverImage.split('?').first.toLowerCase();
    final isGif = user?.isCoverAnimated == true ||
        cleanCover.endsWith('.gif') ||
        coverImage.toLowerCase().contains('.gif') ||
        cleanCover.endsWith('.webp');

    final fontModel = user?.profileFontData ?? ProfileFontModel.fromKey(user?.profileFont);
    final effectiveFontSize = (user?.profileFontSize != null && user!.profileFontSize! > 0)
        ? user.profileFontSize!.toDouble()
        : 22.0;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxProfileWidth
                  : double.infinity,
            ),
            child: Stack(
              children: [
                RefreshIndicator(
                  color: isDark ? Colors.white : Colors.black,
                  edgeOffset: 120,
                  onRefresh: _loadProfile,
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (notification) {
                      final offset = notification.metrics.pixels;
                      final shouldShow = offset > 160;
                      if (shouldShow != _isScrolledPastHeader.value) {
                        _isScrolledPastHeader.value = shouldShow;
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
                      slivers: [
                        // Unified Profile Header (Full-bleed cover, iOS Large Title, Scallop Wave, and unclipped circular Avatar)
                        SliverToBoxAdapter(
                          child: user == null
                              ? Column(
                                  children: [
                                    _buildProfileHeader(
                                      context: context,
                                      isDark: isDark,
                                      user: null,
                                      coverImage: coverImage,
                                      isGif: isGif,
                                      avatarImage: 'https://ui-avatars.com/api/?name=MOKO&size=200&background=FF2D55&color=fff',
                                      displayName: 'Tamu',
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                                      child: _buildGuestCard(context, isDark),
                                    ),
                                  ],
                                )
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildProfileHeader(
                                      context: context,
                                      isDark: isDark,
                                      user: user,
                                      coverImage: coverImage,
                                      isGif: isGif,
                                      avatarImage: avatarImage,
                                      displayName: displayName,
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 145),
                                        _buildUserProfileBody(
                                          context,
                                          isDark,
                                          user,
                                          avatarImage,
                                          displayName,
                                          fontModel,
                                          effectiveFontSize,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

              // Banner Pemberitahuan Update Baru (Jika ada)
              if (_availableUpdate != null)
                SliverToBoxAdapter(
                  child: _buildUpdateAvailableBanner(isDark, _availableUpdate!),
                ),

              // Section 1: Koleksi & Aktivitas
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Modern Apple Bento Card for MyAnimeList Sync
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMalBentoCard(context, isDark),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('KOLEKSI & AKTIVITAS', isDark),
                      _buildGlassGroup(
                        isDark: isDark,
                        children: [
                          _buildGlassTile(
                            icon: CupertinoIcons.clock_fill,
                            title: 'Riwayat Tonton & Baca',
                            subtitle: 'Lanjutkan episode & chapter terakhir',
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                            ),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.bookmark_fill,
                            title: 'Bookmark Saya',
                            subtitle: 'Koleksi anime & komik tersimpan',
                            badge: _bookmarkCount > 0 ? '$_bookmarkCount' : null,
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const UnifiedBookmarksScreen()),
                            ),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.person_2_fill,
                            title: 'Teman & Permintaan',
                            subtitle: 'Daftar teman, permintaan masuk & terkirim',
                            badge: _friendCount > 0 ? '$_friendCount' : null,
                            isDark: isDark,
                            showChevron: true,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const FriendRequestsScreen()),
                            ).then((_) => _loadProfile()),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.square_list_fill,
                            title: 'Forum Diskusi',
                            subtitle: 'Ruang diskusi teori, fan art & rekomendasi',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const ForumFeedScreen()),
                            ),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.rosette,
                            title: 'Papan Peringkat (Leaderboard)',
                            subtitle: 'Peringkat petualang teratas & perolehan XP',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const LeaderboardScreen()),
                            ),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.bell_fill,
                            title: 'Pusat Notifikasi',
                            subtitle: 'Notifikasi like & balasan komentar',
                            isDark: isDark,
                            showChevron: true,
                            trailing: ValueListenableBuilder<int>(
                              valueListenable: UniversalNotificationService.instance.totalUnreadNotifier,
                              builder: (context, count, _) {
                                if (count <= 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onTap: () => UniversalNotificationModal.show(context),
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.sparkles,
                            title: 'Gelar & Role Genre',
                            subtitle: _genreSummary?.primaryRole != null
                                ? '${_genreSummary!.primaryRole!.emoji} ${_genreSummary!.primaryRole!.roleName}'
                                : 'Lihat progres & katalog gelar tontonan',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () {
                              if (_genreSummary?.primaryRole != null) {
                                showGenreRoleDetailModal(
                                  context,
                                  _genreSummary!.primaryRole!,
                                  allRoles: _genreSummary!.roles,
                                  isDark: isDark,
                                  onEquipChanged: _loadProfile,
                                );
                              } else {
                                showGenreRoleCatalogModal(context, isDark: isDark);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Section 2: Tampilan & Kustomisasi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('TAMPILAN & KUSTOMISASI', isDark),
                      _buildGlassGroup(
                        isDark: isDark,
                        children: [
                          _buildGlassTile(
                            icon: CupertinoIcons.chat_bubble_text_fill,
                            title: 'Background Komentar',
                            subtitle: 'Kustomisasi tema kartu, gambar & GIF',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () {
                              AdMobService.instance.showRewardedAd(
                                onRewardEarned: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => const CommentBackgroundSettingsScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.sparkles,
                            title: 'Background Forum Khusus',
                            subtitle: 'Kustomisasi wallpaper & suasana thread forum',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () {
                              AdMobService.instance.showRewardedAd(
                                onRewardEarned: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => const ChatBackgroundScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Section: Konten Khusus (Jika Mode 18+ Terbuka)
              if (AdultContentService.instance.is18Unlocked)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('KONTEN KHUSUS (18+)', isDark),
                        _buildGlassGroup(
                          isDark: isDark,
                          children: [
                            _buildGlassTile(
                              icon: CupertinoIcons.shield_fill,
                              iconColor: const Color(0xFFFF2D55),
                              title: 'Mode 18+',
                              subtitle: 'Sentuh saklar untuk mengunci kembali',
                              isDark: isDark,
                              trailing: CupertinoSwitch(
                                value: true,
                                activeTrackColor: const Color(0xFFFF2D55),
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  AdultContentService.instance.set18Unlocked(
                                    val,
                                    userId: user?.id,
                                  );
                                  setState(() {});
                                },
                              ),
                            ),
                            _buildGlassTile(
                              icon: CupertinoIcons.film_fill,
                              iconColor: const Color(0xFFFF2D55),
                              title: 'Javtiful (JAV)',
                              subtitle: 'Streaming Film & Video JAV HD',
                              isDark: isDark,
                              showChevron: true,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const JavHomeScreen()),
                                );
                              },
                            ),
                            _buildGlassTile(
                              icon: CupertinoIcons.play_circle_fill,
                              title: 'zPic',
                              subtitle: 'Streaming klip & video dewasa',
                              isDark: isDark,
                              showChevron: true,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const ZpicHomeScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Section 3: Aplikasi & Akun
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('PENGATURAN & AKUN', isDark),
                      _buildGlassGroup(
                        isDark: isDark,
                        children: [
                          _buildGlassTile(
                            icon: CupertinoIcons.arrow_down_circle_fill,
                            title: 'Pembaruan & Info Versi',
                            subtitle: _availableUpdate != null
                                ? 'Versi baru ${_availableUpdate!.version} tersedia • Ketuk untuk unduh'
                                : 'Moko ${AppUpdateService.currentVersion} • Versi terbaru terpasang',
                            badge: _availableUpdate != null ? 'Update Baru' : AppUpdateService.currentVersion,
                            isDark: isDark,
                            showChevron: true,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              AppUpdateService.instance.checkAndShowUpdate(context, isManual: true);
                            },
                          ),
                          _buildGlassTile(
                            icon: CupertinoIcons.gear_alt_fill,
                            title: 'Pengaturan Sistem',
                            subtitle: 'Tema, font, pembaruan, cache & lainnya',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                          if (user != null)
                            _buildGlassTile(
                              icon: CupertinoIcons.square_arrow_right,
                              iconColor: const Color(0xFFFF3B30),
                              title: 'Keluar dari Akun',
                              titleColor: const Color(0xFFFF3B30),
                              isDark: isDark,
                              showChevron: false,
                              onTap: _loading ? null : _handleLogout,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Clean Single Ad Placement at the bottom
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 24, bottom: 6),
                  child: AdBannerWidget(),
                ),
              ),

              // Bottom clearance for floating navbar
              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.bottomNavPadding(context) + 40),
              ),
            ],
          ),
        ),
      ),

      // Floating Pinned iOS Navigation Bar (fades in smoothly without rebuilding the screen or running blur passes)
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isScrolledPastHeader,
          builder: (context, isScrolled, _) {
            return AnimatedOpacity(
              opacity: isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !isScrolled,
                child: Container(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 8,
                    right: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xF2000000)
                        : const Color(0xF2FFFFFF),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        _buildIosActionButton(
                          icon: CupertinoIcons.chevron_back,
                          onTap: () => Navigator.maybePop(context),
                          isDark: isDark,
                          onCover: false,
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Profil',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: isDark
                                ? AppColors.iosTextPrimaryDark
                                : AppColors.iosTextPrimaryLight,
                          ),
                        ),
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.gear_alt_fill,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        isDark: isDark,
                        onCover: false,
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.arrow_clockwise,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _loadProfile();
                        },
                        isDark: isDark,
                        onCover: false,
                      ),
                    ],
                  ),
                ),
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
);
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

  // Guest Frosted Glass Welcome Card
  Widget _buildGuestCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        blur: 10,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 0.6,
        ),
        child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242428) : const Color(0xFFF2F2F7),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(9),
            child: Image.asset(
              'assets/icons/moko.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.person_crop_circle,
                size: 28,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onNameTapped,
            child: Text(
              'MOKO Anime & Komik',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Masuk dengan Google untuk sinkronisasi bookmark, riwayat tontonan, dan ikut mengobrol.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 2,
                shadowColor: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.20),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Masuk dengan Google',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  bool _isBirthdayToday(UserModel user) {
    if (user.isBirthdayToday) return true;
    if (user.tanggalLahir != null && user.tanggalLahir!.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(user.tanggalLahir!.trim());
      if (parsed != null) {
        final now = DateTime.now();
        return now.month == parsed.month && now.day == parsed.day;
      }
    }
    return false;
  }

  String? _formatBirthdayTag(UserModel user) {
    if (user.isBirthdayPrivate) {
      return null; // Jangan tampilkan apa pun jika privat!
    }

    final isToday = _isBirthdayToday(user);
    final hasDob = user.tanggalLahir != null && user.tanggalLahir!.trim().isNotEmpty;
    final hasAge = user.age != null;
    final hasZodiac = user.zodiac != null && user.zodiac!.trim().isNotEmpty;

    if (!hasDob && !hasAge && !hasZodiac) return null;

    if (user.isBirthdayAgeOnly) {
      // Hanya tampilkan umur & zodiak (tanggal lahir disembunyikan!)
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

    // Public / default: tampilkan tanggal lahir lengkap
    if (isToday) {
      return '🎂 Ultah Hari Ini! (${hasAge ? '${user.age} thn' : ''})';
    }

    final parts = <String>[];
    if (hasDob) parts.add(user.tanggalLahir!.trim());
    if (hasAge) parts.add('(${user.age} thn)');
    if (hasZodiac) parts.add('• ${user.zodiac}');
    return parts.join(' ');
  }

  Widget _buildFestiveBirthdayBanner({
    required String name,
    required int? age,
    required bool isDark,
    ProfileFontModel? fontModel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF2D55),
            Color(0xFFFF375F),
            Color(0xFFFF9500),
            Color(0xFFFFCC00),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2D55).withValues(alpha: 0.40),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFFF9500).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🎉', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('🎂', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Text('✨', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Selamat Ulang Tahun, $name! 🎈',
            textAlign: TextAlign.center,
            style: _heroTextStyle(
              fontModel,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            age != null
                ? 'Selamat menginjak usia $age tahun! Semoga panjang umur, sehat selalu, dan penuh kebahagiaan! 🎁🥳'
                : 'Hari ini adalah hari spesialmu! Semoga harimu menyenangkan dan penuh kebahagiaan! 🎁🥳',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // Bento Glass Card Profile Body
  Widget _buildUserProfileBody(
    BuildContext context,
    bool isDark,
    UserModel user,
    String avatarImage,
    String displayName,
    ProfileFontModel? fontModel,
    double effectiveFontSize,
  ) {
    final bdayTagText = _formatBirthdayTag(user);
    final hasLocation = user.location != null && user.location!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Hero Bento Profile Card (Overlaps Cover naturally) ───────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(24),
            blur: 0,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Row: Avatar + Name & Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            DecoratedAvatar(
                              radius: 38,
                              avatarUrl: avatarImage,
                              decorationUrl: user.fullAvatarDecorationUrl,
                              decorationCode: user.avatarDecorationCode,
                              decorationScale: user.avatarDecorationScale ?? 1.0,
                              offsetX: user.avatarDecorationOffsetX ?? 0,
                              offsetY: user.avatarDecorationOffsetY ?? 0,
                              fallbackName: displayName,
                              borderWidth: (user.fullAvatarDecorationUrl != null || (user.avatarDecorationCode != null && user.avatarDecorationCode!.isNotEmpty)) ? 0.0 : 2.5,
                              borderColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AdMobService.instance.showRewardedAd(
                                  onRewardEarned: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(builder: (_) => const AvatarDecorationScreen()),
                                    ).then((_) => _loadProfile());
                                  },
                                );
                              },
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(builder: (_) => EditProfileScreen(user: user)),
                                  ).then((_) => _loadProfile());
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF18181C) : Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    CupertinoIcons.camera_fill,
                                    color: isDark ? Colors.black : Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // User Details: Name, Badges, Username
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Display Name + Verified/Admin
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onNameTapped,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: _heroTextStyle(
                                        fontModel,
                                        fontSize: (effectiveFontSize > 19) ? 19 : effectiveFontSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user.verifiedBadge) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      CupertinoIcons.checkmark_seal_fill,
                                      size: 16,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ],
                                  if (user.isAdmin) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: isDark ? Colors.white24 : Colors.black12,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(CupertinoIcons.shield_lefthalf_fill, size: 8, color: isDark ? Colors.white : Colors.black),
                                          const SizedBox(width: 2),
                                          Text(
                                            'ADMIN',
                                            style: _heroTextStyle(fontModel, fontSize: 8.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, letterSpacing: 0.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 5),

                            // Metadata row: @username & chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Clipboard.setData(ClipboardData(text: user.username));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('@${user.username} disalin!'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.at, size: 10, color: isDark ? Colors.white60 : Colors.black45),
                                        const SizedBox(width: 2),
                                        Text(user.username, style: _heroTextStyle(fontModel, fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                                        const SizedBox(width: 3),
                                        Icon(CupertinoIcons.doc_on_doc, size: 9, color: isDark ? Colors.white38 : Colors.black38),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_genreSummary != null && (_genreSummary!.primaryRole != null || _genreSummary!.roles.isNotEmpty))
                                  GenreRoleBadge(
                                    role: _genreSummary!.primaryRole ?? _genreSummary!.roles.first,
                                    compact: true,
                                    onTap: () => showGenreRoleDetailModal(
                                      context,
                                      _genreSummary!.primaryRole ?? _genreSummary!.roles.first,
                                      allRoles: _genreSummary!.roles,
                                      isDark: isDark,
                                      onEquipChanged: _loadProfile,
                                    ),
                                  ),

                                if (hasLocation)
                                  _buildMetaTag(icon: CupertinoIcons.location_solid, label: user.location!, isDark: isDark, fontModel: fontModel),

                                if (bdayTagText != null)
                                  GestureDetector(
                                    onTap: () { HapticFeedback.selectionClick(); _showBirthdayVisibilitySheet(user); },
                                    child: _buildMetaTag(
                                      icon: _isBirthdayToday(user) ? CupertinoIcons.gift_fill : CupertinoIcons.gift,
                                      label: bdayTagText,
                                      isDark: isDark,
                                      fontModel: fontModel,
                                      isFestive: _isBirthdayToday(user),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Birthday banner if today
                  if (_isBirthdayToday(user) && !user.isBirthdayPrivate) ...[
                    const SizedBox(height: 12),
                    _buildFestiveBirthdayBanner(name: displayName, age: user.isBirthdayPrivate ? null : user.age, isDark: isDark, fontModel: fontModel),
                  ],

                  // User Bio
                  if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        user.bio!,
                        style: _heroTextStyle(
                          fontModel,
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                          height: 1.35,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action Buttons row inside Hero Card
                  Row(
                    children: [
                      // Primary: Edit Profil
                      Expanded(
                        flex: 5,
                        child: BouncyTap(
                          scaleDown: 0.96,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(context, CupertinoPageRoute(builder: (_) => EditProfileScreen(user: user))).then((_) => _loadProfile());
                          },
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(19),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.pencil, size: 14, color: isDark ? Colors.black : Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  'Edit Profil',
                                  style: _heroTextStyle(fontModel, fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.black : Colors.white, letterSpacing: -0.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Secondary: Public
                      Expanded(
                        flex: 4,
                        child: _buildActionButton(
                          icon: CupertinoIcons.globe,
                          label: 'Public',
                          isDark: isDark,
                          fontModel: fontModel,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(context, CupertinoPageRoute(builder: (_) => OtherUserProfileScreen(username: user.username, initialUser: user))).then((_) => _loadProfile());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Secondary: Bingkai
                      Expanded(
                        flex: 4,
                        child: _buildActionButton(
                          icon: CupertinoIcons.sparkles,
                          label: 'Bingkai',
                          isDark: isDark,
                          fontModel: fontModel,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            AdMobService.instance.showRewardedAd(
                              onRewardEarned: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const AvatarDecorationScreen())),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // ── 2. Bento Statistics Grid ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              // Row 1: Anime & Komik (2 prominent cards)
              Row(
                children: [
                  Expanded(
                    child: _buildBentoStatCard(
                      icon: CupertinoIcons.play_circle_fill,
                      accentColor: const Color(0xFFFF2D55),
                      value: '$_watchCount',
                      label: 'Anime Ditonton',
                      subtitle: 'Riwayat tontonan',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const HistoryScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildBentoStatCard(
                      icon: CupertinoIcons.book_fill,
                      accentColor: const Color(0xFF007AFF),
                      value: '$_comicReadCount',
                      label: 'Komik Dibaca',
                      subtitle: 'Chapter terakhir',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const HistoryScreen()));
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: Bookmark, Teman, Durasi (3 compact cards)
              Row(
                children: [
                  Expanded(
                    child: _buildBentoCompactStatCard(
                      icon: CupertinoIcons.bookmark_fill,
                      accentColor: const Color(0xFFFF9500),
                      value: '$_bookmarkCount',
                      label: 'Bookmark',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const UnifiedBookmarksScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBentoCompactStatCard(
                      icon: CupertinoIcons.person_2_fill,
                      accentColor: const Color(0xFF34C759),
                      value: '$_friendCount',
                      label: 'Teman',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const FriendRequestsScreen())).then((_) => _loadProfile());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBentoCompactStatCard(
                      icon: CupertinoIcons.bolt_fill,
                      accentColor: const Color(0xFFAF52DE),
                      value: _watchDuration.isNotEmpty ? _formatCompactDuration(_watchDuration) : (user.role?.toUpperCase() ?? 'AKTIF'),
                      label: _watchDuration.isNotEmpty ? 'Durasi' : 'Status',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showUserProfileCard(context, user: user);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 3. Bento Level & XP Gamification Card ─────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: LevelXpCard(user: user, onXpUpdated: _loadProfile),
        ),
      ],
    );
  }

  // Bento Main Stat Card (Row 1) - iOS HIG Inset Card
  Widget _buildBentoStatCard({
    required IconData icon,
    required Color accentColor,
    required String value,
    required String label,
    required String subtitle,
    required bool isDark,
    ProfileFontModel? fontModel,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      scaleDown: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, size: 17, color: accentColor),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 13,
                  color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF3C3C43),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white38 : const Color(0xFF8E8E93),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bento Compact Stat Card (Row 2) - iOS HIG Inset Card
  Widget _buildBentoCompactStatCard({
    required IconData icon,
    required Color accentColor,
    required String value,
    required String label,
    required bool isDark,
    ProfileFontModel? fontModel,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      scaleDown: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.5),
              ),
              child: Center(
                child: Icon(icon, size: 14, color: accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactDuration(String raw) {
    if (raw.isEmpty) return '0j';
    if (raw.contains(':')) {
      final parts = raw.split(':');
      final hours = parts.isNotEmpty ? parts[0] : '0';
      return '${hours}j';
    }
    return raw;
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
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    ProfileFontModel? fontModel,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      scaleDown: 0.95,
      onTap: onTap,
      child: GlassContainer(
        height: 38,
        borderRadius: BorderRadius.circular(19),
        blur: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: _heroTextStyle(
                fontModel,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMalBentoCard(BuildContext context, bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: MalService.instance.isConnectedNotifier,
      builder: (context, isConnected, _) {
        final username = MalService.instance.username;
        return BouncyTap(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const MalIntegrationScreen()),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16233B), const Color(0xFF141418)]
                    : [const Color(0xFFEAF1FB), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.35 : 0.20),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // MAL Logo Badge with Glow
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E51A2),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E51A2).withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'MAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Sync Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'MyAnimeList Sync',
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? const Color(0xFF34C759).withValues(alpha: 0.18)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isConnected ? 'AKTIF' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isConnected
                                    ? const Color(0xFF34C759)
                                    : (isDark ? Colors.white54 : Colors.black45),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isConnected
                            ? '@${username ?? "user"}'
                            : 'Hubungkan akun untuk auto-sync saat nonton & baca',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Modern iOS Chevron Button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 15,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 16, 7),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildGlassGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
    final List<Widget> items = [];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 58,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        blur: 10,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.6,
        ),
        child: Column(
          children: items,
        ),
      ),
    );
  }

  Widget _buildGlassTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    String? badge,
    Color? titleColor,
    required bool isDark,
    Widget? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return BouncyTap(
      scaleDown: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (iconColor != null)
                    ? iconColor.withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.07)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color: iconColor ?? (isDark ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: titleColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (trailing != null)
              trailing
            else if (showChevron)
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: isDark ? Colors.white38 : const Color(0xFFC7C7CC),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateAvailableBanner(bool isDark, AppUpdateModel update) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: BouncyTap(
        scaleDown: 0.97,
        onTap: () {
          AppUpdateDialog.show(
            context,
            update: update,
            isManual: true,
          );
        },
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          blur: 10,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            width: 0.6,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.arrow_down_circle_fill,
                  size: 26,
                  color: isDark ? Colors.white : Colors.black,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'UPDATE TERSEDIA',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          update.version,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pembaruan baru tersedia! Ketuk untuk melihat catatan rilis & unduh langsung di aplikasi.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Unduh',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}