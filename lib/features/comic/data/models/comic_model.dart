import '../../../../core/config/api_config.dart';

/// Comic card model (lists, search, bookmarks).
class ComicModel {
  final String slug;
  final String title;
  final String? thumb;
  final String? type;
  final String? rating;
  final String? status;
  final String? latestChapter;
  final String? synopsis;
  final String? author;

  final String? genre;
  final String? readers;
  final String? timeAgo;

  const ComicModel({
    required this.slug,
    required this.title,
    this.thumb,
    this.type,
    this.rating,
    this.status,
    this.latestChapter,
    this.synopsis,
    this.author,
    this.genre,
    this.readers,
    this.timeAgo,
  });

  static String extractCleanSlug(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (s.contains('?')) s = s.split('?').first;
    if (s.contains('#')) s = s.split('#').first;

    // Remove protocol
    s = s.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');

    // Malformed backend scraper bug where domain has no trailing slash:
    // e.g. "komiku.orgarchmage-curriculum" or "komiku.idarchmage-curriculum"
    s = s.replaceAll(
      RegExp(
        r'^(?:www\.)?komiku\.(?:org|id|co\.id|com|site|vip|net|me|cc|io|xyz|top|biz|info)(?!/)',
        caseSensitive: false,
      ),
      '',
    );

    // If it contains a domain with slash: e.g. "komiku.org/manga/archmage-curriculum/"
    if (s.contains('/')) {
      s = s.replaceAll(
        RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?::\d+)?/'),
        '',
      );
    }

