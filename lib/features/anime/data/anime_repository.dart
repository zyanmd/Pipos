import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_error_formatter.dart';
import './models/anime_model.dart';
import './models/ylnime_extra_models.dart';
import './models/genre_role_model.dart';

class AnimeRepository {
  AnimeRepository._();
  static final AnimeRepository instance = AnimeRepository._();

  Map<String, dynamic>? _cachedHome;
  DateTime? _cachedHomeTime;
  Future<Map<String, dynamic>>? _inFlightHome;

  TodayScheduleModel? _cachedScheduleToday;
  DateTime? _cachedScheduleTodayTime;
  Future<TodayScheduleModel>? _inFlightScheduleToday;

  List<AnimeModel>? _cachedCompletedP1;
  DateTime? _cachedCompletedP1Time;
  Future<List<AnimeModel>>? _inFlightCompletedP1;

  List<AnimeModel>? _cachedMovies;
  DateTime? _cachedMoviesTime;
  Future<List<AnimeModel>>? _inFlightMovies;

  HyperPageData? _cachedHyper;
  DateTime? _cachedHyperTime;
  Future<HyperPageData?>? _inFlightHyper;

  final Map<String, ({PollingPageData data, DateTime time})> _cachedPolling = {};
  final Map<String, Future<PollingPageData?>> _inFlightPolling = {};

  bool get hasCachedHome => _cachedHome != null && _cachedHome!.isNotEmpty;
  Map<String, dynamic>? get cachedHome => _cachedHome;
  TodayScheduleModel? get cachedScheduleToday => _cachedScheduleToday;

  /// Prefetch home and today's schedule during startup
  void prefetchHome() {
    home().catchError((_) => <String, dynamic>{});
    scheduleToday().catchError((_) => const TodayScheduleModel());
  }

