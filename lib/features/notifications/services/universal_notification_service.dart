import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/models/chat_model.dart';
import '../data/notification_repository.dart';

/// Universal Notification Service that unifies notifications from:
/// 1. Anime Episode Comments (likes & replies)
/// 2. General Community Chat (mentions @ & message replies)
class UniversalNotificationService {
  UniversalNotificationService._();
  static final UniversalNotificationService instance = UniversalNotificationService._();

  final ValueNotifier<int> totalUnreadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> commentUnreadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> chatUnreadNotifier = ValueNotifier<int>(0);

  Timer? _pollingTimer;
  bool _isRefreshing = false;

  void init() {
    refreshUnreadCounts();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      refreshUnreadCounts();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
  }

  /// Manually refresh unread counts across all notification sources
  Future<void> refreshUnreadCounts() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final results = await Future.wait([
        NotificationRepository.instance.getUnreadCommentNotificationsCount(),
        ChatRepository.instance.getNotificationSummary(),
      ]);

      final int commentUnread = (results[0] as num?)?.toInt() ?? 0;
      final chatSummary = results[1] as ChatNotificationSummaryModel?;
      final int chatUnread = chatSummary != null
          ? (chatSummary.unreadMentions + chatSummary.unreadReplies)
          : 0;

      commentUnreadNotifier.value = commentUnread;
      chatUnreadNotifier.value = chatUnread;
      totalUnreadNotifier.value = commentUnread + chatUnread;
    } catch (_) {} finally {
      _isRefreshing = false;
    }
  }

  /// Optimistically decrement unread count when user clicks an individual notification
  void decrementUnread({int by = 1, bool isChat = true}) {
    if (isChat) {
      final current = chatUnreadNotifier.value;
      final next = (current - by).clamp(0, 99999);
      chatUnreadNotifier.value = next;
    } else {
      final current = commentUnreadNotifier.value;
      final next = (current - by).clamp(0, 99999);
      commentUnreadNotifier.value = next;
    }
    totalUnreadNotifier.value =
        (commentUnreadNotifier.value + chatUnreadNotifier.value).clamp(0, 99999);
  }

  /// Mark all notifications across both Anime Comments & Chat as read
  Future<void> markAllAsRead() async {
    commentUnreadNotifier.value = 0;
    chatUnreadNotifier.value = 0;
    totalUnreadNotifier.value = 0;

    await Future.wait<dynamic>([
      NotificationRepository.instance.markAllCommentNotificationsRead(),
      ChatRepository.instance.markAllMentionsRead(),
      ChatRepository.instance.markAllReplyNotificationsRead(),
      ChatRepository.instance.markAllAsRead(),
    ]);
  }

  /// Mark all anime comment notifications as read
  Future<void> markAllCommentNotificationsRead() async {
    commentUnreadNotifier.value = 0;
    totalUnreadNotifier.value = chatUnreadNotifier.value;
    await NotificationRepository.instance.markAllCommentNotificationsRead();
  }

  /// Mark all chat notifications as read
  Future<void> markAllChatNotificationsRead() async {
    chatUnreadNotifier.value = 0;
    totalUnreadNotifier.value = commentUnreadNotifier.value;
    await Future.wait<dynamic>([
      ChatRepository.instance.markAllMentionsRead(),
      ChatRepository.instance.markAllReplyNotificationsRead(),
      ChatRepository.instance.markAllAsRead(),
    ]);
  }
}
