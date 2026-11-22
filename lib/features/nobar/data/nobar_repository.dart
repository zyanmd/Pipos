import '../../../core/network/api_client.dart';
import 'models/nobar_model.dart';

class NobarRepository {
  NobarRepository._();
  static final NobarRepository instance = NobarRepository._();

  String get _base => ApiConfig.nobarBase;

  /// Get list of active public rooms
  Future<List<NobarRoomModel>> getPublicRooms() async {
    try {
      final resp = await ApiClient.instance.get('$_base/rooms');
      if (resp.data is Map && resp.data['success'] == true) {
        final list = resp.data['rooms'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((e) => NobarRoomModel.fromJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get room details by code
  Future<NobarRoomModel?> getRoom(String code, {String? passcode}) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.get(
        '$_base/rooms/$cleanCode',
        queryParameters: passcode != null && passcode.isNotEmpty ? {'passcode': passcode} : null,
      );
      if (resp.data is Map && resp.data['success'] == true) {
        final roomData = resp.data['room'];
        if (roomData is Map<String, dynamic>) {
          return NobarRoomModel.fromJson(roomData);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Create a new watch party room
  Future<NobarRoomModel?> createRoom({
    required String title,
    required String animeId,
    required String animeTitle,
    String animePoster = '',
    required String episodeKey,
    String episodeNumber = '',
    required String streamUrl,
    bool isPrivate = false,
    String passcode = '',
    String username = '',
    String avatar = '',
  }) async {
    try {
      final resp = await ApiClient.instance.post(
        '$_base/rooms',
        data: {
          'title': title,
          'anime_id': animeId,
          'anime_title': animeTitle,
          'anime_poster': animePoster,
          'episode_key': episodeKey,
          'episode_number': episodeNumber,
          'stream_url': streamUrl,
          'is_private': isPrivate,
          'passcode': passcode,
          'username': username,
          'avatar': avatar,
        },
      );
      if (resp.data is Map && resp.data['success'] == true) {
        final roomData = resp.data['room'];
        if (roomData is Map<String, dynamic>) {
          return NobarRoomModel.fromJson(roomData);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Join an existing room
  Future<NobarRoomModel?> joinRoom(
    String code, {
    String? passcode,
    String username = '',
    String avatar = '',
  }) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post(
        '$_base/rooms/$cleanCode/join',
        data: {
          if (passcode != null) 'passcode': passcode,
          if (username.isNotEmpty) 'username': username,
          if (avatar.isNotEmpty) 'avatar': avatar,
        },
      );
      if (resp.data is Map && resp.data['success'] == true) {
        final roomData = resp.data['room'];
        if (roomData is Map<String, dynamic>) {
          return NobarRoomModel.fromJson(roomData);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Synchronize playback state (host / participants)
  Future<bool> syncPlayback(
    String code, {
    required int currentPositionMs,
    required bool isPlaying,
    String action = 'sync',
  }) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post(
        '$_base/rooms/$cleanCode/sync',
        data: {
          'current_position_ms': currentPositionMs,
          'is_playing': isPlaying,
          'action': action,
        },
      );
      return resp.data is Map && resp.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Heartbeat ping to maintain active status and get playback state
  Future<Map<String, dynamic>?> ping(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post('$_base/rooms/$cleanCode/ping');
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Leave room
  Future<bool> leaveRoom(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post('$_base/rooms/$cleanCode/leave');
      return resp.data is Map && resp.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// End / dissolve room (host deletes room and all messages)
  Future<bool> endRoom(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.delete('$_base/rooms/$cleanCode');
      return resp.data is Map && resp.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Change active episode in room (Host only)
  Future<bool> changeEpisode(
    String code, {
    required String episodeNumber,
    required String episodeKey,
    required String streamUrl,
  }) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post(
        '$_base/rooms/$cleanCode/episode',
        data: {
          'episode_number': episodeNumber,
          'episode_key': episodeKey,
          'stream_url': streamUrl,
        },
      );
      return resp.data is Map && resp.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get live chat messages with incremental polling (after_id)
  Future<List<NobarMessageModel>> getMessages(String code, {int afterId = 0}) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.get(
        '$_base/rooms/$cleanCode/messages',
        queryParameters: afterId > 0 ? {'after_id': afterId} : null,
      );
      if (resp.data is Map && resp.data['success'] == true) {
        final list = resp.data['messages'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((e) => NobarMessageModel.fromJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Send chat message or emoji reaction
  Future<NobarMessageModel?> sendMessage(
    String code,
    String message, {
    String type = 'chat',
    String username = '',
    String avatar = '',
  }) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resp = await ApiClient.instance.post(
        '$_base/rooms/$cleanCode/messages',
        data: {
          'message': message,
          'type': type,
          if (username.isNotEmpty) 'username': username,
          if (avatar.isNotEmpty) 'avatar': avatar,
        },
      );
      if (resp.data is Map && resp.data['success'] == true) {
        final msgData = resp.data['message'];
        if (msgData is Map<String, dynamic>) {
          return NobarMessageModel.fromJson(msgData);
        }
      }
    } catch (_) {}
    return null;
  }
}
