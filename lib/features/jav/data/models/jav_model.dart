import '../../../../core/config/api_config.dart';

class JavVideoModel {
  final String id;
  final String code;
  final String title;
  final String url;
  final String thumbnail;
  final String image;
  final String duration;
  final String views;
  final String quality;
  final String timeAgo;
  final String type;
  final String previewVideo;

  const JavVideoModel({
    required this.id,
    this.code = '',
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.image,
    required this.duration,
    required this.views,
    required this.quality,
    required this.timeAgo,
    required this.type,
    required this.previewVideo,
  });

  static String extractCode(String text) {
    final m = RegExp(r'\b([A-Za-z0-9]{2,10}-[0-9]{2,6})\b').firstMatch(text);
    return m != null ? m.group(1)!.toUpperCase() : '';
  }

  static String formatDuration(String raw) {
    var d = raw.trim();
    if (d.isEmpty) return '';
    if (d.startsWith('PT')) {
      final hoursMatch = RegExp(r'(\d+)H').firstMatch(d);
      final minsMatch = RegExp(r'(\d+)M').firstMatch(d);
      final secsMatch = RegExp(r'(\d+)S').firstMatch(d);

      final h = hoursMatch != null ? int.tryParse(hoursMatch.group(1)!) ?? 0 : 0;
      final m = minsMatch != null ? int.tryParse(minsMatch.group(1)!) ?? 0 : 0;
      final s = secsMatch != null ? int.tryParse(secsMatch.group(1)!) ?? 0 : 0;

      if (h > 0) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
    }
    return d;
  }