  /// Home page: featured + ongoing + completed with memory caching & in-flight deduplication.
  Future<Map<String, dynamic>> home({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHome != null && _cachedHomeTime != null) {
      if (DateTime.now().difference(_cachedHomeTime!) < const Duration(minutes: 5)) {
        return _cachedHome!;
      }
    }

    if (!forceRefresh && _inFlightHome != null) {
      return _inFlightHome!;
    }

    final future = () async {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.animeHome);
        final raw = resp.data;
        if (raw is Map) {
          final rawData = raw['data'];
          if (rawData is Map) {
            final rawMap = Map<String, dynamic>.from(rawData);
            _cachedHome = rawMap;
            _cachedHomeTime = DateTime.now();
            return rawMap;
          } else if (rawData is List) {
            final list = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final mapped = <String, dynamic>{
              'carousel': list.take(8).toList(),
              'ongoing': list,
              'ongoing_anime': list,
              'latest': list,
              'new_releases': list,
              'data': list,
            };
            _cachedHome = mapped;
            _cachedHomeTime = DateTime.now();
            return mapped;
          }
        }
        final data = _unwrap(resp.data);
        final map = _asMap(data);
        if (map.isNotEmpty) {
          _cachedHome = map;
          _cachedHomeTime = DateTime.now();
        }
        return map;
      } finally {
        _inFlightHome = null;
      }
    }();

    _inFlightHome = future;
    return future;
  }

  Future<List<AnimeModel>> ongoing({int page = 1}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.animeOngoing,
      queryParameters: {'page': page},
    );
    return _asList(resp.data).map((e) => AnimeModel.fromJson(e)).toList();
  }

  Future<List<AnimeModel>> completed({int page = 1, bool forceRefresh = false}) async {
    if (page == 1 && !forceRefresh && _cachedCompletedP1 != null && _cachedCompletedP1Time != null) {
      if (DateTime.now().difference(_cachedCompletedP1Time!) < const Duration(minutes: 10)) {
        return _cachedCompletedP1!;
      }
    }
    if (page == 1 && !forceRefresh && _inFlightCompletedP1 != null) {
      return _inFlightCompletedP1!;
    }

    final future = () async {
      try {
        final resp = await ApiClient.instance.get(
          ApiEndpoints.animeCompleted,
          queryParameters: {'page': page},
        );
        final unwrapped = _unwrap(resp.data);
        final res = _asList(unwrapped).map((e) => AnimeModel.fromJson(e)).toList();
        if (page == 1 && res.isNotEmpty) {
          _cachedCompletedP1 = res;
          _cachedCompletedP1Time = DateTime.now();
        }
        return res;
      } finally {
        if (page == 1) _inFlightCompletedP1 = null;
      }
    }();

    if (page == 1) _inFlightCompletedP1 = future;
    return future;
  }

  /// Today's airing anime schedule (/ylnime/schedule/today) with memory caching & in-flight deduplication.
  Future<TodayScheduleModel> scheduleToday({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedScheduleToday != null && _cachedScheduleTodayTime != null) {
      if (DateTime.now().difference(_cachedScheduleTodayTime!) < const Duration(minutes: 5)) {
        return _cachedScheduleToday!;
      }
    }

    if (!forceRefresh && _inFlightScheduleToday != null) {
      return _inFlightScheduleToday!;
    }

    final future = () async {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.animeScheduleToday);
        final unwrapped = _unwrap(resp.data);
        if (unwrapped is Map) {
          final res = TodayScheduleModel.fromJson(Map<String, dynamic>.from(unwrapped));
          _cachedScheduleToday = res;
          _cachedScheduleTodayTime = DateTime.now();
          return res;
        }
      } catch (_) {
      } finally {
        _inFlightScheduleToday = null;
      }
      return const TodayScheduleModel();
    }();

    _inFlightScheduleToday = future;
    return future;
  }

  Future<List<ScheduleModel>> schedule() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.animeSchedule);
    final unwrapped = _unwrap(resp.data);
    final list = _asList(unwrapped);
    if (list.isEmpty) {
      // Maybe it's { data: { schedule: { ... } } } or { day: [...] } shape
      final m = _asMap(unwrapped);
      final schedMap = m['schedule'] is Map ? Map<String, dynamic>.from(m['schedule'] as Map) : m;
      return schedMap.entries
          .map((e) => ScheduleModel(day: e.key, items: _toAnimeList(e.value)))
          .toList();
    }
    return list.map((e) => ScheduleModel.fromJson(e)).toList();
  }

  Future<List<GenreModel>> genres() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.animeGenres);
    final unwrapped = _unwrap(resp.data);
    final list = _asList(unwrapped);
    if (list.isEmpty && unwrapped is Map && unwrapped['genres'] is List) {
      return (unwrapped['genres'] as List)
          .map((e) => GenreModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return list.map((e) => GenreModel.fromJson(e)).toList();
  }

  Future<List<AnimeModel>> byGenre(String slug, {int page = 1}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.animeByGenre(slug),
      queryParameters: {'page': page},
    );
    return _asList(resp.data).map((e) => AnimeModel.fromJson(e)).toList();
  }

  final Map<String, AnimeDetailModel> _detailCache = {};
  final Map<String, DateTime> _detailCacheTime = {};
  final Map<String, Future<AnimeDetailModel>> _inFlightDetail = {};

  Future<AnimeDetailModel> detail(String id, {bool forceRefresh = false}) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty || cleanId == 'None') {
      throw Exception('ID anime tidak valid');
    }
    if (!forceRefresh && _detailCache.containsKey(cleanId) && _detailCacheTime.containsKey(cleanId)) {
      if (DateTime.now().difference(_detailCacheTime[cleanId]!) < const Duration(minutes: 15)) {
        return _detailCache[cleanId]!;
      }
    }
    if (!forceRefresh && _inFlightDetail.containsKey(cleanId)) {
      return _inFlightDetail[cleanId]!;
    }

    final future = () async {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.animeDetail(cleanId));
        final data = _unwrap(resp.data);
        final model = AnimeDetailModel.fromJson(Map<String, dynamic>.from(data));
        _detailCache[cleanId] = model;
        _detailCacheTime[cleanId] = DateTime.now();
        return model;
      } catch (e) {
        try {
          final seriesUrl = cleanId.startsWith('http') ? cleanId : 'https://ylnime.com/index.php?series=$cleanId';
          final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeSeries(seriesUrl));
          final data = _unwrap(resp.data);
          if (data is Map && data.isNotEmpty) {
            final model = AnimeDetailModel.fromJson(Map<String, dynamic>.from(data));
            _detailCache[cleanId] = model;
            _detailCacheTime[cleanId] = DateTime.now();
            return model;
          }
        } catch (_) {}
        rethrow;
      } finally {
        _inFlightDetail.remove(cleanId);
      }
    }();

    _inFlightDetail[cleanId] = future;
    return future;
  }

  Future<EpisodeStreamModel> episode(String id) async {
    final resp = await ApiClient.instance.get(ApiEndpoints.animeEpisode(id));
    final data = _unwrap(resp.data);
    return EpisodeStreamModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<YlnimeEpisodeStreams?> ylnimeEpisode(
    String episodeUrl, {
    String? seriesSlug,
    String? quality,
    bool forceFull = false,
  }) async {
    // ⚡ Langsung panggil GET /api/ylnime/episode?url=... (&quality=...)
    try {
      final endpoint = ApiEndpoints.animeEpisode(
        episodeUrl,
        seriesSlug: seriesSlug,
        quality: quality,
      );
      final resp = await ApiClient.instance.get(endpoint);
      final data = _unwrap(resp.data);
      if (data is Map && data.isNotEmpty) {
        final stream = YlnimeEpisodeStreams.fromJson(Map<String, dynamic>.from(data));
        if (stream.qualities.isNotEmpty || stream.bestPlayable != null) {
          debugPrint('[AnimeRepository] ylnimeEpisode success (endpoint: $endpoint, qualities: ${stream.qualities.length})');
          return stream;
        }
      }
    } catch (e) {
      debugPrint('[AnimeRepository] ylnimeEpisode error: $e');
    }

    return null;
  }

  /// Alias for backward compatibility: routes directly to ylnimeEpisode
  Future<YlnimeEpisodeStreams?> ylnimeStreams({
    required String url,
    String quality = '720p',
    String? seriesSlug,
  }) async {
    return ylnimeEpisode(url, seriesSlug: seriesSlug, quality: quality);
  }

  /// ⚡ Ganti resolusi video langsung lewat GET /api/ylnime/episode?url=...&quality=...
  Future<YlnimeEpisodeStreams?> changeEpisodeResolution({
    required String episodeUrl,
    required String reso,
    String? seriesSlug,
  }) async {
    return ylnimeEpisode(episodeUrl, seriesSlug: seriesSlug, quality: reso, forceFull: true);
  }

  /// Resolve YLnime episode URL by anime title or slug and episode number.
  Future<String?> resolveYlnimeEpisodeUrl({
    required String title,
    int? episodeNumber,
    String? seriesSlug,
  }) async {
    int? extractEpNum(dynamic e) {
      if (e is! Map) return null;
      return int.tryParse(e['episode_number']?.toString() ?? '') ??
          int.tryParse(e['episode']?.toString() ?? '') ??
          int.tryParse(e['number']?.toString() ?? '') ??
          int.tryParse(
            RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false)
                    .firstMatch(e['title']?.toString() ?? e['label']?.toString() ?? '')
                    ?.group(1) ??
                '',
          ) ??
          int.tryParse(
            RegExp(r'\b(\d+)\b')
                    .firstMatch(e['title']?.toString() ?? e['label']?.toString() ?? '')
                    ?.group(1) ??
                '',
          ) ??
          int.tryParse(
            RegExp(r'episode=([^&]+)').firstMatch(e['url']?.toString() ?? '')?.group(1) ?? '',
          );
    }

    try {
      // 1. Try seriesSlug directly if available
      if (seriesSlug != null && seriesSlug.isNotEmpty) {
        final seriesUrl = 'https://ylnime.com/index.php?series=$seriesSlug';
        final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeSeries(seriesUrl));
        final data = _unwrap(resp.data);
        if (data is Map && data['episodes'] is List) {
          final epList = data['episodes'] as List;
          if (episodeNumber != null) {
            for (final e in epList) {
              if (e is Map && e['url'] != null) {
                final eNum = extractEpNum(e);
                if (eNum == episodeNumber) {
                  return e['url'].toString();
                }
              }
            }
          } else if (epList.isNotEmpty && epList.first is Map && epList.first['url'] != null) {
            return epList.first['url'].toString();
          }
        }
      }

      // 2. Search title on YLnime
      final cleanTitle = title.replaceAll(RegExp(r'Subtitle\s+Indonesia|Sub\s+Indo', caseSensitive: false), '').trim();
      final searchResp = await ApiClient.instance.get(ApiEndpoints.ylnimeSearch(cleanTitle));
      final searchData = _unwrap(searchResp.data);
      List results = [];
      if (searchData is Map && searchData['results'] is List) {
        results = searchData['results'] as List;
      }
      if (results.isNotEmpty && results.first is Map && results.first['url'] != null) {
        final foundSeriesUrl = results.first['url'].toString();
        final seriesResp = await ApiClient.instance.get(ApiEndpoints.ylnimeSeries(foundSeriesUrl));
        final sData = _unwrap(seriesResp.data);
        if (sData is Map && sData['episodes'] is List) {
          final epList = sData['episodes'] as List;
          if (episodeNumber != null) {
            for (final e in epList) {
              if (e is Map && e['url'] != null) {
                final eNum = extractEpNum(e);
                if (eNum == episodeNumber) {
                  return e['url'].toString();
                }
              }
            }
          } else if (epList.isNotEmpty && epList.first is Map && epList.first['url'] != null) {
            return epList.first['url'].toString();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<AnimeModel>> search(String q) async {
    final resp = await ApiClient.instance.get(ApiEndpoints.animeSearch(q));
    return _asList(resp.data).map((e) => AnimeModel.fromJson(e)).toList();
  }

  Future<List<AnimeModel>> animeList({int page = 1}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.animeList,
      queryParameters: {'page': page},
    );
    return _asList(resp.data).map((e) => AnimeModel.fromJson(e)).toList();
  }

  // â”€â”€ Bookmarks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<List<AnimeModel>> bookmarks() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeBookmarks);
      final raw = resp.data is Map && resp.data['data'] != null ? resp.data['data'] : resp.data;
      final list = _asList(raw);
      if (list.isNotEmpty) {
        return list.map((e) => AnimeModel.fromJson(e)).toList();
      }
    } catch (_) {}
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.animeBookmarks);
      final raw = resp.data is Map && resp.data['data'] != null ? resp.data['data'] : resp.data;
      return _asList(raw).map((e) => AnimeModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addBookmark({
    required String animeId,
    required String title,
    String? thumb,
    String? status,
    String? score,
    String? url,
  }) async {
    final payload = {
      'anime_id': animeId,
      'animeId': animeId,
      'id': animeId,
      'title': title,
      'anime_title': title,
      if (thumb != null) ...{
        'poster': thumb,
        'poster_url': thumb,
        'thumbnail': thumb,
        'thumb': thumb,
        'anime_thumbnail': thumb,
      },
      if (url != null) 'url': url,
      if (status != null) 'status': status,
      if (score != null) 'score': score,
    };
    try {
      await ApiClient.instance.post(ApiEndpoints.ylnimeBookmarks, data: payload);
      return;
    } catch (_) {}
    await ApiClient.instance.post(ApiEndpoints.animeBookmarks, data: payload);
  }

  Future<void> removeBookmark(String animeId) async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.ylnimeBookmarkDelete(animeId));
      return;
    } catch (_) {}
    await ApiClient.instance.delete(ApiEndpoints.animeBookmarkDelete(animeId));
  }

  Future<bool> isBookmarked(String animeId) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.animeBookmarkCheck(animeId),
      );
      final d = _asMap(resp.data);
      if (d['bookmarked'] == true || d['is_bookmarked'] == true) return true;
    } catch (_) {}
    try {
      final list = await bookmarks();
      final target = animeId.toLowerCase();
      return list.any(
        (b) =>
            b.id.toLowerCase() == target ||
            (target.isNotEmpty && b.id.toLowerCase().contains(target)) ||
            (b.id.isNotEmpty && target.contains(b.id.toLowerCase())),
      );
    } catch (_) {
      return false;
    }
  }

  // â”€â”€ Watch history â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> addToHistory({
    required String animeId,
    required String episodeId,
    required String title,
    String? seriesKey,
    String? episodeLabel,
    String? episodeUrl,
    String? seriesUrl,
    String? thumb,
    int? position,
    int? duration,
    int? watchDuration,
    String? episodeNumber,
    bool? isCompleted,
    bool? force,
  }) async {
    String? epNum = episodeNumber;
    if (epNum == null && episodeLabel != null) {
      final m = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(episodeLabel);
      if (m != null) epNum = m.group(1);
    }

    String cleanEpId = episodeId.trim();
    final alEpMatch = RegExp(r'(al-[a-z0-9]+-\d+)', caseSensitive: false).firstMatch(cleanEpId);
    if (alEpMatch != null) {
      cleanEpId = alEpMatch.group(1)!;
    }

    String? resolvedSeriesKey = seriesKey;
    if (resolvedSeriesKey == null ||
        resolvedSeriesKey.isEmpty ||
        RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) {
      if (seriesUrl != null && seriesUrl.isNotEmpty) {
        final m = RegExp(r'[?&]series=([^&#]+)').firstMatch(seriesUrl);
        if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
          final cand = m.group(1)!;
          if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
            resolvedSeriesKey = cand;
          }
        }
      }
      if ((resolvedSeriesKey == null || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) &&
          animeId.isNotEmpty &&
          !animeId.startsWith('http') &&
          !RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(animeId)) {
        resolvedSeriesKey = animeId;
      }
      if ((resolvedSeriesKey == null || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) &&
          episodeUrl != null &&
          episodeUrl.isNotEmpty) {
        final m = RegExp(r'[?&]series=([^&#]+)').firstMatch(episodeUrl);
        if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
          final cand = m.group(1)!;
          if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
            resolvedSeriesKey = cand;
          }
        }
      }
    }
    resolvedSeriesKey ??= (animeId.isNotEmpty && !animeId.startsWith('http')) ? animeId : seriesKey;

    String? finalSeriesUrl = seriesUrl;
    if (finalSeriesUrl != null && finalSeriesUrl.isNotEmpty) {
      if (finalSeriesUrl.contains('/series.php?series=')) {
        finalSeriesUrl = finalSeriesUrl.replaceAll('/series.php?series=', '/?series=');
      }
    } else if (resolvedSeriesKey != null && resolvedSeriesKey.isNotEmpty) {
      finalSeriesUrl = 'https://ylnime.com/?series=$resolvedSeriesKey';
    }

    final posVal = position ?? 0;
    final durVal = duration ?? 0;
    final data = {
      'anime_id': animeId,
      'anime_title': title,
      'title': title,
      'episode_id': cleanEpId,
      'episode_key': cleanEpId,
      if (resolvedSeriesKey != null && resolvedSeriesKey.isNotEmpty) 'series_key': resolvedSeriesKey,
      'episode_title': episodeLabel ?? episodeId,
      'episode_url': episodeUrl ?? '',
      'current_time': posVal,
      'position': posVal,
      'total_duration': durVal,
      'duration': durVal,
      if (watchDuration != null) 'watch_duration': watchDuration,
      if (finalSeriesUrl != null && finalSeriesUrl.isNotEmpty) 'series_url': finalSeriesUrl,
      if (epNum != null) 'episode_number': epNum,
      if (episodeLabel != null) 'episode_label': episodeLabel,
      if (thumb != null) ...{
        'thumbnail': thumb,
        'thumb': thumb,
        'anime_thumbnail': thumb,
      },
      if (isCompleted != null) 'is_completed': isCompleted,
      if (force != null) 'force': force,
    };

    try {
      await ApiClient.instance.post(ApiEndpoints.ylnimeWatchHistory, data: data);
    } catch (_) {
      // Coba fallback endpoint, jika gagal lempar error agar caller tahu tidak tersimpan ke database
      await ApiClient.instance.post(ApiEndpoints.animeWatchHistory, data: data);
    }
  }

  /// Partial auto-save progress during playback (called periodically)
  Future<void> updateWatchProgress({
    required String animeId,
    required String episodeId,
    required int currentTime,
    required int totalDuration,
    String? seriesKey,
    int? watchDuration,
    String? animeTitle,
    String? episodeTitle,
    String? thumbnail,
    String? seriesUrl,
    String? episodeUrl,
    bool? isCompleted,
    bool? force,
  }) async {
    String cleanEpId = episodeId.trim();
    final alEpMatch = RegExp(r'(al-[a-z0-9]+-\d+)', caseSensitive: false).firstMatch(cleanEpId);
    if (alEpMatch != null) {
      cleanEpId = alEpMatch.group(1)!;
    }

    String? resolvedSeriesKey = seriesKey;
    if (resolvedSeriesKey == null ||
        resolvedSeriesKey.isEmpty ||
        RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) {
      if (seriesUrl != null && seriesUrl.isNotEmpty) {
        final m = RegExp(r'[?&]series=([^&#]+)').firstMatch(seriesUrl);
        if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
          final cand = m.group(1)!;
          if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
            resolvedSeriesKey = cand;
          }
        }
      }
      if ((resolvedSeriesKey == null || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) &&
          animeId.isNotEmpty &&
          !animeId.startsWith('http') &&
          !RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(animeId)) {
        resolvedSeriesKey = animeId;
      }
      if ((resolvedSeriesKey == null || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(resolvedSeriesKey)) &&
          episodeUrl != null &&
          episodeUrl.isNotEmpty) {
        final m = RegExp(r'[?&]series=([^&#]+)').firstMatch(episodeUrl);
        if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
          final cand = m.group(1)!;
          if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
            resolvedSeriesKey = cand;
          }
        }
      }
    }
    resolvedSeriesKey ??= (animeId.isNotEmpty && !animeId.startsWith('http')) ? animeId : seriesKey;

    String? finalSeriesUrl = seriesUrl;
    if (finalSeriesUrl != null && finalSeriesUrl.isNotEmpty) {
      if (finalSeriesUrl.contains('/series.php?series=')) {
        finalSeriesUrl = finalSeriesUrl.replaceAll('/series.php?series=', '/?series=');
      }
    } else if (resolvedSeriesKey != null && resolvedSeriesKey.isNotEmpty) {
      finalSeriesUrl = 'https://ylnime.com/?series=$resolvedSeriesKey';
    }

    final data = {
      'anime_id': animeId,
      'episode_id': cleanEpId,
      'current_time': 0, // Simpan per episode saja, tidak per menit
      'total_duration': 0,
      if (resolvedSeriesKey != null && resolvedSeriesKey.isNotEmpty) 'series_key': resolvedSeriesKey,
      if (animeTitle != null) 'anime_title': animeTitle,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (finalSeriesUrl != null && finalSeriesUrl.isNotEmpty) 'series_url': finalSeriesUrl,
      if (episodeUrl != null && episodeUrl.isNotEmpty) 'episode_url': episodeUrl,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (force != null) 'force': force,
    };

    try {
      await ApiClient.instance.post(ApiEndpoints.ylnimeWatchHistoryProgress, data: data);
    } catch (_) {
      try {
        await ApiClient.instance.post(ApiEndpoints.ylnimeWatchHistory, data: data);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> watchHistory({
    int page = 1,
    int limit = 50,
    String status = 'all',
    String? animeId,
    String sort = 'recent',
  }) async {
    try {
      final query = {
        'page': page,
        'limit': limit,
        'status': status,
        if (animeId != null && animeId.isNotEmpty) 'anime_id': animeId,
        'sort': sort,
      };
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeWatchHistory,
        queryParameters: query,
      );
      final list = _asList(resp.data);
      if (list.isNotEmpty) {
        return list;
      }
      if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
        return [];
      }
    } catch (_) {}

    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.animeWatchHistory);
      return _asList(resp.data).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// ðŸ”¥ Get watch history RAW dari backend (include stats, pagination, dll)
  Future<Map<String, dynamic>?> getWatchHistoryRaw({
    String? animeId,
    int limit = 200,
    int page = 1,
    String status = 'all',
    String sort = 'recent',
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
        'status': status,
        'sort': sort,
      };
      if (animeId != null && animeId.isNotEmpty) {
        params['anime_id'] = animeId;
      }

      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeWatchHistory,
        queryParameters: params,
      );

      if (resp.data is Map && resp.data['success'] == true) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[Repo] getWatchHistoryRaw error: $e');
      return null;
    }
  }

  /// ðŸ”¥ Get saved position untuk 1 episode dari BACKEND (cross-device sync).
  /// Return posisi dalam detik (int) atau null kalau tidak ada.
  /// ðŸ”¥ Get saved position untuk 1 episode dari BACKEND (Disabled per user request)
  Future<int?> getSavedPositionFromBackend({
    required String animeId,
    required String episodeId,
    String? episodeNumber,
    String? episodeUrl,
    String? episodeLabel,
  }) async {
    try {
      final history = await getWatchHistoryRaw(animeId: animeId, limit: 200);
      if (history == null) return null;

      final list = history['data'] as List? ?? [];

      // Normalisasi untuk matching
      final targetEpisodeId = episodeId.trim();
      final targetClean = targetEpisodeId.replaceAll(RegExp(r'^al-'), '');

      String? targetEpNum = episodeNumber?.trim();
      if ((targetEpNum == null || targetEpNum.isEmpty) && episodeLabel != null) {
        final m = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(episodeLabel);
        if (m != null) targetEpNum = m.group(1);
      }
      if ((targetEpNum == null || targetEpNum.isEmpty) && int.tryParse(targetEpisodeId) != null) {
        targetEpNum = targetEpisodeId;
      }

      for (final item in list) {
        if (item is! Map) continue;

        final dbEpisodeId = item['episode_id']?.toString() ?? '';
        final dbEpisodeKey = item['episode_key']?.toString() ?? '';
        final dbEpisodeNum = item['episode_number']?.toString() ?? '';
        final dbEpisodeUrl = item['episode_url']?.toString() ?? '';
        final dbClean = dbEpisodeId.replaceAll(RegExp(r'^al-'), '');

        // Match: by full id, key, clean, endsWith, url, or episode number
        bool isMatch = targetEpisodeId.isNotEmpty &&
            (dbEpisodeId == targetEpisodeId ||
                dbEpisodeKey.contains(targetEpisodeId) ||
                dbClean == targetClean ||
                dbEpisodeId.endsWith(targetEpisodeId) ||
                targetEpisodeId.endsWith(dbEpisodeId));

        if (!isMatch && episodeUrl != null && episodeUrl.isNotEmpty && dbEpisodeUrl.isNotEmpty) {
          isMatch = dbEpisodeUrl == episodeUrl ||
              (dbEpisodeUrl.contains('episode=') &&
                  episodeUrl.contains('episode=') &&
                  dbEpisodeUrl.split('episode=').last == episodeUrl.split('episode=').last);
        }

        if (!isMatch && targetEpNum != null && targetEpNum.isNotEmpty) {
          if (dbEpisodeNum == targetEpNum) {
            isMatch = true;
          } else {
            final dbTitle = item['episode_title']?.toString() ?? item['title']?.toString() ?? '';
            final dbMatch = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(dbTitle);
            if (dbMatch != null && dbMatch.group(1) == targetEpNum) {
              isMatch = true;
            }
          }
        }

        if (isMatch) {
          final timeVal = item['current_time'] ??
              item['currentTime'] ??
              item['watch_duration'] ??
              item['watchDuration'] ??
              item['position'] ??
              item['position_seconds'] ??
              item['last_position'] ??
              item['lastPosition'] ??
              item['last_pos'];
          final parsed = AnimeHistoryModel.parseTimeInSeconds(timeVal);
          if (parsed > 0) return parsed;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Repo] getSavedPositionFromBackend error: $e');
      return null;
    }
  }

  /// Incomplete continue watching list
  Future<List<Map<String, dynamic>>> continueWatching({int limit = 20}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeContinueWatching,
        queryParameters: {'limit': limit},
      );
      final list = _asList(resp.data);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Aggregate watch stats
  Future<Map<String, dynamic>> watchHistoryStats() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeWatchHistoryStats);
      final raw = resp.data;
      if (raw is Map && raw['data'] != null && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> removeFromHistory(String animeId) async {
    try {
      await ApiClient.instance.delete('${ApiEndpoints.ylnimeWatchHistory}/$animeId');
    } catch (_) {}
    try {
      await ApiClient.instance.delete(ApiEndpoints.animeWatchHistoryDelete(animeId));
    } catch (_) {}
  }

  Future<void> deleteHistoryEpisode(String episodeKey) async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.ylnimeWatchHistoryEpisodeDelete(episodeKey));
    } catch (_) {}
  }

  Future<void> clearAllHistory() async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.ylnimeWatchHistoryClearAll);
    } catch (_) {}
  }

  // â”€â”€ YLnime Comments â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<List<EpisodeCommentModel>> getEpisodeComments(
    String episodeKey, {
    int page = 1,
    int limit = 20,
    String sort = 'newest',
  }) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.ylnimeEpisodeComments(episodeKey, page: page, limit: limit, sort: sort),
    );
    final raw = _asList(resp.data);
    return raw.map((e) => EpisodeCommentModel.fromJson(e)).toList();
  }

  Future<EpisodeCommentModel?> addEpisodeComment({
    required String episodeKey,
    required String animeId,
    required int episodeNumber,
    required String content,
    int? parentId,
    bool isSpoiler = false,
    String? mediaUrl,
    String? mediaType,
    String? mediaThumbnail,
  }) async {
    final body = <String, dynamic>{
      'episode_key': episodeKey,
      'anime_id': animeId,
      'episode_number': episodeNumber,
      'content': content,
      'parent_id': parentId,
      'is_spoiler': isSpoiler,
    };
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      body['media_url'] = mediaUrl;
      body['media_type'] = mediaType ?? (mediaUrl.toLowerCase().endsWith('.gif') ? 'gif' : 'image');
      if (mediaThumbnail != null) body['media_thumbnail'] = mediaThumbnail;
    }

    final resp = await ApiClient.instance.post(
      ApiEndpoints.ylnimeAddComment,
      data: body,
    );
    final d = _asMap(resp.data);
    final commentData = d['data'] ?? d['comment'];
    if (commentData is Map) {
      return EpisodeCommentModel.fromJson(Map<String, dynamic>.from(commentData));
    }
    return null;
  }

  /// Upload media (image / GIF max 5MB) for comment
  Future<Map<String, dynamic>?> uploadCommentMedia(File file) async {
    try {
      String filename = file.path.split(Platform.pathSeparator).last;
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
      if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
        filename = 'comment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
        ),
      });
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeUploadCommentMedia,
        data: form,
      );
      final d = _asMap(resp.data);
      if (d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      if (d['media_url'] != null || d['url'] != null) {
        return d;
      }
      return null;
    } catch (e) {
      debugPrint('[AnimeRepository] uploadCommentMedia failed: $e');
      rethrow;
    }
  }

  /// Delete media from comment
  Future<bool> deleteCommentMedia(int commentId) async {
    try {
      final resp = await ApiClient.instance.delete(
        ApiEndpoints.ylnimeDeleteCommentMedia(commentId),
      );
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get current user's YLnime comment background settings
  Future<Map<String, dynamic>?> getUserCommentBackground() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeUserCommentBackground);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Set user's YLnime comment background settings
  Future<Map<String, dynamic>?> setUserCommentBackground({
    required String background,
    String bgType = 'image',
    double opacity = 1.0,
    int blur = 0,
    String? textColor,
  }) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeUserCommentBackground,
        data: {
          'background': background,
          'background_type': bgType,
          'opacity': opacity,
          'blur': blur,
          if (textColor != null && textColor.isNotEmpty) 'text_color': textColor,
        },
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Delete/reset user's YLnime comment background settings
  Future<bool> deleteUserCommentBackground() async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.ylnimeUserCommentBackground);
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Upload file and set user's YLnime comment background directly
  Future<Map<String, dynamic>?> uploadUserCommentBackground(
    File file, {
    double opacity = 1.0,
    int blur = 0,
    String? textColor,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final map = <String, dynamic>{
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'opacity': opacity.toString(),
        'blur': blur.toString(),
      };
      if (textColor != null && textColor.isNotEmpty) {
        map['text_color'] = textColor;
      }
      final form = FormData.fromMap(map);

      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeUserCommentBackgroundUpload,
        data: form,
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> toggleCommentLike(int commentId) async {
    final resp = await ApiClient.instance.post(
      ApiEndpoints.ylnimeCommentLike(commentId),
    );
    final d = _asMap(resp.data);
    if (d['data'] is Map) {
      return Map<String, dynamic>.from(d['data'] as Map);
    }
    if (d.containsKey('is_liked') || d.containsKey('likes_count')) {
      return d;
    }
    return null;
  }

  Future<bool> deleteComment(int commentId) async {
    final resp = await ApiClient.instance.delete(
      ApiEndpoints.ylnimeDeleteComment(commentId),
    );
    final d = _asMap(resp.data);
    return d['success'] == true;
  }

  Future<int> getCommentsCount(String episodeKey) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeCommentsCount(episodeKey),
      );
      final d = _asMap(resp.data);
      if (d['data'] is Map) {
        final val = d['data']['comments_count'] ?? d['data']['count'] ?? d['data']['total'];
        if (val != null) return int.tryParse(val.toString()) ?? 0;
      }
      final directVal = d['count'] ?? d['total'] ?? d['comments_count'];
      if (directVal != null) {
        return int.tryParse(directVal.toString()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<EpisodeCommentModel>> getCommentReplies(
    int commentId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.ylnimeCommentReplies(commentId, limit: limit, offset: offset),
    );
    final raw = _asList(resp.data);
    return raw.map((e) => EpisodeCommentModel.fromJson(e)).toList();
  }

  // ── YLnime Anime List (A-Z) ──────────────────────────────
  Future<YlnimeAnimeListResponse> ylnimeAnimeList({String letter = 'A'}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.ylnimeAnimeList(letter: letter),
    );
    final raw = resp.data;
    if (raw is Map) {
      return YlnimeAnimeListResponse.fromJson(
        Map<String, dynamic>.from(raw),
        fallbackLetter: letter,
      );
    }
    return YlnimeAnimeListResponse(currentLetter: letter);
  }

  Future<List<YlnimeAnimeListItem>> ylnimeAnimeListAll({String letter = 'A'}) async {
    final res = await ylnimeAnimeList(letter: letter);
    return res.animeList;
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (data is Map) {
      if (data['data'] is Map) {
        return _asList(data['data']);
      }
      if (data['data'] is List) {
        return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      // Look for common collection keys
      for (final k in [
        'history',
        'watch_history',
        'bookmarks',
        'comments',
        'replies',
        'data',
        'anime',
        'items',
        'results',
        'anime_list',
        'list',
        'days',
        'genres',
        'episodes',
      ]) {
        if (data[k] is List) {
          return (data[k] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      return data['data'];
    }
    return data;
  }

  List<AnimeModel> _toAnimeList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Public: Get YLnime stats by username (total bookmarks, watch history, duration, etc.)
  Future<Map<String, dynamic>> ylnimeUserStats(String username) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeUserStats(username));
      final raw = resp.data;
      if (raw is Map && raw['data'] != null && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (_) {
      return {};
    }
  }

  /// Public: Get YLnime bookmarks list by username
  Future<Map<String, dynamic>> ylnimeUserBookmarks(
    String username, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeUserBookmarks(username, page: page, limit: limit),
      );
      final raw = resp.data;
      if (raw is Map && raw['data'] != null && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (_) {
      return {};
    }
  }

  /// Public: Get YLnime watch history list by username
  Future<Map<String, dynamic>> ylnimeUserHistory(
    String username, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeUserHistory(username, page: page, limit: limit),
      );
      final raw = resp.data;
      if (raw is Map && raw['data'] != null && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (_) {
      return {};
    }
  }

  static const String _kEquippedRoleGenreKey = 'moko_equipped_genre_role_slug';
  static const String _kEquippedRoleItemKey = 'moko_equipped_genre_role_json';

  Future<UserGenreSummary> _applyLocalEquippedRole(UserGenreSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localGenre = prefs.getString(_kEquippedRoleGenreKey);
      final localJson = prefs.getString(_kEquippedRoleItemKey);

      GenreRoleItem? localRole;
      if (localJson != null && localJson.isNotEmpty) {
        try {
          localRole = GenreRoleItem.fromJson(jsonDecode(localJson) as Map<String, dynamic>).copyWith(
            isPinned: true,
            isPrimary: true,
          );
        } catch (_) {}
      }

      if (localGenre != null && localGenre.isNotEmpty) {
        if (summary.pinnedRole != null &&
            summary.pinnedRole!.genre.toLowerCase() == localGenre.toLowerCase()) {
          return summary;
        }

        var found = false;
        final updatedRoles = summary.roles.map((r) {
          if (r.genre.toLowerCase() == localGenre.toLowerCase()) {
            found = true;
            return r.copyWith(isPinned: true, isPrimary: true);
          }
          return r.copyWith(isPinned: false, isPrimary: false);
        }).toList();

        if (found) {
          final target = updatedRoles.firstWhere((r) => r.genre.toLowerCase() == localGenre.toLowerCase());
          return UserGenreSummary(
            roles: updatedRoles,
            stats: summary.stats,
            topGenre: summary.topGenre,
            pinnedRole: target,
            totalGenresWatched: summary.totalGenresWatched,
            hasRoles: true,
          );
        }

        if (localRole != null) {
          return UserGenreSummary(
            roles: [localRole, ...summary.roles],
            stats: summary.stats,
            topGenre: summary.topGenre,
            pinnedRole: localRole,
            totalGenresWatched: summary.totalGenresWatched,
            hasRoles: true,
          );
        }
      }
    } catch (_) {}
    return summary;
  }

  /// Get current user's genre roles and progression summary
  Future<UserGenreSummary> getGenreRoles() async {
    UserGenreSummary summary = const UserGenreSummary();
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolesMe);
      final raw = resp.data;
      if (raw is Map && raw['data'] is Map) {
        summary = UserGenreSummary.fromJson(Map<String, dynamic>.from(raw['data']));
      }
    } catch (_) {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.userGenreRolesMe);
        final raw = resp.data;
        if (raw is Map && raw['data'] is Map) {
          summary = UserGenreSummary.fromJson(Map<String, dynamic>.from(raw['data']));
        }
      } catch (_) {}
    }

    return await _applyLocalEquippedRole(summary);
  }

  /// Alias for getGenreRoles
  Future<UserGenreSummary> getMyGenreRoles() => getGenreRoles();

  /// Public: Get user's genre roles and progression by username
  Future<UserGenreSummary> getUserGenreRoles(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return const UserGenreSummary();

    // 1. Try /ylnime/genre-roles/user/<username>
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolesUser(cleanUsername));
      final raw = resp.data;
      if (raw is Map && raw['data'] is Map) {
        final d = raw['data'] as Map;
        if (d['genre_summary'] is Map) {
          return UserGenreSummary.fromJson(Map<String, dynamic>.from(d['genre_summary']));
        }
        return UserGenreSummary.fromJson(Map<String, dynamic>.from(d));
      }
    } catch (_) {}

    // 2. Try /users/public/<username>/genre-roles
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userPublicGenreRoles(cleanUsername));
      final raw = resp.data;
      if (raw is Map && raw['data'] is Map) {
        final d = raw['data'] as Map;
        if (d['genre_summary'] is Map) {
          return UserGenreSummary.fromJson(Map<String, dynamic>.from(d['genre_summary']));
        }
        return UserGenreSummary.fromJson(Map<String, dynamic>.from(d));
      }
    } catch (_) {}

    // 3. Try /ylnime/genre-roles/pinned/<username>
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolePinnedUser(cleanUsername));
      final raw = resp.data;
      if (raw is Map && raw['data'] is Map) {
        final d = raw['data'] as Map;
        final pinnedRaw = d['pinned_role'] ?? d;
        if (pinnedRaw is Map) {
          final pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(pinnedRaw)).copyWith(
            isPinned: true,
            isPrimary: true,
          );
          return UserGenreSummary(
            roles: [pinned],
            pinnedRole: pinned,
            hasRoles: true,
          );
        }
      }
    } catch (_) {}

    return const UserGenreSummary();
  }

  /// Alias for getUserGenreRoles
  Future<UserGenreSummary> getGenreRolesByUsername(String username) => getUserGenreRoles(username);

  /// Get catalog of all available genre roles, tiers, and thresholds
  Future<List<GenreRoleCatalogItem>> getGenreRolesCatalog() async {
    try {
      dynamic raw;
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolesDefinitions);
        raw = resp.data;
      } catch (_) {
        try {
          final resp = await ApiClient.instance.get(ApiEndpoints.userGenreRoleDefinitions);
          raw = resp.data;
        } catch (_) {}
      }

      if (raw is Map && raw['data'] != null) {
        final dataObj = raw['data'];
        List? list;
        if (dataObj is Map) {
          list = (dataObj['definitions'] as List?) ?? (dataObj['catalog'] as List?);
        } else if (dataObj is List) {
          list = dataObj;
        }

        if (list != null && list.isNotEmpty) {
          final items = list
              .whereType<Map>()
              .map((e) => GenreRoleCatalogItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (items.isNotEmpty) {
            return items;
          }
        }
      }
    } catch (_) {}

    return defaultGenreRoleCatalog;
  }


  /// Resync genre stats from watch history
  Future<Map<String, dynamic>?> resyncGenreStats({
    bool resetStats = false,
    bool forceRefreshGenres = false,
  }) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeGenreRolesResync,
        data: {
          'reset_stats': resetStats,
          'force_refresh_genres': forceRefreshGenres,
        },
      );
      final raw = resp.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return null;
    } catch (_) {
      try {
        await recalculateGenreRoles();
      } catch (_) {}
      return null;
    }
  }

  /// Get definitions of all genre roles
  Future<Map<String, dynamic>?> getGenreDefinitions() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolesDefinitions);
      final raw = resp.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reset / hapus semua role genre akun user (mengosongkan role genre & statistik tontonan genre)
  Future<bool> resetGenreRoles() async {
    bool success = false;

    // 1. Coba endpoint resync dengan reset_stats: true
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeGenreRolesResync,
        data: {
          'reset_stats': true,
          'force_refresh_genres': true,
          'clear_all': true,
        },
      );
      if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
        success = true;
      }
    } catch (_) {}

    // 2. Coba endpoint DELETE /ylnime/genre-roles/reset
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.ylnimeGenreRolesReset);
      if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
        success = true;
      }
    } catch (_) {}

    // 3. Coba endpoint POST /ylnime/genre-roles/reset
    try {
      final resp = await ApiClient.instance.post(ApiEndpoints.ylnimeGenreRolesReset);
      if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
        success = true;
      }
    } catch (_) {}

    // 4. Coba DELETE /ylnime/genre-roles
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.ylnimeGenreRoles);
      if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
        success = true;
      }
    } catch (_) {}

    return success;
  }

  /// Force recalculate genre roles and stats from watch history
  Future<bool> recalculateGenreRoles() async {
    try {
      final resp = await ApiClient.instance.post(ApiEndpoints.ylnimeRecalculateGenreRoles);
      final raw = resp.data;
      return raw is Map && raw['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Pasang / Equip genre role agar ditampilkan di profil dan komentar
  Future<bool> equipGenreRole(int roleId, {String? genre, GenreRoleItem? roleItem}) async {
    final cleanGenre = GenreUtils.sanitizeGenre(genre) ?? (genre?.trim().toLowerCase() ?? '');

    // 1. Kirim ke backend: POST /api/ylnime/genre-roles/pin dengan body {"genre": cleanGenre}
    if (cleanGenre.isNotEmpty) {
      try {
        final resp = await ApiClient.instance.post(
          ApiEndpoints.ylnimeGenreRolePin,
          data: {'genre': cleanGenre},
        );
        if (resp.data is Map && (resp.data['success'] == true || resp.data['status'] == 'success')) {
          debugPrint('[AnimeRepo] equipGenreRole backend success: $cleanGenre');
        }
      } catch (e) {
        debugPrint('[AnimeRepo] equipGenreRole API warning: $e');
      }
    }

    // 2. Selalu simpan di SharedPreferences agar profil dan komentar langsung terupdate konsisten
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cleanGenre.isNotEmpty) {
        await prefs.setString(_kEquippedRoleGenreKey, cleanGenre);
      }
      if (roleItem != null) {
        final pinnedItem = roleItem.copyWith(isPinned: true, isPrimary: true);
        await prefs.setString(_kEquippedRoleItemKey, jsonEncode(pinnedItem.toJson()));
      }
    } catch (_) {}

    return true;
  }

  /// Lepas / Unequip role genre (kembali ke penentuan tier otomatis)
  Future<bool> unequipGenreRole() async {
    try {
      await ApiClient.instance.post(ApiEndpoints.ylnimeGenreRoleUnpin);
    } catch (e) {
      debugPrint('[AnimeRepo] unequipGenreRole error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEquippedRoleGenreKey);
      await prefs.remove(_kEquippedRoleItemKey);
    } catch (_) {}

    return true;
  }

  /// Ambil role genre yang saat ini dipasang / pinned
  Future<GenreRoleItem?> getPinnedGenreRole() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeGenreRolePinned);
      final raw = _unwrap(resp.data);
      if (raw is Map) {
        return GenreRoleItem.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Top 20 Anime TerHype (/ylnime/hyper) with caching
  Future<HyperPageData?> getHyper({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHyper != null && _cachedHyperTime != null) {
      if (DateTime.now().difference(_cachedHyperTime!) < const Duration(minutes: 10)) {
        return _cachedHyper;
      }
    }
    if (!forceRefresh && _inFlightHyper != null) {
      return _inFlightHyper!;
    }
    final future = () async {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeHyper);
        final raw = _unwrap(resp.data);
        if (raw is Map) {
          final res = HyperPageData.fromJson(Map<String, dynamic>.from(raw));
          _cachedHyper = res;
          _cachedHyperTime = DateTime.now();
          return res;
        }
      } catch (_) {
      } finally {
        _inFlightHyper = null;
      }
      return null;
    }();
    _inFlightHyper = future;
    return future;
  }

  /// Anime Baru Diupload (/ylnime/new-releases)
  Future<YlnimeNewReleasesResponse> newReleases({int page = 1}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.animeNewReleases,
        queryParameters: {'page': page},
      );
      final raw = _unwrap(resp.data);
      if (raw is Map) {
        return YlnimeNewReleasesResponse.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Fallback ke endpoint legacy /ylnime/baru jika diperlukan
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeBaru(page: page));
        final raw = _unwrap(resp.data);
        if (raw is Map) {
          return YlnimeNewReleasesResponse.fromJson(Map<String, dynamic>.from(raw));
        }
      } catch (_) {}
    }
    return const YlnimeNewReleasesResponse();
  }

  /// Baru Diupload legacy list helper (/ylnime/new-releases)
  Future<List<AnimeModel>> getBaru({int page = 1}) async {
    final res = await newReleases(page: page);
    return res.animeList;
  }

  /// Anime Movies (/ylnime/genre/movie or /ylnime/search?q=movie) with caching
  Future<List<AnimeModel>> getMovies({int page = 1, bool forceRefresh = false}) async {
    if (page == 1 && !forceRefresh && _cachedMovies != null && _cachedMoviesTime != null) {
      if (DateTime.now().difference(_cachedMoviesTime!) < const Duration(minutes: 10)) {
        return _cachedMovies!;
      }
    }
    if (page == 1 && !forceRefresh && _inFlightMovies != null) {
      return _inFlightMovies!;
    }
    final Future<List<AnimeModel>> future = () async {
      try {
        final resp = await ApiClient.instance.get(
          ApiEndpoints.animeByGenre('movie', page: page),
        );
        final raw = _unwrap(resp.data);
        final list = _asList(raw);
        if (list.isNotEmpty) {
          final res = list.map((e) => AnimeModel.fromJson(e)).toList();
          if (page == 1) {
            _cachedMovies = res;
            _cachedMoviesTime = DateTime.now();
          }
          return res;
        }
      } catch (_) {}
      try {
        final resp = await ApiClient.instance.get(
          ApiEndpoints.animeSearch('movie', page: page),
        );
        final raw = _unwrap(resp.data);
        final list = _asList(raw);
        final res = list.map((e) => AnimeModel.fromJson(e)).toList();
        if (page == 1 && res.isNotEmpty) {
          _cachedMovies = res;
          _cachedMoviesTime = DateTime.now();
        }
        return res;
      } catch (_) {
        return <AnimeModel>[];
      } finally {
        if (page == 1) _inFlightMovies = null;
      }
    }();
    if (page == 1) _inFlightMovies = future;
    return future;
  }

  /// Polling Karakter / Anime (/ylnime/polling) with caching
  Future<PollingPageData?> getPolling({String kategori = 'cantik', bool forceRefresh = false}) async {
    final clean = (kategori.toLowerCase() == 'ganteng') ? 'tampan' : kategori.toLowerCase();
    if (!forceRefresh && _cachedPolling.containsKey(clean)) {
      final cached = _cachedPolling[clean]!;
      if (DateTime.now().difference(cached.time) < const Duration(minutes: 10)) {
        return cached.data;
      }
    }
    if (!forceRefresh && _inFlightPolling.containsKey(clean)) {
      return _inFlightPolling[clean]!;
    }
    final future = () async {
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.ylnimePolling(kategori: clean));
        final raw = _unwrap(resp.data);
        if (raw is Map) {
          final res = PollingPageData.fromJson(Map<String, dynamic>.from(raw));
          _cachedPolling[clean] = (data: res, time: DateTime.now());
          return res;
        }
      } catch (_) {
      } finally {
        _inFlightPolling.remove(clean);
      }
      return null;
    }();
    _inFlightPolling[clean] = future;
    return future;
  }

  /// Continue Watching list (/ylnime/watch-history/continue-watching)
  Future<List<ContinueWatchingItem>> getContinueWatching() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeContinueWatching);
      final raw = _unwrap(resp.data);
      final list = _asList(raw);
      return list.map((e) => ContinueWatchingItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  String errorMessage(dynamic e) {
    return AppErrorFormatter.format(e, fallback: 'Gagal memuat data anime. Coba lagi nanti.');
  }
}