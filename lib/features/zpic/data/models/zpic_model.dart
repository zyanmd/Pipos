class ZpicSource {
  final String url;
  final String mime;

  const ZpicSource({
    required this.url,
    required this.mime,
  });

  factory ZpicSource.fromJson(Map<String, dynamic> json) {
    return ZpicSource(
      url: (json['url'] ?? '').toString(),
      mime: (json['mime'] ?? 'video/mp4').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'mime': mime,
      };
}

class ZpicVideoModel {
  final String title;
  final String url;
  final String fullUrl;
  final String thumbnail;
  final String views;
  final bool isNsfw;
  final String videoId;
  final String? videoSrc;
  final String? poster;
  final List<ZpicSource> videoSources;

  const ZpicVideoModel({
    required this.title,
    required this.url,
    required this.fullUrl,
    required this.thumbnail,
    required this.views,
    required this.isNsfw,
    required this.videoId,
    this.videoSrc,
    this.poster,
    this.videoSources = const [],
  });

  factory ZpicVideoModel.fromJson(Map<String, dynamic> json) {
    final rawSources = json['video_sources'] as List<dynamic>?;
    final parsedSources = rawSources != null
        ? rawSources
            .whereType<Map<String, dynamic>>()
            .map(ZpicSource.fromJson)
            .toList()
        : <ZpicSource>[];

    // Extract videoId if empty
    String id = (json['video_id'] ?? '').toString();
    if (id.isEmpty) {
      final u = (json['url'] ?? '').toString();
      if (u.isNotEmpty) {
        id = u.startsWith('/') ? u.substring(1) : u;
      }
    }

    return ZpicVideoModel(
      title: (json['title'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString(),
      fullUrl: (json['full_url'] ?? '').toString(),
      thumbnail: (json['thumbnail'] ?? json['poster'] ?? '').toString(),
      views: (json['views'] ?? '').toString(),
      isNsfw: json['is_nsfw'] == true,
      videoId: id,
      videoSrc: json['video_src']?.toString(),
      poster: json['poster']?.toString(),
      videoSources: parsedSources,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'full_url': fullUrl,
        'thumbnail': thumbnail,
        'views': views,
        'is_nsfw': isNsfw,
        'video_id': videoId,
        'video_src': videoSrc,
        'poster': poster,
        'video_sources': videoSources.map((e) => e.toJson()).toList(),
      };
}
