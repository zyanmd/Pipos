// Models for Global Community Chat
import '../../../auth/data/models/user_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../shared/widgets/smooth_avatar_decoration.dart';

class ChatMentionUser {
  final int id;
  final String username;
  final String? avatar;
  final bool isRead;

  const ChatMentionUser({
    required this.id,
    required this.username,
    this.avatar,
    this.isRead = false,
  });

  factory ChatMentionUser.fromJson(Map<String, dynamic> j) {
    return ChatMentionUser(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      username: j['username']?.toString() ?? 'Unknown',
      avatar: j['avatar']?.toString(),
      isRead: j['is_read'] == true || j['is_read'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatar': avatar,
    'is_read': isRead,
  };
}

class ChatTaggedContent {
  final String type; // 'anime' | 'comic'
  final String id;
  final String title;
  final String? thumb;
  final String? extra;

  const ChatTaggedContent({
    required this.type,
    required this.id,
    required this.title,
    this.thumb,
    this.extra,
  });

  String toTagString() {
    final cleanTitle = title.replaceAll('|', '-').replaceAll('\n', ' ').trim();
    final cleanThumb = (thumb ?? '').replaceAll('|', '').trim();
    final cleanExtra = (extra ?? '').replaceAll('|', '-').trim();
    return '[tag:$type|$id|$cleanTitle|$cleanThumb|$cleanExtra]';
  }

  static ChatTaggedContent? parse(String raw) {
    if (!raw.contains('[tag:')) return null;
    final match = RegExp(r'\[tag:(anime|comic)\|([^|]+)\|([^|]+)(?:\|([^|]*))?(?:\|([^\]]*))?\]').firstMatch(raw);
    if (match != null) {
      return ChatTaggedContent(
        type: match.group(1)!,
        id: match.group(2)!,
        title: match.group(3)!,
        thumb: match.group(4)?.isNotEmpty == true ? match.group(4) : null,
        extra: match.group(5)?.isNotEmpty == true ? match.group(5) : null,
      );
    }
    return null;
  }

  static String stripTags(String text) {
    return text.replaceAll(RegExp(r'\[tag:(?:anime|comic)\|[^\]]+\]'), '').trim();
  }
}

class ChatReplyModel {
  final int id;
  final String message;
  final String username;
  final int? userId;
  final String? avatar;
  final String? avatarDecorationUrl;
  final String? avatarDecorationCode;
  final String? mediaUrl;
  final String mediaType;
  final bool hasMedia;
  final bool verifiedBadge;

  const ChatReplyModel({
    required this.id,
    required this.message,
    required this.username,
    this.userId,
    this.avatar,
    this.avatarDecorationUrl,
    this.avatarDecorationCode,
    this.mediaUrl,
    this.mediaType = 'none',
    this.hasMedia = false,
    this.verifiedBadge = false,
  });

  ChatTaggedContent? get taggedContent => ChatTaggedContent.parse(message);
  String get displayMessage => ChatTaggedContent.stripTags(message);

  String? get fullMediaUrl {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;
    if (mediaUrl!.startsWith('http://') || mediaUrl!.startsWith('https://')) return mediaUrl;
    if (mediaUrl!.startsWith('/data/') || mediaUrl!.startsWith('/storage/emulated/') || mediaUrl!.contains(':\\')) {
      return mediaUrl;
    }
    final clean = mediaUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  String? get fullAvatarDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(avatarDecorationUrl, avatarDecorationCode);
  }

  String get authorAvatarUrl {
    final norm = UserModel.normalizeAvatarUrl(avatar);
    if (norm != null && norm.isNotEmpty) return norm;
    final name = (username.isNotEmpty && username != 'Unknown') ? username : 'User';
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=128&background=FF2D55&color=fff&bold=true';
  }

  factory ChatReplyModel.fromJson(Map<String, dynamic> j) {
    final mUrl = j['media_url']?.toString();
    var mType = j['media_type']?.toString() ?? 'none';
    if (mUrl != null && mUrl.isNotEmpty) {
      if (mUrl.toLowerCase().endsWith('.gif') || mUrl.toLowerCase().contains('.gif')) {
        mType = 'gif';
      } else if (mType == 'none') {
        mType = 'image';
      }
    }

    final rawAvatar = j['avatar']?.toString() ??
        j['avatar_url']?.toString() ??
        (j['user'] is Map ? (j['user']['avatar']?.toString() ?? j['user']['avatar_url']?.toString()) : null) ??
        (j['sender'] is Map ? (j['sender']['avatar']?.toString() ?? j['sender']['avatar_url']?.toString()) : null);

    Map<String, dynamic>? rDecorMap;
    if (j['avatar_decoration'] is Map) {
      rDecorMap = Map<String, dynamic>.from(j['avatar_decoration'] as Map);
    } else if (j['user'] is Map && j['user']['avatar_decoration'] is Map) {
      rDecorMap = Map<String, dynamic>.from(j['user']['avatar_decoration'] as Map);
    } else if (j['sender'] is Map && j['sender']['avatar_decoration'] is Map) {
      rDecorMap = Map<String, dynamic>.from(j['sender']['avatar_decoration'] as Map);
    }

    final rDecorUrl = j['avatar_decoration_url']?.toString() ??
        (j['user'] is Map ? j['user']['avatar_decoration_url']?.toString() : null) ??
        (j['sender'] is Map ? j['sender']['avatar_decoration_url']?.toString() : null) ??
        rDecorMap?['image_url']?.toString() ??
        rDecorMap?['url']?.toString();

    String? rDecorCode = j['avatar_decoration_code']?.toString() ??
        (j['user'] is Map ? j['user']['avatar_decoration_code']?.toString() : null) ??
        (j['sender'] is Map ? j['sender']['avatar_decoration_code']?.toString() : null) ??
        rDecorMap?['code']?.toString();

    if ((rDecorCode == null || rDecorCode.isEmpty) && j['avatar_decoration'] is String) {
      final str = j['avatar_decoration'].toString().trim();
      if (str.isNotEmpty && !str.contains('/') && !str.startsWith('http')) {
        rDecorCode = str;
      }
    }

    if ((rDecorCode == null || rDecorCode.isEmpty) && rDecorUrl != null && rDecorUrl.isNotEmpty) {
      final uri = Uri.tryParse(rDecorUrl);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : rDecorUrl.split('/').last;
      final extracted = seg.replaceAll('.png', '').replaceAll('.webp', '').replaceAll('.gif', '').trim();
      if (extracted.isNotEmpty) rDecorCode = extracted;
    }

    final isReplyVerified = (j['verified_badge'] is int)
        ? (j['verified_badge'] as int) == 1
        : (j['verified_badge'] == true ||
            j['verified_badge']?.toString() == '1' ||
            j['verified_badge']?.toString().toLowerCase() == 'true' ||
            j['user_verified_badge'] == true ||
            j['user_verified_badge'] == 1 ||
            j['user_verified_badge']?.toString() == '1' ||
            j['author_verified_badge'] == true ||
            j['author_verified_badge'] == 1 ||
            j['author_verified_badge']?.toString() == '1' ||
            (j['user'] is Map &&
                ((j['user']['verified_badge'] is int && j['user']['verified_badge'] == 1) ||
                    j['user']['verified_badge'] == true ||
                    j['user']['verified_badge']?.toString() == '1' ||
                    j['user']['is_verified_badge'] == true ||
                    j['user']['is_verified_badge'] == 1 ||
                    j['user']['is_verified_badge']?.toString() == '1')));

    return ChatReplyModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      message: j['message']?.toString() ?? '',
      username: j['username']?.toString() ?? (j['user'] is Map ? j['user']['username']?.toString() : null) ?? 'Unknown',
      userId: j['user_id'] is int ? j['user_id'] as int : int.tryParse(j['user_id']?.toString() ?? '0'),
      avatar: rawAvatar,
      avatarDecorationUrl: rDecorUrl,
      avatarDecorationCode: rDecorCode,
      mediaUrl: mUrl,
      mediaType: mType,
      hasMedia: j['has_media'] == true || (mUrl != null && mUrl.isNotEmpty && mType != 'none'),
      verifiedBadge: isReplyVerified,
    );
  }
}

class ChatMessageModel {
  final int id;
  final int userId;
  final String username;
  final String? avatar;
  final String? avatarDecorationUrl;
  final String? avatarDecorationCode;
  final String message;
  final String? mediaUrl;
  final String mediaType; // 'image', 'gif', 'none'
  final String? mediaThumbnail;
  final bool hasMedia;
  final String? backgroundUrl;
  final String backgroundType; // 'image', 'gif', 'none'
  final bool hasBackground;
  final String? textColor;
  final List<ChatMentionUser> mentions;
  final List<String> notFoundMentions;
  final List<String> allMentions;
  final int mentionCount;
  final int? replyToId;
  final ChatReplyModel? replyTo;
  final bool isEdited;
  final bool isDeleted;
  final List<int> readBy;
  final int readCount;
  final bool isRead;
  final bool verifiedBadge;
  final String? createdAt;
  final String? updatedAt;

