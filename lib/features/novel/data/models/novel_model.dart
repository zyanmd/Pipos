import '../../../../core/config/api_config.dart';

/// Single item representing a Novel in lists, home, search, etc.
class NovelItemModel {
  final int? id;
  final String title;
  final String slug;
  final String poster;
  final String type;
  final String status;
  final String latestChapter;
  final double rating;
  final List<String> genres;
  final String? letter;

  const NovelItemModel({
    this.id,
    required this.title,
    required this.slug,
    required this.poster,
    this.type = 'Web Novel',
    this.status = 'Ongoing',
    this.latestChapter = '',
    this.rating = 4.5,
    this.genres = const [],
    this.letter,
  });

  String get effectivePosterUrl => ApiEndpoints.novelImageUrl(poster);
  String get displayTitle => _cleanNovelText(title);

  /// Clean short chapter badge for novel cards / home screen
  String get cleanLatestChapter {
    if (latestChapter.isEmpty) return '';
    return NovelChapterModel.parseChapterBadge(latestChapter, fallback: latestChapter);
  }

  factory NovelItemModel.fromJson(Map<String, dynamic> json) {
    var rawPoster = json['poster']?.toString() ?? json['image']?.toString() ?? '';
    final rawRating = json['rating'];
    double parsedRating = 4.5;
    if (rawRating != null) {
      parsedRating = double.tryParse(rawRating.toString()) ?? 4.5;
    }

    final rawId = json['id'];
    int? parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId != null) {
      parsedId = int.tryParse(rawId.toString());
    }

