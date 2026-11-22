import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/anime/data/anime_repository.dart';
import '../../features/anime/data/models/anime_model.dart';
import '../../features/comic/data/comic_repository.dart';
import '../../features/comic/data/models/comic_model.dart';
import '../models/mal_models.dart';
import 'anime_watch_progress_service.dart';
import 'comic_read_progress_service.dart';

/// Laporan hasil sinkronisasi riwayat tontonan/bacaan antara Moko dan MyAnimeList
class MalSyncReport {
  final int animeUploaded;
  final int mangaUploaded;
  final int animeImported;
  final int mangaImported;
  final List<String> logs;
  final bool success;
  final String? errorMessage;
  final DateTime timestamp;

  const MalSyncReport({
    this.animeUploaded = 0,
    this.mangaUploaded = 0,
    this.animeImported = 0,
    this.mangaImported = 0,
    this.logs = const [],
    this.success = true,
    this.errorMessage,
    required this.timestamp,
  });

  int get totalSynced => animeUploaded + mangaUploaded + animeImported + mangaImported;
}

/// Service untuk mengelola autentikasi dan sinkronisasi MyAnimeList (MAL)
class MalService {
  MalService._();
  static final MalService instance = MalService._();

  static const String _defaultClientId = 'b2b433aa309f9665ac875cf8924b545a';
  static const String _malApiBase = 'https://api.myanimelist.net/v2';
  static const String _jikanApiBase = 'https://api.jikan.moe/v4';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ),);

  // SharedPreferences keys
  static const _kAccessToken = 'mal_access_token';
  static const _kRefreshToken = 'mal_refresh_token';
  static const _kTokenExpiry = 'mal_token_expiry';
  static const _kUsername = 'mal_username';
  static const _kPictureUrl = 'mal_picture_url';
  static const _kClientId = 'mal_custom_client_id';
  static const _kAutoScrobble = 'mal_auto_scrobble_enabled';
  static const _kCachedMatches = 'mal_cached_matches_map';
  static const _kCachedMangaMatches = 'mal_cached_manga_matches_map';
  static const _kMalToLocalAnimeMatches = 'mal_to_local_anime_v1';
  static const _kMalToLocalMangaMatches = 'mal_to_local_manga_v1';
  static const _kLastSyncTime = 'mal_last_sync_time_millis';

  SharedPreferences? _prefs;
  String? _accessToken;
  String? _refreshToken;
  int? _tokenExpiry;
  String? _username;
  String? _pictureUrl;
  bool _autoScrobble = true;
  int? _lastSyncTimeMillis;
  final Map<String, int> _titleMatchCache = {};
  final Map<String, int> _mangaTitleMatchCache = {};
  final Map<int, String> _malToLocalAnimeMap = {};
  final Map<int, String> _malToLocalMangaMap = {};

  bool hasLocalMappingForMalId(int malId) => _malToLocalAnimeMap.containsKey(malId);
  String? getLocalAnimeIdForMalId(int malId) => _malToLocalAnimeMap[malId];

  bool hasLocalMangaMappingForMalId(int malId) => _malToLocalMangaMap.containsKey(malId);
  String? getLocalMangaSlugForMalId(int malId) => _malToLocalMangaMap[malId];

  // Notifiers untuk UI reaktif
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> hasOAuthNotifier = ValueNotifier(false);
  final ValueNotifier<String?> usernameNotifier = ValueNotifier(null);
  final ValueNotifier<String?> pictureUrlNotifier = ValueNotifier(null);
  final ValueNotifier<bool> autoScrobbleNotifier = ValueNotifier(true);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> syncStatusMessageNotifier = ValueNotifier(null);
  final ValueNotifier<MalSyncReport?> lastSyncReportNotifier = ValueNotifier(null);

  bool get isConnected => isConnectedNotifier.value;
  bool get hasOAuth => hasOAuthNotifier.value;
  String? get username => usernameNotifier.value;
  String? get pictureUrl => pictureUrlNotifier.value;
  bool get isAutoScrobbleEnabled => autoScrobbleNotifier.value;
  bool get isSyncing => isSyncingNotifier.value;
  DateTime? get lastSyncTime => _lastSyncTimeMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(_lastSyncTimeMillis!)
      : null;

  String get clientId {
    final custom = _prefs?.getString(_kClientId)?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return _defaultClientId;
  }

  Future<void> setCustomClientId(String? id) async {
    final prefs = await _getPrefs();
    if (id == null || id.trim().isEmpty) {
      await prefs.remove(_kClientId);
    } else {
      await prefs.setString(_kClientId, id.trim());
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Inisialisasi data tersimpan
  Future<void> init() async {
    try {
      final prefs = await _getPrefs();
      _accessToken = prefs.getString(_kAccessToken);
      _refreshToken = prefs.getString(_kRefreshToken);
      _tokenExpiry = prefs.getInt(_kTokenExpiry);
      _username = prefs.getString(_kUsername);
      _pictureUrl = prefs.getString(_kPictureUrl);
      _autoScrobble = prefs.getBool(_kAutoScrobble) ?? true;

      final cachedJson = prefs.getString(_kCachedMatches);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            if (v is int) _titleMatchCache[k] = v;
          });
        } catch (_) {}
      }

      final cachedMangaJson = prefs.getString(_kCachedMangaMatches);
      if (cachedMangaJson != null && cachedMangaJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedMangaJson) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            if (v is int) _mangaTitleMatchCache[k] = v;
          });
        } catch (_) {}
      }

      final cachedLocalAnime = prefs.getString(_kMalToLocalAnimeMatches);
      if (cachedLocalAnime != null && cachedLocalAnime.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedLocalAnime) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            final id = int.tryParse(k);
            if (id != null && v is String) _malToLocalAnimeMap[id] = v;
          });
        } catch (_) {}
      }

      final cachedLocalManga = prefs.getString(_kMalToLocalMangaMatches);
      if (cachedLocalManga != null && cachedLocalManga.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedLocalManga) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            final id = int.tryParse(k);
            if (id != null && v is String) _malToLocalMangaMap[id] = v;
          });
        } catch (_) {}
      }

      final hasToken = _accessToken != null && _accessToken!.isNotEmpty;
      final hasUser = _username != null && _username!.isNotEmpty;

      _lastSyncTimeMillis = prefs.getInt(_kLastSyncTime);
      if (_lastSyncTimeMillis != null) {
        lastSyncReportNotifier.value = MalSyncReport(
          timestamp: DateTime.fromMillisecondsSinceEpoch(_lastSyncTimeMillis!),
        );
      }

      hasOAuthNotifier.value = hasToken;
      isConnectedNotifier.value = hasToken || hasUser;
      usernameNotifier.value = _username;
      pictureUrlNotifier.value = _pictureUrl;
      autoScrobbleNotifier.value = _autoScrobble;

      // Cek apakah token perlu diperbarui
      if (hasToken && _tokenExpiry != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now >= (_tokenExpiry! - 300)) {
          unawaited(refreshToken());
        }
      }
    } catch (e) {
      debugPrint('[MAL] Gagal inisialisasi MalService: $e');
    }
  }

  /// Mengatur status auto-scrobble (update tontonan otomatis)
  Future<void> setAutoScrobble(bool enabled) async {
    _autoScrobble = enabled;
    autoScrobbleNotifier.value = enabled;
    final prefs = await _getPrefs();
    await prefs.setBool(_kAutoScrobble, enabled);
  }

  // ─────────────────────────────────────────────────────────────
  // OAUTH 2.0 PKCE FLOW
  // ─────────────────────────────────────────────────────────────

  /// Menghasilkan random string untuk code_verifier (PKCE)
  static String generateCodeVerifier() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// URL otorisasi MyAnimeList OAuth2
  String getAuthorizationUrl({
    required String codeVerifier,
    required String redirectUri,
    String? state,
  }) {
    final query = Uri(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'code_challenge': codeVerifier, // MAL mendukung plain challenge
        'code_challenge_method': 'plain',
        if (state != null) 'state': state,
        'redirect_uri': redirectUri,
      },
    ).query;
    return 'https://myanimelist.net/v1/oauth2/authorize?$query';
  }

  /// Menukarkan kode otorisasi menjadi access_token
  Future<bool> exchangeAuthCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    try {
      final res = await _dio.post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': clientId,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final accessToken = data['access_token']?.toString();
        final refreshToken = data['refresh_token']?.toString();
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 2678400; // 31 hari default
        final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;

        if (accessToken != null) {
          await _saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryTimestamp: expiry,
          );
          // Ambil profil pengguna
          await fetchCurrentUserProfile();
          // 🔥 Otomatis sinkronkan riwayat tontonan/bacaan ke akun MyAnimeList pengguna
          unawaited(syncWithMal());
          return true;
        }
      }
    } catch (e) {
      debugPrint('[MAL] Gagal menukarkan token: $e');
    }
    return false;
  }

  /// Memperbarui access token dengan refresh token
  Future<bool> refreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final res = await _dio.post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': clientId,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final accessToken = data['access_token']?.toString();
        final newRefresh = data['refresh_token']?.toString() ?? _refreshToken;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 2678400;
        final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;

        if (accessToken != null) {
          await _saveTokens(
            accessToken: accessToken,
            refreshToken: newRefresh,
            expiryTimestamp: expiry,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('[MAL] Gagal refresh token: $e');
    }
    return false;
  }

  Future<void> _saveTokens({
    required String accessToken,
    String? refreshToken,
    required int expiryTimestamp,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = expiryTimestamp;

    final prefs = await _getPrefs();
    await prefs.setString(_kAccessToken, accessToken);
    if (refreshToken != null) await prefs.setString(_kRefreshToken, refreshToken);
    await prefs.setInt(_kTokenExpiry, expiryTimestamp);

    hasOAuthNotifier.value = true;
    isConnectedNotifier.value = true;
  }

  /// Hubungkan dengan Username saja (Mode Cepat & Publik tanpa login OAuth)
  Future<bool> connectWithUsername(String rawUsername) async {
    final clean = rawUsername.trim();
    if (clean.isEmpty) return false;

    try {
      // Validasi profil via Jikan API v4
      final res = await _dio.get('$_jikanApiBase/users/$clean/full');
      if (res.statusCode == 200 && res.data?['data'] != null) {
        final user = MalUser.fromJson(res.data['data']);
        _username = user.name;
        _pictureUrl = user.picture;

        final prefs = await _getPrefs();
        await prefs.setString(_kUsername, _username!);
        if (_pictureUrl != null) await prefs.setString(_kPictureUrl, _pictureUrl!);

        usernameNotifier.value = _username;
        pictureUrlNotifier.value = _pictureUrl;
        isConnectedNotifier.value = true;
        // 🔥 Otomatis impor daftar tontonan MAL ke katalog lokal
        unawaited(syncWithMal(uploadLocalToMal: false, importMalToLocal: true));
        return true;
      }
    } catch (e) {
      debugPrint('[MAL] Gagal menghubungkan username: $e');
    }
    return false;
  }

  /// Ambil profil pengguna saat ini
  Future<MalUser?> fetchCurrentUserProfile() async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      if (_username != null && _username!.isNotEmpty) {
        // Fallback Jikan
        try {
          final res = await _dio.get('$_jikanApiBase/users/$_username/full');
          if (res.statusCode == 200 && res.data?['data'] != null) {
            return MalUser.fromJson(res.data['data']);
          }
        } catch (_) {}
      }
      return null;
    }

    try {
      final res = await _dio.get(
        '$_malApiBase/users/@me?fields=anime_statistics',
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );

      if (res.statusCode == 200 && res.data != null) {
        final user = MalUser.fromJson(res.data);
        _username = user.name;
        _pictureUrl = user.picture;

        final prefs = await _getPrefs();
        await prefs.setString(_kUsername, _username!);
        if (_pictureUrl != null) await prefs.setString(_kPictureUrl, _pictureUrl!);

        usernameNotifier.value = _username;
        pictureUrlNotifier.value = _pictureUrl;
        return user;
      }
    } catch (e) {
      debugPrint('[MAL] Gagal ambil profil MAL: $e');
    }
    return null;
  }

  /// Logout / Putuskan koneksi MyAnimeList
  Future<void> disconnect() async {
    final prefs = await _getPrefs();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kTokenExpiry);
    await prefs.remove(_kUsername);
    await prefs.remove(_kPictureUrl);
    await prefs.remove(_kLastSyncTime);

    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _username = null;
    _pictureUrl = null;
    _lastSyncTimeMillis = null;

    hasOAuthNotifier.value = false;
    isConnectedNotifier.value = false;
    usernameNotifier.value = null;
    pictureUrlNotifier.value = null;
    lastSyncReportNotifier.value = null;
  }

  // ─────────────────────────────────────────────────────────────
  // ANIME MATCHING & SEARCH
  // ─────────────────────────────────────────────────────────────

  /// Pembersihan judul anime untuk pencarian akurat
  static String cleanTitleForMatching(String title) {
    var s = title.trim();
    // Hilangkan tag batch/resolusi/format dalam kurung siku & kurung biasa
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    // Hilangkan kata-kata umum scraper anime & website
    s = s.replaceAll(
      RegExp(r'\b(Nonton\s*Anime\s*Online\s*Gratis|Nonton\s*Anime\s*Gratis|Nonton\s*Anime|Nonton|Anime\s*Online|Subtitle\s*Indonesia|Sub\s*Indo|Online|Gratis|Streaming|Download|Batch|BD|Movie|TV|Season\s*\d+|Part\s*\d+|S\d+)\b', caseSensitive: false),
      ' ',
    );
    // Hilangkan multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Mencocokkan judul Animeverse dengan ID MyAnimeList
  Future<MalAnimeItem?> findMalAnime(String title, {String? animeId}) async {
    // 0. Cek animeId di cache jika tersedia
    if (animeId != null && animeId.trim().isNotEmpty) {
      final idKey = animeId.trim().toLowerCase();
      if (_titleMatchCache.containsKey(idKey)) {
        final cachedId = _titleMatchCache[idKey]!;
        final details = await getAnimeDetails(cachedId);
        if (details != null) return details;
      }
    }

    final rawKey = title.trim().toLowerCase();
    if (_titleMatchCache.containsKey(rawKey)) {
      final cachedId = _titleMatchCache[rawKey]!;
      final details = await getAnimeDetails(cachedId);
      if (details != null) return details;
    }

    final clean = cleanTitleForMatching(title);
    if (clean.isEmpty) return null;

    final cacheKey = clean.toLowerCase();
    if (_titleMatchCache.containsKey(cacheKey)) {
      final cachedId = _titleMatchCache[cacheKey]!;
      return getAnimeDetails(cachedId);
    }

    try {
      // 1. Coba Official MAL API jika ada token
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/anime',
          queryParameters: {
            'q': clean,
            'limit': 5,
            'nsfw': 'true',
            'fields': 'id,title,main_picture,alternative_titles,num_episodes,mean,status,synopsis,my_list_status{status,score,num_episodes_watched,is_rewatching,updated_at}',
          },
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          final list = res.data['data'] as List;
          if (list.isNotEmpty) {
            final node = list.first['node'] as Map<String, dynamic>;
            final item = MalAnimeItem.fromJson(node);
            _cacheMatch(cacheKey, item.id);
            _cacheMatch(rawKey, item.id);
            if (animeId != null && animeId.trim().isNotEmpty) {
              _cacheMatch(animeId.trim().toLowerCase(), item.id);
            }
            return item;
          }
        }
      }

      // 2. Fallback via Jikan API v4
      final jikanRes = await _dio.get(
        '$_jikanApiBase/anime',
        queryParameters: {'q': clean, 'limit': 3, 'sfw': false},
      );

      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] is List) {
        final list = jikanRes.data['data'] as List;
        if (list.isNotEmpty) {
          final item = MalAnimeItem.fromJson(list.first as Map<String, dynamic>);
          _cacheMatch(cacheKey, item.id);
          _cacheMatch(rawKey, item.id);
          if (animeId != null && animeId.trim().isNotEmpty) {
            _cacheMatch(animeId.trim().toLowerCase(), item.id);
          }
          return item;
        }
      }
    } catch (e) {
      debugPrint('[MAL] Gagal mencari anime "$clean": $e');
    }
    return null;
  }

  void _cacheMatch(String key, int malId) {
    _titleMatchCache[key] = malId;
    _saveCacheToPrefs();
  }

  /// Hubungkan judul anime secara manual ke MAL ID tertentu (termasuk slug animeId)
  /// [syncToCloud] jika bernilai true, akan menyimpan tag mapping ke akun MyAnimeList (Cloud)
  Future<void> setManualAnimeMapping(
    String title,
    int malId, {
    String? animeId,
    bool syncToCloud = true,
  }) async {
    final clean = cleanTitleForMatching(title).toLowerCase();
    _cacheMatch(clean, malId);
    _cacheMatch(title.trim().toLowerCase(), malId);
    if (animeId != null && animeId.trim().isNotEmpty) {
      final cleanId = animeId.trim().toLowerCase();
      _cacheMatch(cleanId, malId);
      _malToLocalAnimeMap[malId] = animeId.trim();
      unawaited(_saveMalToLocalAnimeMap());
      if (syncToCloud) {
        unawaited(_syncMappingToMalCloud(malId: malId, localId: animeId.trim(), isAnime: true));
      }
    }
  }

  Future<void> _saveMalToLocalAnimeMap() async {
    try {
      final prefs = await _getPrefs();
      final mapToSave = _malToLocalAnimeMap.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString(_kMalToLocalAnimeMatches, jsonEncode(mapToSave));
    } catch (_) {}
  }

  /// Memutuskan / mereset hubungan anime ke MAL ID tertentu
  Future<void> removeManualAnimeMapping(String title, {String? animeId, int? malId}) async {
    final clean = cleanTitleForMatching(title).toLowerCase();
    _titleMatchCache.remove(clean);
    _titleMatchCache.remove(title.trim().toLowerCase());
    if (animeId != null && animeId.trim().isNotEmpty) {
      _titleMatchCache.remove(animeId.trim().toLowerCase());
    }
    if (malId != null) {
      _malToLocalAnimeMap.remove(malId);
      _titleMatchCache.removeWhere((k, v) => v == malId);
      unawaited(_saveMalToLocalAnimeMap());
      unawaited(_syncMappingToMalCloud(malId: malId, localId: null, isAnime: true));
    } else {
      final cachedId = _titleMatchCache[clean] ?? _titleMatchCache[title.trim().toLowerCase()];
      if (cachedId != null) {
        _malToLocalAnimeMap.remove(cachedId);
        _titleMatchCache.removeWhere((k, v) => v == cachedId);
        unawaited(_saveMalToLocalAnimeMap());
        unawaited(_syncMappingToMalCloud(malId: cachedId, localId: null, isAnime: true));
      }
    }
    unawaited(_saveCacheToPrefs());
  }

  /// Hubungkan judul komik/manga secara manual ke MAL ID tertentu (termasuk slug comicSlug)
  /// [syncToCloud] jika bernilai true, akan menyimpan tag mapping ke akun MyAnimeList (Cloud)
  Future<void> setManualMangaMapping(
    String title,
    int malId, {
    String? comicSlug,
    bool syncToCloud = true,
  }) async {
    final clean = cleanMangaTitleForMatching(title).toLowerCase();
    _cacheMangaMatch(clean, malId);
    _cacheMangaMatch(title.trim().toLowerCase(), malId);
    if (comicSlug != null && comicSlug.trim().isNotEmpty) {
      final cleanSlug = comicSlug.trim().toLowerCase();
      _cacheMangaMatch(cleanSlug, malId);
      _malToLocalMangaMap[malId] = comicSlug.trim();
      unawaited(_saveMalToLocalMangaMap());
      if (syncToCloud) {
        unawaited(_syncMappingToMalCloud(malId: malId, localId: comicSlug.trim(), isAnime: false));
      }
    }
  }

  Future<void> _saveMalToLocalMangaMap() async {
    try {
      final prefs = await _getPrefs();
      final mapToSave = _malToLocalMangaMap.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString(_kMalToLocalMangaMatches, jsonEncode(mapToSave));
    } catch (_) {}
  }

  /// Memutuskan / mereset hubungan komik ke MAL ID tertentu
  Future<void> removeManualMangaMapping(String title, {String? comicSlug, int? malId}) async {
    final clean = cleanMangaTitleForMatching(title).toLowerCase();
    _mangaTitleMatchCache.remove(clean);
    _mangaTitleMatchCache.remove(title.trim().toLowerCase());
    if (comicSlug != null && comicSlug.trim().isNotEmpty) {
      _mangaTitleMatchCache.remove(comicSlug.trim().toLowerCase());
    }
    if (malId != null) {
      _malToLocalMangaMap.remove(malId);
      _mangaTitleMatchCache.removeWhere((k, v) => v == malId);
      unawaited(_saveMalToLocalMangaMap());
      unawaited(_syncMappingToMalCloud(malId: malId, localId: null, isAnime: false));
    } else {
      final cachedId = _mangaTitleMatchCache[clean] ?? _mangaTitleMatchCache[title.trim().toLowerCase()];
      if (cachedId != null) {
        _malToLocalMangaMap.remove(cachedId);
        _mangaTitleMatchCache.removeWhere((k, v) => v == cachedId);
        unawaited(_saveMalToLocalMangaMap());
        unawaited(_syncMappingToMalCloud(malId: cachedId, localId: null, isAnime: false));
      }
    }
    unawaited(_saveMangaCacheToPrefs());
  }

  /// Sinkronkan pemetaan judul kustom ke cloud MyAnimeList (via tags)
  /// sehingga otomatis tersimpan di akun dan terbaca di semua device (HP, Windows, dll)
  Future<void> _syncMappingToMalCloud({
    required int malId,
    required String? localId,
    required bool isAnime,
  }) async {
    if (!hasOAuth || _accessToken == null || _accessToken!.isEmpty) return;

    try {
      final endpoint = isAnime ? '$_malApiBase/anime/$malId' : '$_malApiBase/manga/$malId';
      final res = await _dio.get(
        endpoint,
        queryParameters: {'fields': 'my_list_status{tags}'},
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );

      final existingTags = <String>[];
      if (res.statusCode == 200 && res.data != null) {
        final rawTags = res.data['my_list_status']?['tags'];
        if (rawTags is List) {
          for (final t in rawTags) {
            if (t != null && t.toString().isNotEmpty) existingTags.add(t.toString());
          }
        }
      }

      final tagPrefix = isAnime ? 'moko_anime:' : 'moko_manga:';
      final altPrefix = isAnime ? 'moko:' : 'moko_comic:';

      existingTags.removeWhere((t) {
        final l = t.toLowerCase();
        return l.startsWith(tagPrefix) || l.startsWith(altPrefix);
      });

      if (localId != null && localId.trim().isNotEmpty) {
        existingTags.add('$tagPrefix${localId.trim()}');
      }

      final putEndpoint = isAnime
          ? '$_malApiBase/anime/$malId/my_list_status'
          : '$_malApiBase/manga/$malId/my_list_status';

      await _dio.put(
        putEndpoint,
        data: {'tags': existingTags.join(',')},
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      debugPrint('[MAL Cloud] Sukses sinkron pemetaan $malId -> $localId ke akun MAL!');
    } catch (e) {
      debugPrint('[MAL Cloud] Gagal sinkron pemetaan ke akun MAL: $e');
    }
  }

  /// Cari daftar anime dari MyAnimeList untuk pemilihan manual (mendukung nama, ID angka, atau URL MAL)
  Future<List<MalAnimeItem>> searchMalAnime(String query, {int limit = 20}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    // 0. Dukungan direct MAL ID atau URL (contoh: 62018 atau https://myanimelist.net/anime/62018/...)
    int? directMalId;
    final urlMatch = RegExp(r'myanimelist\.net/anime/(\d+)').firstMatch(clean);
    if (urlMatch != null) {
      directMalId = int.tryParse(urlMatch.group(1)!);
    } else {
      directMalId = int.tryParse(clean);
    }

    if (directMalId != null) {
      final directItem = await getAnimeDetails(directMalId);
      if (directItem != null) {
        return [directItem];
      }
    }

    try {
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/anime',
          queryParameters: {
            'q': clean,
            'limit': limit,
            'nsfw': 'true', // Mengizinkan semua kategori termasuk 18+/ecchi
            'fields': 'id,title,main_picture,alternative_titles,num_episodes,mean,status,synopsis,my_list_status{status,score,num_episodes_watched,is_rewatching,updated_at}',
          },
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          final list = res.data['data'] as List;
          return list
              .where((e) => e is Map && e['node'] is Map)
              .map((e) => MalAnimeItem.fromJson(Map<String, dynamic>.from(e['node'] as Map)))
              .toList();
        }
      }

      final jikanRes = await _dio.get(
        '$_jikanApiBase/anime',
        queryParameters: {
          'q': clean,
          'limit': limit,
          'sfw': false,
        },
      );

      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] is List) {
        final list = jikanRes.data['data'] as List;
        return list
            .whereType<Map>()
            .map((e) => MalAnimeItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('[MAL] Error searchMalAnime "$clean": $e');
    }
    return [];
  }

  /// Cari daftar komik/manga dari MyAnimeList untuk pemilihan manual (mendukung nama, ID angka, atau URL MAL)
  Future<List<MalMangaItem>> searchMalManga(String query, {int limit = 20}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    // 0. Dukungan direct Manga ID atau URL (contoh: 1234 atau https://myanimelist.net/manga/1234/...)
    int? directMangaId;
    final urlMatch = RegExp(r'myanimelist\.net/manga/(\d+)').firstMatch(clean);
    if (urlMatch != null) {
      directMangaId = int.tryParse(urlMatch.group(1)!);
    } else {
      directMangaId = int.tryParse(clean);
    }

    if (directMangaId != null) {
      final directItem = await getMangaDetails(directMangaId);
      if (directItem != null) {
        return [directItem];
      }
    }

    try {
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/manga',
          queryParameters: {
            'q': clean,
            'limit': limit,
            'nsfw': 'true',
            'fields': 'id,title,main_picture,alternative_titles,num_chapters,num_volumes,mean,status,synopsis,my_list_status{status,score,num_chapters_read,num_volumes_read,is_rereading,updated_at}',
          },
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          final list = res.data['data'] as List;
          return list
              .where((e) => e is Map && e['node'] is Map)
              .map((e) => MalMangaItem.fromJson(Map<String, dynamic>.from(e['node'] as Map)))
              .toList();
        }
      }

      final jikanRes = await _dio.get(
        '$_jikanApiBase/manga',
        queryParameters: {
          'q': clean,
          'limit': limit,
          'sfw': false,
        },
      );

      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] is List) {
        final list = jikanRes.data['data'] as List;
        return list
            .whereType<Map>()
            .map((e) => MalMangaItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('[MAL] Error searchMalManga "$clean": $e');
    }
    return [];
  }

  Future<void> _saveCacheToPrefs() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_kCachedMatches, jsonEncode(_titleMatchCache));
    } catch (_) {}
  }

  /// Detail anime berdasarkan MAL ID
  Future<MalAnimeItem?> getAnimeDetails(int malId) async {
    try {
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/anime/$malId?fields=id,title,main_picture,alternative_titles,num_episodes,mean,status,synopsis,my_list_status{status,score,num_episodes_watched,is_rewatching,updated_at}',
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );
        if (res.statusCode == 200 && res.data != null) {
          return MalAnimeItem.fromJson(res.data);
        }
      }

      final jikanRes = await _dio.get('$_jikanApiBase/anime/$malId/full');
      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] != null) {
        return MalAnimeItem.fromJson(jikanRes.data['data']);
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // AUTO-SCROBBLE & STATUS UPDATE
  // ─────────────────────────────────────────────────────────────

  /// Scrobble tontonan: otomatis update episode ke profil MAL saat nonton
  Future<bool> scrobbleEpisode({
    required String animeTitle,
    String? animeId,
    required int episodeNumber,
    bool isCompleted = false,
    int? totalEpisodes,
  }) async {
    if (!isConnected || !isAutoScrobbleEnabled) return false;
    if (!hasOAuth) {
      // Tidak ada OAuth token untuk menulis data ke akun pengguna
      return false;
    }

    try {
      final malAnime = await findMalAnime(animeTitle, animeId: animeId);
      if (malAnime == null) return false;

      final finalStatus = (isCompleted || (totalEpisodes != null && episodeNumber >= totalEpisodes))
          ? 'completed'
          : 'watching';

      return await updateAnimeStatus(
        malId: malAnime.id,
        status: finalStatus,
        episodesWatched: episodeNumber,
      );
    } catch (e) {
      debugPrint('[MAL] Gagal scrobble episode: $e');
    }
    return false;
  }

  /// Update status anime di daftar pengguna MAL
  Future<bool> updateAnimeStatus({
    required int malId,
    required String status,
    int? episodesWatched,
    int? score,
  }) async {
    if (_accessToken == null || _accessToken!.isEmpty) return false;

    try {
      final data = <String, dynamic>{
        'status': status,
        if (episodesWatched != null) 'num_watched_episodes': episodesWatched,
        if (score != null) 'score': score,
      };

      try {
        final res = await _dio.put(
          '$_malApiBase/anime/$malId/my_list_status',
          data: data,
          options: Options(
            headers: {'Authorization': 'Bearer $_accessToken'},
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
        if (res.statusCode == 200) {
          debugPrint('[MAL] Sukses update anime $malId: $status, ep $episodesWatched');
          return true;
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          // Token expired, coba refresh
          debugPrint('[MAL] Token kadaluwarsa, mencoba refresh token...');
          final refreshed = await refreshToken();
          if (refreshed && _accessToken != null) {
            final retryRes = await _dio.put(
              '$_malApiBase/anime/$malId/my_list_status',
              data: data,
              options: Options(
                headers: {'Authorization': 'Bearer $_accessToken'},
                contentType: Headers.formUrlEncodedContentType,
              ),
            );
            return retryRes.statusCode == 200;
          }
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('[MAL] Gagal update status di MAL: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // USER WATCHLIST & LOCAL CATALOG MATCHING
  // ─────────────────────────────────────────────────────────────

  /// Ambil daftar anime pengguna (Watching, Plan to Watch, Completed, dll)
  /// dan otomatis periksa apakah anime tersebut tersedia di server Animeverse
  Future<List<MalAnimeListEntry>> getUserWatchlist({String? status}) async {
    final list = <MalAnimeListEntry>[];

    try {
      // 1. Jika terhubung via OAuth, gunakan endpoint resmi MAL
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final query = <String, dynamic>{
          'fields': 'list_status{status,score,num_episodes_watched,is_rewatching,updated_at,tags,comments},num_episodes,mean,status,synopsis,alternative_titles',
          'limit': 100,
          if (status != null && status != 'all') 'status': status,
        };

        final res = await _dio.get(
          '$_malApiBase/users/@me/animelist',
          queryParameters: query,
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          for (final item in res.data['data']) {
            if (item['node'] != null) {
              list.add(MalAnimeListEntry.fromMalJson(item['node'], item['list_status']));
            }
          }
        }
      } else if (_username != null && _username!.isNotEmpty) {
        // 2. Fallback via Jikan user animelist
        final jikanStatus = (status == null || status == 'all') ? 'all' : status;
        final res = await _dio.get(
          '$_jikanApiBase/users/$_username/animelist/$jikanStatus',
        );
        if (res.statusCode == 200 && res.data?['data'] is List) {
          for (final item in res.data['data']) {
            list.add(MalAnimeListEntry.fromJikanJson(item));
          }
        }
      }

      // Sinkronkan pemetaan custom (yang tersimpan di akun MAL cloud) ke local memory
      for (final item in list) {
        final customId = item.customMappedId;
        if (customId != null && customId.isNotEmpty) {
          _malToLocalAnimeMap[item.anime.id] = customId;
          _titleMatchCache[customId.toLowerCase()] = item.anime.id;
        }
      }
      unawaited(_saveMalToLocalAnimeMap());

      // 3. Cocokkan ketersediaan anime dengan server Animeverse
      return await checkLocalAvailability(list);
    } catch (e) {
      debugPrint('[MAL] Gagal mengambil daftar tontonan: $e');
    }
    return list;
  }

  /// Mencari anime terbaik di server Animeverse dengan fallback judul alternatif & franchise
  Future<AnimeModel?> _findBestAnimeMatchOnServer(MalAnimeItem anime) async {
    final candidates = <String>{};

    final primaryClean = cleanTitleForMatching(anime.title);
    if (primaryClean.isNotEmpty) {
      candidates.add(primaryClean);
    }

    if (anime.title.contains(':')) {
      final beforeColon = cleanTitleForMatching(anime.title.split(':').first);
      if (beforeColon.length >= 3) candidates.add(beforeColon);
    }
    if (anime.title.contains(' - ')) {
      final beforeDash = cleanTitleForMatching(anime.title.split(' - ').first);
      if (beforeDash.length >= 3) candidates.add(beforeDash);
    }

    for (final alt in anime.alternativeTitles) {
      final cleanAlt = cleanTitleForMatching(alt);
      if (cleanAlt.isNotEmpty) {
        candidates.add(cleanAlt);
        if (alt.contains(':')) {
          final beforeColon = cleanTitleForMatching(alt.split(':').first);
          if (beforeColon.length >= 3) candidates.add(beforeColon);
        }
      }
    }

    for (final q in candidates) {
      try {
        final searchRes = await AnimeRepository.instance.search(q);
        if (searchRes.isNotEmpty) {
          final qLower = q.toLowerCase();
          final exact = searchRes.firstWhere(
            (item) => item.title.trim().toLowerCase() == qLower,
            orElse: () => searchRes.firstWhere(
              (item) => item.title.toLowerCase().contains(qLower) || qLower.contains(item.title.toLowerCase()),
              orElse: () => searchRes.first,
            ),
          );
          return exact;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Memeriksa ketersediaan anime di katalog Animeverse dan OTOMATIS menghubungkan (auto-map)
  /// agar langsung tersambung ke server sejak awal.
  Future<List<MalAnimeListEntry>> checkLocalAvailability(List<MalAnimeListEntry> entries) async {
    if (entries.isEmpty) return entries;
    final results = List<MalAnimeListEntry>.from(entries);

    const int maxConcurrent = 3;
    final queue = List.generate(entries.length, (i) => i);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final index = queue.removeAt(0);
        final entry = entries[index];
        try {
          if (hasLocalMappingForMalId(entry.anime.id)) {
            results[index] = entry.copyWith(isAvailableLocally: true);
            continue;
          }
          final match = await _findBestAnimeMatchOnServer(entry.anime);
          if (match != null) {
            // 🔥 OTOMATIS HUBUNGKAN KE SERVER SEJAK AWAL (hanya local, jangan spam cloud)
            await setManualAnimeMapping(match.title, entry.anime.id, animeId: match.id, syncToCloud: false);
            results[index] = entry.copyWith(isAvailableLocally: true);
          } else {
            results[index] = entry.copyWith(isAvailableLocally: false);
          }
        } catch (_) {
          results[index] = entry.copyWith(isAvailableLocally: false);
        }
      }
    }

    final workers = List.generate(
      maxConcurrent.clamp(1, entries.length),
      (_) => worker(),
    );
    await Future.wait(workers);
    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // MANGA / KOMIK SYNC & MATCHING
  // ─────────────────────────────────────────────────────────────

  /// Pembersihan judul komik untuk pencarian akurat di MAL Manga
  static String cleanMangaTitleForMatching(String title) {
    var s = title.trim();
    // Hilangkan tag kurung siku & biasa
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    // Hilangkan kata-kata umum scraper komik
    s = s.replaceAll(
      RegExp(r'\b(Baca\s*Komik|Baca\s*Manga|Bahasa\s*Indonesia|Indo|Sub\s*Indo|Komik|Manga|Manhwa|Manhua|Color|Warna|Batch|Chapter\s*\d+|Ch\s*\d+)\b', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Mencocokkan judul komik dengan ID MyAnimeList Manga
  Future<MalMangaItem?> findMalManga(String title, {String? comicSlug}) async {
    if (comicSlug != null && comicSlug.trim().isNotEmpty) {
      final slugKey = comicSlug.trim().toLowerCase();
      if (_mangaTitleMatchCache.containsKey(slugKey)) {
        final cachedId = _mangaTitleMatchCache[slugKey]!;
        final details = await getMangaDetails(cachedId);
        if (details != null) return details;
      }
    }
    final rawKey = title.trim().toLowerCase();
    if (_mangaTitleMatchCache.containsKey(rawKey)) {
      final cachedId = _mangaTitleMatchCache[rawKey]!;
      final details = await getMangaDetails(cachedId);
      if (details != null) return details;
    }

    final clean = cleanMangaTitleForMatching(title);
    if (clean.isEmpty) return null;

    final cacheKey = clean.toLowerCase();
    if (_mangaTitleMatchCache.containsKey(cacheKey)) {
      final cachedId = _mangaTitleMatchCache[cacheKey]!;
      return getMangaDetails(cachedId);
    }

    try {
      // 1. Official MAL API jika ada token
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/manga',
          queryParameters: {
            'q': clean,
            'limit': 5,
            'nsfw': 'true',
            'fields': 'id,title,main_picture,alternative_titles,num_chapters,num_volumes,mean,status,synopsis,my_list_status{status,score,num_chapters_read,is_rereading,updated_at}',
          },
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          final list = res.data['data'] as List;
          if (list.isNotEmpty) {
            final node = list.first['node'] as Map<String, dynamic>;
            final item = MalMangaItem.fromJson(node);
            _cacheMangaMatch(cacheKey, item.id);
            _cacheMangaMatch(rawKey, item.id);
            if (comicSlug != null && comicSlug.trim().isNotEmpty) {
              _cacheMangaMatch(comicSlug.trim().toLowerCase(), item.id);
            }
            return item;
          }
        }
      }

      // 2. Fallback via Jikan v4
      final jikanRes = await _dio.get(
        '$_jikanApiBase/manga',
        queryParameters: {'q': clean, 'limit': 3, 'sfw': false},
      );

      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] is List) {
        final list = jikanRes.data['data'] as List;
        if (list.isNotEmpty) {
          final item = MalMangaItem.fromJson(list.first as Map<String, dynamic>);
          _cacheMangaMatch(cacheKey, item.id);
          _cacheMangaMatch(rawKey, item.id);
          if (comicSlug != null && comicSlug.trim().isNotEmpty) {
            _cacheMangaMatch(comicSlug.trim().toLowerCase(), item.id);
          }
          return item;
        }
      }
    } catch (e) {
      debugPrint('[MAL] Gagal mencari manga "$clean": $e');
    }
    return null;
  }

  void _cacheMangaMatch(String key, int malId) {
    _mangaTitleMatchCache[key] = malId;
    _saveMangaCacheToPrefs();
  }

  Future<void> _saveMangaCacheToPrefs() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_kCachedMangaMatches, jsonEncode(_mangaTitleMatchCache));
    } catch (_) {}
  }

  /// Detail manga berdasarkan MAL ID
  Future<MalMangaItem?> getMangaDetails(int malId) async {
    try {
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final res = await _dio.get(
          '$_malApiBase/manga/$malId?fields=id,title,main_picture,alternative_titles,num_chapters,num_volumes,mean,status,synopsis,my_list_status{status,score,num_chapters_read,is_rereading,updated_at}',
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );
        if (res.statusCode == 200 && res.data != null) {
          return MalMangaItem.fromJson(res.data);
        }
      }

      final jikanRes = await _dio.get('$_jikanApiBase/manga/$malId/full');
      if (jikanRes.statusCode == 200 && jikanRes.data?['data'] != null) {
        return MalMangaItem.fromJson(jikanRes.data['data']);
      }
    } catch (_) {}
    return null;
  }

  /// Auto-Scrobble membaca komik/chapter
  Future<bool> scrobbleChapter({
    required String comicTitle,
    String? comicSlug,
    required int chapterNumber,
    bool isCompleted = false,
    int? totalChapters,
  }) async {
    if (!isConnected || !isAutoScrobbleEnabled) return false;
    if (!hasOAuth) return false;

    try {
      final malManga = await findMalManga(comicTitle, comicSlug: comicSlug);
      if (malManga == null) return false;

      final finalStatus = (isCompleted || (totalChapters != null && chapterNumber >= totalChapters))
          ? 'completed'
          : 'reading';

      return await updateMangaStatus(
        malId: malManga.id,
        status: finalStatus,
        chaptersRead: chapterNumber,
      );
    } catch (e) {
      debugPrint('[MAL] Gagal scrobble chapter komik: $e');
    }
    return false;
  }

  /// Update status komik di daftar pengguna MAL
  Future<bool> updateMangaStatus({
    required int malId,
    required String status,
    int? chaptersRead,
    int? score,
  }) async {
    if (_accessToken == null || _accessToken!.isEmpty) return false;

    try {
      final data = <String, dynamic>{
        'status': status,
        if (chaptersRead != null) 'num_chapters_read': chaptersRead,
        if (score != null) 'score': score,
      };

      try {
        final res = await _dio.put(
          '$_malApiBase/manga/$malId/my_list_status',
          data: data,
          options: Options(
            headers: {'Authorization': 'Bearer $_accessToken'},
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
        if (res.statusCode == 200) {
          debugPrint('[MAL] Sukses update komik $malId: $status, ch $chaptersRead');
          return true;
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          debugPrint('[MAL] Token kadaluwarsa saat update manga, mencoba refresh token...');
          final refreshed = await refreshToken();
          if (refreshed && _accessToken != null) {
            final retryRes = await _dio.put(
              '$_malApiBase/manga/$malId/my_list_status',
              data: data,
              options: Options(
                headers: {'Authorization': 'Bearer $_accessToken'},
                contentType: Headers.formUrlEncodedContentType,
              ),
            );
            return retryRes.statusCode == 200;
          }
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('[MAL] Gagal update status komik di MAL: $e');
    }
    return false;
  }

  /// Ambil daftar manga pengguna dari MAL
  Future<List<MalMangaListEntry>> getUserMangaWatchlist({String? status}) async {
    final list = <MalMangaListEntry>[];

    try {
      // 1. Official MAL API
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final query = <String, dynamic>{
          'fields': 'list_status{status,score,num_chapters_read,num_volumes_read,is_rereading,updated_at,tags,comments},num_chapters,num_volumes,mean,status,synopsis,alternative_titles',
          'limit': 100,
          if (status != null && status != 'all') 'status': status,
        };

        final res = await _dio.get(
          '$_malApiBase/users/@me/mangalist',
          queryParameters: query,
          options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
        );

        if (res.statusCode == 200 && res.data?['data'] is List) {
          for (final item in res.data['data']) {
            if (item['node'] != null) {
              list.add(MalMangaListEntry.fromMalJson(item['node'], item['list_status']));
            }
          }
        }
      } else if (_username != null && _username!.isNotEmpty) {
        // 2. Fallback via Jikan user mangalist
        final jikanStatus = (status == null || status == 'all') ? 'all' : status;
        final res = await _dio.get(
          '$_jikanApiBase/users/$_username/mangalist/$jikanStatus',
        );
        if (res.statusCode == 200 && res.data?['data'] is List) {
          for (final item in res.data['data']) {
            list.add(MalMangaListEntry.fromJikanJson(item));
          }
        }
      }

      // Sinkronkan pemetaan custom komik (yang tersimpan di akun MAL cloud) ke local memory
      for (final item in list) {
        final customSlug = item.customMappedSlug;
        if (customSlug != null && customSlug.isNotEmpty) {
          _malToLocalMangaMap[item.manga.id] = customSlug;
          _mangaTitleMatchCache[customSlug.toLowerCase()] = item.manga.id;
        }
      }
      unawaited(_saveMalToLocalMangaMap());

      // 3. Cocokkan ketersediaan manga di katalog server
      return await checkMangaLocalAvailability(list);
    } catch (e) {
      debugPrint('[MAL] Gagal mengambil daftar komik: $e');
    }
    return list;
  }

  /// Mencari komik terbaik di server Comicverse dengan fallback judul alternatif & franchise
  Future<ComicModel?> _findBestMangaMatchOnServer(MalMangaItem manga) async {
    final candidates = <String>{};

    final primaryClean = cleanMangaTitleForMatching(manga.title);
    if (primaryClean.isNotEmpty) {
      candidates.add(primaryClean);
    }

    if (manga.title.contains(':')) {
      final beforeColon = cleanMangaTitleForMatching(manga.title.split(':').first);
      if (beforeColon.length >= 3) candidates.add(beforeColon);
    }
    if (manga.title.contains(' - ')) {
      final beforeDash = cleanMangaTitleForMatching(manga.title.split(' - ').first);
      if (beforeDash.length >= 3) candidates.add(beforeDash);
    }

    for (final alt in manga.alternativeTitles) {
      final cleanAlt = cleanMangaTitleForMatching(alt);
      if (cleanAlt.isNotEmpty) {
        candidates.add(cleanAlt);
        if (alt.contains(':')) {
          final beforeColon = cleanMangaTitleForMatching(alt.split(':').first);
          if (beforeColon.length >= 3) candidates.add(beforeColon);
        }
      }
    }

    for (final q in candidates) {
      try {
        final searchRes = await ComicRepository.instance.search(q);
        if (searchRes.isNotEmpty) {
          final qLower = q.toLowerCase();
          final exact = searchRes.firstWhere(
            (item) => item.title.trim().toLowerCase() == qLower,
            orElse: () => searchRes.firstWhere(
              (item) => item.title.toLowerCase().contains(qLower) || qLower.contains(item.title.toLowerCase()),
              orElse: () => searchRes.first,
            ),
          );
          return exact;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Memeriksa ketersediaan komik di katalog Animeverse dan OTOMATIS menghubungkan (auto-map)
  /// agar langsung tersambung ke server sejak awal.
  Future<List<MalMangaListEntry>> checkMangaLocalAvailability(List<MalMangaListEntry> entries) async {
    if (entries.isEmpty) return entries;
    final results = List<MalMangaListEntry>.from(entries);

    const int maxConcurrent = 3;
    final queue = List.generate(entries.length, (i) => i);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final index = queue.removeAt(0);
        final entry = entries[index];
        try {
          if (hasLocalMangaMappingForMalId(entry.manga.id)) {
            results[index] = entry.copyWith(isAvailableLocally: true);
            continue;
          }
          final match = await _findBestMangaMatchOnServer(entry.manga);
          if (match != null) {
            // 🔥 OTOMATIS HUBUNGKAN KE KOMIK SERVER SEJAK AWAL (hanya local, jangan spam cloud)
            await setManualMangaMapping(match.title, entry.manga.id, comicSlug: match.slug, syncToCloud: false);
            results[index] = entry.copyWith(isAvailableLocally: true);
          } else {
            results[index] = entry.copyWith(isAvailableLocally: false);
          }
        } catch (_) {
          results[index] = entry.copyWith(isAvailableLocally: false);
        }
      }
    }

    final workers = List.generate(
      maxConcurrent.clamp(1, entries.length),
      (_) => worker(),
    );
    await Future.wait(workers);
    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // FULL BIDIRECTIONAL SYNC (MOKO <-> MYANIMELIST)
  // ─────────────────────────────────────────────────────────────

  /// Sinkronisasi menyeluruh antara riwayat tontonan/bacaan lokal Moko dengan akun MyAnimeList.
  /// Sangat optimal dijalankan otomatis saat pengguna baru pertama kali menghubungkan akun MAL.
  Future<MalSyncReport> syncWithMal({
    bool uploadLocalToMal = true,
    bool importMalToLocal = true,
  }) async {
    if (!isConnected) {
      return MalSyncReport(
        success: false,
        errorMessage: 'Akun MyAnimeList belum terhubung.',
        timestamp: DateTime.now(),
      );
    }

    if (isSyncingNotifier.value) {
      return lastSyncReportNotifier.value ??
          MalSyncReport(
            success: false,
            errorMessage: 'Sinkronisasi sedang berlangsung.',
            timestamp: DateTime.now(),
          );
    }

    isSyncingNotifier.value = true;
    syncStatusMessageNotifier.value = 'Menyiapkan sinkronisasi...';

    int animeUploaded = 0;
    int mangaUploaded = 0;
    int animeImported = 0;
    int mangaImported = 0;
    final logs = <String>[];

    try {
      // 1. Unggah riwayat tontonan anime lokal ke akun MyAnimeList
      if (uploadLocalToMal && hasOAuth) {
        syncStatusMessageNotifier.value = 'Menyinkronkan tontonan anime ke MyAnimeList...';
        final recentAnime = await AnimeWatchProgressService.instance.getRecentAnimeHistoryMaps(limit: 100);

        for (final item in recentAnime) {
          try {
            final title = item['animeTitle']?.toString() ?? item['animeId']?.toString() ?? '';
            final animeId = item['animeId']?.toString();
            final epStr = AnimeWatchProgressService.extractEpisodeNumber(item['episodeId']?.toString()) ??
                AnimeWatchProgressService.extractEpisodeNumber(item['episodeUrl']?.toString()) ??
                AnimeWatchProgressService.extractEpisodeNumber(item['episodeLabel']?.toString());
            final epNum = int.tryParse(epStr ?? '') ?? 0;
            final isCompleted = item['isCompleted'] == true;

            if (epNum > 0 && title.isNotEmpty) {
              final malAnime = await findMalAnime(title, animeId: animeId);
              if (malAnime != null) {
                final malWatched = malAnime.myListStatus?.numEpisodesWatched ?? 0;
                // Hanya update jika episode lokal lebih besar atau sama
                if (epNum >= malWatched) {
                  final status = isCompleted ? 'completed' : 'watching';
                  final ok = await updateAnimeStatus(
                    malId: malAnime.id,
                    status: status,
                    episodesWatched: epNum,
                  );
                  if (ok) {
                    animeUploaded++;
                    logs.add('Anime: $title -> Ep $epNum ($status)');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[MAL Sync] Gagal sync anime: $e');
          }
        }

        // 2. Unggah riwayat bacaan komik lokal ke akun MyAnimeList
        syncStatusMessageNotifier.value = 'Menyinkronkan bacaan komik ke MyAnimeList...';
        final recentComics = await ComicReadProgressService.instance.getAllReadComics();

        for (final c in recentComics) {
          try {
            final title = c.comicTitle ?? c.comicSlug;
            final chNum = ComicReadProgressService.extractChapterNumber(c.chapterLabel) ??
                ComicReadProgressService.extractChapterNumber(c.chapterId) ??
                0;

            if (chNum > 0 && title.isNotEmpty) {
              final malManga = await findMalManga(title, comicSlug: c.comicSlug);
              if (malManga != null) {
                final malRead = malManga.myListStatus?.numChaptersRead ?? 0;
                if (chNum >= malRead) {
                  final status = c.isCompleted ? 'completed' : 'reading';
                  final ok = await updateMangaStatus(
                    malId: malManga.id,
                    status: status,
                    chaptersRead: chNum,
                  );
                  if (ok) {
                    mangaUploaded++;
                    logs.add('Komik: $title -> Ch $chNum ($status)');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[MAL Sync] Gagal sync komik: $e');
          }
        }
      }

      // 3. Impor dari MyAnimeList ke lokal jika lokal belum punya riwayat
      if (importMalToLocal) {
        syncStatusMessageNotifier.value = 'Mengambil daftar anime dari MyAnimeList...';
        final malAnimeList = await getUserWatchlist(status: 'all');

        for (final entry in malAnimeList) {
          try {
            if (entry.numWatchedEpisodes > 0) {
              String? localId = getLocalAnimeIdForMalId(entry.anime.id);
              if (localId == null || localId.isEmpty) {
                final searchRes = await AnimeRepository.instance.search(cleanTitleForMatching(entry.anime.title));
                if (searchRes.isNotEmpty) {
                  localId = searchRes.first.id;
                  await setManualAnimeMapping(entry.anime.title, entry.anime.id, animeId: localId, syncToCloud: false);
                }
              }

              if (localId != null && localId.isNotEmpty) {
                final existing = await AnimeWatchProgressService.instance.getLastWatchedAnime(localId);
                final existingEpStr = existing != null
                    ? (AnimeWatchProgressService.extractEpisodeNumber(existing.episodeId) ??
                        AnimeWatchProgressService.extractEpisodeNumber(existing.episodeLabel))
                    : null;
                final existingEp = int.tryParse(existingEpStr ?? '') ?? 0;

                if (existingEp < entry.numWatchedEpisodes) {
                  await AnimeWatchProgressService.instance.saveProgress(
                    animeId: localId,
                    episodeId: 'ep_${entry.numWatchedEpisodes}',
                    episodeLabel: 'Episode ${entry.numWatchedEpisodes}',
                    animeTitle: entry.anime.title,
                    thumb: entry.anime.mainPicture,
                    positionSeconds: 1200,
                    totalDurationSeconds: 1200,
                  );
                  animeImported++;
                }
              }
            }
          } catch (e) {
            debugPrint('[MAL Sync] Gagal impor anime: $e');
          }
        }
      }

      final now = DateTime.now();
      _lastSyncTimeMillis = now.millisecondsSinceEpoch;
      final prefs = await _getPrefs();
      await prefs.setInt(_kLastSyncTime, _lastSyncTimeMillis!);

      final report = MalSyncReport(
        animeUploaded: animeUploaded,
        mangaUploaded: mangaUploaded,
        animeImported: animeImported,
        mangaImported: mangaImported,
        logs: logs,
        success: true,
        timestamp: now,
      );

      lastSyncReportNotifier.value = report;
      return report;
    } catch (e) {
      debugPrint('[MAL] Error saat syncWithMal: $e');
      final report = MalSyncReport(
        success: false,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
      lastSyncReportNotifier.value = report;
      return report;
    } finally {
      isSyncingNotifier.value = false;
      syncStatusMessageNotifier.value = null;
    }
  }
}
