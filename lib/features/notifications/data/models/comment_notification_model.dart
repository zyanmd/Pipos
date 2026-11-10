import '../../../auth/data/models/user_model.dart';

class CommentNotificationModel {
  final dynamic id;
  final String type; // 'comment_like' | 'comment_reply'
  final String referenceType;
  final int? referenceId;
  final int? actorId;
  final String? actorUsername;
  final String? actorAvatar;
  final String? actorRank;
  final String message;
  final String? redirectUrl;
  final String? episodeKey;
  final String? animeId;
  final int? episodeNumber;
  final String? commentPreview;
  final String? replyPreview;
  final bool isRead;
  final String? createdAt;

  const CommentNotificationModel({
    required this.id,
    required this.type,
    this.referenceType = 'ylnime_comment',
    this.referenceId,
    this.actorId,
    this.actorUsername,
    this.actorAvatar,
    this.actorRank,
    required this.message,
    this.redirectUrl,
    this.episodeKey,
    this.animeId,
    this.episodeNumber,
    this.commentPreview,
    this.replyPreview,
    this.isRead = false,
    this.createdAt,
  });

  factory CommentNotificationModel.fromJson(Map<String, dynamic> json) {
    // Actor info (from actor map, user map, sender map or extra_data)
    final actorMap = json['actor'] is Map
        ? Map<String, dynamic>.from(json['actor'] as Map)
        : (json['user'] is Map
            ? Map<String, dynamic>.from(json['user'] as Map)
            : (json['sender'] is Map
                ? Map<String, dynamic>.from(json['sender'] as Map)
                : (json['from_user'] is Map ? Map<String, dynamic>.from(json['from_user'] as Map) : null)));
    final extraData = json['extra_data'] is Map ? Map<String, dynamic>.from(json['extra_data'] as Map) : null;
    final commentMap = json['comment'] is Map ? Map<String, dynamic>.from(json['comment'] as Map) : null;
    final replyMap = json['reply'] is Map ? Map<String, dynamic>.from(json['reply'] as Map) : null;

    final actorId = actorMap?['id'] as int? ?? json['actor_id'] as int? ?? json['user_id'] as int?;
    final actorUsername = actorMap?['username'] as String? ??
        actorMap?['name'] as String? ??
        extraData?['actor_username'] as String? ??
        extraData?['username'] as String? ??
        json['actor_username'] as String? ??
        json['username'] as String?;

    final rawActorAvatar = actorMap?['avatar'] as String? ??
        actorMap?['avatar_url'] as String? ??
        actorMap?['photo'] as String? ??
        actorMap?['profile_picture'] as String? ??
        extraData?['actor_avatar'] as String? ??
        extraData?['avatar'] as String? ??
        extraData?['avatar_url'] as String? ??
        json['actor_avatar'] as String? ??
        json['avatar'] as String? ??
        json['avatar_url'] as String? ??
        (replyMap?['user'] is Map ? replyMap!['user']['avatar']?.toString() : null) ??
        (commentMap?['user'] is Map ? commentMap!['user']['avatar']?.toString() : null);

    final actorAvatar = UserModel.normalizeAvatarUrl(rawActorAvatar) ?? rawActorAvatar;
    final actorRank = actorMap?['rank'] as String? ?? extraData?['actor_rank'] as String?;

    // Comment context
    final commentPreview = extraData?['comment_preview'] as String? ??
        commentMap?['content_preview'] as String? ??
        commentMap?['content'] as String?;

    final replyPreview = replyMap?['content_preview'] as String? ??
        replyMap?['content'] as String?;

    final episodeKey = json['episode_key'] as String? ??
        extraData?['episode_key'] as String? ??
        commentMap?['episode_key'] as String?;

    final animeId = json['anime_id']?.toString() ??
        extraData?['anime_id']?.toString() ??
        commentMap?['anime_id']?.toString();

    final epNumRaw = extraData?['episode_number'] ?? commentMap?['episode_number'];
    final episodeNumber = epNumRaw != null ? int.tryParse(epNumRaw.toString()) : null;

    final redirectUrl = json['redirect_url'] as String? ?? extraData?['redirect_url'] as String?;

    final isReadVal = json['is_read'] == true ||
        json['is_read'] == 1 ||
        json['is_read']?.toString() == '1' ||
        json['is_read']?.toString() == 'true';

    return CommentNotificationModel(
      id: json['id'],
      type: (json['type'] ?? 'comment_reply').toString(),
      referenceType: (json['reference_type'] ?? 'ylnime_comment').toString(),
      referenceId: json['reference_id'] != null ? int.tryParse(json['reference_id'].toString()) : null,
      actorId: actorId,
      actorUsername: actorUsername,
      actorAvatar: actorAvatar,
      actorRank: actorRank,
      message: (json['message'] ?? 'Interaksi komentar baru').toString(),
      redirectUrl: redirectUrl,
      episodeKey: episodeKey,
      animeId: animeId,
      episodeNumber: episodeNumber,
      commentPreview: commentPreview,
      replyPreview: replyPreview,
      isRead: isReadVal,
      createdAt: json['created_at']?.toString(),
    );
  }

  CommentNotificationModel copyWith({bool? isRead}) {
    return CommentNotificationModel(
      id: id,
      type: type,
      referenceType: referenceType,
      referenceId: referenceId,
      actorId: actorId,
      actorUsername: actorUsername,
      actorAvatar: actorAvatar,
      actorRank: actorRank,
      message: message,
      redirectUrl: redirectUrl,
      episodeKey: episodeKey,
      animeId: animeId,
      episodeNumber: episodeNumber,
      commentPreview: commentPreview,
      replyPreview: replyPreview,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

