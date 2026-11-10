import '../../../../core/utils/app_date_utils.dart';
import '../../../auth/data/models/user_model.dart';

/// Model untuk ulasan pengguna dan penanda re-watch / re-read
class UserReviewModel {
  final int id;
  final int userId;
  final String? username;
  final String? userAvatar;
  final String? userDecorationUrl;
  final String? userDecorationCode;
  final String itemType; // 'anime' atau 'comic'
  final String targetId; // slug series / slug komik
  final String targetTitle;
  final String? targetCover;
  final String? subId; // misal 'al-154266-1' atau slug chapter
  final String? subTitle; // misal 'Episode 1' atau 'Chapter 1194'
  final String? content;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'gif'
  final double rating;
  final String status; // 'planned', 'replaying', 'completed'
  final int likesCount;
  final int commentsCount;
  final bool userLiked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserReviewModel({
    required this.id,
    required this.userId,
    this.username,
    this.userAvatar,
    this.userDecorationUrl,
    this.userDecorationCode,
    required this.itemType,
    required this.targetId,
    required this.targetTitle,
    this.targetCover,
    this.subId,
    this.subTitle,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.rating = 0.0,
    this.status = 'completed',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.userLiked = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserReviewModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null;
    final authorMap = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : null;

    final parsedUsername = (json['username'] ??
            userMap?['username'] ??
            authorMap?['username'] ??
            json['user_name'] ??
            json['display_name'] ??
            userMap?['name'] ??
            userMap?['display_name'] ??
            authorMap?['name'])
        ?.toString();

    final rawAvatar = json['user_avatar'] ??
        json['avatar'] ??
        json['avatar_url'] ??
        json['user_photo'] ??
        json['photo_url'] ??
        userMap?['avatar'] ??
        userMap?['avatar_url'] ??
        userMap?['user_avatar'] ??
        userMap?['photo_url'] ??
        authorMap?['avatar'] ??
        authorMap?['avatar_url'];

    final parsedAvatar = UserModel.normalizeAvatarUrl(rawAvatar);

    final dynamic rawDecorObj = json['avatar_decoration'] ?? userMap?['avatar_decoration'] ?? authorMap?['avatar_decoration'];
    final decorMap = rawDecorObj is Map ? Map<String, dynamic>.from(rawDecorObj) : null;

    final rawDecorUrl = (json['user_decoration_url'] ??
            json['avatar_decoration_url'] ??
            userMap?['avatar_decoration_url'] ??
            authorMap?['avatar_decoration_url'] ??
            decorMap?['image_url'] ??
            decorMap?['url'])
        ?.toString();

    final rawDecorCode = (json['user_decoration_code'] ??
            json['avatar_decoration_code'] ??
            userMap?['avatar_decoration_code'] ??
            authorMap?['avatar_decoration_code'] ??
            decorMap?['code'])
        ?.toString();

    final parsedUserId = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse('${json['user_id'] ?? userMap?['id'] ?? authorMap?['id']}') ?? 0;

    return UserReviewModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      userId: parsedUserId,
      username: parsedUsername,
      userAvatar: parsedAvatar,
      userDecorationUrl: rawDecorUrl,
      userDecorationCode: rawDecorCode,
      itemType: (json['item_type'] as String?)?.toLowerCase() ?? 'anime',
      targetId: json['target_id'] as String? ?? '',
      targetTitle: json['target_title'] as String? ?? '',
      targetCover: json['target_cover'] as String?,
      subId: json['sub_id'] as String?,
      subTitle: json['sub_title'] as String?,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      status: json['status'] as String? ?? 'completed',
      likesCount: json['likes_count'] is int ? json['likes_count'] as int : int.tryParse('${json['likes_count']}') ?? 0,
      commentsCount: json['comments_count'] is int ? json['comments_count'] as int : int.tryParse('${json['comments_count']}') ?? 0,
      userLiked: json['user_liked'] == true,
      createdAt: AppDateUtils.parseToLocal(json['created_at']),
      updatedAt: AppDateUtils.parseToLocal(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar,
      'user_decoration_url': userDecorationUrl,
      'user_decoration_code': userDecorationCode,
      'item_type': itemType,
      'target_id': targetId,
      'target_title': targetTitle,
      'target_cover': targetCover,
      'sub_id': subId,
      'sub_title': subTitle,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'rating': rating,
      'status': status,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'user_liked': userLiked,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserReviewModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? userAvatar,
    String? userDecorationUrl,
    String? userDecorationCode,
    String? itemType,
    String? targetId,
    String? targetTitle,
    String? targetCover,
    String? subId,
    String? subTitle,
    String? content,
    String? mediaUrl,
    String? mediaType,
    double? rating,
    String? status,
    int? likesCount,
    int? commentsCount,
    bool? userLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      userDecorationUrl: userDecorationUrl ?? this.userDecorationUrl,
      userDecorationCode: userDecorationCode ?? this.userDecorationCode,
      itemType: itemType ?? this.itemType,
      targetId: targetId ?? this.targetId,
      targetTitle: targetTitle ?? this.targetTitle,
      targetCover: targetCover ?? this.targetCover,
      subId: subId ?? this.subId,
      subTitle: subTitle ?? this.subTitle,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      userLiked: userLiked ?? this.userLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'planned':
        return itemType == 'anime' ? 'Mau Nonton Ulang' : 'Mau Baca Ulang';
      case 'replaying':
        return itemType == 'anime' ? 'Sedang Diulang' : 'Sedang Dibaca Ulang';
      default:
        return 'Selesai Diulas';
    }
  }
}

/// Model untuk komentar pada ulasan
class UserReviewCommentModel {
  final int id;
  final int reviewId;
  final int userId;
  final String? username;
  final String? userAvatar;
  final String? userDecorationUrl;
  final String? userDecorationCode;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserReviewCommentModel({
    required this.id,
    required this.reviewId,
    required this.userId,
    this.username,
    this.userAvatar,
    this.userDecorationUrl,
    this.userDecorationCode,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  factory UserReviewCommentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null;
    final authorMap = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : null;

    final parsedUsername = (json['username'] ??
            userMap?['username'] ??
            authorMap?['username'] ??
            json['user_name'] ??
            json['display_name'] ??
            userMap?['name'] ??
            userMap?['display_name'] ??
            authorMap?['name'])
        ?.toString();

    final rawAvatar = json['user_avatar'] ??
        json['avatar'] ??
        json['avatar_url'] ??
        json['user_photo'] ??
        json['photo_url'] ??
        userMap?['avatar'] ??
        userMap?['avatar_url'] ??
        userMap?['user_avatar'] ??
        userMap?['photo_url'] ??
        authorMap?['avatar'] ??
        authorMap?['avatar_url'];

    final parsedAvatar = UserModel.normalizeAvatarUrl(rawAvatar);

    final dynamic rawDecorObj = json['avatar_decoration'] ?? userMap?['avatar_decoration'] ?? authorMap?['avatar_decoration'];
    final decorMap = rawDecorObj is Map ? Map<String, dynamic>.from(rawDecorObj) : null;

    final rawDecorUrl = (json['user_decoration_url'] ??
            json['avatar_decoration_url'] ??
            userMap?['avatar_decoration_url'] ??
            authorMap?['avatar_decoration_url'] ??
            decorMap?['image_url'] ??
            decorMap?['url'])
        ?.toString();

    final rawDecorCode = (json['user_decoration_code'] ??
            json['avatar_decoration_code'] ??
            userMap?['avatar_decoration_code'] ??
            authorMap?['avatar_decoration_code'] ??
            decorMap?['code'])
        ?.toString();

    final parsedUserId = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse('${json['user_id'] ?? userMap?['id'] ?? authorMap?['id']}') ?? 0;

    return UserReviewCommentModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      reviewId: json['review_id'] is int ? json['review_id'] as int : int.tryParse('${json['review_id']}') ?? 0,
      userId: parsedUserId,
      username: parsedUsername,
      userAvatar: parsedAvatar,
      userDecorationUrl: rawDecorUrl,
      userDecorationCode: rawDecorCode,
      content: json['content'] as String? ?? '',
      createdAt: AppDateUtils.parseToLocal(json['created_at']),
      updatedAt: AppDateUtils.parseToLocal(json['updated_at']),
    );
  }
}
