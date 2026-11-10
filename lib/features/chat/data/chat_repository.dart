import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_model.dart';

class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  /// Get global chat room metadata
  Future<ChatInfoModel?> getChatInfo() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.chatInfo);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return ChatInfoModel.fromJson(Map<String, dynamic>.from(d['data'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// Get messages with pagination & filters
  /// Get messages with pagination & filters (Search, Media, Background, MentionsMe, RepliesToMe)
  Future<Map<String, dynamic>?> getMessages({
    int page = 1,
    int perPage = 50,
    String? search,
    bool mediaOnly = false,
    bool withBackground = false,
    String? before,
    String? after,
    bool mentionsMe = false,
    bool repliesToMe = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
        if (mediaOnly) 'media_only': 'true',
        if (withBackground) 'with_background': 'true',
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        if (mentionsMe) 'mentions_me': 'true',
        if (repliesToMe) 'replies_to_me': 'true',
      };

      final resp = await ApiClient.instance.get(
        ApiEndpoints.chatMessages,
        queryParameters: queryParams,
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        final rawList = dataMap['messages'];
        final messages = <ChatMessageModel>[];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              messages.add(ChatMessageModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        return {
          'messages': messages,
          'pagination': dataMap['pagination'],
          'unread_count': dataMap['unread_count'] ?? 0,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Fetch the single latest chat message for the running marquee banner
  Future<ChatMessageModel?> getLatestMessage() async {
    try {
      final res = await getMessages(page: 1, perPage: 1);
      if (res != null && res['messages'] is List) {
        final list = res['messages'] as List<ChatMessageModel>;
        if (list.isNotEmpty) return list.first;
      }
    } catch (_) {}
    return null;
  }

  /// Send a new message
  Future<ChatMessageModel?> sendMessage({
    required String message,
    int? replyToId,
    String? mediaUrl,
    String mediaType = 'none',
    String? backgroundUrl,
    String backgroundType = 'none',
    String? textColor,
    String? avatarDecorationCode,
    String? avatarDecorationUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'message': message,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (mediaUrl != null && mediaUrl.isNotEmpty) ...{
          'media_url': mediaUrl,
          'media_type': mediaType,
        },
        if (backgroundUrl != null && backgroundUrl.isNotEmpty) ...{
          'background_url': backgroundUrl,
          'background_type': backgroundType,
          if (textColor != null && textColor.isNotEmpty) 'text_color': textColor,
        },
        if (avatarDecorationCode != null && avatarDecorationCode.isNotEmpty)
          'avatar_decoration_code': avatarDecorationCode,
        if (avatarDecorationUrl != null && avatarDecorationUrl.isNotEmpty)
          'avatar_decoration_url': avatarDecorationUrl,
      };

      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatMessages,
        data: body,
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        if (dataMap['message'] is Map) {
          final msgMap = Map<String, dynamic>.from(dataMap['message'] as Map);
          if (dataMap['mentions'] != null) {
            msgMap['mention_info'] = dataMap['mentions'];
          }
          if (dataMap['mentions_notified'] != null) {
            msgMap['mentions_notified'] = dataMap['mentions_notified'];
          }
          return ChatMessageModel.fromJson(msgMap);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Edit an existing message
  Future<ChatMessageModel?> editMessage({
    required int messageId,
    String? message,
    String? mediaUrl,
    String? mediaType,
    bool removeMedia = false,
    String? backgroundUrl,
    String? backgroundType,
    String? textColor,
    bool removeBackground = false,
  }) async {
    try {
      final body = <String, dynamic>{
        if (message != null) 'message': message,
        if (removeMedia) 'remove_media': true,
        if (!removeMedia && mediaUrl != null) ...{
          'media_url': mediaUrl,
          if (mediaType != null) 'media_type': mediaType,
        },
        if (removeBackground) 'remove_background': true,
        if (!removeBackground && backgroundUrl != null) ...{
          'background_url': backgroundUrl,
          if (backgroundType != null) 'background_type': backgroundType,
          if (textColor != null) 'text_color': textColor,
        },
      };

      final resp = await ApiClient.instance.put(
        ApiEndpoints.chatMessage(messageId),
        data: body,
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        if (dataMap['message'] is Map) {
          return ChatMessageModel.fromJson(Map<String, dynamic>.from(dataMap['message'] as Map));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Delete a message
  /// Delete a message (soft delete)
  Future<bool> deleteMessage(int messageId) async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.chatMessage(messageId));
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Delete message media attachment only
  Future<bool> deleteMessageMedia(int messageId) async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.chatDeleteMedia(messageId));
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Delete message background customization only
  Future<bool> deleteMessageBackground(int messageId) async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.chatDeleteBackground(messageId));
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Upload media attachment (Image / GIF max 5MB)
  Future<Map<String, dynamic>?> uploadMedia(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatUploadMedia,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final d = _asMap(resp.data);
      if (d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      if (d['media_url'] != null || d['url'] != null) {
        return d;
      }
    } catch (e, st) {
      debugPrint('[ChatRepository] uploadMedia error: $e\n$st');
    }
    return null;
  }

  /// Upload chat bubble background (Image / GIF max 5MB)
  Future<Map<String, dynamic>?> uploadBackground(File file, {String? textColor}) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final map = <String, dynamic>{
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      };
      if (textColor != null && textColor.isNotEmpty) {
        map['text_color'] = textColor;
      }
      final form = FormData.fromMap(map);

      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatUploadBackground,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Get current user's chat background settings
  Future<Map<String, dynamic>?> getUserChatBackground() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.chatUserBackground);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Set user's chat background settings
  Future<Map<String, dynamic>?> setUserChatBackground({
    required String background,
    String bgType = 'image',
    double opacity = 1.0,
    int blur = 0,
    String? textColor,
    String bubbleStyle = 'default',
  }) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatUserBackground,
        data: {
          'background': background,
          'background_type': bgType,
          'opacity': opacity,
          'blur': blur,
          if (textColor != null && textColor.isNotEmpty) 'text_color': textColor,
          'bubble_style': bubbleStyle,
        },
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Delete/reset user's chat background settings
  Future<bool> deleteUserChatBackground() async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.chatUserBackground);
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Upload file and set user's chat background directly
  Future<Map<String, dynamic>?> uploadUserChatBackground(
    File file, {
    double opacity = 1.0,
    int blur = 0,
    String? textColor,
    String bubbleStyle = 'default',
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final map = <String, dynamic>{
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'opacity': opacity.toString(),
        'blur': blur.toString(),
        'bubble_style': bubbleStyle,
      };
      if (textColor != null && textColor.isNotEmpty) {
        map['text_color'] = textColor;
      }
      final form = FormData.fromMap(map);

      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatUserBackgroundUpload,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Get notification summary (unread count)
  Future<ChatNotificationSummaryModel?> getNotificationSummary() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.chatNotificationsSummary);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return ChatNotificationSummaryModel.fromJson(Map<String, dynamic>.from(d['data'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// Get mentions notifications
  Future<List<ChatMentionItemModel>> getMentions({int? isRead, int page = 1, int perPage = 20}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.chatMentions,
        queryParameters: {
          if (isRead != null) 'is_read': isRead,
          'page': page,
          'per_page': perPage,
        },
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final list = (d['data'] as Map)['mentions'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => ChatMentionItemModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Mark mention notification as read
  Future<bool> markMentionRead(int mentionId) async {
    try {
      final resp = await ApiClient.instance.patch(ApiEndpoints.chatMentionRead(mentionId));
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all mentions as read
  Future<bool> markAllMentionsRead() async {
    try {
      final resp = await ApiClient.instance.post(ApiEndpoints.chatMentionsReadAll);
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get reply notifications
  Future<List<ChatReplyNotificationItemModel>> getReplyNotifications({int? isRead, int page = 1, int perPage = 20}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.chatReplyNotifications,
        queryParameters: {
          if (isRead != null) 'is_read': isRead,
          'page': page,
          'per_page': perPage,
        },
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final list = (d['data'] as Map)['notifications'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((n) => ChatReplyNotificationItemModel.fromJson(Map<String, dynamic>.from(n)))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Mark reply notification as read
  Future<bool> markReplyNotificationRead(int notifId) async {
    try {
      final resp = await ApiClient.instance.patch(ApiEndpoints.chatReplyNotificationRead(notifId));
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all reply notifications as read
  Future<bool> markAllReplyNotificationsRead() async {
    try {
      final resp = await ApiClient.instance.post(ApiEndpoints.chatReplyNotificationsReadAll);
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Search users for mentions (@username autocomplete)
  Future<List<ChatUserSearchResult>> searchUsers(String query) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.chatUsersSearch,
        queryParameters: {'q': query},
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final list = (d['data'] as Map)['users'];
        if (list is List) {
          return list
               .whereType<Map>()
               .map((u) => ChatUserSearchResult.fromJson(Map<String, dynamic>.from(u)))
               .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Validate mention usernames (returns found and not_found)
  Future<({List<ChatMentionUser> found, List<String> notFound})> validateMentions(List<String> usernames) async {
    if (usernames.isEmpty) return (found: <ChatMentionUser>[], notFound: <String>[]);
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.chatMentionsValidate,
        data: {'usernames': usernames},
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        final foundRaw = dataMap['found'];
        final notFoundRaw = dataMap['not_found'];
        final found = <ChatMentionUser>[];
        final notFound = <String>[];
        if (foundRaw is List) {
          for (final item in foundRaw) {
            if (item is Map) {
              found.add(ChatMentionUser.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        if (notFoundRaw is List) {
          for (final item in notFoundRaw) {
            if (item != null) notFound.add(item.toString());
          }
        }
        return (found: found, notFound: notFound);
      }
    } catch (_) {}
    return (found: <ChatMentionUser>[], notFound: usernames);
  }

  /// Mark all chat messages & notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final resp = await ApiClient.instance.post(ApiEndpoints.chatReadAll);
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all general notifications as read
  Future<bool> markAllGeneralNotificationsRead() async {
    return markAllAsRead();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
