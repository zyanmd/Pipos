import '../../../core/network/api_client.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../anime/data/models/anime_model.dart' show GenreModel;
import './models/comic_model.dart';

class ComicRepository {
  ComicRepository._();
  static final ComicRepository instance = ComicRepository._();

  Future<List<ComicModel>> populer() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.comicPopuler);
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<List<ComicModel>> terbaru({
    String? tipe,
    String? genre,
    String? genre2,
    String? status,
    String? orderby,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      if (tipe != null && tipe.isNotEmpty) 'tipe': tipe,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (genre2 != null && genre2.isNotEmpty) 'genre2': genre2,
      if (status != null && status.isNotEmpty) 'status': status,
      if (orderby != null && orderby.isNotEmpty) 'orderby': orderby,
    };
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicTerbaru,
      queryParameters: query,
    );
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<List<ComicModel>> pustaka({int page = 1}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicPustaka,
      queryParameters: {'page': page},
    );
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<List<ComicModel>> ranking(String period) async {
    final resp = await ApiClient.instance.get(ApiEndpoints.comicRanking(period));
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<List<ComicModel>> search(String q) async {
    final resp = await ApiClient.instance.get(ApiEndpoints.comicSearch(q));
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<List<GenreModel>> genres() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.comicGenres);
    return _asList(resp.data)
        .map((e) => GenreModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ComicModel>> byGenre(String slug, {int page = 1}) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicByGenre(slug),
      queryParameters: {'page': page},
    );
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  /// Get alphabetical directory of comics with letter/type filters and pagination.
  Future<DaftarKomikResultModel> daftarKomik({
    String? tipe,
    String? huruf,
    int halaman = 1,
  }) async {
    final query = <String, dynamic>{
      'halaman': halaman,
      if (tipe != null && tipe.isNotEmpty) 'tipe': tipe,
      if (huruf != null && huruf.isNotEmpty) 'huruf': huruf,
    };
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicDaftar,
      queryParameters: query,
    );
    final map = _asMap(resp.data);
    return DaftarKomikResultModel.fromJson(map);
  }

  Future<ComicDetailModel> detail(String slug) async {
    final cleanSlug = ComicModel.extractCleanSlug(slug);
    final resp = await ApiClient.instance.get(ApiEndpoints.comicDetail(cleanSlug));
    final data = _unwrap(resp.data);
    return ComicDetailModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ChapterImagesModel> chapter(String chapterId) async {
    final cleanSlug = ChapterModel.extractCleanSlug(chapterId);
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicChapter,
      queryParameters: {'slug': cleanSlug, 'id': cleanSlug},
    );
    final data = _unwrap(resp.data);
    return ChapterImagesModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ChapterImagesModel> chapterLegacy(String chapterId) async {
    final cleanSlug = ChapterModel.extractCleanSlug(chapterId);
    final resp = await ApiClient.instance.get(
      ApiEndpoints.comicChapterLegacy,
      queryParameters: {'slug': cleanSlug, 'id': cleanSlug},
    );
    final data = _unwrap(resp.data);
    return ChapterImagesModel.fromJson(Map<String, dynamic>.from(data));
  }

  // ── Bookmarks ─────────────────────────────────────────────
  Future<List<ComicModel>> bookmarks() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.comicBookmarks);
    return _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
  }

  Future<void> addBookmark({
    required String comicSlug,
    required String title,
    String? thumb,
    String? type,
  }) async {
    await ApiClient.instance.post(
      ApiEndpoints.comicBookmarks,
      data: {
        'comic_slug': comicSlug,
        'slug': comicSlug,
        'comic_title': title,
        'title': title,
        if (thumb != null) ...{
          'comic_thumbnail': thumb,
          'thumbnail': thumb,
          'thumb': thumb,
        },
        if (type != null) 'type': type,
      },
    );
  }

  Future<void> removeBookmark(String slug) async {
    await ApiClient.instance.delete(ApiEndpoints.comicBookmarkDelete(slug));
  }

  Future<bool> isBookmarked(String slug) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.comicBookmarkCheck(slug),
      );
      final d = _asMap(resp.data);
      return d['bookmarked'] == true || d['is_bookmarked'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Read history ──────────────────────────────────────────
  Future<void> addToHistory({
    required String comicSlug,
    required String chapterId,
    required String title,
    String? chapterLabel,
    String? thumb,
    String? chapterNumber,
    int? lastPage,
    int? totalPages,
  }) async {
    final cleanChapterSlug = ChapterModel.extractCleanSlug(chapterId);
    String? chNum = chapterNumber;
    if (chNum == null && chapterLabel != null) {
      final m = RegExp(r'(?:Chapter|Ch|Chap)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(chapterLabel);
      if (m != null) chNum = m.group(1);
    }
    await ApiClient.instance.post(
      ApiEndpoints.comicReadHistory,
      data: {
        'comic_slug': comicSlug,
        'comic_title': title,
        'title': title,
        'chapter_slug': cleanChapterSlug,
        'chapter_id': cleanChapterSlug,
        'chapter_title': chapterLabel ?? cleanChapterSlug,
        if (chNum != null) 'chapter_number': chNum,
        if (chapterLabel != null) 'chapter_label': chapterLabel,
        if (thumb != null) ...{
          'comic_thumbnail': thumb,
          'thumb': thumb,
          'thumbnail': thumb,
        },
        if (lastPage != null) 'last_page': lastPage,
        if (totalPages != null) 'total_pages': totalPages,
      },
    );
  }

  Future<List<Map<String, dynamic>>> readHistory() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.comicReadHistory);
      return _asList(resp.data).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> readHistoryLatest() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.comicReadHistoryLatest);
      return _asList(resp.data).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> removeFromHistory(String slug) async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.comicReadHistoryDelete(slug));
    } catch (_) {}
  }

  /// Get public comic reading stats by username (no auth required)
  /// Returns { 'username': ..., 'total_history': ..., 'total_bookmarks': ..., 'unique_comics_read': ... }
  Future<Map<String, dynamic>> publicStats(String username) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.comicUserStats(username),
      );
      final data = _unwrap(resp.data);
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (data is Map) {
      if (data['data'] is Map) {
        return _asList(data['data']);
      }
      if (data['data'] is List) {
        return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      for (final k in ['history', 'read_history', 'bookmarks', 'data', 'items', 'results', 'comics', 'list', 'chapters']) {
        if (data[k] is List) {
          return (data[k] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : {};

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      return data['data'];
    }
    return data;
  }

  String errorMessage(dynamic e) {
    return AppErrorFormatter.format(e, fallback: 'Gagal memuat data komik. Coba lagi nanti.');
  }
}
