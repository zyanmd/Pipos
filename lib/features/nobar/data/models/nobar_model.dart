/// Model representing a Watch Party (Nobar) Room
class NobarRoomModel {
  final int id;
  final String code;
  final String title;
  final String animeId;
  final String animeTitle;
  final String animePoster;
  final String episodeKey;
  final String episodeNumber;
  final String streamUrl;
  final bool isPrivate;
  final int hostId;
  final String hostUsername;
  final String hostAvatar;
  final bool isPlaying;
  final int currentPositionMs;
  final int participantsCount;
  final String status;
  final DateTime? lastSyncAt;
  final DateTime? createdAt;
  final List<NobarParticipantModel> participants;

  const NobarRoomModel({
    required this.id,
    required this.code,
    required this.title,
    required this.animeId,
    required this.animeTitle,
    this.animePoster = '',
    required this.episodeKey,
    this.episodeNumber = '',
    required this.streamUrl,
    this.isPrivate = false,
    this.hostId = 0,
    required this.hostUsername,
    this.hostAvatar = '',
    this.isPlaying = false,
    this.currentPositionMs = 0,
    this.participantsCount = 1,
    this.status = 'active',
    this.lastSyncAt,
    this.createdAt,
    this.participants = const [],
  });

  factory NobarRoomModel.fromJson(Map<String, dynamic> json) {
    List<NobarParticipantModel> parts = [];
    if (json['participants'] is List) {
      parts = (json['participants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => NobarParticipantModel.fromJson(e))
          .toList();
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return NobarRoomModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Nobar Anime',
      animeId: json['anime_id']?.toString() ?? '',
      animeTitle: json['anime_title']?.toString() ?? 'Anime',
      animePoster: json['anime_poster']?.toString() ?? '',
      episodeKey: json['episode_key']?.toString() ?? '',
      episodeNumber: json['episode_number']?.toString() ?? '',
      streamUrl: json['stream_url']?.toString() ?? '',
      isPrivate: json['is_private'] == true,
      hostId: json['host_id'] is int ? json['host_id'] as int : int.tryParse('${json['host_id']}') ?? 0,
      hostUsername: json['host_username']?.toString() ?? 'Host',
      hostAvatar: json['host_avatar']?.toString() ?? '',
      isPlaying: json['is_playing'] == true,
      currentPositionMs: json['current_position_ms'] is int
          ? json['current_position_ms'] as int
          : int.tryParse('${json['current_position_ms']}') ?? 0,
      participantsCount: json['participants_count'] is int
          ? json['participants_count'] as int
          : int.tryParse('${json['participants_count']}') ?? 1,
      status: json['status']?.toString() ?? 'active',
      lastSyncAt: parseDate(json['last_sync_at']),
      createdAt: parseDate(json['created_at']),
      participants: parts,
    );
  }

  NobarRoomModel copyWith({
    bool? isPlaying,
    int? currentPositionMs,
    int? participantsCount,
    List<NobarParticipantModel>? participants,
    String? status,
    String? episodeNumber,
    String? episodeKey,
    String? streamUrl,
  }) {
    return NobarRoomModel(
      id: id,
      code: code,
      title: title,
      animeId: animeId,
      animeTitle: animeTitle,
      animePoster: animePoster,
      episodeKey: episodeKey ?? this.episodeKey,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      streamUrl: streamUrl ?? this.streamUrl,
      isPrivate: isPrivate,
      hostId: hostId,
      hostUsername: hostUsername,
      hostAvatar: hostAvatar,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      participantsCount: participantsCount ?? this.participantsCount,
      status: status ?? this.status,
      lastSyncAt: lastSyncAt,
      createdAt: createdAt,
      participants: participants ?? this.participants,
    );
  }
}

/// Participant in watch party
class NobarParticipantModel {
  final int id;
  final String roomCode;
  final int userId;
  final String username;
  final String avatar;
  final bool isHost;
  final DateTime? joinedAt;

  const NobarParticipantModel({
    required this.id,
    required this.roomCode,
    this.userId = 0,
    required this.username,
    this.avatar = '',
    this.isHost = false,
    this.joinedAt,
  });

  factory NobarParticipantModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return NobarParticipantModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      roomCode: json['room_code']?.toString() ?? '',
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse('${json['user_id']}') ?? 0,
      username: json['username']?.toString() ?? 'User',
      avatar: json['avatar']?.toString() ?? '',
      isHost: json['is_host'] == true,
      joinedAt: parseDate(json['joined_at']),
    );
  }
}

/// Live chat message or reaction
class NobarMessageModel {
  final int id;
  final String roomCode;
  final int userId;
  final String username;
  final String avatar;
  final String message;
  final String type; // chat, reaction, system
  final DateTime? createdAt;

  const NobarMessageModel({
    required this.id,
    required this.roomCode,
    this.userId = 0,
    required this.username,
    this.avatar = '',
    required this.message,
    this.type = 'chat',
    this.createdAt,
  });

  factory NobarMessageModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return NobarMessageModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      roomCode: json['room_code']?.toString() ?? '',
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse('${json['user_id']}') ?? 0,
      username: json['username']?.toString() ?? 'Anonim',
      avatar: json['avatar']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'chat',
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
