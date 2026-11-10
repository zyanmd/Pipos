class UserAnimeFavorite {
  final int id;
  final String animeId;
  final String title;
  final String? thumbnail;
  final String type; // 'ylnime' | 'anime'
  final bool isProfileLiked;
  final DateTime? createdAt;

  UserAnimeFavorite({
    required this.id,
    required this.animeId,
    required this.title,
    this.thumbnail,
    required this.type,
    this.isProfileLiked = false,
    this.createdAt,
  });

  factory UserAnimeFavorite.fromJson(Map<String, dynamic> json) {
    return UserAnimeFavorite(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      animeId: json['anime_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString(),
      type: json['type']?.toString() ?? 'ylnime',
      isProfileLiked: json['is_profile_liked'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class UserComicFavorite {
  final int id;
  final String slug;
  final String title;
  final String? thumbnail;
  final String? chapterSlug;
  final int? chapterNumber;
  final bool isProfileLiked;
  final DateTime? createdAt;

  UserComicFavorite({
    required this.id,
    required this.slug,
    required this.title,
    this.thumbnail,
    this.chapterSlug,
    this.chapterNumber,
    this.isProfileLiked = false,
    this.createdAt,
  });

  factory UserComicFavorite.fromJson(Map<String, dynamic> json) {
    return UserComicFavorite(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString(),
      chapterSlug: json['chapter_slug']?.toString(),
      chapterNumber: json['chapter_number'] is int ? json['chapter_number'] : int.tryParse('${json['chapter_number']}'),
      isProfileLiked: json['is_profile_liked'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class UserCommentItem {
  final int id;
  final String animeId;
  final String episodeKey;
  final int episodeNumber;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaThumbnail;
  final int likesCount;
  final int repliesCount;
  final bool isSpoiler;
  final DateTime? createdAt;

  UserCommentItem({
    required this.id,
    required this.animeId,
    required this.episodeKey,
    required this.episodeNumber,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.mediaThumbnail,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isSpoiler = false,
    this.createdAt,
  });

  factory UserCommentItem.fromJson(Map<String, dynamic> json) {
    return UserCommentItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      animeId: json['anime_id']?.toString() ?? '',
      episodeKey: json['episode_key']?.toString() ?? '',
      episodeNumber: json['episode_number'] is int ? json['episode_number'] : int.tryParse('${json['episode_number']}') ?? 1,
      content: json['content']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type']?.toString(),
      mediaThumbnail: json['media_thumbnail']?.toString(),
      likesCount: json['likes_count'] is int ? json['likes_count'] : int.tryParse('${json['likes_count']}') ?? 0,
      repliesCount: json['replies_count'] is int ? json['replies_count'] : int.tryParse('${json['replies_count']}') ?? 0,
      isSpoiler: json['is_spoiler'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class UserChatItem {
  final int id;
  final String message;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaThumbnail;
  final int? replyToId;
  final DateTime? createdAt;

  UserChatItem({
    required this.id,
    required this.message,
    this.mediaUrl,
    this.mediaType,
    this.mediaThumbnail,
    this.replyToId,
    this.createdAt,
  });

  factory UserChatItem.fromJson(Map<String, dynamic> json) {
    return UserChatItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      message: json['message']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type']?.toString(),
      mediaThumbnail: json['media_thumbnail']?.toString(),
      replyToId: json['reply_to_id'] is int ? json['reply_to_id'] : int.tryParse('${json['reply_to_id']}'),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