    // Strip leading/trailing slashes, then strip leading manga/ or comic/
    s = s.replaceAll(RegExp(r'^/+|/+$'), '');
    s = s.replaceAll(
      RegExp(r'^(?:manga|komik|comic)/+', caseSensitive: false),
      '',
    );
    s = s.replaceAll(RegExp(r'^/+|/+$'), '');
    return s;
  }

  /// Ekstraksi thumbnail komik secara komprehensif dari berbagai kemungkinan format key API
  /// (misal 'thumbnail', 'comic_thumbnail', 'thumb', 'cover', objek 'comic', atau objek 'data')
  static String? extractThumbnail(Map<String, dynamic>? j) {
    if (j == null) return null;

    final candidateKeys = [
      'thumbnail',
      'comic_thumbnail',
      'thumb',
      'image',
      'cover',
      'poster',
      'comic_image',
      'img',
    ];

    // 1. Cek langsung di level root
    for (final key in candidateKeys) {
      final val = j[key];
      if (val is String && val.trim().isNotEmpty) {
        return normalizeThumbnailUrl(val.trim());
      } else if (val is Map) {
        final nested = (val['src'] ?? val['url'] ?? val['link'] ?? val['href'])?.toString();
        if (nested != null && nested.trim().isNotEmpty) {
          return normalizeThumbnailUrl(nested.trim());
        }
      }
    }

    // 2. Cek di dalam objek relasi 'comic'
    if (j['comic'] is Map) {
      final cMap = Map<String, dynamic>.from(j['comic'] as Map);
      for (final key in candidateKeys) {
        final val = cMap[key];
        if (val is String && val.trim().isNotEmpty) {
          return normalizeThumbnailUrl(val.trim());
        } else if (val is Map) {
          final nested = (val['src'] ?? val['url'] ?? val['link'] ?? val['href'])?.toString();
          if (nested != null && nested.trim().isNotEmpty) {
            return normalizeThumbnailUrl(nested.trim());
          }
        }
      }
    }

    // 3. Cek di dalam objek relasi 'data'
    if (j['data'] is Map) {
      final dMap = Map<String, dynamic>.from(j['data'] as Map);
      for (final key in candidateKeys) {
        final val = dMap[key];
        if (val is String && val.trim().isNotEmpty) {
          return normalizeThumbnailUrl(val.trim());
        } else if (val is Map) {
          final nested = (val['src'] ?? val['url'] ?? val['link'] ?? val['href'])?.toString();
          if (nested != null && nested.trim().isNotEmpty) {
            return normalizeThumbnailUrl(nested.trim());
          }
        }
      }
    }

    return null;
  }

  /// Normalisasi URL thumbnail agar selalu mengarah ke protokol HTTPS yang valid dan mirror CDN komiku yang aktif (thumbnail.komiku.org)
  static String normalizeThumbnailUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    // Replace dead thumbnail.komiku.to with live Cloudflare mirror thumbnail.komiku.org
    if (u.contains('thumbnail.komiku.to')) {
      u = u.replaceAll('thumbnail.komiku.to', 'thumbnail.komiku.org');
    }
    if (u.startsWith('//')) {
      return 'https:$u';
    }
    if (u.startsWith('http://thumbnail.komiku.org')) {
      return u.replaceFirst('http://', 'https://');
    }
    if (u.startsWith('/img/upload/')) {
      return 'https://thumbnail.komiku.org$u';
    }
    return u;
  }

  factory ComicModel.fromJson(Map<String, dynamic> j) {
    String? latestChap;
    final rawChap = j['latest_chapter'] ?? j['last_chapter'] ?? j['chapter'];
    if (rawChap is Map) {
      latestChap = (rawChap['chapter'] ?? rawChap['title'] ?? rawChap['name'])?.toString();
    } else if (rawChap != null) {
      latestChap = rawChap.toString();
    }

    final thumb = extractThumbnail(j);

    final rawSlug = (j['comic_slug'] ?? j['slug'] ?? j['id'] ?? '').toString();
    final rawUrl = (j['url'] ?? j['link'] ?? j['href'] ?? '').toString();
    var clean = '';
    if (rawUrl.isNotEmpty && rawUrl.toLowerCase().contains('/manga/')) {
      clean = extractCleanSlug(rawUrl);
    }
    if (clean.isEmpty) {
      clean = extractCleanSlug(rawSlug);
    }
    if (clean.isEmpty && rawUrl.isNotEmpty) {
      clean = extractCleanSlug(rawUrl);
    }

    return ComicModel(
      slug: clean.isNotEmpty ? clean : rawSlug,
      title: (j['comic_title'] ?? j['title'] ?? j['name'] ?? '').toString(),
      thumb: thumb,
      type: (j['type'] ?? j['jenis'])?.toString(),
      rating: (j['rating'] ?? j['score'])?.toString(),
      status: j['status']?.toString(),
      latestChapter: latestChap,
      synopsis: (j['synopsis'] ?? j['description'])?.toString(),
      author: (j['author'] ?? j['creator'])?.toString(),
      genre: j['genre']?.toString(),
      readers: j['readers']?.toString(),
      timeAgo: (j['time_ago'] ?? j['timeAgo'] ?? j['updated_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        'thumb': thumb,
        'type': type,
        'rating': rating,
        'status': status,
        'latest_chapter': latestChapter,
        'synopsis': synopsis,
        'author': author,
        if (genre != null) 'genre': genre,
        if (readers != null) 'readers': readers,
        if (timeAgo != null) 'time_ago': timeAgo,
      };
}

/// Comic detail (from /comic/detail/<slug>).
class ComicDetailModel {
  final String slug;
  final String title;
  final String? thumb;
  final String? synopsis;
  final String? status;
  final String? type;
  final String? rating;
  final String? author;
  final String? artist;
  final String? readingDirection;
  final String? releaseYear;
  final List<ChapterModel> chapters;
  final List<String> genres;

  const ComicDetailModel({
    required this.slug,
    required this.title,
    this.thumb,
    this.synopsis,
    this.status,
    this.type,
    this.rating,
    this.author,
    this.artist,
    this.readingDirection,
    this.releaseYear,
    this.chapters = const [],
    this.genres = const [],
  });

  factory ComicDetailModel.fromJson(Map<String, dynamic> j) {
    final chapters = <ChapterModel>[];
    final list = j['chapters'] ?? j['chapter_list'];
    if (list is List) {
      for (final c in list) {
        if (c is Map) {
          chapters.add(ChapterModel.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    final genres = <String>[];
    final g = j['genres'];
    if (g is List) {
      genres.addAll(g.map((e) => e.toString()));
    } else if (g is String) {
      genres.addAll(g.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }

    final thumb = ComicModel.extractThumbnail(j);

    return ComicDetailModel(
      slug: (j['comic_slug'] ?? j['slug'] ?? j['id'] ?? '').toString(),
      title: (j['comic_title'] ?? j['title'] ?? j['name'] ?? '').toString(),
      thumb: thumb,
      synopsis: (j['synopsis'] ?? j['description'])?.toString(),
      status: j['status']?.toString(),
      type: (j['type'] ?? j['jenis'])?.toString(),
      rating: (j['rating'] ?? j['score'])?.toString(),
      author: (j['author'] ?? j['creator'])?.toString(),
      artist: (j['artist'])?.toString(),
      readingDirection: (j['reading_direction'] ?? j['direction'])?.toString(),
      releaseYear: (j['release_year'] ?? j['year'])?.toString(),
      chapters: chapters,
      genres: genres,
    );
  }
}

/// Chapter list entry.
class ChapterModel {
  final String id; // chapter clean slug used by /comic/chapter?slug=...
  final String label;
  final String? uploadedOn;
  final String? url;

  const ChapterModel({
    required this.id,
    required this.label,
    this.uploadedOn,
    this.url,
  });

  static String extractCleanSlug(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (s.contains('?')) s = s.split('?').first;
    if (s.contains('#')) s = s.split('#').first;

    // Remove protocol
    s = s.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');

    // Malformed backend scraper bug where domain has no trailing slash
    s = s.replaceAll(
      RegExp(
        r'^(?:www\.)?komiku\.(?:org|id|co\.id|com|site|vip|net|me|cc|io|xyz|top|biz|info)(?!/)',
        caseSensitive: false,
      ),
      '',
    );

    // If it contains a domain with slash
    if (s.contains('/')) {
      s = s.replaceAll(
        RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?::\d+)?/'),
        '',
      );
    }

    s = s.replaceAll(RegExp(r'^/+|/+$'), '');
    s = s.replaceAll(RegExp(r'^(?:ch|chapter)/+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^/+|/+$'), '');
    return s;
  }

  factory ChapterModel.fromJson(Map<String, dynamic> j) {
    final rawId = (j['slug'] ?? j['chapter_slug'] ?? j['id'] ?? j['chapter_id'] ?? j['chapterId'] ?? '').toString();
    final rawUrl = (j['url'] ?? j['link'] ?? '').toString();
    final cleanId = extractCleanSlug(rawId.isNotEmpty ? rawId : rawUrl);

    return ChapterModel(
      id: cleanId.isNotEmpty ? cleanId : rawId,
      label: (j['label'] ?? j['title'] ?? j['name'] ?? j['chapter'] ?? '').toString(),
      uploadedOn: (j['uploaded_on'] ?? j['date'] ?? j['upload_date'])?.toString(),
      url: rawUrl.isNotEmpty ? rawUrl : null,
    );
  }
}

/// Chapter images (from /comic/chapter?slug=...).
class ChapterImagesModel {
  final String id;
  final String title;
  final String? comicSlug;
  final String? comicTitle;
  final List<String> images;

  const ChapterImagesModel({
    required this.id,
    required this.title,
    this.comicSlug,
    this.comicTitle,
    this.images = const [],
  });

  static String resolveImageUrl(String url) {
    if (url.startsWith('/api/comic/proxy') || url.startsWith('/comic/proxy')) {
      final normalizedPath = url.startsWith('/') ? url : '/$url';
      return '${ApiConfig.baseUrl}$normalizedPath';
    }
    return url;
  }

  factory ChapterImagesModel.fromJson(Map<String, dynamic> j) {
    final images = <String>[];
    final imgs = j['imagesproxy'] ?? j['images'] ?? j['pages'] ?? j['image_list'];
    if (imgs is List) {
      for (final i in imgs) {
        if (i is String) {
          images.add(resolveImageUrl(i));
        } else if (i is Map) {
          final url = (i['url'] ?? i['image'] ?? i['src'])?.toString();
          if (url != null) images.add(resolveImageUrl(url));
        }
      }
    }
    return ChapterImagesModel(
      id: (j['slug'] ?? j['chapter_slug'] ?? j['id'] ?? j['chapter_id'] ?? '').toString(),
      title: (j['title'] ?? j['chapter_title'] ?? '').toString(),
      comicSlug: (j['comic_slug'] ?? j['slug'])?.toString(),
      comicTitle: (j['comic_title'] ?? j['title'])?.toString(),
      images: images,
    );
  }
}

/// Comic Read History Model matching comic_history DB table
class ComicHistoryModel {
  final String id;
  final String comicSlug;
  final String comicTitle;
  final String? comicThumbnail;
  final String? chapterSlug;
  final String? chapterNumber;
  final String? chapterTitle;
  final int lastPage;
  final int totalPages;
  final bool isCompleted;
  final String? readAt;

  const ComicHistoryModel({
    required this.id,
    required this.comicSlug,
    required this.comicTitle,
    this.comicThumbnail,
    this.chapterSlug,
    this.chapterNumber,
    this.chapterTitle,
    this.lastPage = 0,
    this.totalPages = 0,
    this.isCompleted = false,
    this.readAt,
  });

  factory ComicHistoryModel.fromJson(Map<String, dynamic> j) {
    String? chNum = (j['chapter_number'] ?? j['chapter_num'] ?? j['ch_num'])?.toString();
    String? chTitle = (j['chapter_title'] ?? j['chapter_label'] ?? j['chapter_name'])?.toString();

    // If chapter number is null or empty, attempt extraction from chapter_title
    if ((chNum == null || chNum.isEmpty || chNum == '0') && chTitle != null) {
      final m = RegExp(r'(?:Chapter|Ch|Chap)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(chTitle);
      if (m != null) {
        chNum = m.group(1);
      }
    }

    final thumb = ComicModel.extractThumbnail(j);

    return ComicHistoryModel(
      id: (j['id'] ?? '').toString(),
      comicSlug: (j['comic_slug'] ?? j['slug'] ?? j['comic_id'] ?? '').toString(),
      comicTitle: (j['comic_title'] ?? j['title'] ?? 'Komik').toString(),
      comicThumbnail: thumb,
      chapterSlug: (j['chapter_slug'] ?? j['chapter_id'])?.toString(),
      chapterNumber: chNum,
      chapterTitle: chTitle,
      lastPage: int.tryParse(j['last_page']?.toString() ?? '') ??
          int.tryParse(j['page']?.toString() ?? '') ??
          int.tryParse(j['last_page_number']?.toString() ?? '') ??
          int.tryParse(j['page_number']?.toString() ?? '') ??
          0,
      totalPages: int.tryParse(j['total_pages']?.toString() ?? '') ??
          int.tryParse(j['total_page']?.toString() ?? '') ??
          int.tryParse(j['pages']?.toString() ?? '') ??
          0,
      isCompleted: j['is_completed'] == true || j['is_completed'] == 1,
      readAt: (j['read_at'] ?? j['watched_at'] ?? j['updated_at'] ?? j['created_at'])?.toString(),
    );
  }

  /// Clean display label for the chapter, e.g. "Chapter 411"
  String get formattedChapter {
    if (chapterNumber != null && chapterNumber!.isNotEmpty && chapterNumber != '0') {
      return 'Chapter $chapterNumber';
    }
    if (chapterTitle != null && chapterTitle!.isNotEmpty) {
      var t = chapterTitle!;
      if (t.toLowerCase().startsWith(comicTitle.toLowerCase())) {
        t = t.substring(comicTitle.length).trim();
        if (t.startsWith('-') || t.startsWith(':')) t = t.substring(1).trim();
      }
      if (t.isNotEmpty) return t;
    }
    return 'Baca Chapter';
  }

  /// Page progress text, e.g. "Hal. 12 / 24"
  String get pageProgress {
    if (lastPage > 0) {
      if (totalPages > 0) {
        return 'Hal. $lastPage / $totalPages';
      }
      return 'Hal. $lastPage';
    }
    return '';
  }
}

/// Model for letter items in Comic A-Z Directory
class DaftarLetterModel {
  final String label;
  final String? huruf;
  final String count;
  final String? url;
  final bool isActive;

  const DaftarLetterModel({
    required this.label,
    this.huruf,
    required this.count,
    this.url,
    this.isActive = false,
  });

  factory DaftarLetterModel.fromJson(Map<String, dynamic> j) {
    return DaftarLetterModel(
      label: (j['label'] ?? '').toString(),
      huruf: j['huruf']?.toString(),
      count: (j['count'] ?? '0').toString(),
      url: j['url']?.toString(),
      isActive: j['is_active'] == true,
    );
  }
}

/// Response wrapper for /api/comic/daftar-komik
class DaftarKomikResultModel {
  final List<ComicModel> items;
  final List<DaftarLetterModel> letters;
  final int total;
  final int totalDisplayed;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const DaftarKomikResultModel({
    required this.items,
    required this.letters,
    required this.total,
    required this.totalDisplayed,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory DaftarKomikResultModel.fromJson(Map<String, dynamic> j) {
    final rawData = j['data'] as List? ?? [];
    final items = rawData
        .whereType<Map>()
        .map((e) => ComicModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawLetters = j['letters'] as List? ?? [];
    final letters = rawLetters
        .whereType<Map>()
        .map((e) => DaftarLetterModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final pagination = j['pagination'] as Map? ?? {};
    final currentPage = int.tryParse(pagination['current_page']?.toString() ?? '') ??
        int.tryParse(pagination['current']?.toString() ?? '') ??
        int.tryParse((j['filters'] as Map?)?['halaman']?.toString() ?? '') ??
        1;
    final totalPages = int.tryParse(pagination['total_pages']?.toString() ?? '') ?? 1;
    final hasNext = pagination['next'] != null && pagination['next'].toString().isNotEmpty;
    final hasPrev = pagination['prev'] != null && pagination['prev'].toString().isNotEmpty;
    final total = int.tryParse(j['total']?.toString() ?? '') ?? items.length;
    final totalDisplayed = int.tryParse(j['total_displayed']?.toString() ?? '') ?? items.length;

    return DaftarKomikResultModel(
      items: items,
      letters: letters,
      total: total,
      totalDisplayed: totalDisplayed,
      currentPage: currentPage,
      totalPages: totalPages,
      hasNext: hasNext || currentPage < totalPages,
      hasPrev: hasPrev || currentPage > 1,
    );
  }
}
