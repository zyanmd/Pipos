import 'package:dio/dio.dart';
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

  /// Daftar genre komik kurasi komprehensif (kompatibel penuh dengan database komiku & MAL)
  static const List<GenreModel> defaultComicGenres = [
    GenreModel(slug: 'action', name: 'Action'),
    GenreModel(slug: 'adventure', name: 'Adventure'),
    GenreModel(slug: 'comedy', name: 'Comedy'),
    GenreModel(slug: 'drama', name: 'Drama'),
    GenreModel(slug: 'fantasy', name: 'Fantasy'),
    GenreModel(slug: 'isekai', name: 'Isekai'),
    GenreModel(slug: 'romance', name: 'Romance'),
    GenreModel(slug: 'shounen', name: 'Shounen'),
    GenreModel(slug: 'seinen', name: 'Seinen'),
    GenreModel(slug: 'shoujo', name: 'Shoujo'),
    GenreModel(slug: 'martial-arts', name: 'Martial Arts'),
    GenreModel(slug: 'reincarnation', name: 'Reincarnation'),
    GenreModel(slug: 'supernatural', name: 'Supernatural'),
    GenreModel(slug: 'mystery', name: 'Mystery'),
    GenreModel(slug: 'horror', name: 'Horror'),
    GenreModel(slug: 'slice-of-life', name: 'Slice of Life'),
    GenreModel(slug: 'sci-fi', name: 'Sci-Fi'),
    GenreModel(slug: 'school-life', name: 'School Life'),
    GenreModel(slug: 'sports', name: 'Sports'),
    GenreModel(slug: 'historical', name: 'Historical'),
    GenreModel(slug: 'psychological', name: 'Psychological'),
    GenreModel(slug: 'manhwa', name: 'Manhwa'),
    GenreModel(slug: 'manhua', name: 'Manhua'),
    GenreModel(slug: 'magic', name: 'Magic'),
    GenreModel(slug: 'super-power', name: 'Super Power'),
    GenreModel(slug: 'thriller', name: 'Thriller'),
    GenreModel(slug: 'tragedy', name: 'Tragedy'),
    GenreModel(slug: 'time-travel', name: 'Time Travel'),
    GenreModel(slug: 'webtoon', name: 'Webtoon'),
    GenreModel(slug: 'dungeons', name: 'Dungeons'),
    GenreModel(slug: 'leveling', name: 'Leveling'),
    GenreModel(slug: 'overpowered-protagonist', name: 'Overpowered Protagonist'),
    GenreModel(slug: 'system', name: 'System'),
    GenreModel(slug: 'revenge', name: 'Revenge'),
    GenreModel(slug: 'villainess', name: 'Villainess'),
    GenreModel(slug: 'game', name: 'Game'),
    GenreModel(slug: 'demons', name: 'Demons'),
    GenreModel(slug: 'harem', name: 'Harem'),
    GenreModel(slug: 'ecchi', name: 'Ecchi'),
    GenreModel(slug: 'dark-fantasy', name: 'Dark Fantasy'),
    GenreModel(slug: 'apocalypse', name: 'Apocalypse'),
    GenreModel(slug: 'survival', name: 'Survival'),
    GenreModel(slug: 'military', name: 'Military'),
    GenreModel(slug: 'mecha', name: 'Mecha'),
    GenreModel(slug: 'vampire', name: 'Vampire'),
    GenreModel(slug: 'monsters', name: 'Monsters'),
    GenreModel(slug: 'police', name: 'Police'),
    GenreModel(slug: 'royalty', name: 'Royalty'),
    GenreModel(slug: 'space', name: 'Space'),
    GenreModel(slug: 'wuxia', name: 'Wuxia'),
    GenreModel(slug: 'xianxia', name: 'Xianxia'),
  ];

  Future<List<GenreModel>> genres() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.comicGenres);
      final apiList = _asList(resp.data)
          .map((e) => GenreModel.fromJson(Map<String, dynamic>.from(e)))
          .where((g) => g.slug.isNotEmpty && g.name.isNotEmpty)
          .toList();

      final map = <String, GenreModel>{};
      for (final g in defaultComicGenres) {
        map[g.slug.toLowerCase()] = g;
      }
      for (final g in apiList) {
        map[g.slug.toLowerCase()] = g;
      }
      final list = map.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (_) {
      return defaultComicGenres;
    }
  }

  /// Memuat daftar komik berdasarkan genre secara andal (mendukung pagination dan fallback scraper)
  Future<List<ComicModel>> byGenre(String slug, {int page = 1}) async {
    final cleanSlug = slug.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-');

    // 1. Coba ambil langsung dari live endpoint mirror komiku (mendukung live paginasi)
    try {
      final pagePath = page > 1 ? 'page/$page/' : '';
      final url = 'https://api.komiku.org/genre/$cleanSlug/$pagePath';
      final resp = await ApiClient.instance.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': ApiClient.userAgent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      if (resp.data is String && (resp.data as String).isNotEmpty) {
        final parsed = parseKomikuBgeHtml(resp.data as String);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    // 2. Fallback ke endpoint backend
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.comicByGenre(cleanSlug),
        queryParameters: {'page': page},
      );
      final list = _asList(resp.data).map((e) => ComicModel.fromJson(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // 3. Fallback pencarian teks jika halaman pertama
    if (page == 1) {
      try {
        final searchResult = await search(cleanSlug.replaceAll('-', ' '));
        if (searchResult.isNotEmpty) return searchResult;
      } catch (_) {}
    }

    return [];
  }

  /// Parser HTML untuk kartu komik dari komiku
  static List<ComicModel> parseKomikuBgeHtml(String html) {
    final list = <ComicModel>[];
    final blocks = html.split('<div class="bge">');
    if (blocks.length <= 1) return list;

    final slugRegex = RegExp(r'href="(?:https?://[^/"]+)?/(?:manga|komik)/([^/"]+)/?"');
    final imgRegex = RegExp(r'<img[^>]+(?:src|data-src)="([^"]+)"');
    final titleRegex = RegExp(r'<h3>\s*(.*?)\s*</h3>', dotAll: true);
    final typeGenreRegex = RegExp(r'<div class="tpe1_inf">\s*(?:<b>([^<]+)</b>)?\s*([^<]*)', dotAll: true);
    final chRegex = RegExp(r'href="/[^"]*chapter-([^/"]+)/?"[^>]*><span>([^<]+)</span>');
    final altChRegex = RegExp(r'<span>(Chapter\s*[^<]+)</span>');
    final descRegex = RegExp(r'<p>\s*(.*?)\s*</p>', dotAll: true);

    for (var i = 1; i < blocks.length; i++) {
      final block = blocks[i];
      final slug = slugRegex.firstMatch(block)?.group(1);
      if (slug == null || slug.isEmpty) continue;

      final img = imgRegex.firstMatch(block)?.group(1);
      final rawTitle = titleRegex.firstMatch(block)?.group(1);
      final title = rawTitle != null ? _cleanHtml(rawTitle) : slug;

      final typeMatch = typeGenreRegex.firstMatch(block);
      final type = typeMatch?.group(1)?.trim();
      final genre = typeMatch?.group(2)?.trim();

      var ch = chRegex.firstMatch(block)?.group(2)?.trim();
      ch ??= altChRegex.firstMatch(block)?.group(1)?.trim();

      final desc = descRegex.firstMatch(block)?.group(1)?.trim();

      list.add(ComicModel(
        slug: slug,
        title: title,
        thumb: img != null ? ComicModel.normalizeThumbnailUrl(img) : null,
        type: type != null && type.isNotEmpty ? type : null,
        genre: genre != null && genre.isNotEmpty ? genre : null,
        latestChapter: ch,
        synopsis: desc != null && desc.isNotEmpty ? _cleanHtml(desc) : null,
      ),);
    }
    return list;
  }

  static String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
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
