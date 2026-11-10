import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// API Configuration
/// Supports standard cPanel hosting, custom domains, and local development.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'http://103.119.237.37:2028';
  static const String _kCustomBaseUrl = 'custom_api_base_url';

  static String _baseUrl = defaultBaseUrl;

  /// Base URL of the backend. Override dynamically for custom hosting.
  /// Production Server: https://api.pipinipon.site
  /// Emulator:          http://10.0.2.2:5000
  /// iOS sim:           http://127.0.0.1:5000
  static String get baseUrl => _baseUrl;
  static const String apiPrefix = '/api';

  /// Full API base, e.g. http://103.119.237.37:2028/api
  static String get apiBase => '$baseUrl$apiPrefix';

  /// Per-module bases
  static String get authBase => '$apiBase/auth';
  static String get userBase => '$apiBase/users';
  static String get animeBase => '$apiBase/ylnime';
  static String get comicBase => '$apiBase/comic';
  static String get chatBase => '$apiBase/chat';
  static String get reviewBase => '$apiBase/reviews';
  static String get novelBase => '$apiBase/novel';
  static String get zpicBase => '$apiBase/zpic';

  /// Connection timeout for all HTTP requests
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Default page size for paginated endpoints
  static const int defaultPageSize = 20;

  /// Remote Config URL dari GitHub repo (zyanmd/api)
  static const List<String> remoteConfigUrls = [
    'https://raw.githubusercontent.com/zyanmd/api/refs/heads/main/api_config.json?token=GHSAT0AAAAAAEBT5NXRZ5EHMKK5PTADOKGY2WF4ZYQ',
    'https://raw.githubusercontent.com/zyanmd/api/main/api_config.json',
  ];

  static const String remoteConfigUrl =
      'https://raw.githubusercontent.com/zyanmd/api/refs/heads/main/api_config.json?token=GHSAT0AAAAAAEBT5NXRZ5EHMKK5PTADOKGY2WF4ZYQ';

  /// Load custom base URL if saved in SharedPreferences,
  /// lalu sinkronkan dari remote GitHub repo di background/init
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kCustomBaseUrl);
      if (saved != null && !saved.contains('103.119.237.37:2028')) {
        await prefs.remove(_kCustomBaseUrl);
        _baseUrl = defaultBaseUrl;
      } else if (saved != null && saved.trim().isNotEmpty) {
        _baseUrl = sanitizeUrl(saved);
      } else {
        _baseUrl = defaultBaseUrl;
      }
    } catch (_) {}
  }

  /// Tarik konfigurasi domain API terbaru dari GitHub Repo secara dinamis
  static Future<bool> syncFromRemoteConfig([String? customUrl]) async {
    final urlsToTry = customUrl != null ? [customUrl] : remoteConfigUrls;

    for (final targetUrl in urlsToTry) {
      if (targetUrl.isEmpty) continue;
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(Uri.parse(targetUrl));
        final response = await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            final newBase = data['api_base_url'] ?? data['base_url'] ?? data['api_url'];
            if (newBase is String && newBase.trim().isNotEmpty) {
              final sanitized = sanitizeUrl(newBase);
              if (sanitized != _baseUrl) {
                await setCustomBaseUrl(sanitized);
                return true;
              }
              return true;
            }
          }
        }
      } catch (e) {
        // Coba url berikutnya
      }
    }
    return false;
  }

  /// Update the base URL dynamically (e.g. pointing to a cPanel domain)
  static Future<void> setCustomBaseUrl(String url) async {
    final clean = sanitizeUrl(url);
    _baseUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCustomBaseUrl, clean);
    } catch (_) {}
  }

  /// Reset to the default backend URL
  static Future<void> resetBaseUrl() async {
    _baseUrl = defaultBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCustomBaseUrl);
    } catch (_) {}
  }

  /// Sanitize URL string (removes trailing slashes, ensures http/https scheme)
  static String sanitizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty || u.contains('103.119.237.37')) return defaultBaseUrl;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      if (RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(u) || u.contains(':2028') || u.contains(':2026')) {
        u = 'http://$u';
      } else {
        u = 'https://$u';
      }
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

