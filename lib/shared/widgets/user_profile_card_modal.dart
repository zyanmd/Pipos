import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../features/anime/data/anime_repository.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/avatar_decoration/presentation/avatar_decoration_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/comic/data/comic_repository.dart';
import '../../features/profile/data/models/profile_font_model.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_font_picker_modal.dart';
import '../../core/services/user_decor_resolver.dart';
import '../providers/auth_provider.dart';
import 'decorated_avatar.dart';
import 'calm_gif.dart';
import '../../features/anime/data/models/genre_role_model.dart';
import '../../features/anime/presentation/widgets/genre_role_widgets.dart';
import '../../features/profile/presentation/other_user_profile_screen.dart';

/// Navigates to the full OtherUserProfileScreen instead of modal bottom sheet.
Future<void> showUserProfileCard(
  BuildContext context, {
  String? username,
  UserModel? user,
}) {
  HapticFeedback.selectionClick();
  final targetUsername = username ?? user?.username ?? '';
  if (targetUsername.isEmpty) return Future.value();

  return Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) => OtherUserProfileScreen(
        username: targetUsername,
        initialUser: user,
      ),
    ),
  );
}

/// Fallback / Alternative bottom sheet version
Future<void> showUserProfileCardModal(
  BuildContext context, {
  String? username,
  UserModel? user,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _UserProfileCardSheet(
      initialUsername: username,
      initialUser: user,
    ),
  );
}

class _UserProfileCardSheet extends StatefulWidget {
  final String? initialUsername;
  final UserModel? initialUser;

  const _UserProfileCardSheet({
    this.initialUsername,
    this.initialUser,
  });

  @override
  State<_UserProfileCardSheet> createState() => _UserProfileCardSheetState();
}

class _UserProfileCardSheetState extends State<_UserProfileCardSheet> {
  UserModel? _user;
  int _watchCount = 0;
  int _bookmarkCount = 0;
  String _watchDuration = '';
  int _comicHistoryCount = 0;
  int _comicBookmarkCount = 0;
  int _comicUniqueRead = 0;
  UserGenreSummary? _genreSummary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    final initialUsername = widget.initialUsername ?? widget.initialUser?.username;
    if (_user == null && initialUsername != null && initialUsername.trim().isNotEmpty) {
      final cached = UserDecorResolver.instance.get(initialUsername);
      if (cached != null) {
        _user = UserModel(
          id: 0,
          username: cached.username,
          email: '',
          avatarUrl: cached.avatarUrl,
          avatarDecorationUrl: cached.decorationUrl,
          avatarDecorationCode: cached.decorationCode,
          avatarDecorationScale: cached.decorationScale,
          avatarDecorationOffsetX: cached.decorationOffsetX,
          avatarDecorationOffsetY: cached.decorationOffsetY,
          profileFontData: cached.profileFontData,
          verifiedBadge: cached.verifiedBadge,
        );
      }
    }
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final currentAuthUser = context.read<AuthProvider>().user;
    final targetUsername = widget.initialUsername ?? widget.initialUser?.username ?? currentAuthUser?.username ?? '';