  const ChatMessageModel({
    required this.id,
    required this.userId,
    required this.username,
    this.avatar,
    this.avatarDecorationUrl,
    this.avatarDecorationCode,
    required this.message,
    this.mediaUrl,
    this.mediaType = 'none',
    this.mediaThumbnail,
    this.hasMedia = false,
    this.backgroundUrl,
    this.backgroundType = 'none',
    this.hasBackground = false,
    this.textColor,
    this.mentions = const [],
    this.notFoundMentions = const [],
    this.allMentions = const [],
    this.mentionCount = 0,
    this.replyToId,
    this.replyTo,
    this.isEdited = false,
    this.isDeleted = false,
    this.readBy = const [],
    this.readCount = 0,
    this.isRead = false,
    this.verifiedBadge = false,
    this.createdAt,
    this.updatedAt,
  });

  ChatTaggedContent? get taggedContent => ChatTaggedContent.parse(message);
  String get displayMessage => ChatTaggedContent.stripTags(message);

  String? get fullAvatarDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(avatarDecorationUrl, avatarDecorationCode);
  }

  /// Absolute media attachment URL
  String? get fullMediaUrl {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;
    if (mediaUrl!.startsWith('http://') || mediaUrl!.startsWith('https://')) return mediaUrl;
    if (mediaUrl!.startsWith('/data/') || mediaUrl!.startsWith('/storage/emulated/') || mediaUrl!.contains(':\\')) {
      return mediaUrl;
    }
    final clean = mediaUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  /// Absolute bubble background URL
  String? get fullBackgroundUrl {
    if (backgroundUrl == null || backgroundUrl!.isEmpty) return null;
    if (backgroundUrl!.startsWith('http://') || backgroundUrl!.startsWith('https://')) return backgroundUrl;
    if (backgroundUrl!.startsWith('/data/') || backgroundUrl!.startsWith('/storage/emulated/') || backgroundUrl!.contains(':\\')) {
      return backgroundUrl;
    }
    final clean = backgroundUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  bool get isMediaGif => mediaType == 'gif';
  bool get isBackgroundGif => backgroundType == 'gif';

  /// Author avatar URL with fallback to UI-Avatars
  String get authorAvatarUrl {
    final norm = UserModel.normalizeAvatarUrl(avatar);
    if (norm != null && norm.isNotEmpty) return norm;
    final name = (username.isNotEmpty && username != 'Unknown') ? username : 'User';
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=128&background=FF2D55&color=fff&bold=true';
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> j) {
    final mUrl = j['media_url']?.toString();
    var mType = j['media_type']?.toString() ?? 'none';
    if (mUrl != null && mUrl.isNotEmpty) {
      if (mUrl.toLowerCase().endsWith('.gif') || mUrl.toLowerCase().contains('.gif')) {
        mType = 'gif';
      } else if (mType == 'none') {
        mType = 'image';
      }
    }

    final userMap = j['user'] is Map ? (j['user'] as Map) : null;
    final bgUrl = (j['background_url'] != null && j['background_url'].toString().isNotEmpty && j['background_url'].toString() != 'none')
        ? j['background_url'].toString()
        : (userMap != null && userMap['chat_background'] != null && userMap['chat_background'].toString().isNotEmpty && userMap['chat_background'].toString() != 'none')
            ? userMap['chat_background'].toString()
            : (userMap != null && userMap['chat_background_url'] != null && userMap['chat_background_url'].toString().isNotEmpty && userMap['chat_background_url'].toString() != 'none')
                ? userMap['chat_background_url'].toString()
                : null;
    var bgType = (j['background_type'] != null && j['background_type'].toString().isNotEmpty && j['background_type'].toString() != 'none')
        ? j['background_type'].toString()
        : (userMap != null && userMap['chat_background_type'] != null && userMap['chat_background_type'].toString().isNotEmpty)
            ? userMap['chat_background_type'].toString()
            : 'none';
    if (bgUrl != null && bgUrl.isNotEmpty && (bgType == 'none' || bgType == 'image')) {
      if (bgUrl.toLowerCase().endsWith('.gif') || bgUrl.toLowerCase().contains('.gif')) {
        bgType = 'gif';
      }
    }

    final mentionsList = <ChatMentionUser>[];
    final notFoundList = <String>[];
    final allList = <String>[];

    if (j['mention_info'] is Map) {
      final mInfo = j['mention_info'] as Map;
      if (mInfo['found'] is List) {
        for (final m in mInfo['found']) {
          if (m is Map) {
            mentionsList.add(ChatMentionUser.fromJson(Map<String, dynamic>.from(m)));
          }
        }
      }
      if (mInfo['not_found'] is List) {
        for (final n in mInfo['not_found']) {
          if (n != null && n.toString().isNotEmpty) notFoundList.add(n.toString());
        }
      }
      if (mInfo['all'] is List) {
        for (final a in mInfo['all']) {
          if (a != null && a.toString().isNotEmpty) allList.add(a.toString());
        }
      }
    }

    if (j['mentions'] is List) {
      for (final m in j['mentions']) {
        if (m is Map) {
          final u = ChatMentionUser.fromJson(Map<String, dynamic>.from(m));
          if (!mentionsList.any((x) => x.id == u.id && x.username.toLowerCase() == u.username.toLowerCase())) {
            mentionsList.add(u);
          }
        } else if (m is String && m.isNotEmpty) {
          if (!allList.contains(m)) allList.add(m);
        }
      }
    }

    if (j['mentions_notified'] is List) {
      for (final m in j['mentions_notified']) {
        if (m is Map) {
          final u = ChatMentionUser.fromJson(Map<String, dynamic>.from(m));
          if (!mentionsList.any((x) => x.id == u.id && x.username.toLowerCase() == u.username.toLowerCase())) {
            mentionsList.add(u);
          }
        }
      }
    }

    if (j['not_found_mentions'] is List) {
      for (final n in j['not_found_mentions']) {
        if (n != null && !notFoundList.contains(n.toString())) {
          notFoundList.add(n.toString());
        }
      }
    }

    ChatReplyModel? rep;
    if (j['reply_to'] is Map) {
      rep = ChatReplyModel.fromJson(Map<String, dynamic>.from(j['reply_to'] as Map));
    }

    final readByList = <int>[];
    if (j['read_by'] is List) {
      for (final r in j['read_by']) {
        if (r is int) {
          readByList.add(r);
        } else if (r != null) {
          final p = int.tryParse(r.toString());
          if (p != null) readByList.add(p);
        }
      }
    }

    final repId = j['reply_to_id'] is int
        ? j['reply_to_id'] as int
        : int.tryParse(j['reply_to_id']?.toString() ?? '');

    final rawAvatar = j['avatar']?.toString() ??
        j['avatar_url']?.toString() ??
        (j['user'] is Map ? (j['user']['avatar']?.toString() ?? j['user']['avatar_url']?.toString()) : null) ??
        (j['sender'] is Map ? (j['sender']['avatar']?.toString() ?? j['sender']['avatar_url']?.toString()) : null);

    Map<String, dynamic>? msgDecorMap;
    if (j['avatar_decoration'] is Map) {
      msgDecorMap = Map<String, dynamic>.from(j['avatar_decoration'] as Map);
    } else if (j['user'] is Map && j['user']['avatar_decoration'] is Map) {
      msgDecorMap = Map<String, dynamic>.from(j['user']['avatar_decoration'] as Map);
    } else if (j['sender'] is Map && j['sender']['avatar_decoration'] is Map) {
      msgDecorMap = Map<String, dynamic>.from(j['sender']['avatar_decoration'] as Map);
    }

    final msgDecorUrl = j['avatar_decoration_url']?.toString() ??
        (j['user'] is Map ? j['user']['avatar_decoration_url']?.toString() : null) ??
        (j['sender'] is Map ? j['sender']['avatar_decoration_url']?.toString() : null) ??
        msgDecorMap?['image_url']?.toString() ??
        msgDecorMap?['url']?.toString();

    String? msgDecorCode = j['avatar_decoration_code']?.toString() ??
        (j['user'] is Map ? j['user']['avatar_decoration_code']?.toString() : null) ??
        (j['sender'] is Map ? j['sender']['avatar_decoration_code']?.toString() : null) ??
        msgDecorMap?['code']?.toString();

    if ((msgDecorCode == null || msgDecorCode.isEmpty) && j['avatar_decoration'] is String) {
      final str = j['avatar_decoration'].toString().trim();
      if (str.isNotEmpty && !str.contains('/') && !str.startsWith('http')) {
        msgDecorCode = str;
      }
    }

    if ((msgDecorCode == null || msgDecorCode.isEmpty) && msgDecorUrl != null && msgDecorUrl.isNotEmpty) {
      final uri = Uri.tryParse(msgDecorUrl);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : msgDecorUrl.split('/').last;
      final extracted = seg.replaceAll('.png', '').replaceAll('.webp', '').replaceAll('.gif', '').trim();
      if (extracted.isNotEmpty) msgDecorCode = extracted;
    }

    return ChatMessageModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      userId: j['user_id'] is int ? j['user_id'] as int : int.tryParse(j['user_id']?.toString() ?? '0') ?? 0,
      username: j['username']?.toString() ?? (j['user'] is Map ? j['user']['username']?.toString() : null) ?? 'Pengguna',
      avatar: rawAvatar,
      avatarDecorationUrl: msgDecorUrl,
      avatarDecorationCode: msgDecorCode,
      message: j['message']?.toString() ?? '',
      mediaUrl: mUrl,
      mediaType: mType,
      mediaThumbnail: j['media_thumbnail']?.toString(),
      hasMedia: j['has_media'] == true || (mUrl != null && mUrl.isNotEmpty && mType != 'none'),
      backgroundUrl: bgUrl,
      backgroundType: bgType,
      hasBackground: j['has_background'] == true || (bgUrl != null && bgUrl.isNotEmpty && bgType != 'none'),
      textColor: j['text_color']?.toString() ??
          (userMap != null ? userMap['chat_text_color']?.toString() : null),
      mentions: mentionsList,
      notFoundMentions: notFoundList,
      allMentions: allList,
      mentionCount: j['mention_count'] is int
          ? j['mention_count'] as int
          : (int.tryParse(j['mention_count']?.toString() ?? '') ?? mentionsList.length),
      replyToId: repId,
      replyTo: rep,
      isEdited: j['is_edited'] == true || j['is_edited'] == 1,
      isDeleted: j['is_deleted'] == true || j['is_deleted'] == 1,
      readBy: readByList,
      readCount: j['read_count'] is int
          ? j['read_count'] as int
          : (int.tryParse(j['read_count']?.toString() ?? '') ?? readByList.length),
      isRead: j['is_read'] == true || j['is_read'] == 1,
      verifiedBadge: (j['verified_badge'] is int)
          ? (j['verified_badge'] as int) == 1
          : (j['verified_badge'] == true ||
              j['verified_badge']?.toString() == '1' ||
              j['verified_badge']?.toString().toLowerCase() == 'true' ||
              j['user_verified_badge'] == true ||
              j['user_verified_badge'] == 1 ||
              j['user_verified_badge']?.toString() == '1' ||
              j['author_verified_badge'] == true ||
              j['author_verified_badge'] == 1 ||
              j['author_verified_badge']?.toString() == '1' ||
              (j['user'] is Map &&
                  ((j['user']['verified_badge'] is int && j['user']['verified_badge'] == 1) ||
                      j['user']['verified_badge'] == true ||
                      j['user']['verified_badge']?.toString() == '1' ||
                      j['user']['is_verified_badge'] == true ||
                      j['user']['is_verified_badge'] == 1 ||
                      j['user']['is_verified_badge']?.toString() == '1'))),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
    );
  }

  ChatMessageModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? avatar,
    String? avatarDecorationUrl,
    String? avatarDecorationCode,
    String? message,
    String? mediaUrl,
    String? mediaType,
    String? mediaThumbnail,
    bool? hasMedia,
    String? backgroundUrl,
    String? backgroundType,
    bool? hasBackground,
    String? textColor,
    List<ChatMentionUser>? mentions,
    List<String>? notFoundMentions,
    List<String>? allMentions,
    int? mentionCount,
    int? replyToId,
    ChatReplyModel? replyTo,
    bool? isEdited,
    bool? isDeleted,
    List<int>? readBy,
    int? readCount,
    bool? isRead,
    bool? verifiedBadge,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      avatarDecorationUrl: avatarDecorationUrl ?? this.avatarDecorationUrl,
      avatarDecorationCode: avatarDecorationCode ?? this.avatarDecorationCode,
      message: message ?? this.message,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      mediaThumbnail: mediaThumbnail ?? this.mediaThumbnail,
      hasMedia: hasMedia ?? this.hasMedia,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      backgroundType: backgroundType ?? this.backgroundType,
      hasBackground: hasBackground ?? this.hasBackground,
      textColor: textColor ?? this.textColor,
      mentions: mentions ?? this.mentions,
      notFoundMentions: notFoundMentions ?? this.notFoundMentions,
      allMentions: allMentions ?? this.allMentions,
      mentionCount: mentionCount ?? this.mentionCount,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      readBy: readBy ?? this.readBy,
      readCount: readCount ?? this.readCount,
      isRead: isRead ?? this.isRead,
      verifiedBadge: verifiedBadge ?? this.verifiedBadge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if a mentioned username belongs to a user registered in the DB
  bool isMentionValid(String username) {
    final clean = username.replaceFirst('@', '').toLowerCase();
    return mentions.any((m) => m.username.toLowerCase() == clean);
  }

  /// Get the ChatMentionUser object if the mentioned username is registered
  ChatMentionUser? getMentionUser(String username) {
    final clean = username.replaceFirst('@', '').toLowerCase();
    for (final m in mentions) {
      if (m.username.toLowerCase() == clean) return m;
    }
    return null;
  }
}

class ChatInfoModel {
  final int id;
  final String name;
  final String description;
  final int totalMessages;
  final int totalUsers;
  final int mediaMessages;
  final int backgroundMessages;

