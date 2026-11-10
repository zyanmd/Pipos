import '../../../../core/config/api_config.dart';

class ReelModel {
  final String id;
  final String title;
  final String seriesKey;
  final String videoUrl;
  final String coverUrl;
  final int duration;
  final String streamUrl;
  final String streamProxyUrl;
  final String streamType;
  final String quality;
  final String server;
  final String note;
  final ReelClipModel clip;
  final ReelEpisodeModel episode;
  final ReelAnimeModel anime;
  final ReelRedirectModel redirect;
  final ReelUiModel ui;
  final int likes;
  final bool isLiked;

  const ReelModel({
    required this.id,
    required this.title,
    this.seriesKey = '',
    this.videoUrl = '',
    this.coverUrl = '',
    this.duration = 30,
    this.streamUrl = '',
    this.streamProxyUrl = '',
    this.streamType = 'direct',
    this.quality = '720p',
    this.server = 'Animeverse Direct',
    this.note = '',
    required this.clip,
    required this.episode,
    required this.anime,
    required this.redirect,
    required this.ui,
    this.likes = 0,
    this.isLiked = false,
  });

  bool get isPhysicalCut {
    final v = videoUrl.toLowerCase();
    final p = streamProxyUrl.toLowerCase();
    final s = streamUrl.toLowerCase();
    if (v.contains('/uploads/reels/') || p.contains('/uploads/reels/') || s.contains('/uploads/reels/')) {
      return true;
    }
    return false;
  }

