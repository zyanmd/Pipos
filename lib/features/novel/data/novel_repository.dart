import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import './models/novel_model.dart';

class NovelRepository {
  NovelRepository._();
  static final NovelRepository instance = NovelRepository._();

  // In-memory caching
  final Map<String, NovelPaginationData<NovelItemModel>> _homeCache = {};
  final Map<String, DateTime> _homeCacheTime = {};
  final Map<String, Future<NovelPaginationData<NovelItemModel>>> _inFlightHome = {};

  List<NovelGenreModel>? _cachedGenres;

  final Map<String, NovelDetailModel> _detailCache = {};

  static const String _kBookmarksKey = 'saved_novel_bookmarks';
  static const String _kHistoryKey = 'saved_novel_history';

  dynamic _unwrap(dynamic raw) {
    if (raw is Map) {
      if (raw.containsKey('data')) return raw['data'];
      if (raw.containsKey('results')) return raw['results'];
    }
    return raw;
  }

  List<dynamic> _asList(dynamic raw) {
    final unwrapped = _unwrap(raw);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      if (unwrapped.containsKey('results') && unwrapped['results'] is List) {
        return unwrapped['results'] as List;
      }
      if (unwrapped.containsKey('items') && unwrapped['items'] is List) {
        return unwrapped['items'] as List;
      }
    }
    return const [];
  }

  /// Get home page with latest updated novels, optionally filtered by type or status
  Future<NovelPaginationData<NovelItemModel>> getNovelHome({
    int page = 1,
    bool forceRefresh = false,
    String? type,
    String? status,
  }) async {
    final cacheKey = '$page-${type ?? ""}-${status ?? ""}';

    if (page == 1 && !forceRefresh && _homeCache.containsKey(cacheKey) && _homeCacheTime.containsKey(cacheKey)) {
      if (DateTime.now().difference(_homeCacheTime[cacheKey]!) < const Duration(minutes: 5)) {
        return _homeCache[cacheKey]!;
      }
    }

    if (page == 1 && _inFlightHome.containsKey(cacheKey)) {
      return _inFlightHome[cacheKey]!;
    }

    final future = _fetchNovelHome(page, type: type, status: status);
    if (page == 1) _inFlightHome[cacheKey] = future;

    try {
      final res = await future;
      if (page == 1) {
        _homeCache[cacheKey] = res;
        _homeCacheTime[cacheKey] = DateTime.now();
      }
      return res;
    } finally {
      if (page == 1) _inFlightHome.remove(cacheKey);
    }
  }

  Future<NovelPaginationData<NovelItemModel>> _fetchNovelHome(
    int page, {
    String? type,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final resp = await ApiClient.instance.get(
        ApiEndpoints.novelHome,
        queryParameters: queryParams,
      );
      final raw = resp.data;
      final unwrapped = _unwrap(raw);

      List<NovelItemModel> items = [];
      bool hasNext = false;
      int currentPage = page;

      if (unwrapped is Map) {
        final results = unwrapped['results'];
        if (results is List) {
          items = results
              .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        final pag = unwrapped['pagination'];
        if (pag is Map) {
          hasNext = pag['has_next'] == true;
          currentPage = (pag['current_page'] is num) ? (pag['current_page'] as num).toInt() : page;
        }
      } else if (unwrapped is List) {
        items = unwrapped
            .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        hasNext = items.length >= 10;
      }

      return NovelPaginationData<NovelItemModel>(
        items: items,
        currentPage: currentPage,
        hasNext: hasNext,
      );
    } catch (e) {
      debugPrint('[NovelRepository] getNovelHome error: $e');
      rethrow;
    }
  }

  /// Get A-Z alphabetical directory of novels with letter/type filters and pagination
  Future<DaftarNovelResultModel> daftarNovel({
    String? type,
    String? huruf,
    int page = 1,
    String? q,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        if (type != null && type.isNotEmpty && type != 'Semua') 'type': type,
        if (huruf != null && huruf.isNotEmpty && huruf != 'Semua') 'huruf': huruf,
        if (q != null && q.isNotEmpty) 'q': q,
      };
      final resp = await ApiClient.instance.get(
        ApiEndpoints.novelDaftar,
        queryParameters: query,
      );
      final map = (resp.data is Map) ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      return DaftarNovelResultModel.fromJson(map);
    } catch (e) {
      debugPrint('[NovelRepository] daftarNovel error: $e');
      rethrow;
    }
  }

  /// Live search novels (searches both search endpoint and A-Z directory by query)
  Future<List<NovelItemModel>> searchNovels(String q, {int page = 1}) async {
    final clean = q.trim();
    if (clean.isEmpty) return const [];
    try {
      final Map<String, NovelItemModel> resultMap = {};

      // 1. Coba endpoint utama /novel/search?q=
      try {
        final resp = await ApiClient.instance.get(
          ApiEndpoints.novelSearch(clean, page: page),
        );
        final list = _asList(resp.data);
        for (final item in list) {
          final model = NovelItemModel.fromJson(Map<String, dynamic>.from(item as Map));
          if (model.slug.isNotEmpty) {
            resultMap[model.slug] = model;
          }
        }
      } catch (e) {
        debugPrint('[NovelRepository] novelSearch failed for "$clean": $e');
      }

      // 2. Jika hasil masih sedikit atau kosong, cari juga lewat /novel/daftar-novel?q=
      if (resultMap.length < 5) {
        try {
          final daftar = await daftarNovel(q: clean, page: page);
          for (final model in daftar.items) {
            if (model.slug.isNotEmpty && !resultMap.containsKey(model.slug)) {
              resultMap[model.slug] = model;
            }
          }
        } catch (_) {}
      }

      return resultMap.values.toList();
    } catch (e) {
      debugPrint('[NovelRepository] searchNovels error: $e');
      return [];
    }
  }

  /// Get novel full details with all chapters
  Future<NovelDetailModel> getNovelDetail(String slug) async {
    var cleanSlug = slug.trim();
    if (cleanSlug.contains('/api/novel/detail/')) {
      cleanSlug = cleanSlug.split('/api/novel/detail/').last;
    } else if (cleanSlug.contains('/novel/detail/')) {
      cleanSlug = cleanSlug.split('/novel/detail/').last;
    }

    if (_detailCache.containsKey(cleanSlug)) {
      return _detailCache[cleanSlug]!;
    }

    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.novelDetail(cleanSlug));
      final raw = resp.data;
      if (raw is Map) {
        final detail = NovelDetailModel.fromJson(Map<String, dynamic>.from(raw));
        if (detail.title.isNotEmpty || detail.slug.isNotEmpty) {
          _detailCache[cleanSlug] = detail;
          return detail;
        }
      }
      final unwrapped = _unwrap(raw);
      if (unwrapped is Map) {
        final detail = NovelDetailModel.fromJson(Map<String, dynamic>.from(unwrapped));
        _detailCache[cleanSlug] = detail;
        return detail;
      }
      throw Exception('Data novel tidak valid');
    } catch (e) {
      debugPrint('[NovelRepository] getNovelDetail error: $e');
      rethrow;
    }
  }

  /// Read single chapter content
  Future<NovelReaderModel> readChapter(String slug) async {
    var cleanSlug = slug.trim();
    if (cleanSlug.contains('/api/novel/read/')) {
      cleanSlug = cleanSlug.split('/api/novel/read/').last;
    } else if (cleanSlug.contains('/novel/read/')) {
      cleanSlug = cleanSlug.split('/novel/read/').last;
    }

    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.novelRead(cleanSlug));
      final unwrapped = _unwrap(resp.data);
      if (unwrapped is Map) {
        return NovelReaderModel.fromJson(Map<String, dynamic>.from(unwrapped), fallbackSlug: cleanSlug);
      }
      throw Exception('Isi chapter tidak ditemukan');
    } catch (e) {
      debugPrint('[NovelRepository] readChapter error: $e');
      rethrow;
    }
  }

  /// Get available novel genres
  Future<List<NovelGenreModel>> getNovelGenres() async {
    if (_cachedGenres != null && _cachedGenres!.isNotEmpty) {
      return _cachedGenres!;
    }
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.novelGenres);
      final list = _asList(resp.data);
      if (list.isNotEmpty) {
        _cachedGenres = list
            .map((e) => NovelGenreModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return _cachedGenres!;
      }
    } catch (e) {
      debugPrint('[NovelRepository] getNovelGenres error: $e');
    }

    _cachedGenres = const [
      NovelGenreModel(name: 'Romance', slug: 'romance', count: 262),
      NovelGenreModel(name: 'Fantasy', slug: 'fantasy', count: 221),
      NovelGenreModel(name: 'Comedy', slug: 'comedy', count: 212),
      NovelGenreModel(name: 'Harem', slug: 'harem', count: 196),
      NovelGenreModel(name: 'Action', slug: 'action', count: 193),
      NovelGenreModel(name: 'Adventure', slug: 'adventure', count: 167),
      NovelGenreModel(name: 'School Life', slug: 'school-life', count: 146),
      NovelGenreModel(name: 'Drama', slug: 'drama', count: 108),
      NovelGenreModel(name: 'Slice of Life', slug: 'slice-of-life', count: 103),
      NovelGenreModel(name: 'Shounen', slug: 'shounen', count: 73),
      NovelGenreModel(name: 'Supernatural', slug: 'supernatural', count: 53),
      NovelGenreModel(name: 'Ecchi', slug: 'ecchi', count: 46),
      NovelGenreModel(name: 'Martial Arts', slug: 'martial-arts', count: 44),
      NovelGenreModel(name: 'Seinen', slug: 'seinen', count: 41),
      NovelGenreModel(name: 'Mature', slug: 'mature', count: 36),
      NovelGenreModel(name: 'Psychological', slug: 'psychological', count: 31),
      NovelGenreModel(name: 'Adult', slug: 'adult', count: 30),
      NovelGenreModel(name: 'Mystery', slug: 'mystery', count: 29),
      NovelGenreModel(name: 'Xianxia', slug: 'xianxia', count: 25),
      NovelGenreModel(name: 'Xuanhuan', slug: 'xuanhuan', count: 19),
      NovelGenreModel(name: 'Tragedy', slug: 'tragedy', count: 18),
      NovelGenreModel(name: 'Sci-fi', slug: 'sci-fi', count: 13),
      NovelGenreModel(name: 'Wuxia', slug: 'wuxia', count: 9),
      NovelGenreModel(name: 'Gender Bender', slug: 'gender-bender', count: 4),
      NovelGenreModel(name: 'Horror', slug: 'horror', count: 4),
      NovelGenreModel(name: 'Shoujo', slug: 'shoujo', count: 3),
      NovelGenreModel(name: 'Mecha', slug: 'mecha', count: 3),
      NovelGenreModel(name: 'Smut', slug: 'smut', count: 2),
      NovelGenreModel(name: 'Josei', slug: 'josei', count: 2),
      NovelGenreModel(name: 'Transmigration', slug: 'transmigration', count: 1),
      NovelGenreModel(name: 'Male Protagonist', slug: 'male-protagonist', count: 1),
      NovelGenreModel(name: 'Historical', slug: 'historical', count: 1),
      NovelGenreModel(name: 'Heroes', slug: 'heroes', count: 1),
      NovelGenreModel(name: 'Protagonist Strong from the Start', slug: 'protagonist-strong-from-the-start', count: 1),
    ];
    return _cachedGenres!;
  }

  /// Get novels filtered by genre
  Future<List<NovelItemModel>> getNovelsByGenre(String genreSlug, {int page = 1}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.novelByGenre(genreSlug.trim(), page: page),
      );
      final list = _asList(resp.data);
      return list
          .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[NovelRepository] getNovelsByGenre error: $e');
      return [];
    }
  }

  /// Get available novel tags
  Future<List<NovelTagModel>> getNovelTags() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.novelTags);
      final list = _asList(resp.data);
      if (list.isNotEmpty) {
        return list
            .map((e) => NovelTagModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[NovelRepository] getNovelTags error: $e');
    }
    return [];
  }

  /// Get novels filtered by tag
  Future<List<NovelItemModel>> getNovelsByTag(String tagSlug, {int page = 1}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.novelByTag(tagSlug.trim(), page: page),
      );
      final list = _asList(resp.data);
      return list
          .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[NovelRepository] getNovelsByTag error: $e');
      return [];
    }
  }

  // ─── BOOKMARK LOCAL & REMOTE SYNC ───

  Future<List<NovelItemModel>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBookmarksKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> isBookmarked(String slug) async {
    final list = await getBookmarks();
    return list.any((b) => b.slug == slug);
  }

  Future<void> toggleBookmark(NovelDetailModel detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getBookmarks();
      final idx = current.indexWhere((b) => b.slug == detail.slug);

      if (idx >= 0) {
        current.removeAt(idx);
        // Call backend delete async
        try {
          ApiClient.instance.delete(ApiEndpoints.novelBookmarkDelete(detail.slug)).ignore();
        } catch (_) {}
      } else {
        current.insert(
          0,
          NovelItemModel(
            title: detail.title,
            slug: detail.slug,
            poster: detail.poster,
            type: detail.type,
            status: detail.status,
            rating: detail.rating,
            genres: detail.genres,
            latestChapter: detail.chapters.isNotEmpty ? detail.chapters.first.title : '',
          ),
        );
        // Call backend add async
        try {
          ApiClient.instance.post(
            ApiEndpoints.novelBookmarkAdd,
            data: {
              'novel_slug': detail.slug,
              'title': detail.title,
              'poster': detail.poster,
            },
          ).ignore();
        } catch (_) {}
      }

      await prefs.setString(_kBookmarksKey, jsonEncode(current.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[NovelRepository] toggleBookmark error: $e');
    }
  }

  // ─── READING HISTORY ───

  Future<void> saveReadingHistory({
    required String novelSlug,
    required String novelTitle,
    required String novelPoster,
    required String chapterSlug,
    required String chapterTitle,
    double progress = 0.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw) as List;
        } catch (_) {}
      }

      // Remove existing for this novel
      list.removeWhere((item) => (item is Map) && item['novel_slug'] == novelSlug);

      final entry = {
        'novel_slug': novelSlug,
        'novel_title': novelTitle,
        'novel_poster': novelPoster,
        'chapter_slug': chapterSlug,
        'chapter_title': chapterTitle,
        'progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      };

      list.insert(0, entry);
      if (list.length > 50) {
        list = list.sublist(0, 50);
      }

      await prefs.setString(_kHistoryKey, jsonEncode(list));

      // Push to backend history if logged in
      try {
        ApiClient.instance.post(ApiEndpoints.novelHistory, data: entry).ignore();
      } catch (_) {}
    } catch (e) {
      debugPrint('[NovelRepository] saveReadingHistory error: $e');
    }
  }

  Future<bool> removeBookmark(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getBookmarks();
      current.removeWhere((b) => b.slug == slug);
      await prefs.setString(_kBookmarksKey, jsonEncode(current.map((e) => e.toJson()).toList()));
      try {
        ApiClient.instance.delete(ApiEndpoints.novelBookmarkDelete(slug)).ignore();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[NovelRepository] removeBookmark error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReadingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> removeHistory(String novelSlug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        list.removeWhere((item) => (item is Map) && item['novel_slug'] == novelSlug);
        await prefs.setString(_kHistoryKey, jsonEncode(list));
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kHistoryKey);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getLastReadChapter(String novelSlug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map && item['novel_slug'] == novelSlug) {
            return Map<String, dynamic>.from(item);
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