  const ChatInfoModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalMessages,
    required this.totalUsers,
    required this.mediaMessages,
    required this.backgroundMessages,
  });

  factory ChatInfoModel.fromJson(Map<String, dynamic> j) {
    return ChatInfoModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '1') ?? 1,
      name: j['name']?.toString() ?? 'Global Chat',
      description: j['description']?.toString() ?? 'Satu ruang chat untuk semua pengguna',
      totalMessages: j['total_messages'] is int ? j['total_messages'] as int : int.tryParse(j['total_messages']?.toString() ?? '0') ?? 0,
      totalUsers: j['total_users'] is int ? j['total_users'] as int : int.tryParse(j['total_users']?.toString() ?? '0') ?? 0,
      mediaMessages: j['media_messages'] is int ? j['media_messages'] as int : int.tryParse(j['media_messages']?.toString() ?? '0') ?? 0,
      backgroundMessages: j['background_messages'] is int ? j['background_messages'] as int : int.tryParse(j['background_messages']?.toString() ?? '0') ?? 0,
    );
  }
}

class ChatNotificationSummaryModel {
  final int unreadMentions;
  final int unreadReplies;
  final int unreadMessages;
  final int totalUnread;

  const ChatNotificationSummaryModel({
    this.unreadMentions = 0,
    this.unreadReplies = 0,
    this.unreadMessages = 0,
    this.totalUnread = 0,
  });