    if (targetUsername.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Pengguna tidak ditemukan';
        });
      }
      return;
    }

    final isMe = currentAuthUser != null &&
        (currentAuthUser.username.toLowerCase() == targetUsername.toLowerCase() ||
         currentAuthUser.id == widget.initialUser?.id);

    try {
      UserModel fetchedUser;
      Map<String, dynamic> stats = {};
      int watchCount = 0;
      int bookmarkCount = 0;
      String watchDuration = '';
      int comicHistoryCount = 0;
      int comicBookmarkCount = 0;
      int comicUniqueRead = 0;

      // 1. Fetch public YLnime user stats (/ylnime/user/<username>/stats)
      try {
        final ylnimeStatsData = await AnimeRepository.instance.ylnimeUserStats(targetUsername);
        final s = (ylnimeStatsData['stats'] is Map)
            ? ylnimeStatsData['stats'] as Map
            : ylnimeStatsData;

        if (s.isNotEmpty) {
          bookmarkCount = (s['total_bookmarks'] as num?)?.toInt() ?? 0;
          watchCount = (s['total_history'] as num?)?.toInt() ??
              (s['total_unique_anime'] as num?)?.toInt() ??
              0;
          final dur = s['total_watch_duration_formatted'];
          if (dur != null && dur.toString().isNotEmpty && dur.toString() != '0s') {
            watchDuration = dur.toString();
          }
        }
      } catch (_) {}

      // 2. Fetch public Komik reading stats (/comic/public/stats/<username>)
      try {
        final comicData = await ComicRepository.instance.publicStats(targetUsername);
        final cd = (comicData.containsKey('data') && comicData['data'] is Map)
            ? comicData['data'] as Map
            : comicData;
        if (cd.isNotEmpty) {
          comicHistoryCount = (cd['total_history'] as num?)?.toInt() ?? 0;
          comicBookmarkCount = (cd['total_bookmarks'] as num?)?.toInt() ?? 0;
          comicUniqueRead = (cd['unique_comics_read'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      // 3. Fetch or sync user profile
      if (isMe) {
        fetchedUser = currentAuthUser;
        try {
          fetchedUser = await ProfileRepository.instance.me();
          if (mounted) context.read<AuthProvider>().setUser(fetchedUser);
        } catch (_) {}

        // Fallback for self if public stats returned 0 or wasn't reachable
        if (watchCount == 0) {
          try {
            final history = await AnimeRepository.instance.watchHistory();
            watchCount = history.length;
          } catch (_) {}
        }
        if (bookmarkCount == 0) {
          try {
            final bms = await AnimeRepository.instance.bookmarks();
            bookmarkCount = bms.length;
          } catch (_) {}
        }
        if (comicHistoryCount == 0) {
          try {
            final ch = await ComicRepository.instance.readHistory();
            comicHistoryCount = ch.length;
          } catch (_) {}
        }
        if (comicBookmarkCount == 0) {
          try {
            final cb = await ComicRepository.instance.bookmarks();
            comicBookmarkCount = cb.length;
          } catch (_) {}
        }

        // Fetch generic stats
        try {
          stats = await ProfileRepository.instance.stats(targetUsername);
        } catch (_) {}
      } else {
        // Fetch target user profile from API /users/<username>
        try {
          fetchedUser = await ProfileRepository.instance.byUsername(targetUsername);
        } catch (_) {
          fetchedUser = _user ?? UserModel(id: 0, username: targetUsername, email: '');
        }

        // Fetch target user generic stats
        try {
          stats = await ProfileRepository.instance.stats(targetUsername);
        } catch (_) {}

        // Fallback calculation if watchCount or bookmarkCount still 0
        if (watchCount == 0) {
          if (stats.containsKey('watch_count')) {
            watchCount = (stats['watch_count'] as num?)?.toInt() ?? 0;
          } else if (stats.containsKey('anime_watched')) {
            watchCount = (stats['anime_watched'] as num?)?.toInt() ?? 0;
          } else if (stats.containsKey('study_stats') && stats['study_stats'] is Map) {
            final s = stats['study_stats'] as Map;
            watchCount = (s['total_studied'] as num?)?.toInt() ?? 0;
          }
        }
        if (bookmarkCount == 0 && stats.containsKey('bookmarks')) {
          if (stats['bookmarks'] is Map) {
            bookmarkCount = (stats['bookmarks']['total'] as num?)?.toInt() ?? 0;
          } else if (stats['bookmarks'] is num) {
            bookmarkCount = (stats['bookmarks'] as num).toInt();
          }
        }
      }

      // 3. Fetch Genre Roles Summary (/ylnime/user/<username>/genre-roles)
      UserGenreSummary? genreSummary;
      try {
        genreSummary = await AnimeRepository.instance.getUserGenreRoles(targetUsername);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _user = fetchedUser;
          _watchCount = watchCount;
          _bookmarkCount = bookmarkCount;
          _watchDuration = watchDuration;
          _comicHistoryCount = comicHistoryCount;
          _comicBookmarkCount = comicBookmarkCount;
          _comicUniqueRead = comicUniqueRead;
          if (genreSummary != null) {
            _genreSummary = genreSummary;
          }
          _loading = false;
        });
        UserDecorResolver.instance.register(
          username: fetchedUser.username,
          avatarUrl: fetchedUser.avatarUrl,
          decorationUrl: fetchedUser.fullAvatarDecorationUrl,
          decorationCode: fetchedUser.avatarDecorationCode,
          decorationScale: fetchedUser.avatarDecorationScale ?? 1.0,
          decorationOffsetX: fetchedUser.avatarDecorationOffsetX ?? 0,
          decorationOffsetY: fetchedUser.avatarDecorationOffsetY ?? 0,
          profileFontData: fetchedUser.profileFontData ?? ProfileFontModel.fromKey(fetchedUser.profileFont),
          verifiedBadge: fetchedUser.verifiedBadge,
          genreRole: genreSummary?.primaryRole ?? (genreSummary?.roles.isNotEmpty == true ? genreSummary!.roles.first : null),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_user != null) {
            _loading = false;
          } else {
            _loading = false;
            _error = 'Gagal memuat profil pengguna';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAuthUser = context.watch<AuthProvider>().user;
    final isMe = _user != null && currentAuthUser != null &&
        (_user!.id == currentAuthUser.id ||
         _user!.username.toLowerCase() == currentAuthUser.username.toLowerCase());

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top iOS drag indicator pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            Flexible(
              child: _loading && _user == null
                  ? _buildLoadingSkeleton(isDark)
                  : _error != null && _user == null
                      ? _buildErrorState(isDark)
                      : _buildProfileContent(context, isDark, isMe),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _cardTextStyle(
    ProfileFontModel? fontModel, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    bool inheritSize = true,
  }) {
    if (fontModel != null) {
      return fontModel.textStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        inheritSize: inheritSize,
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

  Widget _buildProfileContent(BuildContext context, bool isDark, bool isMe) {
    final user = _user!;
    final currentAuthUser = context.watch<AuthProvider>().user;
    final displayName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : ((isMe && currentAuthUser?.displayName != null && currentAuthUser!.displayName!.trim().isNotEmpty)
            ? currentAuthUser.displayName!
            : user.username);
    final role = (isMe ? currentAuthUser?.role : null) ?? user.role ?? 'Member';
    final isAdmin = role.toLowerCase() == 'admin';

    final resolvedDecor = UserDecorResolver.instance.get(user.username);
    final fontModel = (isMe ? currentAuthUser?.profileFontData : null) ??
        user.profileFontData ??
        resolvedDecor?.profileFontData ??
        ProfileFontModel.fromKey(isMe ? (currentAuthUser?.profileFont ?? user.profileFont) : user.profileFont);

    final rawFontSize = (user.profileFontSize != null && user.profileFontSize! > 0)
        ? user.profileFontSize!.toDouble()
        : (isMe && currentAuthUser?.profileFontSize != null && currentAuthUser!.profileFontSize! > 0
            ? currentAuthUser.profileFontSize!.toDouble()
            : 16.0);
    final titleFontSize = (rawFontSize + 4.0).clamp(18.0, 24.0);

    return DefaultTextStyle.merge(
      style: _cardTextStyle(fontModel, inheritSize: false),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ── 1. COVER PHOTO BANNER & OVERLAYS ─────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image / Gradient
              SizedBox(
                height: 130,
                width: double.infinity,
                child: user.coverUrl != null && user.coverUrl!.isNotEmpty
                    ? ((user.isCoverAnimated ||
                            user.coverUrl!.toLowerCase().contains('.gif') ||
                            user.coverUrl!.toLowerCase().contains('.webp'))
                        ? CalmGif(
                            source: user.coverUrl!,
                            fit: BoxFit.cover,
                            speed: 1.0,
                            minFrameDurationMs: 20,
                            placeholder: _buildCoverFallback(isDark),
                            errorWidget: Image.network(
                              user.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildCoverFallback(isDark),
                            ),
                          )
                        : Image.network(
                            user.coverUrl!,
                            fit: BoxFit.cover,
                            frameBuilder: (context, child, frame, wasSync) {
                              if (wasSync || frame != null) return child;
                              return _buildCoverFallback(isDark);
                            },
                            errorBuilder: (_, __, ___) => _buildCoverFallback(isDark),
                          ))
                    : _buildCoverFallback(isDark),
              ),

              // Gradient Vignette
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        (isDark ? const Color(0xFF161618) : Colors.white)
                            .withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Close Button (Top Right)
              Positioned(
                top: 10,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Self Preview Badge (Top Left)
              if (isMe)
                Positioned(
                  top: 10,
                  left: 14,
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.person_fill, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Profil Anda',
                                style: _cardTextStyle(
                                  fontModel,
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 2. AVATAR WITH EQUIPPED BINGKAI ───────────────────
              Positioned(
                bottom: -44,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: DecoratedAvatar(
                    avatarUrl: user.avatarUrl ?? (isMe ? currentAuthUser?.avatarUrl : resolvedDecor?.avatarUrl),
                    decorationUrl: user.fullAvatarDecorationUrl ?? (isMe ? currentAuthUser?.fullAvatarDecorationUrl : resolvedDecor?.decorationUrl),
                    fallbackName: displayName,
                    radius: 44,
                    decorationScale: user.avatarDecorationScale ?? (isMe ? currentAuthUser?.avatarDecorationScale : resolvedDecor?.decorationScale) ?? 1.0,
                    offsetX: user.avatarDecorationOffsetX ?? (isMe ? currentAuthUser?.avatarDecorationOffsetX : resolvedDecor?.decorationOffsetX) ?? 0,
                    offsetY: user.avatarDecorationOffsetY ?? (isMe ? currentAuthUser?.avatarDecorationOffsetY : resolvedDecor?.decorationOffsetY) ?? 0,
                    borderWidth: 3.0,
                    borderColor: isDark ? const Color(0xFF161618) : Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 52),

          // ── 3. USER INFO & IDENTITY ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Name + Badges + 1 Genre Role next to name
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _cardTextStyle(
                          fontModel,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    if (user.verifiedBadge) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.sakuraGradient),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ADMIN',
                          style: _cardTextStyle(
                            fontModel,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
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
                          );
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 2),

                // Username handle (@username)
                Text(
                  '@${user.username}',
                  style: _cardTextStyle(
                    fontModel,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),

                // ── PERAYAAN SELAMAT ULANG TAHUN (FESTIVE BANNER DI CARD) ──
                if (_isBirthdayToday(user) && !user.isBirthdayPrivate) ...[
                  const SizedBox(height: 12),
                  _buildFestiveBirthdayBanner(
                    name: user.displayName?.isNotEmpty == true ? user.displayName! : user.username,
                    age: user.isBirthdayPrivate ? null : user.age,
                    isDark: isDark,
                    fontModel: fontModel,
                  ),
                ],

                // Bio
                if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      user.bio!.trim(),
                      style: _cardTextStyle(
                        fontModel,
                        fontSize: 13.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // Metadata (Location, Website, Birthday, Join Date)
                () {
                  final bdayText = _formatBirthdayDisplay(user);
                  final hasLocation = user.location != null && user.location!.trim().isNotEmpty;
                  final hasCreatedAt = user.createdAt != null;

                  if (!hasLocation && bdayText == null && !hasCreatedAt) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        if (hasLocation)
                          _buildMetaChip(
                            icon: CupertinoIcons.location_solid,
                            text: user.location!.trim(),
                            isDark: isDark,
                            fontModel: fontModel,
                          ),
                        if (bdayText != null)
                          _buildMetaChip(
                            icon: _isBirthdayToday(user) ? CupertinoIcons.gift_fill : CupertinoIcons.gift,
                            text: bdayText,
                            isDark: isDark,
                            fontModel: fontModel,
                            isFestive: _isBirthdayToday(user),
                          ),
                        if (hasCreatedAt)
                          _buildMetaChip(
                            icon: CupertinoIcons.calendar,
                            text: 'Bergabung ${_formatDate(user.createdAt!)}',
                            isDark: isDark,
                            fontModel: fontModel,
                          ),
                      ],
                    ),
                  );
                }(),

                const SizedBox(height: 18),

                // ── 4. STATISTIK KARTU (Anime & Komik) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Anime
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.play_circle_fill,
                            size: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'STATISTIK TONTONAN (ANIME)',
                            style: _cardTextStyle(
                              fontModel,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Jumlah Tontonan
                          Expanded(
                            child: _buildStatItem(
                              icon: CupertinoIcons.play_rectangle_fill,
                              iconColor: isDark ? Colors.white : Colors.black,
                              value: '$_watchCount',
                              label: 'Tontonan',
                              isDark: isDark,
                              fontModel: fontModel,
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 38,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          // Koleksi Bookmark
                          Expanded(
                            child: _buildStatItem(
                              icon: CupertinoIcons.bookmark_fill,
                              iconColor: isDark ? Colors.white : Colors.black,
                              value: '$_bookmarkCount',
                              label: 'Tersimpan',
                              isDark: isDark,
                              fontModel: fontModel,
                            ),
                          ),
                          if (_watchDuration.isNotEmpty) ...[
                            Container(
                              width: 0.5,
                              height: 38,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            // Durasi Tonton
                            Expanded(
                              child: _buildStatItem(
                                icon: CupertinoIcons.time_solid,
                                iconColor: const Color(0xFF34C759),
                                value: _watchDuration,
                                label: 'Durasi',
                                isDark: isDark,
                                fontModel: fontModel,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Hairline Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),

                      // Header Komik
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.book_fill,
                            size: 13,
                            color: Color(0xFFFF9500),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'STATISTIK BACAAN (KOMIK)',
                            style: _cardTextStyle(
                              fontModel,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Total Bab Dibaca
                          Expanded(
                            child: _buildStatItem(
                              icon: CupertinoIcons.book_circle_fill,
                              iconColor: const Color(0xFFFF9500),
                              value: '$_comicHistoryCount',
                              label: 'Bab Dibaca',
                              isDark: isDark,
                              fontModel: fontModel,
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 38,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          // Judul Komik Unik
                          Expanded(
                            child: _buildStatItem(
                              icon: CupertinoIcons.square_grid_2x2_fill,
                              iconColor: const Color(0xFF5856D6),
                              value: '$_comicUniqueRead',
                              label: 'Judul Unik',
                              isDark: isDark,
                              fontModel: fontModel,
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 38,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          // Bookmark Komik
                          Expanded(
                            child: _buildStatItem(
                              icon: CupertinoIcons.heart_fill,
                              iconColor: const Color(0xFFFF2D55),
                              value: '$_comicBookmarkCount',
                              label: 'Favorit',
                              isDark: isDark,
                              fontModel: fontModel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── 5. ACTION BUTTONS ──────────────────────────────────
                if (isMe) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AvatarDecorationScreen(),
                              ),
                            );
                          },
                          icon: const Icon(CupertinoIcons.sparkles, size: 16),
                          label: Text(
                            'Ganti Bingkai',
                            style: _cardTextStyle(fontModel, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black,
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black26, width: 1.0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showProfileFontPicker(
                              context,
                              user: isMe ? (currentAuthUser ?? user) : user,
                              onUpdated: (updatedUser) {
                                setState(() {
                                  _user = updatedUser;
                                });
                                UserDecorResolver.instance.registerUserModel(updatedUser);
                                context.read<AuthProvider>().setUser(updatedUser);
                              },
                            );
                          },
                          icon: const Icon(CupertinoIcons.textformat, size: 16),
                          label: Text(
                            'Font Profil',
                            style: _cardTextStyle(fontModel, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black,
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black26, width: 1.0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: user),
                          ),
                        );
                      },
                      icon: const Icon(CupertinoIcons.pencil, size: 16),
                      label: Text(
                        'Edit Profil',
                        style: _cardTextStyle(fontModel, fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 4,
                        shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => ChatScreen(
                              initialText: '@${user.username} ',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(CupertinoIcons.chat_bubble_2_fill, size: 18),
                      label: Text(
                        'Kirim Pesan ke @${user.username}',
                        style: _cardTextStyle(fontModel, fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 4,
                        shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCoverFallback(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF2D55),
            Color(0xFF8E44AD),
            Color(0xFF2C3E50),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  String? _formatBirthdayDisplay(UserModel user) {
    if (user.isBirthdayPrivate) {
      return null; // Kalau privat, jangan tampilkan apa pun di card!
    }

    final isToday = _isBirthdayToday(user);
    final hasDob = user.tanggalLahir != null && user.tanggalLahir!.trim().isNotEmpty;
    final hasAge = user.age != null;
    final hasZodiac = user.zodiac != null && user.zodiac!.trim().isNotEmpty;

    if (!hasDob && !hasAge && !hasZodiac) return null;

    if (user.isBirthdayAgeOnly) {
      // Hanya umur & zodiak (tanggal lahir disembunyikan!)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2D55).withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFFF9500).withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.50),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🎉', style: TextStyle(fontSize: 20)),
              SizedBox(width: 6),
              Text('🎂', style: TextStyle(fontSize: 24)),
              SizedBox(width: 6),
              Text('✨', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Selamat Ulang Tahun, $name! 🎈',
            textAlign: TextAlign.center,
            style: _cardTextStyle(
              fontModel,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            age != null
                ? 'Selamat menginjak usia $age tahun! Semoga panjang umur & penuh berkah! 🎁🥳'
                : 'Hari ini adalah hari spesialmu! Semoga penuh keceriaan & berkah! 🎁🥳',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required bool isDark,
    ProfileFontModel? fontModel,
    bool isFestive = false,
  }) {
    if (isFestive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF2D55), Color(0xFFFF9500)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.30),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              text,
              style: _cardTextStyle(
                fontModel,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: _cardTextStyle(
            fontModel,
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
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
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _cardTextStyle(
            fontModel,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _cardTextStyle(
            fontModel,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 14),
            Text(
              'Memuat profil pengguna...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, size: 36, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Pengguna tidak ditemukan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = (local.month >= 1 && local.month <= 12) ? months[local.month - 1] : '';
    return '$monthName ${local.year}';
  }
}
