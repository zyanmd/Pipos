import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import 'models/comment_notification_model.dart';

class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  /// Get anime comment notifications (likes & replies)
  Future<List<CommentNotificationModel>> getCommentNotifications({
    String type = 'all',
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.ylnimeCommentNotifications,
        queryParameters: {
          'type': type,
          'unread_only': unreadOnly,
          'limit': limit,
          'offset': offset,
        },
      );
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is List) {
        final rawList = d['data'] as List;
        return rawList
            .whereType<Map>()
            .map((item) => CommentNotificationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('[NotificationRepository] getCommentNotifications error: $e');
    }
    return [];
  }

  /// Get unread count for anime comment notifications
  Future<int> getUnreadCommentNotificationsCount() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.ylnimeCommentNotificationsCount);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final data = Map<String, dynamic>.from(d['data'] as Map);
        return int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Mark single comment notification as read
  Future<bool> markCommentNotificationRead(dynamic notifId) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeCommentNotificationRead(notifId),
      );
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (e) {
      debugPrint('[NotificationRepository] markCommentNotificationRead error: $e');
      return false;
    }
  }

  /// Mark all comment notifications as read
  Future<int> markAllCommentNotificationsRead() async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeCommentNotificationsReadAll,
      );
      final d = _asMap(resp.data);
      if (d['success'] == true) {
        return int.tryParse(d['updated']?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('[NotificationRepository] markAllCommentNotificationsRead error: $e');
    }
    return 0;
  }

  /// Delete a comment notification
  Future<bool> deleteCommentNotification(dynamic notifId) async {
    try {
      final resp = await ApiClient.instance.delete(
        ApiEndpoints.ylnimeCommentNotificationDelete(notifId),
      );
      final d = _asMap(resp.data);
      return d['success'] == true;
    } catch (e) {
      debugPrint('[NotificationRepository] deleteCommentNotification error: $e');
      return false;
    }
  }

  /// Cleanup old notifications
  Future<int> cleanupOldNotifications({int days = 30}) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.ylnimeCommentNotificationsCleanup,
        queryParameters: {'days': days},
      );
      final d = _asMap(resp.data);
      if (d['success'] == true) {
        return int.tryParse(d['deleted']?.toString() ?? '0') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