  factory ChatNotificationSummaryModel.fromJson(Map<String, dynamic> j) {
    return ChatNotificationSummaryModel(
      unreadMentions: j['unread_mentions'] is int ? j['unread_mentions'] as int : int.tryParse(j['unread_mentions']?.toString() ?? '0') ?? 0,
      unreadReplies: j['unread_replies'] is int ? j['unread_replies'] as int : int.tryParse(j['unread_replies']?.toString() ?? '0') ?? 0,
      unreadMessages: j['unread_messages'] is int ? j['unread_messages'] as int : int.tryParse(j['unread_messages']?.toString() ?? '0') ?? 0,
      totalUnread: j['total_unread'] is int ? j['total_unread'] as int : int.tryParse(j['total_unread']?.toString() ?? '0') ?? 0,
    );
  }
}

class ChatUserSearchResult {
  final int id;
  final String username;
  final String? avatar;
  final bool verifiedBadge;

  const ChatUserSearchResult({
    required this.id,
    required this.username,
    this.avatar,
    this.verifiedBadge = false,
  });

  factory ChatUserSearchResult.fromJson(Map<String, dynamic> j) {
    return ChatUserSearchResult(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      username: j['username']?.toString() ?? '',
      avatar: j['avatar']?.toString(),
      verifiedBadge: (j['verified_badge'] is int)
          ? (j['verified_badge'] as int) == 1
          : (j['verified_badge'] == true ||
              j['verified_badge']?.toString() == '1' ||
              j['verified_badge']?.toString().toLowerCase() == 'true' ||
              j['user_verified_badge'] == true ||
              j['user_verified_badge'] == 1 ||
              j['user_verified_badge']?.toString() == '1' ||
              j['is_verified_badge'] == true ||
              j['is_verified_badge'] == 1 ||
              j['is_verified_badge']?.toString() == '1'),
    );
  }
}

