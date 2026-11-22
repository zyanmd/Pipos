import '../../../reels/data/models/reel_model.dart';

/// Model komentar dalam sebuah thread forum
class ForumCommentModel {
  final String id;
  final String threadId;
  final String authorName;
  final String? authorAvatar;
  final int authorLevel;
  final String content;
  final String? imageUrl;
  int likes;
  bool userLiked;
  final DateTime createdAt;

  ForumCommentModel({
    required this.id,
    required this.threadId,
    required this.authorName,
    this.authorAvatar,
    this.authorLevel = 1,
    required this.content,
    this.imageUrl,
    this.likes = 0,
    this.userLiked = false,
    required this.createdAt,
  });

  factory ForumCommentModel.fromJson(Map<String, dynamic> json) {
    return ForumCommentModel(
      id: json['id']?.toString() ?? '',
      threadId: json['thread_id']?.toString() ?? '',
      authorName: json['author_name'] ?? 'Pengguna',
      authorAvatar: json['author_avatar'],
      authorLevel: (json['author_level'] as num?)?.toInt() ?? 1,
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      userLiked: json['user_liked'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thread_id': threadId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'author_level': authorLevel,
      'content': content,
      'image_url': imageUrl,
      'likes': likes,
      'user_liked': userLiked,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Model Thread Forum Diskusi Komunitas (Reddit / MyAnimeList Style)
class ForumThreadModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final int authorLevel;
  final String category; // Teori Manga, Fan Art, Rekomendasi, Review, Spoiler, Diskusi
  final String? relatedTitle; // Misal: One Piece, Jujutsu Kaisen
  final String? relatedType; // 'anime' atau 'comic'
  final String? relatedSlug; // Slug / ID anime atau komik untuk navigasi
  final String? relatedPoster; // URL poster anime atau komik
  final String? imageUrl;
  final String? videoUrl;
  final int? videoDuration; // Durasi dalam detik
  int upvotes;
  int userVote; // 1 = upvoted, -1 = downvoted, 0 = neutral
  int commentCount;
  final DateTime createdAt;
  final List<ForumCommentModel> comments;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;
  bool get hasTag => relatedTitle != null && relatedTitle!.trim().isNotEmpty;
  bool get isComicTag => relatedType == 'comic';
  bool get isAnimeTag => relatedType == 'anime' || (relatedType == null && hasTag);

  ForumThreadModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorLevel = 1,
    required this.category,
    this.relatedTitle,
    this.relatedType,
    this.relatedSlug,
    this.relatedPoster,
    this.imageUrl,
    this.videoUrl,
    this.videoDuration,
    this.upvotes = 0,
    this.userVote = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.comments = const [],
  });

  factory ForumThreadModel.fromJson(Map<String, dynamic> json) {
    var rawComments = json['comments'];
    List<ForumCommentModel> parsedComments = [];
    if (rawComments is List) {
      parsedComments = rawComments
          .map((c) => ForumCommentModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return ForumThreadModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name'] ?? 'Pengguna',
      authorAvatar: json['author_avatar'],
      authorLevel: (json['author_level'] as num?)?.toInt() ?? 1,
      category: json['category'] ?? 'Diskusi',
      relatedTitle: json['related_title'],
      relatedType: json['related_type']?.toString(),
      relatedSlug: json['related_slug']?.toString(),
      relatedPoster: json['related_poster']?.toString(),
      imageUrl: json['image_url'],
      videoUrl: json['video_url']?.toString(),
      videoDuration: (json['video_duration'] as num?)?.toInt(),
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      userVote: (json['user_vote'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? parsedComments.length,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      comments: parsedComments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'author_level': authorLevel,
      'category': category,
      'related_title': relatedTitle,
      'related_type': relatedType,
      'related_slug': relatedSlug,
      'related_poster': relatedPoster,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'video_duration': videoDuration,
      'upvotes': upvotes,
      'user_vote': userVote,
      'comment_count': commentCount,
      'created_at': createdAt.toIso8601String(),
      'comments': comments.map((c) => c.toJson()).toList(),
    };
  }

  ForumThreadModel copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    int? authorLevel,
    String? category,
    String? relatedTitle,
    String? relatedType,
    String? relatedSlug,
    String? relatedPoster,
    String? imageUrl,
    String? videoUrl,
    int? videoDuration,
    int? upvotes,
    int? userVote,
    int? commentCount,
    DateTime? createdAt,
    List<ForumCommentModel>? comments,
  }) {
    return ForumThreadModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorLevel: authorLevel ?? this.authorLevel,
      category: category ?? this.category,
      relatedTitle: relatedTitle ?? this.relatedTitle,
      relatedType: relatedType ?? this.relatedType,
      relatedSlug: relatedSlug ?? this.relatedSlug,
      relatedPoster: relatedPoster ?? this.relatedPoster,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      upvotes: upvotes ?? this.upvotes,
      userVote: userVote ?? this.userVote,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
    );
  }

  /// Konversi thread forum video menjadi ReelModel kompatibel penuh
  ReelModel toReel() {
    final dur = videoDuration != null && videoDuration! > 0 ? videoDuration! : 30;
    return ReelModel(
      id: id,
      title: title.isNotEmpty ? title : content,
      seriesKey: relatedTitle ?? '',
      videoUrl: videoUrl ?? '',
      coverUrl: relatedPoster ?? imageUrl ?? '',
      duration: dur,
      streamUrl: videoUrl ?? '',
      streamType: 'direct',
      quality: 'HD',
      server: 'Forum Community',
      note: content,
      likes: upvotes,
      isLiked: userVote == 1,
      clip: ReelClipModel(
        startTime: 0,
        endTime: dur,
        duration: dur,
        startTimeFormatted: '00:00',
        endTimeFormatted: '00:${dur.toString().padLeft(2, '0')}',
      ),
      episode: ReelEpisodeModel(
        episodeTitle: relatedTitle ?? 'Forum Reel',
        episodeNumber: '1',
      ),
      anime: ReelAnimeModel(
        title: relatedTitle ?? authorName,
        thumbnail: relatedPoster ?? imageUrl ?? authorAvatar ?? '',
      ),
      redirect: ReelRedirectModel(
        watchUrl: (isAnimeTag && relatedSlug != null) ? relatedSlug! : '',
        detailUrl: id,
      ),
      ui: ReelUiModel(
        clipEnd: dur,
      ),
    );
  }
}