  static String _unwrapProxy(String u) {
    if (!u.contains('/stream-proxy')) return u;
    try {
      final uri = Uri.parse(u.startsWith('/') ? '${ApiConfig.baseUrl}$u' : u);
      final inner = uri.queryParameters['url'];
      if (inner != null && inner.isNotEmpty) {
        final decoded = Uri.decodeFull(inner).trim();
        if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
          return decoded;
        }
      }
    } catch (_) {}
    return u;
  }

  String get effectiveVideoUrl {
    // 0. Unwrap any proxy URL to direct CDN if possible
    final unwrappedStream = _unwrapProxy(streamUrl);
    final unwrappedVideo = _unwrapProxy(videoUrl);
    final unwrappedProxy = _unwrapProxy(streamProxyUrl);

    // 1. Direct high-speed CDN stream (s3.animeverse.id / animekita.org / mp4) - bypass slow VPS proxy!
    for (final cand in [unwrappedStream, unwrappedVideo, unwrappedProxy]) {
      if (cand.isNotEmpty && (cand.contains('s3.animeverse.id') || cand.contains('animekita.org') || cand.endsWith('.mp4') || cand.contains('.mp4?'))) {
        if (cand.startsWith('http://') || cand.startsWith('https://')) {
          return cand;
        }
      }
    }

    // 2. If videoUrl is provided as an absolute URL and is not a slow proxy when streamUrl is direct
    if (unwrappedVideo.isNotEmpty) {
      if (unwrappedVideo.contains('/stream-proxy') && unwrappedStream.isNotEmpty && (unwrappedStream.startsWith('http://') || unwrappedStream.startsWith('https://'))) {
        return unwrappedStream;
      }
      if (unwrappedVideo.startsWith('http://') || unwrappedVideo.startsWith('https://')) {
        return unwrappedVideo;
      }
      final clean = unwrappedVideo.startsWith('/') ? unwrappedVideo : '/$unwrappedVideo';
      return '${ApiConfig.baseUrl}$clean';
    }
    // 3. Fallback to streamProxyUrl
    if (unwrappedProxy.isNotEmpty) {
      if (unwrappedProxy.startsWith('http://') || unwrappedProxy.startsWith('https://')) {
        return unwrappedProxy;
      }
      final clean = unwrappedProxy.startsWith('/') ? unwrappedProxy : '/$unwrappedProxy';
      return '${ApiConfig.baseUrl}$clean';
    }
    // 4. Fallback to streamUrl
    final rawUrl = unwrappedStream;
    if (rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        if (rawUrl.contains('/stream-proxy') || rawUrl.contains('s3.animeverse.id')) return rawUrl;
        final cleanUrl = rawUrl.split('#').first;
        return '${ApiConfig.baseUrl}/api/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(cleanUrl)}';
      }
      final clean = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
      return '${ApiConfig.baseUrl}$clean';
    }
    return '';
  }

  String get effectiveCoverUrl {
    if (coverUrl.isNotEmpty) return coverUrl;
    if (anime.thumbnail.isNotEmpty) return anime.thumbnail;
    return '';
  }

  String get displayTitle {
    var cleaned = title.replaceAll('\n', ' ').replaceAll('\r', ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      seriesKey: json['series_key']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      coverUrl: json['cover_url']?.toString() ?? '',
      duration: int.tryParse(json['duration']?.toString() ?? '30') ?? 30,
      streamUrl: json['stream_url']?.toString() ?? '',
      streamProxyUrl: json['stream_proxy_url']?.toString() ?? '',
      streamType: json['stream_type']?.toString() ?? 'direct',
      quality: json['quality']?.toString() ?? '720p',
      server: json['server']?.toString() ?? 'Animeverse Direct',
      note: json['note']?.toString() ?? '',
      clip: json['clip'] is Map
          ? ReelClipModel.fromJson(Map<String, dynamic>.from(json['clip'] as Map))
          : const ReelClipModel(),
      episode: json['episode'] is Map
          ? ReelEpisodeModel.fromJson(Map<String, dynamic>.from(json['episode'] as Map))
          : const ReelEpisodeModel(),
      anime: json['anime'] is Map
          ? ReelAnimeModel.fromJson(Map<String, dynamic>.from(json['anime'] as Map))
          : const ReelAnimeModel(),
      redirect: json['redirect'] is Map
          ? ReelRedirectModel.fromJson(Map<String, dynamic>.from(json['redirect'] as Map))
          : const ReelRedirectModel(),
      ui: json['ui'] is Map
          ? ReelUiModel.fromJson(Map<String, dynamic>.from(json['ui'] as Map))
          : const ReelUiModel(),
      likes: int.tryParse(json['likes']?.toString() ?? json['total_likes']?.toString() ?? '0') ?? 0,
      isLiked: json['is_liked'] == true || json['liked'] == true,
    );
  }

  ReelModel copyWith({
    String? id,
    int? likes,
    bool? isLiked,
  }) {
    return ReelModel(
      id: id ?? this.id,
      title: title,
      seriesKey: seriesKey,
      videoUrl: videoUrl,
      coverUrl: coverUrl,
      duration: duration,
      streamUrl: streamUrl,
      streamProxyUrl: streamProxyUrl,
      streamType: streamType,
      quality: quality,
      server: server,
      note: note,
      clip: clip,
      episode: episode,
      anime: anime,
      redirect: redirect,
      ui: ui,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class ReelClipModel {
  final int startTime;
  final int endTime;
  final int duration;
  final String startTimeFormatted;
  final String endTimeFormatted;

  const ReelClipModel({
    this.startTime = 0,
    this.endTime = 30,
    this.duration = 30,
    this.startTimeFormatted = '00:00',
    this.endTimeFormatted = '00:30',
  });

  factory ReelClipModel.fromJson(Map<String, dynamic> json) {
    return ReelClipModel(
      startTime: int.tryParse(json['start_time']?.toString() ?? '0') ?? 0,
      endTime: int.tryParse(json['end_time']?.toString() ?? '30') ?? 30,
      duration: int.tryParse(json['duration']?.toString() ?? '30') ?? 30,
      startTimeFormatted: json['start_time_formatted']?.toString() ?? '00:00',
      endTimeFormatted: json['end_time_formatted']?.toString() ?? '00:30',
    );
  }
}

class ReelEpisodeModel {
  final String episodeId;
  final String episodeNumber;
  final String episodeTitle;
  final String episodeUrl;
  final String episodeKey;
  final String seriesUrl;
  final String seriesKey;

  const ReelEpisodeModel({
    this.episodeId = '',
    this.episodeNumber = '',
    this.episodeTitle = '',
    this.episodeUrl = '',
    this.episodeKey = '',
    this.seriesUrl = '',
    this.seriesKey = '',
  });

  String get displayEpisodeTitle {
    var cleaned = episodeTitle.replaceAll('\n', ' ').replaceAll('\r', ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  factory ReelEpisodeModel.fromJson(Map<String, dynamic> json) {
    return ReelEpisodeModel(
      episodeId: json['episode_id']?.toString() ?? '',
      episodeNumber: json['episode_number']?.toString() ?? '',
      episodeTitle: json['episode_title']?.toString() ?? '',
      episodeUrl: json['episode_url']?.toString() ?? '',
      episodeKey: json['episode_key']?.toString() ?? '',
      seriesUrl: json['series_url']?.toString() ?? '',
      seriesKey: json['series_key']?.toString() ?? '',
    );
  }
}

class ReelAnimeModel {
  final String animeId;
  final String title;
  final String thumbnail;
  final int totalDuration;
  final String totalDurationFormatted;

  const ReelAnimeModel({
    this.animeId = '',
    this.title = '',
    this.thumbnail = '',
    this.totalDuration = 1440,
    this.totalDurationFormatted = '24:00',
  });

  factory ReelAnimeModel.fromJson(Map<String, dynamic> json) {
    return ReelAnimeModel(
      animeId: json['anime_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      totalDuration: int.tryParse(json['total_duration']?.toString() ?? '1440') ?? 1440,
      totalDurationFormatted: json['total_duration_formatted']?.toString() ?? '24:00',
    );
  }
}

class ReelRedirectModel {
  final String watchUrl;
  final String detailUrl;
  final String fullEpisodeUrl;

  const ReelRedirectModel({
    this.watchUrl = '',
    this.detailUrl = '',
    this.fullEpisodeUrl = '',
  });

  factory ReelRedirectModel.fromJson(Map<String, dynamic> json) {
    return ReelRedirectModel(
      watchUrl: json['watch_url']?.toString() ?? '',
      detailUrl: json['detail_url']?.toString() ?? '',
      fullEpisodeUrl: json['full_episode_url']?.toString() ?? '',
    );
  }
}

class ReelUiModel {
  final bool autoplay;
  final bool loop;
  final bool muted;
  final String aspectRatio;
  final int clipStart;
  final int clipEnd;

  const ReelUiModel({
    this.autoplay = true,
    this.loop = true,
    this.muted = false,
    this.aspectRatio = '9:16',
    this.clipStart = 0,
    this.clipEnd = 30,
  });

  factory ReelUiModel.fromJson(Map<String, dynamic> json) {
    return ReelUiModel(
      autoplay: json['autoplay'] != false,
      loop: json['loop'] != false,
      muted: json['muted'] == true,
      aspectRatio: json['aspect_ratio']?.toString() ?? '9:16',
      clipStart: int.tryParse(json['clip_start']?.toString() ?? '0') ?? 0,
      clipEnd: int.tryParse(json['clip_end']?.toString() ?? '30') ?? 30,
    );
  }
}

class ReelPagination {
  final List<ReelModel> items;
  final int page;
  final int total;
  final bool hasMore;
  final int nextPage;

  const ReelPagination({
    required this.items,
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
    this.nextPage = 1,
  });

  factory ReelPagination.fromJson(Map<String, dynamic> json) {
    List<ReelModel> items = [];
    if (json['data'] is List) {
      items = (json['data'] as List)
          .map((e) => ReelModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return ReelPagination(
      items: items,
      page: int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      total: int.tryParse(json['total']?.toString() ?? '0') ?? items.length,
      hasMore: json['has_more'] == true,
      nextPage: int.tryParse(json['next_page']?.toString() ?? '1') ?? 1,
    );
  }
}