class ChatMentionItemModel {
  final int id;
  final int messageId;
  final String messagePreview;
  final String? fullMessage;
  final String? mediaUrl;
  final String mediaType;
  final bool hasMedia;
  final int mentionedBy;
  final String? mentionedByUsername;
  final String? mentionedByAvatar;
  final bool isRead;
  final bool verifiedBadge;
  final String? createdAt;
  final String? updatedAt;

  const ChatMentionItemModel({
    required this.id,
    required this.messageId,
    required this.messagePreview,
    this.fullMessage,
    this.mediaUrl,
    this.mediaType = 'none',
    this.hasMedia = false,
    required this.mentionedBy,
    this.mentionedByUsername,
    this.mentionedByAvatar,
    this.isRead = false,
    this.verifiedBadge = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatMentionItemModel.fromJson(Map<String, dynamic> j) {
    return ChatMentionItemModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      messageId: j['message_id'] is int ? j['message_id'] as int : int.tryParse(j['message_id']?.toString() ?? '0') ?? 0,
      messagePreview: j['message_preview']?.toString() ?? '',
      fullMessage: j['full_message']?.toString(),
      mediaUrl: j['media_url']?.toString(),
      mediaType: j['media_type']?.toString() ?? 'none',
      hasMedia: j['has_media'] == true,
      mentionedBy: j['mentioned_by'] is int ? j['mentioned_by'] as int : int.tryParse(j['mentioned_by']?.toString() ?? '0') ?? 0,
      mentionedByUsername: j['mentioned_by_username']?.toString(),
      mentionedByAvatar: UserModel.normalizeAvatarUrl(
            j['mentioned_by_avatar']?.toString() ??
            (j['mentioned_by_user'] is Map ? j['mentioned_by_user']['avatar']?.toString() : null) ??
            (j['user'] is Map ? j['user']['avatar']?.toString() : null) ??
            j['avatar']?.toString(),
          ) ??
          j['mentioned_by_avatar']?.toString(),
      isRead: j['is_read'] == true ||
          j['is_read'] == 1 ||
          j['is_read']?.toString() == '1' ||
          j['is_read']?.toString() == 'true',
      verifiedBadge: j['verified_badge'] is int
          ? (j['verified_badge'] as int) == 1
          : (j['verified_badge'] == true ||
              j['verified_badge']?.toString() == '1' ||
              j['mentioned_by_verified_badge'] == true ||
              j['mentioned_by_verified_badge'] == 1 ||
              j['mentioned_by_verified_badge']?.toString() == '1'),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
    );
  }

  ChatMentionItemModel copyWith({bool? isRead}) {
    return ChatMentionItemModel(
      id: id,
      messageId: messageId,
      messagePreview: messagePreview,
      fullMessage: fullMessage,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      hasMedia: hasMedia,
      mentionedBy: mentionedBy,
      mentionedByUsername: mentionedByUsername,
      mentionedByAvatar: mentionedByAvatar,
      isRead: isRead ?? this.isRead,
      verifiedBadge: verifiedBadge,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ChatReplyNotificationItemModel {
  final int id;
  final int messageId;
  final String? originalMessage;
  final int? originalMessageId;
  final String replyMessage;
  final String? mediaUrl;
  final String mediaType;
  final bool hasMedia;
  final int repliedBy;
  final String? repliedByUsername;
  final String? repliedByAvatar;
  final bool isRead;
  final bool verifiedBadge;
  final String? createdAt;
  final String? updatedAt;

  const ChatReplyNotificationItemModel({
    required this.id,
    required this.messageId,
    this.originalMessage,
    this.originalMessageId,
    required this.replyMessage,
    this.mediaUrl,
    this.mediaType = 'none',
    this.hasMedia = false,
    required this.repliedBy,
    this.repliedByUsername,
    this.repliedByAvatar,
    this.isRead = false,
    this.verifiedBadge = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatReplyNotificationItemModel.fromJson(Map<String, dynamic> j) {
    return ChatReplyNotificationItemModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      messageId: j['message_id'] is int ? j['message_id'] as int : int.tryParse(j['message_id']?.toString() ?? '0') ?? 0,
      originalMessage: j['original_message']?.toString(),
      originalMessageId: j['original_message_id'] is int ? j['original_message_id'] as int : int.tryParse(j['original_message_id']?.toString() ?? ''),
      replyMessage: j['reply_message']?.toString() ?? '',
      mediaUrl: j['media_url']?.toString(),
      mediaType: j['media_type']?.toString() ?? 'none',
      hasMedia: j['has_media'] == true,
      repliedBy: j['replied_by'] is int ? j['replied_by'] as int : int.tryParse(j['replied_by']?.toString() ?? '0') ?? 0,
      repliedByUsername: j['replied_by_username']?.toString(),
      repliedByAvatar: UserModel.normalizeAvatarUrl(
            j['replied_by_avatar']?.toString() ??
            (j['replied_by_user'] is Map ? j['replied_by_user']['avatar']?.toString() : null) ??
            (j['user'] is Map ? j['user']['avatar']?.toString() : null) ??
            j['avatar']?.toString(),
          ) ??
          j['replied_by_avatar']?.toString(),
      isRead: j['is_read'] == true ||
          j['is_read'] == 1 ||
          j['is_read']?.toString() == '1' ||
          j['is_read']?.toString() == 'true',
      verifiedBadge: j['verified_badge'] is int
          ? (j['verified_badge'] as int) == 1
          : (j['verified_badge'] == true ||
              j['verified_badge']?.toString() == '1' ||
              j['replied_by_verified_badge'] == true ||
              j['replied_by_verified_badge'] == 1 ||
              j['replied_by_verified_badge']?.toString() == '1'),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
    );
  }

  ChatReplyNotificationItemModel copyWith({bool? isRead}) {
    return ChatReplyNotificationItemModel(
      id: id,
      messageId: messageId,
      originalMessage: originalMessage,
      originalMessageId: originalMessageId,
      replyMessage: replyMessage,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      hasMedia: hasMedia,
      repliedBy: repliedBy,
      repliedByUsername: repliedByUsername,
      repliedByAvatar: repliedByAvatar,
      isRead: isRead ?? this.isRead,
      verifiedBadge: verifiedBadge,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
