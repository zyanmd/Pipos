import '../../../auth/data/models/user_model.dart';
import '../../../profile/data/models/profile_font_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../shared/widgets/smooth_avatar_decoration.dart';
import 'genre_role_model.dart';

/// Safe parser for thumbnail fields which can be either a String or a Map {'src': ...}
String? parseThumb(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) return raw.trim().isNotEmpty ? raw.trim() : null;
  if (raw is Map) {
    final src = raw['src'] ?? raw['url'] ?? raw['link'] ?? raw['image'];
    if (src is String && src.trim().isNotEmpty) return src.trim();
  }
  return null;
}

/// Lightweight anime card model (used in lists, home, search, bookmarks).
class AnimeModel {
  final String id;
  final String title;
  final String? thumb;
  final String? score;
  final String? status;
  final String? episode;
  final String? releasedOn;
  final String? type;
  final String? url;
  final String? synopsis;
  final int? views;

  const AnimeModel({
    required this.id,
    required this.title,
    this.thumb,
    this.score,
    this.status,
    this.episode,
    this.releasedOn,
    this.type,
    this.url,
    this.synopsis,
    this.views,
  });

  /// Cleans redundant episode prefixes like "Ep", "Eps", "Episode", "Ep."
  static String cleanEpisodeNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var s = raw.trim();
    final prefixRegex = RegExp(r'^(?:(?:episodes?|eps?\.?|ch\.?|chapter)\s*[:.-]?\s*)+', caseSensitive: false);
    s = s.replaceFirst(prefixRegex, '').trim();
    final trailingRegex = RegExp(r'\s*(?:episodes?|eps?\.?)\s*$', caseSensitive: false);
    s = s.replaceFirst(trailingRegex, '').trim();
    return s.isNotEmpty ? s : raw.trim();
  }

  /// Formats episode string cleanly with single "Ep <number>" without duplicates.
  static String formatEpisode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final s = cleanEpisodeNumber(raw);
    if (s.isEmpty) return raw.trim();
    final prefixRegex = RegExp(r'^(?:(?:episodes?|eps?\.?|ch\.?|chapter)\s*[:.-]?\s*)+', caseSensitive: false);
    final hadPrefix = prefixRegex.hasMatch(raw.trim());
    if (RegExp(r'^\d+').hasMatch(s) || hadPrefix) {
      return 'Ep $s';
    }
    return s;
  }

  /// Cleans SEO junk and site branding from titles
  static String cleanDisplayTitle(String raw) {
    if (raw.trim().isEmpty) return '';
    var s = raw.trim();

    // 1. Remove website branding / URLs
    s = s.replaceAll(RegExp(r'https?://[^\s]+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\|\s*ylnime(?:\.com)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*ylnime(?:\.com)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bylnime(?:\.com)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bnekopoi(?:\.click|\.care)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bplay\.zpic\.org\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bzpic(?:\.org)?\b', caseSensitive: false), '');

    // 2. Remove streaming SEO suffixes
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*streaming\s+full\s+episode(?:\s+gratis)?.*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*streaming\s+gratis.*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*nonton.*$', caseSensitive: false), '');

    // 3. Remove leading "Nonton streaming" or "Nonton"
    s = s.replaceFirst(RegExp(r'^nonton\s+(?:streaming\s+)?', caseSensitive: false), '');

    // 4. Remove subtitle tags like "Sub Indo HD", "Sub Indo", "Subtitle Indonesia", "BD"
    s = s.replaceAll(RegExp(r'\s*\b(?:sub\s*indo(?:\s*hd)?|subtitle\s+indonesia)\b', caseSensitive: false), '');

    // 5. Clean punctuation at start/end
    s = s.replaceAll(RegExp(r'^[|\-–—.:\s]+|[|\-–—.:\s]+$'), '').trim();

    // 6. Clean multiple spaces
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return s.isNotEmpty ? s : raw.trim();
  }

  /// Cleans web names and URLs from description/synopsis
  static String? cleanDescription(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();
    if (s.toLowerCase().startsWith('nonton streaming') && s.toLowerCase().contains('kualitas')) {
      return null;
    }
    s = s.replaceAll(RegExp(r'https?://[^\s]+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bdi\s+ylnime(?:\.com)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bylnime(?:\.com)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bnekopoi(?:\.click|\.care)?\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bplay\.zpic\.org\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bzpic\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s.isNotEmpty ? s : null;
  }

  factory AnimeModel.fromJson(Map<String, dynamic> raw) {
    final j = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;

    var id = (j['series_key'] ?? j['seriesKey'] ?? j['anime_id'] ?? j['animeId'] ?? j['id'] ?? j['link_id'] ?? j['slug'] ?? '').toString();
    if (id.isEmpty && j['url'] != null) {
      final urlStr = j['url'].toString();
      final m = RegExp(r'series=([^&]+)').firstMatch(urlStr);
      if (m != null) {
        id = m.group(1)!;
      } else if (urlStr.isNotEmpty && !urlStr.startsWith('http')) {
        id = urlStr;
      }
    }
    if (id.isEmpty) {
      final rawTitle = (j['title'] ?? j['anime_title'] ?? j['name'] ?? '').toString().trim();
      if (rawTitle.isNotEmpty) {
        id = rawTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      }
    }
    return AnimeModel(
      id: id,
      title: cleanDisplayTitle((j['title'] ?? j['anime_title'] ?? j['name'] ?? '').toString()),
      thumb: parseThumb(j['cover_url'] ?? j['coverUrl'] ?? j['cover_image'] ?? j['image'] ?? j['poster'] ?? j['poster_url'] ?? j['thumbnail'] ?? j['thumb'] ?? j['cover'] ?? j['anime_thumbnail']),
      score: (j['score'] ?? j['rating'] ?? j['skor'] ?? j['rating_display'] ?? (j['rank'] != null ? '#${j['rank']}' : null))?.toString(),
      status: j['status']?.toString(),
      episode: () {
        if (j['total_episodes'] != null) {
          final t = cleanEpisodeNumber(j['total_episodes'].toString());
          if (t.isNotEmpty) return t;
        }
        if (j['episode'] != null) {
          final e = cleanEpisodeNumber(j['episode'].toString());
          if (e.isNotEmpty) return e;
        }
        if (j['episode_count'] != null) {
          final ec = cleanEpisodeNumber(j['episode_count'].toString());
          if (ec.isNotEmpty) return ec;
        }
        if (j['eps'] != null) {
          final ep = cleanEpisodeNumber(j['eps'].toString());
          if (ep.isNotEmpty) return ep;
        }
        if (j['episodes'] is List) {
          final list = j['episodes'] as List;
          if (list.isNotEmpty && list.first is Map) {
            final firstEp = list.first as Map;
            final epNum = firstEp['episode_number'] ?? firstEp['episode'];
            if (epNum != null) {
              final clean = cleanEpisodeNumber(epNum.toString());
              if (clean.isNotEmpty) return clean;
            }
          }
          if (list.isNotEmpty) return list.length.toString();
        }
        if (j['episodes'] != null && j['episodes'] is! List) {
          final eps = cleanEpisodeNumber(j['episodes'].toString());
          if (eps.isNotEmpty) return eps;
        }
        return null;
      }(),
      releasedOn: (j['released'] ?? j['release_day'] ?? j['day'] ?? j['released_on'] ?? j['release_date'] ?? j['aired'] ?? j['release_time'] ?? (j['views'] != null ? '${j['views']} Views' : null))?.toString(),
      type: j['type']?.toString(),
      url: (j['url'] ?? j['anime_url'])?.toString(),
      synopsis: () {
        var syn = cleanDescription((j['plot'] ?? j['synopsis'] ?? j['description'])?.toString());
        if (syn == null || syn.isEmpty) {
          if (id.contains('nia-liston') || (j['title']?.toString().toLowerCase().contains('nia liston') ?? false)) {
            return 'Seorang pahlawan besar terbaring menjelang ajal tanpa pernah terkalahkan; ia menyesal karena tak pernah menemukan musuh yang mampu menumbangkannya. Ia tak pernah berniat menjemput ajal di tempat selain medan perang, dan kematian yang damai ini membuatnya sangat berharap seandainya segalanya bisa berbeda... Namun, saat tiba-tiba ia terbangun dalam tubuh Nia Liston yang muda dan lemah, sebuah pertarungan baru menantinya. Nia adalah anak yang sakit-sakitan, yang berarti ia harus menempuh jalan panjang sebelum bisa mencapai kondisi prima untuk bertarung. Meski demikian, karena telah diberi kesempatan hidup kedua, ia bertekad untuk meraih apa yang diinginkannya. Kali ini, ia akan hidup—dan mati—demi pertarungan! Beri jalan bagi Sang Gadis Tanpa Ampun!';
          }
        }
        return syn;
      }(),
      views: (j['views'] is num) ? (j['views'] as num).toInt() : int.tryParse(j['views']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumb': thumb,
        'score': score,
        'status': status,
        'episode': episode,
        'released_on': releasedOn,
        'type': type,
        'url': url,
        'synopsis': synopsis,
      };
}

/// Episode entry inside anime detail.
class EpisodeModel {
  final String id;
  final String label;
  final String? url;
  final String? releasedOn;
  final String? episodeNumber;
  final String? thumbnail;

  const EpisodeModel({
    required this.id,
    required this.label,
    this.url,
    this.releasedOn,
    this.episodeNumber,
    this.thumbnail,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> j) {
    var id = (j['id'] ?? j['episode_key'] ?? j['episodeId'] ?? j['episode_id'] ?? '').toString();
    final url = (j['url'] ?? j['link'])?.toString();
    var epNum = (j['episode_number'] ?? j['episode'] ?? j['ep_number'] ?? j['number'])?.toString();
    var rawLabel = (j['title'] ?? j['label'] ?? j['name'] ?? j['episode_title'] ?? (epNum != null ? 'Episode $epNum' : '')).toString();
    var label = AnimeModel.cleanDisplayTitle(rawLabel);
    if (label.isEmpty && epNum != null) {
      label = 'Episode $epNum';
    }

    // If epNum is not in payload, extract from label or url
    if (epNum == null || epNum.trim().isEmpty) {
      final mNum = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(label) ??
          RegExp(r'\b(\d+)\b').firstMatch(label);
      if (mNum != null) {
        epNum = mNum.group(1);
      }
    }

    if (url != null && url.isNotEmpty) {
      final m = RegExp(r'[?&]episode=([^&#]+)').firstMatch(url);
      if (m != null) {
        final epParam = m.group(1)!;
        if (id.isEmpty || (epNum != null && id != epNum && !id.contains(epNum))) {
          id = epParam;
        }
      }
    }

    if (id.isEmpty && epNum != null && epNum.isNotEmpty) {
      id = 'ep_$epNum';
    }

    return EpisodeModel(
      id: id,
      label: label,
      url: url,
      releasedOn: (j['released'] ?? j['date'] ?? j['release_date'] ?? j['released_on'])?.toString(),
      episodeNumber: epNum,
      thumbnail: parseThumb(j['thumbnail'] ?? j['poster'] ?? j['anime_poster'] ?? j['thumb']),
    );
  }
}

/// Episode playback data (from /anime/episode/<id>).
class EpisodeStreamModel {
  final String id;
  final String title;
  final String? animeId;
  final String? animeTitle;
  final String? defaultStreamingUrl;
  final String? prevEpisode;
  final String? nextEpisode;
  final List<StreamSource> streams;
  final List<MirrorLink> mirrors;

  const EpisodeStreamModel({
    required this.id,
    required this.title,
    this.animeId,
    this.animeTitle,
    this.defaultStreamingUrl,
    this.prevEpisode,
    this.nextEpisode,
    this.streams = const [],
    this.mirrors = const [],
  });

  factory EpisodeStreamModel.fromJson(Map<String, dynamic> j) {
    final streams = <StreamSource>[];
    final sList = j['streams'] ?? j['sources'];
    if (sList is List) {
      for (final s in sList) {
        if (s is Map) {
          streams.add(StreamSource.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    } else if (sList is Map && sList['qualities'] is List) {
      for (final q in sList['qualities']) {
        if (q is Map) {
          final qTitle = q['title']?.toString();
          final serverList = q['serverList'] ?? q['servers'];
          if (serverList is List) {
            for (final s in serverList) {
              if (s is Map) {
                streams.add(
                  StreamSource(
                    quality: qTitle ?? s['server']?.toString(),
                    url: (s['url'] ?? s['link'] ?? '').toString(),
                    type: s['type']?.toString(),
                  ),
                );
              }
            }
          }
        }
      }
    }
    final defaultUrl = (j['defaultStreamingUrl'] ?? j['default_streaming_url'] ?? j['stream_url'] ?? j['url'])?.toString();
    if (streams.isEmpty && defaultUrl != null && defaultUrl.isNotEmpty) {
      streams.add(StreamSource(quality: 'Default', url: defaultUrl));
    }

    final mirrors = <MirrorLink>[];
    final mList = j['mirrors'] ?? j['mirror_links'];
    if (mList is List) {
      for (final m in mList) {
        if (m is Map) {
          mirrors.add(MirrorLink.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return EpisodeStreamModel(
      id: (j['episodeId'] ?? j['episode_id'] ?? j['id'] ?? '').toString(),
      title: (j['title'] ?? j['episode_title'] ?? '').toString(),
      animeId: (j['animeId'] ?? j['anime_id'])?.toString(),
      animeTitle: (j['animeTitle'] ?? j['anime_title'])?.toString(),
      defaultStreamingUrl: defaultUrl,
      prevEpisode: (j['prevEpisode'] ?? j['prev_episode'])?.toString(),
      nextEpisode: (j['nextEpisode'] ?? j['next_episode'])?.toString(),
      streams: streams,
      mirrors: mirrors,
    );
  }
}

class StreamSource {
  final String? quality;
  final String url;
  final String? type;

  const StreamSource({this.quality, required this.url, this.type});

  factory StreamSource.fromJson(Map<String, dynamic> j) {
    return StreamSource(
      quality: (j['quality'] ?? j['resolution'])?.toString(),
      url: (j['url'] ?? j['link'] ?? '').toString(),
      type: (j['type'] ?? j['format'])?.toString(),
    );
  }
}

class MirrorLink {
  final String label;
  final String url;

  const MirrorLink({required this.label, required this.url});

  factory MirrorLink.fromJson(Map<String, dynamic> j) {
    return MirrorLink(
      label: (j['label'] ?? j['name'] ?? 'Mirror').toString(),
      url: (j['url'] ?? j['link'] ?? '').toString(),
    );
  }
}

/// Anime detail (from /anime/detail/<id>).
class AnimeDetailModel {
  final String id;
  final String title;
  final String? thumb;
  final String? synopsis;
  final String? status;
  final String? score;
  final String? type;
  final String? duration;
  final String? studio;
  final String? genre; // raw genre string
  final String? releasedOn;
  final String? totalEpisodes;
  final String? url;
  final List<EpisodeModel> episodes;
  final List<String> genres;
  final List<AnimeModel> recommended;

  const AnimeDetailModel({
    required this.id,
    required this.title,
    this.thumb,
    this.synopsis,
    this.status,
    this.score,
    this.type,
    this.duration,
    this.studio,
    this.genre,
    this.releasedOn,
    this.totalEpisodes,
    this.url,
    this.episodes = const [],
    this.genres = const [],
    this.recommended = const [],
  });

  factory AnimeDetailModel.fromJson(Map<String, dynamic> raw) {
    final j = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;

    final episodes = <EpisodeModel>[];
    final epList = j['episodes'] ?? j['episodeList'] ?? j['episode_list'];
    if (epList is List) {
      for (final e in epList) {
        if (e is Map) {
          episodes.add(EpisodeModel.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final genres = <String>[];
    final g = j['genres'] ?? j['genre'];
    if (g is List) {
      for (final item in g) {
        if (item is Map) {
          final name = item['name'] ?? item['title'] ?? item['genre'];
          if (name != null) {
            final clean = GenreUtils.sanitizeGenre(name);
            if (clean != null && clean.isNotEmpty && !genres.contains(clean)) {
              genres.add(clean);
            }
          }
        } else if (item != null) {
          final clean = GenreUtils.sanitizeGenre(item);
          if (clean != null && clean.isNotEmpty && !genres.contains(clean)) {
            genres.add(clean);
          }
        }
      }
    } else if (g is String) {
      for (final part in g.split(',')) {
        final clean = GenreUtils.sanitizeGenre(part);
        if (clean != null && clean.isNotEmpty && !genres.contains(clean)) {
          genres.add(clean);
        }
      }
    }

    final recommended = <AnimeModel>[];
    final recList = j['recommended'] ?? j['recommendations'] ?? j['recommendation'];
    if (recList is List) {
      for (final r in recList) {
        if (r is Map) {
          recommended.add(AnimeModel.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    var id = (j['series_key'] ?? j['id'] ?? j['animeId'] ?? j['anime_id'] ?? '').toString();
    final url = (j['url'] ?? j['anime_url'] ?? j['link'])?.toString();
    if (id.isEmpty && url != null) {
      final m = RegExp(r'series=([^&]+)').firstMatch(url);
      if (m != null) id = m.group(1)!;
    }

    String? genreStr;
    if (j['genre'] is String) {
      genreStr = j['genre'] as String;
    } else if (genres.isNotEmpty) {
      genreStr = genres.join(', ');
    }

    final titleClean = AnimeModel.cleanDisplayTitle((j['title'] ?? j['name'] ?? j['anime_title'] ?? '').toString());
    var syn = AnimeModel.cleanDescription((j['plot'] ?? j['synopsis'] ?? j['description'] ?? j['summary'])?.toString());
    if (syn == null || syn.isEmpty) {
      if (id.contains('nia-liston') || titleClean.toLowerCase().contains('nia liston')) {
        syn = 'Seorang pahlawan besar terbaring menjelang ajal tanpa pernah terkalahkan; ia menyesal karena tak pernah menemukan musuh yang mampu menumbangkannya. Ia tak pernah berniat menjemput ajal di tempat selain medan perang, dan kematian yang damai ini membuatnya sangat berharap seandainya segalanya bisa berbeda... Namun, saat tiba-tiba ia terbangun dalam tubuh Nia Liston yang muda dan lemah, sebuah pertarungan baru menantinya. Nia adalah anak yang sakit-sakitan, yang berarti ia harus menempuh jalan panjang sebelum bisa mencapai kondisi prima untuk bertarung. Meski demikian, karena telah diberi kesempatan hidup kedua, ia bertekad untuk meraih apa yang diinginkannya. Kali ini, ia akan hidup—dan mati—demi pertarungan! Beri jalan bagi Sang Gadis Tanpa Ampun!';
      }
    }

    return AnimeDetailModel(
      id: id,
      title: titleClean,
      thumb: parseThumb(j['cover_image'] ?? j['cover_url'] ?? j['cover'] ?? j['thumbnail'] ?? j['thumb'] ?? j['image'] ?? j['poster'] ?? j['poster_url'] ?? j['anime_thumbnail'] ?? j),
      synopsis: syn,
      status: j['status']?.toString(),
      score: (j['score'] ?? j['rating'])?.toString(),
      type: j['type']?.toString(),
      duration: j['duration']?.toString(),
      studio: j['studio']?.toString(),
      genre: genreStr,
      releasedOn: (j['released'] ?? j['year'] ?? j['releasedOn'] ?? j['released_on'] ?? j['release_date'])?.toString(),
      totalEpisodes: (j['total_episodes'] ?? j['totalEpisodes'] ?? j['episodes_count'] ?? (episodes.isNotEmpty ? episodes.length.toString() : null))?.toString(),
      url: url,
      episodes: episodes,
      genres: genres,
      recommended: recommended,
    );
  }
}

/// Genre item.
class GenreModel {
  final String slug;
  final String name;
  final String? count;

  const GenreModel({
    required this.slug,
    required this.name,
    this.count,
  });

  factory GenreModel.fromJson(Map<String, dynamic> j) {
    final rawName = (j['name'] ?? j['title'] ?? j['genre_name'] ?? j['genre'] ?? '').toString();
    final clean = GenreUtils.sanitizeGenre(rawName) ?? rawName;
    final slug = (j['param'] ?? j['genre_id'] ?? j['slug'] ?? j['id'] ?? clean).toString().toLowerCase().replaceAll(RegExp(r'^[.,;:!?\-–—\s]+|[.,;:!?\-–—\s]+$'), '');
    final name = rawName.isNotEmpty ? rawName.replaceAll(RegExp(r'^[.,;:!?\-–—\s]+|[.,;:!?\-–—\s]+$'), '').trim() : clean;
    return GenreModel(
      slug: slug.isNotEmpty ? slug : clean,
      name: name.isNotEmpty ? name : clean,
      count: j['count']?.toString(),
    );
  }
}

/// Anime schedule entry.
class ScheduleModel {
  final String day;
  final List<AnimeModel> items;

  const ScheduleModel({required this.day, this.items = const []});

  factory ScheduleModel.fromJson(Map<String, dynamic> j) {
    final day = (j['day_name'] ?? j['day'] ?? j['hari'] ?? j['weekday'] ?? '').toString();
    final items = <AnimeModel>[];
    final list = j['anime_list'] ?? j['items'] ?? j['anime'] ?? j['list'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          items.add(AnimeModel.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return ScheduleModel(day: day, items: items);
  }
}

/// Today's anime schedule payload (/ylnime/schedule/today).
class TodayScheduleModel {
  final String today;
  final int total;
  final List<AnimeModel> animeList;

  const TodayScheduleModel({
    this.today = '',
    this.total = 0,
    this.animeList = const [],
  });

  factory TodayScheduleModel.fromJson(Map<String, dynamic> j) {
    final list = <AnimeModel>[];
    final raw = j['anime_list'] ?? j['list'] ?? j['items'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          list.add(AnimeModel.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return TodayScheduleModel(
      today: (j['today'] ?? '').toString(),
      total: j['total'] is int
          ? j['total'] as int
          : int.tryParse(j['total']?.toString() ?? '') ?? list.length,
      animeList: list,
    );
  }
}

/// YLnime Server item for streaming video.
class YlnimeServer {
  final String server;
  final String url;
  final String type;
  final String? note;
  final int? serverId;
  final int? providerId;

  final bool isDirect;
  final String? quality;
  final String? proxyUrl;
  final bool isDead;

  const YlnimeServer({
    required this.server,
    required this.url,
    required this.type,
    this.note,
    this.serverId,
    this.providerId,
    this.isDirect = false,
    this.quality,
    this.proxyUrl,
    this.isDead = false,
  });

  factory YlnimeServer.fromJson(Map<String, dynamic> j) => YlnimeServer(
        server: (j['server'] ?? j['name'] ?? 'Server').toString(),
        url: (j['url'] ?? j['stream_url'] ?? '').toString(),
        type: (j['type'] ?? 'direct').toString(),
        note: j['note']?.toString(),
        serverId: j['server_id'] is int
            ? j['server_id'] as int
            : int.tryParse(j['server_id']?.toString() ?? ''),
        providerId: j['provider_id'] is int
            ? j['provider_id'] as int
            : int.tryParse(j['provider_id']?.toString() ?? ''),
        isDirect: j['is_direct'] == true || (j['type'] == 'direct'),
        quality: j['quality']?.toString(),
        proxyUrl: j['proxy_url']?.toString() ?? j['stream_proxy_url']?.toString(),
        isDead: j['is_dead'] == true,
      );
}

/// YLnime Quality group (360p, 480p, 720p, 1080p).
class YlnimeQualityStream {
  final String title;
  final List<YlnimeServer> serverList;

  const YlnimeQualityStream({
    required this.title,
    this.serverList = const [],
  });

  factory YlnimeQualityStream.fromJson(Map<String, dynamic> j) {
    final list = <YlnimeServer>[];
    final raw = j['serverList'] ?? j['server_list'] ?? j['servers'];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) {
          list.add(YlnimeServer.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return YlnimeQualityStream(
      title: (j['title'] ?? j['quality'] ?? '').toString(),
      serverList: list,
    );
  }
}

/// Episode stream payload with multi-quality and direct servers.
class YlnimeEpisodeStreams {
  final String currentQuality;
  final String? episodeId;
  final int? episodeNumber;
  final String? title;
  final String url;
  final String? seriesName;
  final String? seriesKey;
  final String? seriesUrl;
  final String? nextEpisode;
  final int? nextEpisodeNumber;
  final String? prevEpisode;
  final int? prevEpisodeNumber;
  final List<YlnimeQualityStream> qualities;
  final YlnimeServer? bestPlayable;
  final String? resoDipakai;
  final bool resoFallback;

  const YlnimeEpisodeStreams({
    required this.currentQuality,
    this.episodeId,
    this.episodeNumber,
    this.title,
    required this.url,
    this.seriesName,
    this.seriesKey,
    this.seriesUrl,
    this.nextEpisode,
    this.nextEpisodeNumber,
    this.prevEpisode,
    this.prevEpisodeNumber,
    this.qualities = const [],
    this.bestPlayable,
    this.resoDipakai,
    this.resoFallback = false,
  });

  factory YlnimeEpisodeStreams.fromJson(Map<String, dynamic> j) {
    final qList = <YlnimeQualityStream>[];
    final streams = j['streams'];
    dynamic rawQ;
    if (streams is Map) {
      rawQ = streams['qualities'];
    }
    rawQ ??= j['qualities'];
    if (rawQ is List) {
      for (final q in rawQ) {
        if (q is Map) {
          qList.add(YlnimeQualityStream.fromJson(Map<String, dynamic>.from(q)));
        }
      }
    }
    String? sKey = j['series_key']?.toString();
    if (sKey == null || sKey.isEmpty || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(sKey)) {
      final sUrl = (j['series_url'] ?? '').toString();
      final mS = RegExp(r'[?&]series=([^&#]+)').firstMatch(sUrl);
      if (mS != null && mS.group(1) != null && mS.group(1)!.isNotEmpty) {
        final cand = mS.group(1)!;
        if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
          sKey = cand;
        }
      }
    }
    if (sKey == null || sKey.isEmpty || RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(sKey)) {
      final u = (j['url'] ?? '').toString();
      final mU = RegExp(r'[?&]series=([^&#]+)').firstMatch(u);
      if (mU != null && mU.group(1) != null && mU.group(1)!.isNotEmpty) {
        final cand = mU.group(1)!;
        if (!RegExp(r'^al-[a-z0-9]+$', caseSensitive: false).hasMatch(cand)) {
          sKey = cand;
        }
      }
    }
    if (sKey == null || sKey.isEmpty) {
      final u = (j['url'] ?? '').toString();
      final m = RegExp(r'episode=(al-[a-z0-9]+)-\d+', caseSensitive: false).firstMatch(u);
      if (m != null) {
        sKey = m.group(1);
      }
    }

    final rawEpNum = j['episode_number'];
    final epNum = rawEpNum is int ? rawEpNum : int.tryParse(rawEpNum?.toString() ?? '');
    final rawNextEpNum = j['next_episode_number'];
    final nextEpNum = rawNextEpNum is int ? rawNextEpNum : int.tryParse(rawNextEpNum?.toString() ?? '');
    final rawPrevEpNum = j['prev_episode_number'];
    final prevEpNum = rawPrevEpNum is int ? rawPrevEpNum : int.tryParse(rawPrevEpNum?.toString() ?? '');

    YlnimeServer? bestPlayable;
    if (j['best_playable'] is Map) {
      bestPlayable = YlnimeServer.fromJson(Map<String, dynamic>.from(j['best_playable']));
    }

    final resoDipakai = j['reso_dipakai']?.toString();
    final resoFallback = j['reso_fallback'] == true;

    return YlnimeEpisodeStreams(
      currentQuality: (j['current_quality'] ?? resoDipakai ?? '720p').toString(),
      episodeId: j['episode_id']?.toString(),
      episodeNumber: epNum,
      title: j['title']?.toString(),
      url: (j['url'] ?? '').toString(),
      seriesName: j['series_name']?.toString(),
      seriesKey: sKey,
      seriesUrl: j['series_url']?.toString(),
      nextEpisode: j['next_episode']?.toString(),
      nextEpisodeNumber: nextEpNum,
      prevEpisode: j['prev_episode']?.toString(),
      prevEpisodeNumber: prevEpNum,
      qualities: qList,
      bestPlayable: bestPlayable,
      resoDipakai: resoDipakai,
      resoFallback: resoFallback,
    );
  }
}

/// Episode Comment user info
class EpisodeCommentUser {
  final dynamic id;
  final String username;
  final String? avatar;
  final String? avatarDecorationUrl;
  final String? avatarDecorationCode;
  final bool verifiedBadge;
  final String? profileFont;
  final ProfileFontModel? profileFontData;
  final GenreRoleItem? genreRole;

  const EpisodeCommentUser({
    required this.id,
    required this.username,
    this.avatar,
    this.avatarDecorationUrl,
    this.avatarDecorationCode,
    this.verifiedBadge = false,
    this.profileFont,
    this.profileFontData,
    this.genreRole,
  });

  /// Normalizes avatar paths into absolute URLs
  static String? normalizeAvatar(dynamic v) => UserModel.normalizeAvatarUrl(v);

  /// Full avatar URL helper, falling back to personalized UI-Avatars with brand pink background
  String get fullAvatarUrl {
    final norm = UserModel.normalizeAvatarUrl(avatar);
    if (norm != null && norm.isNotEmpty) {
      return norm;
    }
    final name = (username.isNotEmpty && username != 'Pengguna') ? username : 'User';
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=128&background=FF2D55&color=fff&bold=true';
  }

  String? get fullAvatarDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(avatarDecorationUrl, avatarDecorationCode);
  }

  factory EpisodeCommentUser.fromJson(Map<String, dynamic> j) {
    final rawAvatar = j['avatar'] ??
        j['avatar_url'] ??
        j['user_avatar'] ??
        j['author_avatar'] ??
        j['profile_image'] ??
        j['profile_picture'];
    final rawName = j['username'] ??
        j['author_name'] ??
        j['user_name'] ??
        j['display_name'] ??
        j['name'] ??
        'Pengguna';

    String? decorUrl = j['avatar_decoration_url']?.toString();
    String? decorCode = j['avatar_decoration_code']?.toString();
    if (j['avatar_decoration'] is Map) {
      final dMap = j['avatar_decoration'] as Map;
      decorUrl ??= dMap['image_url']?.toString() ?? dMap['url']?.toString();
      decorCode ??= dMap['code']?.toString();
    } else if (j['avatar_decoration'] is String && j['avatar_decoration'].toString().isNotEmpty) {
      final str = j['avatar_decoration'].toString();
      if (str.startsWith('http') || str.contains('/')) {
        decorUrl ??= str;
      } else {
        decorCode ??= str;
      }
    }

    if ((decorCode == null || decorCode.isEmpty) && decorUrl != null && decorUrl.isNotEmpty) {
      final uri = Uri.tryParse(decorUrl);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : decorUrl.split('/').last;
      final extracted = seg.replaceAll('.png', '').replaceAll('.webp', '').replaceAll('.gif', '').trim();
      if (extracted.isNotEmpty) decorCode = extracted;
    }

    final isVerifiedBadge = (j['verified_badge'] is int)
        ? (j['verified_badge'] as int) == 1
        : (j['verified_badge'] == true ||
            j['verified_badge']?.toString() == '1' ||
            j['verified_badge']?.toString().toLowerCase() == 'true');

    String? pFont = j['profile_font']?.toString();
    ProfileFontModel? pFontData;
    if (j['profile_font_data'] is Map) {
      pFontData = ProfileFontModel.fromJson(Map<String, dynamic>.from(j['profile_font_data'] as Map));
    } else if (pFont != null && pFont.isNotEmpty) {
      pFontData = ProfileFontModel.fromKey(pFont);
    }

    GenreRoleItem? gRole;
    if (j['genre_role'] is Map) {
      gRole = GenreRoleItem.fromJson(Map<String, dynamic>.from(j['genre_role'] as Map));
    } else if (j['primary_role'] is Map) {
      gRole = GenreRoleItem.fromJson(Map<String, dynamic>.from(j['primary_role'] as Map));
    } else if (j['top_role'] is Map) {
      gRole = GenreRoleItem.fromJson(Map<String, dynamic>.from(j['top_role'] as Map));
    } else if (j['roles'] is List && (j['roles'] as List).isNotEmpty) {
      final list = (j['roles'] as List).whereType<Map>().map((e) => GenreRoleItem.fromJson(Map<String, dynamic>.from(e))).toList();
      if (list.isNotEmpty) {
        try {
          gRole = list.firstWhere((r) => r.isPrimary);
        } catch (_) {
          gRole = list.first;
        }
      }
    }

    return EpisodeCommentUser(
      id: j['id'] ?? j['user_id'] ?? j['author_id'] ?? '',
      username: rawName.toString(),
      avatar: UserModel.normalizeAvatarUrl(rawAvatar),
      avatarDecorationUrl: decorUrl,
      avatarDecorationCode: decorCode,
      verifiedBadge: isVerifiedBadge,
      profileFont: pFont,
      profileFontData: pFontData,
      genreRole: gRole,
    );
  }
}

/// Episode Comment model for YLnime comments
class EpisodeCommentModel {
  final int id;
  final String content;
  final bool isSpoiler;
  final bool isPinned;
  final bool isDeleted;
  final int likesCount;
  final int repliesCount;
  final String? createdAt;
  final String? updatedAt;
  final EpisodeCommentUser? user;
  final bool isLiked;
  final List<EpisodeCommentModel> replies;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'gif', 'none'
  final String? mediaThumbnail;
  final bool hasMedia;
  final bool verifiedBadge;

  const EpisodeCommentModel({
    required this.id,
    required this.content,
    this.isSpoiler = false,
    this.isPinned = false,
    this.isDeleted = false,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.isLiked = false,
    this.replies = const [],
    this.mediaUrl,
    this.mediaType = 'none',
    this.mediaThumbnail,
    this.hasMedia = false,
    this.verifiedBadge = false,
  });

  bool get isAuthorVerified => verifiedBadge || user?.verifiedBadge == true;
  GenreRoleItem? get authorGenreRole => user?.genreRole;

  /// Absolute media URL helper
  String? get fullMediaUrl {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;
    if (mediaUrl!.startsWith('http://') || mediaUrl!.startsWith('https://')) {
      return mediaUrl;
    }
    // If it's a local device file path (from local storage, cache, or picker fallback)
    if (mediaUrl!.startsWith('/data/') ||
        mediaUrl!.startsWith('/storage/emulated/') ||
        mediaUrl!.contains(':\\')) {
      return mediaUrl;
    }
    final clean = mediaUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  /// Author avatar URL helper with automatic fallback
  String get authorAvatarUrl =>
      user?.fullAvatarUrl ??
      'https://ui-avatars.com/api/?name=User&size=128&background=FF2D55&color=fff&bold=true';

  EpisodeCommentModel copyWith({
    int? id,
    String? content,
    bool? isSpoiler,
    bool? isPinned,
    bool? isDeleted,
    int? likesCount,
    int? repliesCount,
    String? createdAt,
    String? updatedAt,
    EpisodeCommentUser? user,
    bool? isLiked,
    List<EpisodeCommentModel>? replies,
    String? mediaUrl,
    String? mediaType,
    String? mediaThumbnail,
    bool? hasMedia,
  }) {
    return EpisodeCommentModel(
      id: id ?? this.id,
      content: content ?? this.content,
      isSpoiler: isSpoiler ?? this.isSpoiler,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      mediaThumbnail: mediaThumbnail ?? this.mediaThumbnail,
      hasMedia: hasMedia ?? this.hasMedia,
    );
  }

  factory EpisodeCommentModel.fromJson(Map<String, dynamic> j) {
    final repList = <EpisodeCommentModel>[];
    if (j['replies'] is List) {
      for (final r in j['replies']) {
        if (r is Map) {
          repList.add(EpisodeCommentModel.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }
    final mUrl = j['media_url']?.toString();
    var mType = j['media_type']?.toString() ?? 'none';
    if (mUrl != null && mUrl.isNotEmpty) {
      final isGif = mUrl.toLowerCase().endsWith('.gif') || mUrl.toLowerCase().contains('.gif');
      if (isGif) {
        mType = 'gif';
      } else if (mType == 'none') {
        mType = 'image';
      }
    }
    final hasM = j['has_media'] == true || (mUrl != null && mUrl.isNotEmpty && mType != 'none');

    final rawVb = j['verified_badge'] ??
        j['user_verified_badge'] ??
        j['author_verified_badge'] ??
        j['is_verified_badge'] ??
        (j['user'] is Map
            ? (j['user']['verified_badge'] ??
                j['user']['user_verified_badge'] ??
                j['user']['is_verified_badge'])
            : null);
    final isVb = (rawVb is int)
        ? rawVb == 1
        : (rawVb == true || rawVb?.toString() == '1' || rawVb?.toString().toLowerCase() == 'true');

    // Parse user object or construct from flat fields
    final EpisodeCommentUser parsedUser;
    if (j['user'] is Map) {
      final userMap = Map<String, dynamic>.from(j['user'] as Map);
      if (!userMap.containsKey('verified_badge') && isVb) {
        userMap['verified_badge'] = 1;
      }
      parsedUser = EpisodeCommentUser.fromJson(userMap);
    } else {
      String? flatDecorUrl = j['avatar_decoration_url']?.toString();
      String? flatDecorCode = j['avatar_decoration_code']?.toString();
      if (j['avatar_decoration'] is Map) {
        final dMap = j['avatar_decoration'] as Map;
        flatDecorUrl ??= dMap['image_url']?.toString() ?? dMap['url']?.toString();
        flatDecorCode ??= dMap['code']?.toString();
      } else if (j['avatar_decoration'] is String && j['avatar_decoration'].toString().isNotEmpty) {
        final str = j['avatar_decoration'].toString().trim();
        if (str.startsWith('http') || str.contains('/')) {
          flatDecorUrl ??= str;
        } else {
          flatDecorCode ??= str;
        }
      }

      String? pFont = j['profile_font']?.toString();
      ProfileFontModel? pFontData;
      if (j['profile_font_data'] is Map) {
        pFontData = ProfileFontModel.fromJson(Map<String, dynamic>.from(j['profile_font_data'] as Map));
      } else if (pFont != null && pFont.isNotEmpty) {
        pFontData = ProfileFontModel.fromKey(pFont);
      }

      parsedUser = EpisodeCommentUser(
        id: j['user_id'] ?? j['author_id'] ?? 0,
        username: (j['author_name'] ??
                j['username'] ??
                j['user_name'] ??
                j['display_name'] ??
                j['name'] ??
                'Pengguna')
            .toString(),
        avatar: EpisodeCommentUser.normalizeAvatar(
          j['author_avatar'] ??
              j['avatar'] ??
              j['avatar_url'] ??
              j['user_avatar'] ??
              j['profile_image'] ??
              j['profile_picture'],
        ),
        avatarDecorationUrl: flatDecorUrl,
        avatarDecorationCode: flatDecorCode,
        verifiedBadge: isVb,
        profileFont: pFont,
        profileFontData: pFontData,
      );
    }

    return EpisodeCommentModel(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      content: (j['content'] ?? '').toString(),
      isSpoiler: j['is_spoiler'] == true || j['is_spoiler'] == 1,
      isPinned: j['is_pinned'] == true || j['is_pinned'] == 1,
      isDeleted: j['is_deleted'] == true || j['is_deleted'] == 1,
      likesCount: int.tryParse(j['likes_count']?.toString() ?? '') ?? 0,
      repliesCount: int.tryParse(j['replies_count']?.toString() ?? '') ?? 0,
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
      user: parsedUser,
      isLiked: j['is_liked'] == true || j['is_liked'] == 1,
      replies: repList,
      mediaUrl: mUrl,
      mediaType: mType,
      mediaThumbnail: j['media_thumbnail']?.toString(),
      hasMedia: hasM,
      verifiedBadge: isVb || parsedUser.verifiedBadge,
    );
  }
}

/// Anime Watch History Model matching ylnime_watch_history DB table
class AnimeHistoryModel {
  final String id;
  final String animeId;
  final String animeTitle;
  final String? episodeId;
  final String? episodeNumber;
  final String? episodeTitle;
  final String? thumbnail;
  final String? episodeUrl;
  final int watchDuration;
  final int totalDuration;
  final int currentTime;
  final double progressPercent;
  final String? lastPosition;
  final int totalWatchTime;
  final int watchCount;
  final bool isCompleted;
  final String? completedAt;
  final String? watchedAt;

  const AnimeHistoryModel({
    required this.id,
    required this.animeId,
    required this.animeTitle,
    this.episodeId,
    this.episodeNumber,
    this.episodeTitle,
    this.thumbnail,
    this.episodeUrl,
    this.watchDuration = 0,
    this.totalDuration = 0,
    this.currentTime = 0,
    this.progressPercent = 0.0,
    this.lastPosition,
    this.totalWatchTime = 0,
    this.watchCount = 1,
    this.isCompleted = false,
    this.completedAt,
    this.watchedAt,
  });

  /// Robust helper to parse time in seconds from numbers, numeric strings, or timestamps ("mm:ss", "hh:mm:ss")
  static int parseTimeInSeconds(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val >= 0 ? val : 0;
    if (val is double) return val >= 0 ? val.toInt() : 0;
    final s = val.toString().trim();
    if (s.isEmpty) return 0;

    final numVal = double.tryParse(s);
    if (numVal != null) {
      return numVal >= 0 ? numVal.toInt() : 0;
    }

    final parts = s.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0].trim());
      final sec = double.tryParse(parts[1].trim());
      if (m != null && sec != null) {
        return (m * 60 + sec).toInt();
      }
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      final sec = double.tryParse(parts[2].trim());
      if (h != null && m != null && sec != null) {
        return (h * 3600 + m * 60 + sec).toInt();
      }
    }
    return 0;
  }

  factory AnimeHistoryModel.fromJson(Map<String, dynamic> j) {
    String? epNum = (j['episode_number'] ?? j['episode_num'] ?? j['ep_num'])?.toString();
    String? epTitle = (j['episode_title'] ?? j['episode_label'] ?? j['episode_name'])?.toString();

    // If episode number is null or empty, attempt extraction from episode_title
    if ((epNum == null || epNum.isEmpty || epNum == '0') && epTitle != null) {
      final m = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(epTitle);
      if (m != null) {
        epNum = m.group(1);
      }
    }

    final curTime = parseTimeInSeconds(
      j['current_time'] ??
          j['currentTime'] ??
          j['watch_duration'] ??
          j['watchDuration'] ??
          j['position'] ??
          j['position_seconds'] ??
          j['last_position'] ??
          j['lastPosition'] ??
          j['last_pos'] ??
          j['progress_seconds'] ??
          j['time'],
    );
    final totDur = parseTimeInSeconds(
      j['total_duration'] ??
          j['totalDuration'] ??
          j['duration'] ??
          j['duration_seconds'],
    );

    double prog = double.tryParse(j['progress_percent']?.toString() ?? '') ?? 0.0;
    if (prog <= 0.0 && totDur > 0 && curTime > 0) {
      prog = ((curTime / totDur) * 100).clamp(0.0, 100.0);
    }

    final lastPosStr = (j['last_position'] ?? j['last_pos'] ?? j['lastPosition'])?.toString();

    return AnimeHistoryModel(
      id: (j['id'] ?? '').toString(),
      animeId: (j['anime_id'] ?? j['animeId'] ?? j['slug'] ?? '').toString(),
      animeTitle: (j['anime_title'] ?? j['title'] ?? 'Anime').toString(),
      episodeId: (j['episode_id'] ?? j['episode_key'])?.toString(),
      episodeNumber: epNum,
      episodeTitle: epTitle,
      episodeUrl: (j['episode_url'] ?? j['url'] ?? j['episodeUrl'])?.toString(),
      thumbnail: parseThumb(j['thumbnail'] ?? j['thumb'] ?? j['anime_thumbnail'] ?? j['image']),
      watchDuration: parseTimeInSeconds(j['watch_duration'] ?? j['watchDuration']) > 0
          ? parseTimeInSeconds(j['watch_duration'] ?? j['watchDuration'])
          : curTime,
      totalDuration: totDur,
      currentTime: curTime,
      progressPercent: prog,
      lastPosition: lastPosStr,
      totalWatchTime: parseTimeInSeconds(j['total_watch_time'] ?? j['totalWatchTime']),
      watchCount: int.tryParse(j['watch_count']?.toString() ?? '') ?? 1,
      isCompleted: j['is_completed'] == true || j['is_completed'] == 1,
      completedAt: j['completed_at']?.toString(),
      watchedAt: (j['watched_at'] ?? j['updated_at'] ?? j['created_at'])?.toString(),
    );
  }

  /// Clean display label for the episode, e.g. "Episode 3"
  String get formattedEpisode {
    if (episodeNumber != null && episodeNumber!.isNotEmpty && episodeNumber != '0') {
      return 'Episode $episodeNumber';
    }
    if (episodeTitle != null && episodeTitle!.isNotEmpty) {
      // Clean up "- YLnime" or series name prefixes
      var t = episodeTitle!;
      t = t.replaceAll(RegExp(r'\s*-\s*YLnime.*$', caseSensitive: false), '').trim();
      if (t.toLowerCase().startsWith(animeTitle.toLowerCase())) {
        t = t.substring(animeTitle.length).trim();
        if (t.startsWith('-') || t.startsWith(':')) t = t.substring(1).trim();
      }
      if (t.isNotEmpty) return t;
    }
    return 'Tonton Episode';
  }

  /// Formatted duration e.g. "12:30"
  String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final m = (totalSeconds ~/ 60);
    final s = (totalSeconds % 60);
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get durationProgressText {
    final effectivePos = currentTime > 0 ? currentTime : watchDuration;
    if (effectivePos <= 0) return '';
    final cur = formatDuration(effectivePos);
    if (totalDuration > 0) {
      final tot = formatDuration(totalDuration);
      return '$cur / $tot';
    }
    return cur;
  }
}

/// Model for an item in YLnime Anime List (A-Z)
class YlnimeAnimeListItem {
  final String id;
  final String seriesKey;
  final String title;
  final String? cover;
  final String? poster;
  final String? posterUrl;
  final String? thumbnail;
  final String? image;
  final String? type;
  final String? firstLetter;
  final String? url;

  const YlnimeAnimeListItem({
    this.id = '',
    required this.seriesKey,
    required this.title,
    this.cover,
    this.poster,
    this.posterUrl,
    this.thumbnail,
    this.image,
    this.type,
    this.firstLetter,
    this.url,
  });

  String get effectiveCover {
    if (cover != null && cover!.isNotEmpty) return cover!;
    if (poster != null && poster!.isNotEmpty) return poster!;
    if (posterUrl != null && posterUrl!.isNotEmpty) return posterUrl!;
    if (thumbnail != null && thumbnail!.isNotEmpty) return thumbnail!;
    if (image != null && image!.isNotEmpty) return image!;
    return '';
  }

  factory YlnimeAnimeListItem.fromJson(Map<String, dynamic> json) {
    final sKey = json['series_key']?.toString() ??
        json['id']?.toString() ??
        '';
    final cov = json['cover']?.toString() ??
        json['poster']?.toString() ??
        json['poster_url']?.toString() ??
        json['thumbnail']?.toString() ??
        json['image']?.toString();

    return YlnimeAnimeListItem(
      id: json['id']?.toString() ?? sKey,
      seriesKey: sKey,
      title: json['title']?.toString() ?? '',
      cover: cov,
      poster: json['poster']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      image: json['image']?.toString(),
      type: json['type']?.toString() ?? 'TV',
      firstLetter: json['first_letter']?.toString(),
      url: json['url']?.toString(),
    );
  }

  AnimeModel toAnimeModel() {
    return AnimeModel(
      id: seriesKey.isNotEmpty ? seriesKey : id,
      title: title,
      thumb: effectiveCover,
      url: url,
      type: type,
    );
  }
}

/// Model for a letter button in YLnime Anime List navigation
class YlnimeLetterItem {
  final String letter;
  final String param;
  final String? url;
  final bool isActive;

  const YlnimeLetterItem({
    required this.letter,
    required this.param,
    this.url,
    this.isActive = false,
  });

  factory YlnimeLetterItem.fromJson(Map<String, dynamic> json) {
    return YlnimeLetterItem(
      letter: json['letter']?.toString() ?? '',
      param: json['param']?.toString() ?? '',
      url: json['url']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}

/// Full response model for GET /ylnime/anime-list and /ylnime/anime-list/all
class YlnimeAnimeListResponse {
  final List<YlnimeAnimeListItem> animeList;
  final String currentLetter;
  final String? letterDisplay;
  final List<YlnimeLetterItem> letters;
  final int totalAnime;
  final String? title;
  final String? description;
  final String? url;

  const YlnimeAnimeListResponse({
    this.animeList = const [],
    required this.currentLetter,
    this.letterDisplay,
    this.letters = const [],
    this.totalAnime = 0,
    this.title,
    this.description,
    this.url,
  });

  factory YlnimeAnimeListResponse.fromJson(Map<String, dynamic> json, {String fallbackLetter = 'A'}) {
    // Backend returns { "success": true, "source": "YLnime.com", "data": [...] }
    // or { "anime_list": [...] }
    dynamic rawList = json['data'];
    if (rawList == null || rawList is! List) {
      rawList = json['anime_list'] ?? json['results'] ?? [];
    }
    final list = rawList is List ? rawList : [];

    final lettersRaw = json['letters'] as List<dynamic>? ?? [];

    final parsedItems = list
        .whereType<Map>()
        .map((e) => YlnimeAnimeListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final curLetter = json['current_letter']?.toString() ?? fallbackLetter;

    return YlnimeAnimeListResponse(
      animeList: parsedItems,
      currentLetter: curLetter,
      letterDisplay: json['letter_display']?.toString() ?? '$curLetter (${parsedItems.length} anime)',
      letters: lettersRaw
          .whereType<Map>()
          .map((e) => YlnimeLetterItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalAnime: (json['total_anime'] is num)
          ? (json['total_anime'] as num).toInt()
          : (json['total'] is num)
              ? (json['total'] as num).toInt()
              : parsedItems.length,
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString(),
    );
  }
}

/// Full response model for GET /ylnime/new-releases ("Baru Diupload")
class YlnimeNewReleasesResponse {
  final List<AnimeModel> animeList;
  final int currentPage;
  final String title;
  final String? description;
  final bool hasNext;
  final bool hasPrev;
  final String? nextPageUrl;
  final String? prevPageUrl;
  final int totalAnime;
  final int totalPages;
  final String? url;

  const YlnimeNewReleasesResponse({
    this.animeList = const [],
    this.currentPage = 1,
    this.title = 'Baru Diupload',
    this.description,
    this.hasNext = false,
    this.hasPrev = false,
    this.nextPageUrl,
    this.prevPageUrl,
    this.totalAnime = 0,
    this.totalPages = 1,
    this.url,
  });

  factory YlnimeNewReleasesResponse.fromJson(Map<String, dynamic> json) {
    // Safely unwrap if json contains 'data'
    final map = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json;

    final listRaw = map['anime_list'] as List<dynamic>? ?? [];

    return YlnimeNewReleasesResponse(
      animeList: listRaw
          .whereType<Map>()
          .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: (map['current_page'] is num) ? (map['current_page'] as num).toInt() : 1,
      title: map['title']?.toString() ?? 'Baru Diupload',
      description: map['description']?.toString(),
      hasNext: map['has_next'] == true,
      hasPrev: map['has_prev'] == true,
      nextPageUrl: map['next_page_url']?.toString(),
      prevPageUrl: map['prev_page_url']?.toString(),
      totalAnime: (map['total_anime'] is num) ? (map['total_anime'] as num).toInt() : 0,
      totalPages: (map['total_pages'] is num) ? (map['total_pages'] as num).toInt() : 1,
      url: map['url']?.toString(),
    );
  }
}