/// Endpoint paths Ã¢â‚¬â€ single source of truth for all routes.
class ApiEndpoints {
  ApiEndpoints._();

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ AUTH Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authGoogleLogin = '/auth/google-login';
  static const String authGoogleToken = '/auth/google/token';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authResendVerification = '/auth/resend-verification';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authVerifyToken = '/auth/verify-token';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResetPassword = '/auth/reset-password';
  static const String authResendOtp = '/auth/resend-otp';

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ USER / PROFILE Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String usersAll = '/users/';
  static const String userProfileMe = '/users/profile/me';
  static String userProfileByUsername(String u) => '/users/$u';
  static String userPublicProfile(String u) => '/users/public/$u';
  static String userAvatar(String u) => '/users/$u/avatar';
  static String userCover(String u) => '/users/$u/cover';
  static const String userDeleteMe = '/users/profile/me';
  static String userBySlug(String slug) => '/users/by-slug/$slug';
  static String userStats(String u) => '/users/$u/stats';
  static const String userAvatarDecoration = '/users/profile/me/avatar-decoration';
  static const String userProfileFonts = '/users/profile/fonts';
  static const String userProfileFont = '/users/profile/me/font';
  static const String userBirthday = '/users/profile/me/birthday';
  static const String userBirthdayVisibility = '/users/profile/me/birthday/visibility';
  static const String userNotificationPreference = '/users/notification-preference';

  // ─── FRIENDSHIP / PERTEMANAN ───
  static String friendStatus(String u) => '/friends/status/$u';
  static const String friendRequest = '/friends/request';
  static String friendAccept(int id) => '/friends/accept/$id';
  static String friendReject(int id) => '/friends/reject/$id';
  static String friendCancel(int id) => '/friends/cancel/$id';
  static String friendUnfriend(String u) => '/friends/unfriend/$u';
  static const String friendRequests = '/friends/requests';
  static const String friendsList = '/friends/list';
  static String friendsListUser(String u) => '/friends/list/$u';

