import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/providers/theme_provider.dart';
import '../data/profile_repository.dart';
import '../../anime/data/anime_repository.dart';
import '../../comic/data/comic_repository.dart';
import 'edit_profile_screen.dart';
import 'history_screen.dart';
import 'other_user_profile_screen.dart';
import 'friend_requests_screen.dart';
import 'comment_background_settings_screen.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/chat_background_screen.dart';
import '../../notifications/presentation/universal_notification_modal.dart';
import '../../notifications/services/universal_notification_service.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../avatar_decoration/data/avatar_decoration_repository.dart';
import '../../avatar_decoration/presentation/avatar_decoration_screen.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../data/models/profile_font_model.dart';
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
import '../../../core/services/adult_content_service.dart';

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
    const coverHeight = 210.0;
    const avatarRadius = 46.0;
    const collarThickness = 3.5;
    const avatarCenterY = 195.0;
    const baselineY = 220.0;
    const headerHeight = 265.0;

    return RepaintBoundary(
      child: SizedBox(
        height: headerHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Full-bleed Cover Image
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
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
                          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                        ),
                        errorWidget: Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 800,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
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
                          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                        ),
                      ),
              ),
            ),

          // 2. Gradient Overlay on Cover (IgnorePointer so touches pass through)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.60),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Scalloped Wave Transition (IgnorePointer so wave never blocks touches!)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: IgnorePointer(
              child: CustomPaint(
                painter: ProfileScallopWavePainter(
                  color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF2F2F7),
                  avatarCenterY: avatarCenterY,
                  avatarRadius: avatarRadius,
                  collarThickness: collarThickness,
                  baselineY: baselineY,
                ),
              ),
            ),
          ),

          // 4. Apple iOS Large Title "Profil" on Cover (IgnorePointer so text doesn't block touches)
          Positioned(
            top: topPadding + 46,
            left: 16,
            child: const IgnorePointer(
              child: Text(
                'Profil',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 10,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Circular Avatar (100% UNCLIPPED, 0 negative coordinates, completely within bounds!)
          Positioned(
            top: avatarCenterY - avatarRadius,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedAvatar(
                    radius: avatarRadius,
                    avatarUrl: avatarImage,
                    decorationUrl: user?.fullAvatarDecorationUrl,
                    decorationCode: user?.avatarDecorationCode,
                    decorationScale: user?.avatarDecorationScale ?? 1.0,
                    offsetX: user?.avatarDecorationOffsetX ?? 0,
                    offsetY: user?.avatarDecorationOffsetY ?? 0,
                    fallbackName: displayName,
                    borderWidth: (user?.fullAvatarDecorationUrl != null || (user?.avatarDecorationCode != null && user!.avatarDecorationCode!.isNotEmpty)) ? 0.0 : 3.5,
                    borderColor: isDark ? const Color(0xFF38383A) : const Color(0xFF1D3557),
                    onTap: () {
                      if (user == null) return;
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
                  if (user != null)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => EditProfileScreen(user: user)),
                          ).then((_) => _loadProfile());
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.camera_fill,
                            color: isDark ? Colors.black : Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 6. "Sampul" badge on Cover (Interactive layer)
          Positioned(
            top: 154,
            right: 14,
            child: _buildCoverBadge(context, coverImage),
          ),

          // 7. Action Buttons on Cover (Back, Edit Profile, Refresh) (VERY TOP LAYER)
          Positioned(
            top: topPadding + 8,
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
    final themeContext = context.watch<ThemeProvider>();
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
                              : Column(
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
                            icon: CupertinoIcons.chat_bubble_2_fill,
                            title: 'Chat Komunitas',
                            subtitle: 'Obrolan langsung bersama sesama wibu',
                            isDark: isDark,
                            showChevron: true,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const ChatScreen()),
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
                            icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                            title: 'Mode Gelap',
                            subtitle: isDark ? 'Aktif (OLED Deep Black)' : 'Mati (Light Theme)',
                            isDark: isDark,
                            trailing: CupertinoSwitch(
                              value: isDark,
                              activeTrackColor: isDark ? Colors.white : Colors.black87,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                themeContext.toggle();
                              },
                            ),
                          ),
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
                            title: 'Background Chat Khusus',
                            subtitle: 'Kustomisasi bubble chat, gambar & GIF',
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
                child: SizedBox(height: Responsive.bottomNavPadding(context)),
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
                        ? AppColors.iosBackgroundDark.withValues(alpha: 0.95)
                        : AppColors.iosBackgroundLight.withValues(alpha: 0.95),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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

  // Open User Profile Body (Directly on screen background, no restrictive card container!)
  Widget _buildUserProfileBody(
    BuildContext context,
    bool isDark,
    UserModel user,
    String avatarImage,
    String displayName,
    ProfileFontModel? fontModel,
    double effectiveFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),

              // Display Name & Badges (Verified, Admin, Genre Role)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onNameTapped,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: _heroTextStyle(
                          fontModel,
                          fontSize: effectiveFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.verifiedBadge) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                    ],
                    if (user.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.shield_lefthalf_fill,
                              size: 9,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'ADMIN',
                              style: _heroTextStyle(
                                fontModel,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_genreSummary != null && (_genreSummary!.primaryRole != null || _genreSummary!.roles.isNotEmpty)) ...[
                      const SizedBox(width: 6),
                      GenreRoleBadge(
                        role: _genreSummary!.primaryRole ?? _genreSummary!.roles.first,
                        compact: true,
                        onTap: () {
                          showGenreRoleDetailModal(
                            context,
                            _genreSummary!.primaryRole ?? _genreSummary!.roles.first,
                            allRoles: _genreSummary!.roles,
                            isDark: isDark,
                            onEquipChanged: _loadProfile,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // Minimalist Monochrome Username Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.at, size: 12, color: isDark ? Colors.white60 : Colors.black45),
                    const SizedBox(width: 3),
                    Text(
                      user.username,
                      style: _heroTextStyle(
                        fontModel,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: user.username));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Username @${user.username} disalin!'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Icon(
                        CupertinoIcons.doc_on_doc,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              // Festive Birthday Celebration Banner
              if (_isBirthdayToday(user) && !user.isBirthdayPrivate) ...[
                const SizedBox(height: 12),
                _buildFestiveBirthdayBanner(
                  name: displayName,
                  age: user.isBirthdayPrivate ? null : user.age,
                  isDark: isDark,
                  fontModel: fontModel,
                ),
              ],

              // Bio Quote Container
              if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    user.bio!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _heroTextStyle(
                      fontModel,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                      height: 1.35,
                    ),
                  ),
                ),
              ],

              // Location & Birthday tags (Respects Birthday Privacy)
              () {
                final bdayTagText = _formatBirthdayTag(user);
                final hasLocation = user.location != null && user.location!.isNotEmpty;
                if (!hasLocation && bdayTagText == null) {
                  return const SizedBox.shrink();
                }
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
                          label: user.location!,
                          isDark: isDark,
                          fontModel: fontModel,
                        ),
                      if (bdayTagText != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showBirthdayVisibilitySheet(user);
                          },
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
                );
              }(),

              const SizedBox(height: 14),

              // Quick Action Buttons (Edit Profil, Kartu Publik, Bingkai) - Welcome Pill Style
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: CupertinoIcons.pencil,
                      label: 'Edit Profil',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => EditProfileScreen(user: user)),
                        ).then((_) => _loadProfile());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: CupertinoIcons.person_crop_circle_fill,
                      label: 'Profil Medsos',
                      isDark: isDark,
                      isPrimary: true,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => OtherUserProfileScreen(
                              username: user.username,
                              initialUser: user,
                            ),
                          ),
                        ).then((_) => _loadProfile());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: CupertinoIcons.sparkles,
                      label: 'Bingkai',
                      isDark: isDark,
                      fontModel: fontModel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        AdMobService.instance.showRewardedAd(
                          onRewardEarned: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const AvatarDecorationScreen()),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Integrated Clean Stats Bar (Natural Flow, no card wrapper!)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Tontonan Anime
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                          );
                        },
                        child: _buildStatColumn(
                          icon: CupertinoIcons.play_circle_fill,
                          iconColor: isDark ? Colors.white70 : Colors.black54,
                          value: '$_watchCount',
                          label: 'Anime',
                          isDark: isDark,
                          fontModel: fontModel,
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 0.5,
                      height: 28,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

                    // Bacaan Komik
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                          );
                        },
                        child: _buildStatColumn(
                          icon: CupertinoIcons.book_fill,
                          iconColor: isDark ? Colors.white70 : Colors.black54,
                          value: '$_comicReadCount',
                          label: 'Komik',
                          isDark: isDark,
                          fontModel: fontModel,
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 0.5,
                      height: 28,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

                    // Bookmarks
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const UnifiedBookmarksScreen()),
                          );
                        },
                        child: _buildStatColumn(
                          icon: CupertinoIcons.bookmark_fill,
                          iconColor: isDark ? Colors.white70 : Colors.black54,
                          value: '$_bookmarkCount',
                          label: 'Bookmark',
                          isDark: isDark,
                          fontModel: fontModel,
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 0.5,
                      height: 28,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

                    // Teman
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const FriendRequestsScreen()),
                          ).then((_) => _loadProfile());
                        },
                        child: _buildStatColumn(
                          icon: CupertinoIcons.person_2_fill,
                          iconColor: isDark ? Colors.white70 : Colors.black54,
                          value: '$_friendCount',
                          label: 'Teman',
                          isDark: isDark,
                          fontModel: fontModel,
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 0.5,
                      height: 28,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

                    // Durasi / Status
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          showUserProfileCard(context, user: user);
                        },
                        child: _buildStatColumn(
                          icon: CupertinoIcons.bolt_fill,
                          iconColor: isDark ? Colors.white70 : Colors.black54,
                          value: _watchDuration.isNotEmpty
                              ? _watchDuration
                              : (user.role?.toUpperCase() ?? 'AKTIF'),
                          label: _watchDuration.isNotEmpty ? 'Durasi' : 'Status',
                          isDark: isDark,
                          fontModel: fontModel,
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
    bool isPrimary = false,
    ProfileFontModel? fontModel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDark ? Colors.white : Colors.black)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? (isDark ? Colors.white : Colors.black)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.10)),
            width: 0.8,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isPrimary
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: _heroTextStyle(
                fontModel,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isPrimary
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
    ProfileFontModel? fontModel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _heroTextStyle(
                  fontModel,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
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
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
            letterSpacing: 0.1,
          ),
        ),
      ],
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
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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