  factory JavVideoModel.fromJson(Map<String, dynamic> json) {
    final rawThumb = (json['thumbnail'] ?? json['image'] ?? json['poster'] ?? '').toString();
    final rawImg = (json['image'] ?? json['thumbnail'] ?? json['poster'] ?? '').toString();
    final rawDuration = (json['duration'] ?? '').toString();

    final thumb = ApiEndpoints.javImageUrl(rawThumb);
    final img = ApiEndpoints.javImageUrl(rawImg);

    final title = (json['title'] ?? '').toString().trim();
    final rawCode = (json['code'] ?? '').toString().trim();
    final code = rawCode.isNotEmpty ? rawCode : extractCode(title);

    return JavVideoModel(
      id: (json['id'] ?? '').toString(),
      code: code,
      title: title,
      url: (json['url'] ?? '').toString(),
      thumbnail: thumb,
      image: img,
      duration: formatDuration(rawDuration),
      views: (json['views'] ?? '').toString().trim(),
      quality: (json['quality'] ?? '').toString().trim(),
      timeAgo: (json['time_ago'] ?? json['added_on'] ?? '').toString().trim(),
      type: (json['type'] ?? json['video_type'] ?? '').toString().trim(),
      previewVideo: (json['preview_video'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'url': url,
        'thumbnail': thumbnail,
        'image': image,
        'duration': duration,
        'views': views,
        'quality': quality,
        'time_ago': timeAgo,
        'type': type,
        'preview_video': previewVideo,
      };
}

class JavActressModel {
  final String name;
  final String url;
  final String image;
  final String videoCount;

  const JavActressModel({
    required this.name,
    required this.url,
    required this.image,
    required this.videoCount,
  });

  String get slug => (url.contains('/actress/') ? url.split('/actress/').last.replaceAll('/', '') : name.toLowerCase().replaceAll(' ', '-'));

  factory JavActressModel.fromJson(Map<String, dynamic> json) {
    String rawName = (json['name'] ?? '').toString().trim();
    String count = '';

    // If scraper includes newline with video count, clean it up
    if (rawName.contains('\n')) {
      final parts = rawName.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        rawName = parts.first;
        if (parts.length > 1) {
          count = parts[1];
        }
      }
    }

    return JavActressModel(
      name: rawName,
      url: (json['url'] ?? '').toString(),
      image: ApiEndpoints.javImageUrl((json['image'] ?? '').toString()),
      videoCount: count,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'image': image,
        'video_count': videoCount,
      };
}

class JavCategoryModel {
  final String name;
  final String url;
  final String image;

  const JavCategoryModel({
    required this.name,
    required this.url,
    required this.image,
  });

  String get slug => (url.contains('/category/') ? url.split('/category/').last.replaceAll('/', '') : name.toLowerCase().replaceAll(' ', '-'));

  factory JavCategoryModel.fromJson(Map<String, dynamic> json) {
    var rawName = (json['name'] ?? '').toString().trim();
    // Regex clean count prefix if exists e.g. "412 VideoWanita PenyidikWanita Penyidik"
    final countMatch = RegExp(r'^[\d,\.]+\s*Video(.*)$', caseSensitive: false).firstMatch(rawName);
    if (countMatch != null) {
      rawName = countMatch.group(1)?.trim() ?? rawName;
    }
    // Deduplicate repeated string if duplicated by scraper
    if (rawName.length >= 6) {
      final half = rawName.length ~/ 2;
      final firstHalf = rawName.substring(0, half);
      final secondHalf = rawName.substring(half);
      if (firstHalf == secondHalf) {
        rawName = firstHalf;
      }
    }

    return JavCategoryModel(
      name: rawName,
      url: (json['url'] ?? '').toString(),
      image: ApiEndpoints.javImageUrl((json['image'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'image': image,
      };
}

class JavDetailModel {
  final String id;
  final String code;
  final String title;
  final String url;
  final String thumbnail;
  final String poster;
  final String duration;
  final String views;
  final String likes;
  final String dislikes;
  final String channel;
  final String description;
  final String addedOn;
  final String videoUrl;
  final String streamUrl;
  final List<JavActressModel> actresses;
  final List<JavCategoryModel> categories;
  final List<String> tags;
  final List<JavVideoModel> relatedVideos;

  const JavDetailModel({
    required this.id,
    this.code = '',
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.poster,
    required this.duration,
    required this.views,
    required this.likes,
    required this.dislikes,
    required this.channel,
    required this.description,
    required this.addedOn,
    required this.videoUrl,
    required this.streamUrl,
    required this.actresses,
    required this.categories,
    required this.tags,
    required this.relatedVideos,
  });

  factory JavDetailModel.fromJson(Map<String, dynamic> json) {
    final rawActresses = json['actresses'] as List<dynamic>?;
    final actressesList = rawActresses != null
        ? rawActresses
            .whereType<Map<String, dynamic>>()
            .map(JavActressModel.fromJson)
            .toList()
        : <JavActressModel>[];

    final rawCategories = json['categories'] as List<dynamic>?;
    final categoriesList = rawCategories != null
        ? rawCategories
            .whereType<Map<String, dynamic>>()
            .map(JavCategoryModel.fromJson)
            .toList()
        : <JavCategoryModel>[];

    final rawTags = json['tags'] as List<dynamic>?;
    final tagsList = rawTags != null
        ? rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final rawRelated = json['related_videos'] as List<dynamic>?;
    final relatedList = rawRelated != null
        ? rawRelated
            .whereType<Map<String, dynamic>>()
            .map(JavVideoModel.fromJson)
            .toList()
        : <JavVideoModel>[];

    final rawThumb = (json['thumbnail'] ?? json['poster'] ?? '').toString();
    final rawPoster = (json['poster'] ?? json['thumbnail'] ?? '').toString();
    final thumb = ApiEndpoints.javImageUrl(rawThumb);
    final poster = ApiEndpoints.javImageUrl(rawPoster);
    final vUrl = (json['video_url'] ?? '').toString();
    final sUrl = (json['stream_url'] ?? vUrl).toString();
    final title = (json['title'] ?? '').toString().trim();
    final rawCode = (json['code'] ?? '').toString().trim();
    final code = rawCode.isNotEmpty ? rawCode : JavVideoModel.extractCode(title);

    return JavDetailModel(
      id: (json['id'] ?? '').toString(),
      code: code,
      title: title,
      url: (json['url'] ?? '').toString(),
      thumbnail: thumb,
      poster: poster,
      duration: JavVideoModel.formatDuration((json['duration'] ?? '').toString()),
      views: (json['views'] ?? '').toString().trim(),
      likes: (json['likes'] ?? '0').toString(),
      dislikes: (json['dislikes'] ?? '0').toString(),
      channel: (json['channel'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      addedOn: (json['added_on'] ?? '').toString().trim(),
      videoUrl: vUrl,
      streamUrl: sUrl,
      actresses: actressesList,
      categories: categoriesList,
      tags: tagsList,
      relatedVideos: relatedList,
    );
  }
}

class JavActressDetailModel {
  final String slug;
  final String name;
  final String avatar;
  final String subscribers;
  final String videosCount;
  final String views;
  final String likes;
  final String page;
  final String paginationSummary;
  final List<JavVideoModel> videos;

  const JavActressDetailModel({
    required this.slug,
    required this.name,
    required this.avatar,
    required this.subscribers,
    required this.videosCount,
    required this.views,
    required this.likes,
    required this.page,
    required this.paginationSummary,
    required this.videos,
  });

  factory JavActressDetailModel.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['videos'] as List<dynamic>?;
    final videosList = rawVideos != null
        ? rawVideos
            .whereType<Map<String, dynamic>>()
            .map(JavVideoModel.fromJson)
            .toList()
        : <JavVideoModel>[];

    final rawAvatar = (json['avatar'] ?? json['image'] ?? '').toString();
    final avatarUrl = ApiEndpoints.javImageUrl(rawAvatar);

    return JavActressDetailModel(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      avatar: avatarUrl,
      subscribers: (json['subscribers'] ?? '').toString().trim(),
      videosCount: (json['videos_count'] ?? '').toString().trim(),
      views: (json['views'] ?? '').toString().trim(),
      likes: (json['likes'] ?? '').toString().trim(),
      page: (json['page'] ?? '1').toString(),
      paginationSummary: (json['pagination_summary'] ?? '').toString().trim(),
      videos: videosList,
    );
  }
}