  // ─── USER ACTIVITY (FAVORITES, COMMENTS, CHATS) ───
  static String userFavorites(String u) => '/users/$u/favorites';
  static const String userProfileLikedToggle = '/users/profile/liked';
  static String userProfileLikedCheck(String itemType, String itemId) =>
      '/users/profile/liked/check?item_type=${Uri.encodeQueryComponent(itemType)}&item_id=${Uri.encodeQueryComponent(itemId)}';
  static String userProfileLikedDelete(int id) => '/users/profile/liked/$id';
  static String userComments(String u, {int page = 1, int perPage = 20}) => '/users/$u/comments?page=$page&per_page=$perPage';
  static String userChats(String u, {int page = 1, int perPage = 20}) => '/users/$u/chats?page=$page&per_page=$perPage';

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ ANIME (YLnime) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String animeHome = '/ylnime/home';
  static const String animeNewReleases = '/ylnime/new-releases';
  static const String animeOngoing = '/ylnime/ongoing';
  static const String animeCompleted = '/ylnime/completed';
  static const String animeSchedule = '/ylnime/schedule';
  static const String animeScheduleToday = '/ylnime/schedule/today';
  static const String animeGenres = '/ylnime/genres';
  static const String animeList = '/ylnime/anime-list/all';
  static const String animeListAll = '/ylnime/anime-list/all';
  static const String animeBookmarks = '/ylnime/bookmarks';
  static const String animeWatchHistory = '/ylnime/watch-history';
  static const String animeHealth = '/ylnime/health';
  static String animeDetail(String urlOrId) {
    String url = urlOrId.trim();
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) url = url.substring(1);
      if (url.startsWith('index.php?')) {
        url = 'https://ylnime.com/$url';
      } else if (url.startsWith('series=')) {
        url = 'https://ylnime.com/index.php?$url';
      } else {
        url = 'https://ylnime.com/index.php?series=$url';
      }
    }
    return '/ylnime/series?url=${Uri.encodeQueryComponent(url)}';
  }
  static String _normalizeAnimeEpisodeUrl(String urlOrId, {String? seriesSlug}) {
    String url = urlOrId.trim();
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) url = url.substring(1);
      if (url.startsWith('index.php')) {
        url = 'https://ylnime.com/$url';
      } else if (url.startsWith('episode=')) {
        url = 'https://ylnime.com/index.php?$url';
      } else if (url.contains('series=') && url.contains('episode=')) {
        final query = url.contains('?') ? url.substring(url.indexOf('?') + 1) : url;
        url = 'https://ylnime.com/index.php?$query';
      } else if (url.contains('episode=')) {
        final epPart = url.contains('?') ? url.substring(url.indexOf('?') + 1) : url;
        if (seriesSlug != null && seriesSlug.isNotEmpty) {
          url = 'https://ylnime.com/index.php?series=$seriesSlug&$epPart';
        } else {
          url = 'https://ylnime.com/index.php?$epPart';
        }
      } else {
        url = 'https://ylnime.com/index.php?episode=$url';
        if (seriesSlug != null && seriesSlug.isNotEmpty) {
          url = 'https://ylnime.com/index.php?series=$seriesSlug&episode=$url';
        } else {
          url = 'https://ylnime.com/index.php?episode=$url';
        }
      }
    } else {
      if (seriesSlug != null && seriesSlug.isNotEmpty && !url.contains('series=')) {
        if (url.contains('index.php?')) {
          url = url.replaceFirst('index.php?', 'index.php?series=$seriesSlug&');
        } else if (url.contains('?')) {
          url = url.replaceFirst('?', '?series=$seriesSlug&');
        }
      }
    }
    return url;
  }

  static String animeEpisode(String urlOrId, {String? seriesSlug, String? quality}) {
    final url = _normalizeAnimeEpisodeUrl(urlOrId, seriesSlug: seriesSlug);
    final qParam = (quality != null && quality.isNotEmpty)
        ? '&quality=${Uri.encodeQueryComponent(quality)}'
        : '';
    final sParam = (seriesSlug != null && seriesSlug.isNotEmpty)
        ? '&series=${Uri.encodeQueryComponent(seriesSlug)}'
        : '';
    return '/ylnime/episode?url=${Uri.encodeQueryComponent(url)}$sParam$qParam';
  }

  static String animeEpisodeQuick(String urlOrId, {String? seriesSlug, String? quality}) {
    final url = _normalizeAnimeEpisodeUrl(urlOrId, seriesSlug: seriesSlug);
    final qParam = (quality != null && quality.isNotEmpty)
        ? '&quality=${Uri.encodeQueryComponent(quality)}'
        : '';
    final sParam = (seriesSlug != null && seriesSlug.isNotEmpty)
        ? '&series=${Uri.encodeQueryComponent(seriesSlug)}'
        : '';
    return '/ylnime/episode/streams?url=${Uri.encodeQueryComponent(url)}$sParam$qParam';
  }

  static String animeEpisodeResolution(String urlOrId, {required String reso, String? seriesSlug}) {
    final url = _normalizeAnimeEpisodeUrl(urlOrId, seriesSlug: seriesSlug);
    final sParam = (seriesSlug != null && seriesSlug.isNotEmpty)
        ? '&series=${Uri.encodeQueryComponent(seriesSlug)}'
        : '';
    return '/ylnime/episode/streams?url=${Uri.encodeQueryComponent(url)}$sParam&quality=${Uri.encodeQueryComponent(reso)}';
  }
  static String animeSearch(String q, {int page = 1}) =>
      '/ylnime/search?q=${Uri.encodeQueryComponent(q)}&page=$page';
  static String animeByGenre(String slug, {int page = 1}) =>
      '/ylnime/genre/$slug?page=$page';
  static String animeBookmarkCheck(String id) =>
      '/ylnime/bookmarks/check/$id';
  static String animeBookmarkDelete(String id) =>
      '/ylnime/bookmarks/$id';
  static String animeWatchHistoryDelete(String id) =>
      '/ylnime/watch-history/$id';

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ YLNIME / MULTI-QUALITY STREAMING Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String ylnimeHome = '/ylnime/home';
  static const String ylnimeReels = '/ylnime/reels';
  static const String ylnimeReelsRandom = '/ylnime/reels/random';
  static String ylnimeReelsPaged({int page = 1, int limit = 10}) =>
      '/ylnime/reels?page=$page&count=$limit&limit=$limit';
  static String ylnimeReelsLike(String reelId) =>
      '/ylnime/reels/${Uri.encodeComponent(reelId)}/like';
  static const String ylnimeReelsStreamProxy = '/ylnime/reels/stream-proxy';
  static String ylnimeSeries(String url) => '/ylnime/series?url=${Uri.encodeQueryComponent(url)}';
  static String ylnimeSearch(String q) => '/ylnime/search?q=${Uri.encodeQueryComponent(q)}';
  static String ylnimeStreams({required String url, required String quality}) =>
      '/ylnime/episode/streams?url=${Uri.encodeQueryComponent(url)}&quality=${Uri.encodeQueryComponent(quality)}';
  static String ylnimeEpisodeComments(String episodeKey, {int page = 1, int limit = 20, String sort = 'newest'}) =>
      '/ylnime/episode/${Uri.encodeComponent(episodeKey)}/comments?page=$page&limit=$limit&sort=$sort';
  static const String ylnimeAddComment = '/ylnime/episode/comments';
  static String ylnimeUpdateComment(int commentId) => '/ylnime/episode/comments/$commentId';
  static String ylnimeDeleteComment(int commentId) => '/ylnime/episode/comments/$commentId';
  static String ylnimeCommentLike(int commentId) => '/ylnime/episode/comments/$commentId/like';
  static String ylnimeCommentsCount(String episodeKey) =>
      '/ylnime/episode/${Uri.encodeComponent(episodeKey)}/comments/count';
  static String ylnimeCommentReplies(int commentId, {int limit = 10, int offset = 0}) =>
      '/ylnime/episode/comments/replies/$commentId?limit=$limit&offset=$offset';
  static const String ylnimeUploadCommentMedia = '/ylnime/episode/comments/upload-media';
  static String ylnimeDeleteCommentMedia(int commentId) =>
      '/ylnime/episode/comments/media/$commentId';
  static const String ylnimeUserCommentBackground = '/ylnime/user/comment-background';
  static const String ylnimeUserCommentBackgroundUpload = '/ylnime/user/comment-background/upload';
  static const String ylnimeCommentNotifications = '/ylnime/notifications/comments';
  static const String ylnimeCommentNotificationsCount = '/ylnime/notifications/comments/count';
  static String ylnimeCommentNotificationRead(dynamic id) => '/ylnime/notifications/comments/$id/read';
  static const String ylnimeCommentNotificationsReadAll = '/ylnime/notifications/comments/read-all';
  static String ylnimeCommentNotificationDelete(dynamic id) => '/ylnime/notifications/comments/$id';
  static const String ylnimeCommentNotificationsCleanup = '/ylnime/notifications/comments/cleanup';
  static const String ylnimeWatchHistory = '/ylnime/watch-history';
  static const String ylnimeWatchHistoryProgress = '/ylnime/watch-history/progress';
  static const String ylnimeContinueWatching = '/ylnime/watch-history/continue-watching';
  static const String ylnimeWatchHistoryStats = '/ylnime/watch-history/stats';
  static const String ylnimeWatchHistoryClearAll = '/ylnime/watch-history/clear-all';
  static String ylnimeWatchHistoryEpisodeDelete(String episodeKey) =>
      '/ylnime/watch-history/episode/${Uri.encodeComponent(episodeKey)}';
  static const String ylnimeBookmarks = '/ylnime/bookmarks';
  static String ylnimeBookmarkDelete(String id) => '/ylnime/bookmarks/$id';
  static const String ylnimeAnimeListAll = '/ylnime/anime-list/all';
  static String ylnimeAnimeList({String letter = 'A'}) =>
      '/ylnime/anime-list/all?letter=${Uri.encodeQueryComponent(letter)}';
  static String ylnimeUserStats(String username) => '/ylnime/user/$username/stats';
  static String ylnimeUserBookmarks(String username, {int page = 1, int limit = 20}) =>
      '/ylnime/user/$username/bookmarks?page=$page&limit=$limit';
  static String ylnimeUserHistory(String username, {int page = 1, int limit = 20}) =>
      '/ylnime/user/$username/history?page=$page&limit=$limit';
  static const String ylnimeHyper = '/ylnime/hyper';
  static String ylnimeNewReleases({int page = 1}) => '/ylnime/new-releases?page=$page';
  static String ylnimeBaru({int page = 1}) => '/ylnime/new-releases?page=$page';
  static const String ylnimeGenreRoles = '/ylnime/genre-roles';
  static const String ylnimeGenreRolesMe = '/ylnime/genre-roles/me';
  static const String ylnimeGenreRolesCatalog = '/ylnime/genre-roles/catalog';
  static const String ylnimeGenreRolesDefinitions = '/ylnime/genre-roles/definitions';
  static String ylnimeUserGenreRoles(String username) =>
      '/ylnime/user/${Uri.encodeComponent(username)}/genre-roles';
  static String ylnimeGenreRolesUser(String username) =>
      '/ylnime/genre-roles/user/${Uri.encodeComponent(username)}';
  static const String ylnimeRecalculateGenreRoles = '/ylnime/genre-roles/recalculate';
  static const String ylnimeGenreRolesResync = '/ylnime/genre-roles/resync';
  static const String ylnimeGenreRolesReset = '/ylnime/genre-roles/reset';
  static const String ylnimeGenreRolePin = '/ylnime/genre-roles/pin';
  static String ylnimeGenreRolePinId(int roleId) => '/ylnime/genre-roles/pin/$roleId';
  static String ylnimeGenreRoleEquip(int roleId) => '/ylnime/genre-roles/equip/$roleId';
  static const String ylnimeGenreRoleUnpin = '/ylnime/genre-roles/unpin';
  static const String ylnimeGenreRoleUnequip = '/ylnime/genre-roles/unequip';
  static String ylnimeGenreRolePinnedUser(String username) =>
      '/ylnime/genre-roles/pinned/${Uri.encodeComponent(username)}';
  static const String ylnimeGenreRolePinned = '/ylnime/genre-roles/pinned';
  static const String userGenreRolesMe = '/users/profile/me/genre-roles';
  static const String userGenreRoleDefinitions = '/users/genre-role-definitions';
  static String userPublicGenreRoles(String username) =>
      '/users/public/${Uri.encodeComponent(username)}/genre-roles';
  static String ylnimePolling({String kategori = 'cantik'}) {
    final clean = (kategori.toLowerCase() == 'ganteng') ? 'tampan' : kategori.toLowerCase();
    final enc = Uri.encodeQueryComponent(clean);
    return '/ylnime/polling?kategori=$enc&k=$enc';
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ COMIC Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String comicGenres = '/comic/genres';
  static const String comicPustaka = '/comic/pustaka';
  static const String comicPopuler = '/comic/populer';
  static const String comicTerbaru = '/comic/terbaru';
  static const String comicDaftar = '/comic/daftar-komik';
  static const String comicBookmarks = '/comic/bookmarks';
  static const String comicReadHistory = '/comic/read-history';
  static const String comicReadHistoryLatest = '/comic/read-history/latest';
  static const String comicHealth = '/comic/health';
  static const String comicChapter = '/comic/chapter';
  static const String comicChapterLegacy = '/comic/chapter/legacy';
  static String comicSearch(String q) => '/comic/search?q=${Uri.encodeQueryComponent(q)}';
  static String comicDetail(String slug) => '/comic/detail/$slug';
  static String comicByGenre(String slug) => '/comic/genre/$slug';
  static String comicRanking(String period) => '/comic/ranking/$period';
  static String comicBookmarkCheck(String slug) => '/comic/bookmarks/check/$slug';
  static String comicBookmarkDelete(String slug) => '/comic/bookmarks/$slug';
  static String comicReadHistoryDelete(String slug) => '/comic/read-history/$slug';
  static String comicUserStats(String username) =>
      '/comic/public/stats/${Uri.encodeComponent(username)}';

  // ───── CHAT (GLOBAL COMMUNITY CHAT) ─────
  static const String chatInfo = '/chat/info';
  static const String chatMessages = '/chat/messages';
  static String chatMessage(int id) => '/chat/messages/$id';
  static const String chatUploadMedia = '/chat/upload/media';
  static const String chatUploadBackground = '/chat/upload/background';
  static const String chatReplyNotifications = '/chat/reply-notifications';
  static String chatReplyNotificationRead(int id) => '/chat/reply-notifications/$id/read';
  static const String chatReplyNotificationsReadAll = '/chat/reply-notifications/read-all';
  static const String chatMentions = '/chat/mentions';
  static String chatMentionRead(int id) => '/chat/mentions/$id/read';
  static const String chatMentionsReadAll = '/chat/mentions/read-all';
  static const String chatNotificationsSummary = '/chat/notifications/summary';
  static const String chatReadAll = '/chat/read-all';
  static const String chatUsersSearch = '/chat/users/search';
  static const String chatMentionsValidate = '/chat/mentions/validate';
  static String chatDeleteMedia(int id) => '/chat/messages/$id/media';
  static String chatDeleteBackground(int id) => '/chat/messages/$id/background';
  static const String chatUserBackground = '/chat/user/background';
  static const String chatUserBackgroundUpload = '/chat/user/background/upload';

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ AVATAR DECORATIONS (BINGKAI AVATAR) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String avatarDecorations = '/avatar-decorations';
  static const String avatarDecorationCategories = '/avatar-decorations/categories';
  static const String avatarDecorationMy = '/avatar-decorations/my';
  static const String avatarDecorationSelect = '/avatar-decorations/select';
  static const String avatarDecorationStats = '/avatar-decorations/stats';
  static const String avatarDecorationCatalog = '/avatar-decorations/catalog';
  static String avatarDecorationDetail(int id) => '/avatar-decorations/$id';
  static String avatarDecorationImage(String code) => '/avatar-decorations/image/$code.png';
  static const String avatarDecorationCacheClear = '/avatar-decorations/cache/clear';

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ APP CONFIG & VERSION Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  static const String versionUpdate = '/version/update';
  static const String versionConfig = '/version_config.json';

  // ANNOUNCEMENTS / PEMBERITAHUAN
  static const String announcements = '/announcements';
  static String announcementDetail(int id) => '/announcements/$id';

  // ─── USER REVIEWS / FITUR ULAS ───
  static const String reviews = '/reviews';
  static const String reviewCheck = '/reviews/check';
  static String reviewDetail(int id) => '/reviews/$id';
  static String reviewLike(int id) => '/reviews/$id/like';
  static String reviewComments(int id) => '/reviews/$id/comments';
  static String reviewCommentDelete(int id) => '/reviews/comments/$id';

  // ─── NOVEL ENDPOINTS (SAKURANOVEL) ───
  static const String novelHome = '/novel/home';
  static const String novelDaftar = '/novel/daftar-novel';
  static String novelDaftarQuery({String? huruf, String? type, int page = 1, String? q}) {
    final params = <String>[];
    if (huruf != null && huruf.isNotEmpty && huruf != 'Semua') {
      params.add('huruf=${Uri.encodeQueryComponent(huruf)}');
    }
    if (type != null && type.isNotEmpty && type != 'Semua') {
      params.add('type=${Uri.encodeQueryComponent(type)}');
    }
    if (page > 1) {
      params.add('page=$page');
    }
    if (q != null && q.isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(q)}');
    }
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '/novel/daftar-novel$qs';
  }
  static String novelSearch(String q, {int page = 1}) =>
      '/novel/search?q=${Uri.encodeQueryComponent(q)}&page=$page';
  static String novelDetail(String slug) => '/novel/detail/$slug';
  static String novelRead(String slug) => '/novel/read/$slug';
  static const String novelGenres = '/novel/genres';
  static String novelByGenre(String genreSlug, {int page = 1}) =>
      '/novel/genre/$genreSlug?page=$page';
  static const String novelTags = '/novel/tags';
  static String novelByTag(String tagSlug, {int page = 1}) =>
      '/novel/tag/$tagSlug?page=$page';
  static const String novelBookmarks = '/novel/bookmarks';
  static const String novelBookmarkAdd = '/novel/bookmark';
  static String novelBookmarkDelete(String slug) => '/novel/bookmark/$slug';
  static const String novelHistory = '/novel/history';

  static String novelImageUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    if (rawUrl.contains('/api/novel/image') || rawUrl.contains('/novel/image')) {
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        return rawUrl;
      }
      final clean = rawUrl.startsWith('/api') ? rawUrl.substring(4) : rawUrl;
      return '${ApiConfig.apiBase}$clean';
    }
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return '${ApiConfig.apiBase}/novel/image?url=${Uri.encodeQueryComponent(rawUrl)}';
    }
    if (rawUrl.startsWith('/')) {
      return '${ApiConfig.apiBase}$rawUrl';
    }
    return rawUrl;
  }

  // ───── ZPIC VIDEO & STREAMING ─────
  static const String zpicHome = '/zpic/home';
  static String zpicHomePaged({int page = 1}) => '/zpic/home?page=$page';
  static const String zpicSearch = '/zpic/search';
  static String zpicSearchQuery(String q, {int page = 1}) =>
      '/zpic/search?q=${Uri.encodeQueryComponent(q)}&page=$page';
  static String zpicDetail(String videoId) =>
      '/zpic/detail/${Uri.encodeComponent(videoId)}';
  static const String zpicRandom = '/zpic/random';
  static const String zpicHealth = '/zpic/health';

  // ─── AI SERVICE (VPS MURAH / OPENAI COMPATIBLE) ───
  static const String aiDefaultBaseUrl = 'https://my.vpsmurah.co.id/api/v1';
  static const String aiDefaultModel = 'gemini-38';
  static const String aiChatCompletions = '/chat/completions';
  static const String aiModels = '/models';
}