    List<String> parsedGenres = [];
    if (json['genres'] is List) {
      parsedGenres = (json['genres'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return NovelItemModel(
      id: parsedId,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
      poster: rawPoster,
      type: json['type']?.toString() ?? 'Web Novel',
      status: json['status']?.toString() ?? 'Ongoing',
      latestChapter: json['latest_chapter']?.toString() ?? '',
      rating: parsedRating,
      genres: parsedGenres,
      letter: json['letter']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'slug': slug,
    'poster': poster,
    'type': type,
    'status': status,
    'latest_chapter': latestChapter,
    'rating': rating,
    'genres': genres,
    if (letter != null) 'letter': letter,
  };
}

String _cleanNovelText(String s) {
  if (s.isEmpty) return s;
  var cleaned = s
      .replaceAll('&#8211;', '–')
      .replaceAll('&ndash;', '–')
      .replaceAll('&#8212;', '—')
      .replaceAll('&mdash;', '—')
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8216;', "'")
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&#8220;', '"')
      .replaceAll('&#8221;', '"')
      .replaceAll('&#8222;', '"')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#8230;', '...')
      .replaceAll('&hellip;', '...')
      .replaceAll('&#x2F;', '/')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Chapter item in novel details
class NovelChapterModel {
  final String title;
  final String slug;
  final String date;
  final String readEndpoint;

  const NovelChapterModel({
    required this.title,
    required this.slug,
    this.date = '',
    this.readEndpoint = '',
  });

  /// Clean display title without newlines or html entities
  String get displayTitle => _cleanNovelText(title);

  /// Extracted short chapter / episode badge (e.g. "Ch. 175", "Ch. 5.5", "Art", "Extra", "Epi")
  String get chapterBadge => parseChapterBadge(displayTitle, slug: slug);

  /// Clean chapter subtitle without the repetitive novel title and language suffix
  String cleanSubtitle([String novelTitle = '']) {
    var t = displayTitle;
    t = t.replaceAll(RegExp(r'\(?\s*TAMAT\s*\)?', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bBahasa\s+Indonesia\b', caseSensitive: false), '');
    if (novelTitle.isNotEmpty) {
      final pattern = RegExp('^${RegExp.escape(novelTitle.trim())}[\\s–—:\\-]*', caseSensitive: false);
      t = t.replaceFirst(pattern, '');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Trim leading/trailing separators
    t = t.replaceAll(RegExp(r'^[\s–—:\-]+|[\s–—:\-]+$'), '').trim();
    return t.isNotEmpty ? t : displayTitle;
  }

  /// Universal parser to extract chapter / episode number or special label from any chapter title
  static String parseChapterBadge(String raw, {String slug = '', String fallback = 'Ch'}) {
    final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Check special non-numbered chapters
    if (RegExp(r'\b(?:illustrations?|ilustrasi)\b', caseSensitive: false).hasMatch(t)) {
      return 'Art';
    }
    if (RegExp(r'\bafterword\b', caseSensitive: false).hasMatch(t)) {
      return 'After';
    }
    if (RegExp(r'\bepilogue\b', caseSensitive: false).hasMatch(t)) {
      return 'Epi';
    }
    if (RegExp(r'\bprologue\b', caseSensitive: false).hasMatch(t)) {
      return 'Pro';
    }
    if (RegExp(r'\bextra\b', caseSensitive: false).hasMatch(t)) {
      return 'Extra';
    }
    if (RegExp(r'\bside\s*story\b', caseSensitive: false).hasMatch(t)) {
      return 'Side';
    }

    // Standard Chapter / Ch. / Bab / Episode patterns
    final mChapter = RegExp(r'(?:chapter|ch\.|ep\.|episode|bab)\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(t);
    if (mChapter != null && mChapter.group(1) != null) {
      return 'Ch. ${mChapter.group(1)}';
    }

    // v2c5 or c175 pattern
    final mVC = RegExp(r'v[0-9]+c([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(t);
    if (mVC != null && mVC.group(1) != null) {
      return 'Ch. ${mVC.group(1)}';
    }

    // Volume standalone: Vol. 2
    final mVol = RegExp(r'(?:volume|vol\.)\s*([0-9]+)', caseSensitive: false).firstMatch(t);
    if (mVol != null && mVol.group(1) != null) {
      return 'Vol. ${mVol.group(1)}';
    }

    // Fallback: slug inspection (e.g. "...-chapter-175-...")
    if (slug.isNotEmpty) {
      final mSlug = RegExp(r'(?:chapter|ch|ep|episode|bab)-([0-9]+(?:-[0-9]+)?)', caseSensitive: false).firstMatch(slug);
      if (mSlug != null && mSlug.group(1) != null) {
        return 'Ch. ${mSlug.group(1)!.replaceAll('-', '.')}';
      }
    }

    // Standalone number in title
    final mNum = RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\b').firstMatch(t);
    if (mNum != null && mNum.group(1) != null) {
      return 'Ch. ${mNum.group(1)}';
    }

    return fallback;
  }

  factory NovelChapterModel.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString() ?? '';
    final slug = json['slug']?.toString() ?? '';
    final date = json['date']?.toString() ?? '';
    final readEndpoint = json['read_endpoint']?.toString() ??
        json['readEndpoint']?.toString() ??
        json['endpoint']?.toString() ??
        (slug.isNotEmpty ? '/api/novel/read/$slug' : '');

    return NovelChapterModel(
      title: _cleanNovelText(rawTitle),
      slug: slug,
      date: date,
      readEndpoint: readEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'slug': slug,
    'date': date,
    'read_endpoint': readEndpoint,
  };
}

/// Detailed novel information with chapters
class NovelDetailModel {
  final String title;
  final String altTitle;
  final String slug;
  final String poster;
  final String type;
  final String status;
  final double rating;
  final String synopsis;
  final List<String> genres;
  final String author;
  final String country;
  final String totalChapter;
  final String tags;
  final List<NovelChapterModel> chapters;
  final String source;
  final bool success;

  const NovelDetailModel({
    required this.title,
    this.altTitle = '',
    required this.slug,
    required this.poster,
    this.type = 'Web Novel',
    this.status = 'Ongoing',
    this.rating = 4.2,
    this.synopsis = '',
    this.author = 'Sakuranovel',
    this.country = 'Japan/China/Korea',
    this.totalChapter = '',
    this.tags = '',
    this.genres = const [],
    this.chapters = const [],
    this.source = 'Sakuranovel',
    this.success = true,
  });

  String get effectivePosterUrl => ApiEndpoints.novelImageUrl(poster);
  String get displayTitle => _cleanNovelText(title);
  String get displayAltTitle => _cleanNovelText(altTitle);
  String get ratingString => rating > 0 ? rating.toStringAsFixed(1) : '4.5';

  factory NovelDetailModel.fromJson(Map<String, dynamic> rawJson) {
    // Robustly handle both wrapped { "data": { ... } } and direct map
    final Map<String, dynamic> json = (rawJson.containsKey('data') && rawJson['data'] is Map)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final Map<String, dynamic> info = (json['info'] is Map)
        ? Map<String, dynamic>.from(json['info'] as Map)
        : {};

    final String source = rawJson['source']?.toString() ?? json['source']?.toString() ?? 'Sakuranovel';
    final bool success = rawJson['success'] == true || json['success'] == true || !rawJson.containsKey('success');

    final rawRating = json['rating'] ?? info['rating'];
    double parsedRating = 4.2;
    if (rawRating != null) {
      parsedRating = double.tryParse(rawRating.toString()) ?? 4.2;
    }

    List<String> parsedGenres = [];
    if (json['genres'] is List) {
      parsedGenres = (json['genres'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final rawAuthor = info['author']?.toString() ?? json['author']?.toString() ?? 'Sakuranovel';
    final rawCountry = info['country']?.toString() ?? json['country']?.toString() ?? 'Japan/China/Korea';
    final rawTags = info['tags']?.toString() ?? json['tags']?.toString() ?? 'Action, Fantasy, Adventure';
    if (parsedGenres.isEmpty && rawTags.isNotEmpty) {
      parsedGenres = rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    List<NovelChapterModel> parsedChapters = [];
    if (json['chapters'] is List) {
      parsedChapters = (json['chapters'] as List)
          .map((e) => NovelChapterModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final rawTotalChapter = info['total_chapter']?.toString() ??
        json['total_chapter']?.toString() ??
        (parsedChapters.isNotEmpty ? '${parsedChapters.length}' : '');

    final String rawTitle = json['title']?.toString() ?? '';
    final String rawAlt = json['alt_title']?.toString() ?? json['altTitle']?.toString() ?? '';
    final String rawSlug = json['slug']?.toString() ?? json['id']?.toString() ?? '';

    return NovelDetailModel(
      title: _cleanNovelText(rawTitle),
      altTitle: _cleanNovelText(rawAlt),
      slug: rawSlug,
      poster: json['poster']?.toString() ?? json['image']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Web Novel',
      status: json['status']?.toString() ?? 'Ongoing',
      rating: parsedRating,
      synopsis: _cleanNovelText(json['synopsis']?.toString() ?? ''),
      genres: parsedGenres,
      author: rawAuthor,
      country: rawCountry,
      totalChapter: rawTotalChapter,
      tags: rawTags,
      chapters: parsedChapters,
      source: source,
      success: success,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'genres': genres,
    'info': {
      'author': author,
      'country': country,
      'tags': tags,
      'total_chapter': totalChapter,
    },
    'poster': poster,
    'rating': rating.toStringAsFixed(1),
    'title': title,
    'type': type,
  };

  Map<String, dynamic> toApiResponse() => {
    'data': toJson(),
    'source': source,
    'success': success,
  };
}

/// Chapter content for novel reading
class NovelReaderModel {
  final String title;
  final String slug;
  final String contentHtml;
  final List<String> paragraphs;
  final String? prevSlug;
  final String? nextSlug;
  final String? parentSlug;

  const NovelReaderModel({
    required this.title,
    required this.slug,
    required this.contentHtml,
    required this.paragraphs,
    this.prevSlug,
    this.nextSlug,
    this.parentSlug,
  });

  factory NovelReaderModel.fromJson(Map<String, dynamic> json, {String fallbackSlug = ''}) {
    final title = json['title']?.toString() ?? '';
    final contentRaw = json['content']?.toString() ?? '';
    final nav = json['navigation'] as Map<String, dynamic>? ?? {};

    // Clean HTML into pleasant paragraphs
    final paragraphs = _extractParagraphs(contentRaw);
    final rawSlug = json['slug']?.toString() ?? '';

    return NovelReaderModel(
      title: title,
      slug: rawSlug.isNotEmpty ? rawSlug : fallbackSlug,
      contentHtml: contentRaw,
      paragraphs: paragraphs,
      prevSlug: nav['prev_slug']?.toString(),
      nextSlug: nav['next_slug']?.toString(),
      parentSlug: nav['parent_slug']?.toString(),
    );
  }

  static List<String> _extractParagraphs(String raw) {
    if (raw.isEmpty) return [];

    // Strip script and style blocks first
    var text = raw
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');

    // Replace linebreaks and <p> tags
    text = text
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ''); // Strip all other html tags

    // Decode common html entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8211;', '–')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#8230;', '...')
        .replaceAll('&hellip;', '...');

    final lines = text.split('\n');
    final result = <String>[];
    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) continue;
      // Skip site watermark lines
      if (trimmed.toLowerCase().contains('sakuranovel.id') && trimmed.length < 30) {
        continue;
      }
      result.add(trimmed);
    }
    return result;
  }
}

/// Tag item from /api/novel/tags
class NovelTagModel {
  final String name;
  final String slug;
  final int count;
  final String endpoint;

  const NovelTagModel({
    required this.name,
    required this.slug,
    this.count = 0,
    this.endpoint = '',
  });

  factory NovelTagModel.fromJson(Map<String, dynamic> json) {
    return NovelTagModel(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      count: (json['count'] is num)
          ? (json['count'] as num).toInt()
          : (int.tryParse(json['count']?.toString() ?? '') ?? 0),
      endpoint: json['endpoint']?.toString() ?? '',
    );
  }
}

/// Genre item
class NovelGenreModel {
  final String name;
  final String slug;
  final int count;

  const NovelGenreModel({
    required this.name,
    required this.slug,
    this.count = 0,
  });

  factory NovelGenreModel.fromJson(Map<String, dynamic> json) {
    return NovelGenreModel(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      count: (json['count'] is num)
          ? (json['count'] as num).toInt()
          : (int.tryParse(json['count']?.toString() ?? '') ?? 0),
    );
  }
}

/// Pagination container
class NovelPaginationData<T> {
  final List<T> items;
  final int currentPage;
  final bool hasNext;

  const NovelPaginationData({
    required this.items,
    this.currentPage = 1,
    this.hasNext = false,
  });
}

/// Response wrapper for /api/novel/daftar-novel (A-Z directory)
class DaftarNovelResultModel {
  final List<NovelItemModel> items;
  final List<String> letters;
  final int total;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const DaftarNovelResultModel({
    required this.items,
    required this.letters,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory DaftarNovelResultModel.fromJson(Map<String, dynamic> j) {
    dynamic rawData = j['results'] ?? (j['data'] is Map ? j['data']['results'] : j['data']);
    List<NovelItemModel> items = [];
    if (rawData is List) {
      items = rawData
          .whereType<Map>()
          .map((e) => NovelItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<String> letters = [];
    dynamic rawLetters = j['letters'] ?? (j['data'] is Map ? j['data']['letters'] : null);
    if (rawLetters is List) {
      letters = rawLetters.map((e) => e.toString()).toList();
    }

    final pag = (j['pagination'] is Map ? j['pagination'] : (j['data'] is Map ? j['data'] : {})) as Map;
    final currentPage = int.tryParse(pag['currentPage']?.toString() ?? pag['current_page']?.toString() ?? '') ?? 1;
    final totalPages = int.tryParse(pag['totalPages']?.toString() ?? pag['total_pages']?.toString() ?? '') ?? 1;
    final total = int.tryParse(j['total']?.toString() ?? pag['total']?.toString() ?? '') ?? items.length;
    final hasNext = pag['hasNext'] == true || pag['has_next'] == true || currentPage < totalPages;
    final hasPrev = pag['hasPrev'] == true || pag['has_prev'] == true || currentPage > 1;

    return DaftarNovelResultModel(
      items: items,
      letters: letters,
      total: total,
      currentPage: currentPage,
      totalPages: totalPages,
      hasNext: hasNext,
      hasPrev: hasPrev,
    );
  }
}