/// Elegantly paints the smooth curved scallop transition between cover and page body.
/// Matches the reference design with an arch that curves upwards and cradles the avatar.
class ProfileScallopWavePainter extends CustomPainter {
  final Color color;
  final double avatarCenterX;
  final double avatarCenterY;
  final double avatarRadius;
  final double collarThickness;
  final double baselineY;

  const ProfileScallopWavePainter({
    required this.color,
    this.avatarCenterX = 0.0,
    required this.avatarCenterY,
    required this.avatarRadius,
    this.collarThickness = 8.0,
    required this.baselineY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = avatarCenterX > 0 ? avatarCenterX : size.width / 2;
    final cy = avatarCenterY;
    final collarR = avatarRadius + collarThickness;
    final by = baselineY;

    // Contact angle on collar: 35 degrees above horizontal
    const angleRad = 35.0 * (math.pi / 180.0);
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);

    final leftX = cx - collarR * cosA;
    final leftY = cy - collarR * sinA;
    final rightX = cx + collarR * cosA;
    final rightY = leftY;

    final path = Path();
    path.moveTo(0, by);

    // Left cubic bezier curve sweeping up to collar contact point
    path.cubicTo(
      cx * 0.40, by,
      cx * 0.75, leftY + 10,
      leftX, leftY,
    );

    // Circular arc sweeping OVER the top of the avatar collar
    path.arcToPoint(
      Offset(rightX, rightY),
      radius: Radius.circular(collarR),
      clockwise: true,
    );

    // Right cubic bezier curve sweeping down to right baseline
    path.cubicTo(
      size.width - cx * 0.75, rightY + 10,
      size.width - cx * 0.40, by,
      size.width, by,
    );

    // Fill to the bottom of the container
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ProfileScallopWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.avatarCenterX != avatarCenterX ||
        oldDelegate.avatarCenterY != avatarCenterY ||
        oldDelegate.avatarRadius != avatarRadius ||
        oldDelegate.collarThickness != collarThickness ||
        oldDelegate.baselineY != baselineY;
  }
}