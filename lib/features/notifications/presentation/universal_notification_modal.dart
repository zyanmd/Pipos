import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/services/user_decor_resolver.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../../auth/data/models/user_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../anime/presentation/anime_episode_player.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/models/chat_model.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/models/comment_notification_model.dart';
import '../data/notification_repository.dart';
import '../services/universal_notification_service.dart';
import '../../../core/services/onesignal_service.dart';

/// Notification category types for unified feed
enum UnifiedNotifType {
  commentLike,
  commentReply,
  chatMention,
  chatReply,
  birthday,
}

/// A unified notification model combining anime comments and chat notifications
class UnifiedNotificationItem {
  final String id;
  final UnifiedNotifType type;
  final String? actorUsername;
  final String? actorAvatar;
  final bool isActorVerified;
  final String title;
  final String? subtitle;
  final String? previewText;
  final DateTime? createdAt;
  final String? rawCreatedAt;
  final bool isRead;
  final dynamic originalObject;

  const UnifiedNotificationItem({
    required this.id,
    required this.type,
    this.actorUsername,
    this.actorAvatar,
    this.isActorVerified = false,
    required this.title,
    this.subtitle,
    this.previewText,
    this.createdAt,
    this.rawCreatedAt,
    required this.isRead,
    required this.originalObject,
  });

  bool get isComment =>
      type == UnifiedNotifType.commentLike ||
      type == UnifiedNotifType.commentReply ||
      type == UnifiedNotifType.birthday;

  bool get isChat =>
      type == UnifiedNotifType.chatMention || type == UnifiedNotifType.chatReply;
}

/// Universal Notification Sheet/Modal for Anime Comments & Community Chat
/// Optimized for mobile UX with a sleek monochrome (black & white) theme.
class UniversalNotificationModal extends StatefulWidget {
  final int initialTabIndex;

  const UniversalNotificationModal({
    super.key,
    this.initialTabIndex = 0,
  });

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalNotificationModal(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<UniversalNotificationModal> createState() => _UniversalNotificationModalState();
}

class _UniversalNotificationModalState extends State<UniversalNotificationModal> {
  // 0: Semua (All), 1: Komen Anime, 2: Chat Umum
  int _selectedFilter = 0;
  bool _loading = false;

  List<CommentNotificationModel> _commentsNotifs = [];
  List<ChatMentionItemModel> _chatMentions = [];
  List<ChatReplyNotificationItemModel> _chatReplies = [];

  @override
  void initState() {
    super.initState();
    _selectedFilter = (widget.initialTabIndex >= 0 && widget.initialTabIndex <= 2)
        ? widget.initialTabIndex
        : 0;
    UserDecorResolver.instance.addListener(_onDecorUpdated);
    _loadAll();
  }

  @override
  void dispose() {
    UserDecorResolver.instance.removeListener(_onDecorUpdated);
    super.dispose();
  }

  void _onDecorUpdated() {
    if (mounted) setState(() {});
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  List<UnifiedNotificationItem> get _unifiedItems {
    final List<UnifiedNotificationItem> items = [];

    // Add Anime Comment & Birthday notifications
    for (final n in _commentsNotifs) {
      if (n.type == 'birthday') {
        items.add(
          UnifiedNotificationItem(
            id: 'birthday_${n.id}',
            type: UnifiedNotifType.birthday,
            actorUsername: n.actorUsername ?? 'Moko',
            actorAvatar: n.actorAvatar,
            title: 'Hari Ulang Tahun! 🎂',
            subtitle: 'Selamat Ulang Tahun 🎉',
            previewText: n.message,
            createdAt: _parseDate(n.createdAt),
            rawCreatedAt: n.createdAt,
            isRead: n.isRead,
            originalObject: n,
          ),
        );
        continue;
      }

      final isLike = n.type == 'comment_like';
      items.add(
        UnifiedNotificationItem(
          id: 'comment_${n.id}',
          type: isLike ? UnifiedNotifType.commentLike : UnifiedNotifType.commentReply,
          actorUsername: n.actorUsername,
          actorAvatar: n.actorAvatar,
          title: isLike ? 'menyukai komentar Anda' : 'mengomentari komentar Anda',
          subtitle: n.episodeNumber != null
              ? 'Episode ${n.episodeNumber}'
              : (n.animeId ?? 'Anime'),
          previewText: n.commentPreview,
          createdAt: _parseDate(n.createdAt),
          rawCreatedAt: n.createdAt,
          isRead: n.isRead,
          originalObject: n,
        ),
      );
    }

    // Add Chat Mentions
    for (final m in _chatMentions) {
      items.add(
        UnifiedNotificationItem(
          id: 'chat_mention_${m.id}',
          type: UnifiedNotifType.chatMention,
          actorUsername: m.mentionedByUsername,
          actorAvatar: m.mentionedByAvatar,
          isActorVerified: m.verifiedBadge,
          title: 'menyebut Anda di Chat Umum',
          subtitle: 'Chat Komunitas',
          previewText: m.messagePreview,
          createdAt: _parseDate(m.createdAt),
          rawCreatedAt: m.createdAt,
          isRead: m.isRead,
          originalObject: m,
        ),
      );
    }

    // Add Chat Replies
    for (final r in _chatReplies) {
      items.add(
        UnifiedNotificationItem(
          id: 'chat_reply_${r.id}',
          type: UnifiedNotifType.chatReply,
          actorUsername: r.repliedByUsername,
          actorAvatar: r.repliedByAvatar,
          isActorVerified: r.verifiedBadge,
          title: 'membalas pesan Anda di Chat',
          subtitle: (r.originalMessage != null && r.originalMessage!.isNotEmpty)
              ? 'Pesan: "${r.originalMessage}"'
              : 'Chat Komunitas',
          previewText: r.replyMessage,
          createdAt: _parseDate(r.createdAt),
          rawCreatedAt: r.createdAt,
          isRead: r.isRead,
          originalObject: r,
        ),
      );
    }

    // Sort chronologically (newest first)
    items.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return items;
  }

  List<UnifiedNotificationItem> get _filteredItems {
    final all = _unifiedItems;
    if (_selectedFilter == 1) {
      return all.where((i) => i.isComment).toList();
    } else if (_selectedFilter == 2) {
      return all.where((i) => i.isChat).toList();
    }
    return all;
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        NotificationRepository.instance.getCommentNotifications(limit: 50),
        ChatRepository.instance.getMentions(page: 1, perPage: 40),
        ChatRepository.instance.getReplyNotifications(page: 1, perPage: 40),
      ]);

      if (!mounted) return;

      final comments = results[0] as List<CommentNotificationModel>;
      final mentions = results[1] as List<ChatMentionItemModel>;
      final replies = results[2] as List<ChatReplyNotificationItemModel>;

      setState(() {
        _commentsNotifs = comments;
        _chatMentions = mentions;
        _chatReplies = replies;
        _loading = false;
      });

      // Synchronize unread notifiers accurately
      final int commentUnread = comments.where((c) => !c.isRead).length;
      final int chatUnread = mentions.where((m) => !m.isRead).length +
          replies.where((r) => !r.isRead).length;

      UniversalNotificationService.instance.commentUnreadNotifier.value = commentUnread;
      UniversalNotificationService.instance.chatUnreadNotifier.value = chatUnread;
      UniversalNotificationService.instance.totalUnreadNotifier.value =
          commentUnread + chatUnread;

      // Automatically register avatars & resolve profile decorations for notification actors
      final usernames = <String?>{};
      for (final c in comments) {
        if (c.actorUsername != null && c.actorUsername!.isNotEmpty) {
          usernames.add(c.actorUsername);
          if (c.actorAvatar != null && c.actorAvatar!.isNotEmpty) {
            UserDecorResolver.instance.register(
              username: c.actorUsername!,
              avatarUrl: UserModel.normalizeAvatarUrl(c.actorAvatar),
            );
          }
        }
      }
      for (final m in mentions) {
        if (m.mentionedByUsername != null && m.mentionedByUsername!.isNotEmpty) {
          usernames.add(m.mentionedByUsername);
          if (m.mentionedByAvatar != null && m.mentionedByAvatar!.isNotEmpty) {
            UserDecorResolver.instance.register(
              username: m.mentionedByUsername!,
              avatarUrl: UserModel.normalizeAvatarUrl(m.mentionedByAvatar),
            );
          }
        }
      }
      for (final r in replies) {
        if (r.repliedByUsername != null && r.repliedByUsername!.isNotEmpty) {
          usernames.add(r.repliedByUsername);
          if (r.repliedByAvatar != null && r.repliedByAvatar!.isNotEmpty) {
            UserDecorResolver.instance.register(
              username: r.repliedByUsername!,
              avatarUrl: UserModel.normalizeAvatarUrl(r.repliedByAvatar),
            );
          }
        }
      }
      if (usernames.isNotEmpty) {
        UserDecorResolver.instance.resolveUsers(usernames);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _commentsNotifs = _commentsNotifs.map((c) => c.copyWith(isRead: true)).toList();
      _chatMentions = _chatMentions.map((m) => m.copyWith(isRead: true)).toList();
      _chatReplies = _chatReplies.map((r) => r.copyWith(isRead: true)).toList();
    });
    await UniversalNotificationService.instance.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Semua notifikasi ditandai sudah dibaca', style: TextStyle(fontSize: 12.5)),
          ],
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onCommentTap(CommentNotificationModel notif) async {
    HapticFeedback.lightImpact();
    // ⚡ Hapus tanda belum dibaca seketika (optimistic update)
    if (!notif.isRead) {
      if (mounted) {
        setState(() {
          final idx = _commentsNotifs.indexWhere((c) => c.id == notif.id);
          if (idx != -1) {
            _commentsNotifs[idx] = _commentsNotifs[idx].copyWith(isRead: true);
          }
        });
      }
      UniversalNotificationService.instance.decrementUnread(isChat: false);
      NotificationRepository.instance.markCommentNotificationRead(notif.id).then((_) {
        UniversalNotificationService.instance.refreshUnreadCounts();
      });
    }

    if (!mounted) return;
    Navigator.pop(context);

    final epKey = notif.episodeKey;
    final animeId = notif.animeId;
    if (epKey != null && epKey.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => AnimeEpisodePlayerScreen(
            episodeId: epKey,
            episodeLabel: notif.episodeNumber != null ? 'Episode ${notif.episodeNumber}' : 'Episode',
            animeId: animeId,
            animeTitle: animeId ?? 'Anime',
            scrollToComments: true,
          ),
        ),
      );
    } else if (animeId != null && animeId.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => AnimeDetailScreen(animeId: animeId),
        ),
      );
    }
  }

  Future<void> _deleteCommentNotif(CommentNotificationModel notif) async {
    HapticFeedback.lightImpact();
    final success = await NotificationRepository.instance.deleteCommentNotification(notif.id);
    if (success && mounted) {
      setState(() {
        _commentsNotifs.removeWhere((c) => c.id == notif.id);
      });
      UniversalNotificationService.instance.refreshUnreadCounts();
    }
  }

  Future<void> _onMentionTap(ChatMentionItemModel m) async {
    HapticFeedback.lightImpact();
    // ⚡ Hapus tanda belum dibaca seketika (optimistic update)
    if (!m.isRead) {
      if (mounted) {
        setState(() {
          final idx = _chatMentions.indexWhere((item) => item.id == m.id);
          if (idx != -1) {
            _chatMentions[idx] = _chatMentions[idx].copyWith(isRead: true);
          }
        });
      }
      UniversalNotificationService.instance.decrementUnread(isChat: true);
      ChatRepository.instance.markMentionRead(m.id).then((_) {
        UniversalNotificationService.instance.refreshUnreadCounts();
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          targetMessageId: m.messageId,
        ),
      ),
    );
  }

  Future<void> _onReplyTap(ChatReplyNotificationItemModel r) async {
    HapticFeedback.lightImpact();
    // ⚡ Hapus tanda belum dibaca seketika (optimistic update)
    if (!r.isRead) {
      if (mounted) {
        setState(() {
          final idx = _chatReplies.indexWhere((item) => item.id == r.id);
          if (idx != -1) {
            _chatReplies[idx] = _chatReplies[idx].copyWith(isRead: true);
          }
        });
      }
      UniversalNotificationService.instance.decrementUnread(isChat: true);
      ChatRepository.instance.markReplyNotificationRead(r.id).then((_) {
        UniversalNotificationService.instance.refreshUnreadCounts();
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          targetMessageId: r.messageId != 0 ? r.messageId : r.originalMessageId,
        ),
      ),
    );
  }

  void _onItemTap(UnifiedNotificationItem item) {
    if (item.type == UnifiedNotifType.commentLike || item.type == UnifiedNotifType.commentReply) {
      _onCommentTap(item.originalObject as CommentNotificationModel);
    } else if (item.type == UnifiedNotifType.chatMention) {
      _onMentionTap(item.originalObject as ChatMentionItemModel);
    } else if (item.type == UnifiedNotifType.chatReply) {
      _onReplyTap(item.originalObject as ChatReplyNotificationItemModel);
    } else if (item.type == UnifiedNotifType.birthday) {
      _onBirthdayTap(item.originalObject as CommentNotificationModel);
    }
  }

  void _onBirthdayTap(CommentNotificationModel notif) {
    HapticFeedback.lightImpact();
    // Optimistic mark as read
    setState(() {
      final idx = _commentsNotifs.indexWhere((c) => c.id == notif.id);
      if (idx != -1) {
        _commentsNotifs[idx] = CommentNotificationModel(
          id: notif.id,
          type: notif.type,
          referenceType: notif.referenceType,
          referenceId: notif.referenceId,
          actorId: notif.actorId,
          actorUsername: notif.actorUsername,
          actorAvatar: notif.actorAvatar,
          actorRank: notif.actorRank,
          message: notif.message,
          redirectUrl: notif.redirectUrl,
          episodeKey: notif.episodeKey,
          animeId: notif.animeId,
          episodeNumber: notif.episodeNumber,
          commentPreview: notif.commentPreview,
          replyPreview: notif.replyPreview,
          isRead: true,
          createdAt: notif.createdAt,
        );
      }
    });
    NotificationRepository.instance.markCommentNotificationRead(notif.id);
    UniversalNotificationService.instance.refreshUnreadCounts();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E24)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎂 ', style: TextStyle(fontSize: 24)),
            Text('Hari Ulang Tahun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          notif.message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final bottomInset = media.padding.bottom;

    final commentUnread = _commentsNotifs.where((c) => !c.isRead).length;
    final chatUnread = _chatMentions.where((m) => !m.isRead).length +
        _chatReplies.where((r) => !r.isRead).length;
    final totalUnread = commentUnread + chatUnread;

    final items = _filteredItems;

    return Container(
      height: screenHeight * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111113) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle Pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Title & Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with Notification Bell
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      ),
                      child: Icon(
                        CupertinoIcons.bell_fill,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (totalUnread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          totalUnread > 99 ? '99+' : '$totalUnread baru',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Top Right Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mark All As Read Button
                    if (totalUnread > 0)
                      GestureDetector(
                        onTap: _markAllAsRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_alt,
                                size: 12,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tandai dibaca',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Notification Settings Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        OneSignalService.showPreferenceModal(context).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(
                          CupertinoIcons.gear_alt_fill,
                          size: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),

                    // Close Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Segment Filter Tabs (Semua, Komen Anime, Chat Umum)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                _buildFilterTab(
                  label: 'Semua',
                  count: totalUnread,
                  isSelected: _selectedFilter == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilter = 0);
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: 'Komen Anime',
                  count: commentUnread,
                  isSelected: _selectedFilter == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilter = 1);
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: 'Chat Umum',
                  count: chatUnread,
                  isSelected: _selectedFilter == 2,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilter = 2);
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Notification Feed List
          Expanded(
            child: _loading
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 13),
                  )
                : items.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        color: isDark ? Colors.white : Colors.black,
                        backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          itemBuilder: (ctx, i) => _buildNotificationTile(items[i], isDark),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF0F0F2)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white12 : Colors.black12),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white : Colors.black),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.black : Colors.white),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: isDark ? Colors.white : Colors.black,
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 70),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.bell_slash,
                    size: 38,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada Notifikasi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Text(
                    'Semua balasan komentar anime, sebutan (@mention), dan pesan chat umum akan masuk ke sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(UnifiedNotificationItem item, bool isDark) {
    IconData badgeIcon;
    String categoryLabel;

    switch (item.type) {
      case UnifiedNotifType.commentLike:
        badgeIcon = CupertinoIcons.heart_fill;
        categoryLabel = 'Komen Anime';
        break;
      case UnifiedNotifType.commentReply:
        badgeIcon = CupertinoIcons.chat_bubble_fill;
        categoryLabel = 'Komen Anime';
        break;
      case UnifiedNotifType.chatMention:
        badgeIcon = CupertinoIcons.at;
        categoryLabel = 'Chat Umum';
        break;
      case UnifiedNotifType.chatReply:
        badgeIcon = CupertinoIcons.reply;
        categoryLabel = 'Chat Umum';
        break;
      case UnifiedNotifType.birthday:
        badgeIcon = Icons.cake_rounded;
        categoryLabel = 'Ulang Tahun';
        break;
    }

    final contentWidget = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onItemTap(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: item.isRead
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actor Avatar with Decorated Frame & Mini Corner Badge
              GestureDetector(
                onTap: () {
                  if (item.actorUsername != null &&
                      item.actorUsername!.isNotEmpty &&
                      item.type != UnifiedNotifType.birthday) {
                    HapticFeedback.selectionClick();
                    showUserProfileCard(
                      context,
                      username: item.actorUsername,
                    );
                  }
                },
                child: Builder(
                  builder: (context) {
                    final decor = UserDecorResolver.instance.get(item.actorUsername);
                    final rawAvatar = (item.actorAvatar != null && item.actorAvatar!.isNotEmpty)
                        ? item.actorAvatar
                        : decor?.avatarUrl;
                    final resolvedAvatarUrl = UserModel.normalizeAvatarUrl(rawAvatar);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DecoratedAvatar(
                          radius: 20,
                          avatarUrl: resolvedAvatarUrl,
                          decorationUrl: decor?.decorationUrl,
                          decorationCode: decor?.decorationCode,
                          decorationScale: decor?.decorationScale ?? 1.0,
                          offsetX: decor?.decorationOffsetX ?? 0,
                          offsetY: decor?.decorationOffsetY ?? 0,
                          fallbackName: item.actorUsername?.isNotEmpty == true
                              ? item.actorUsername!
                              : (item.type == UnifiedNotifType.birthday ? 'Moko' : 'User'),
                          borderColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderWidth: 0.5,
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white : Colors.black,
                              border: Border.all(
                                color: isDark ? const Color(0xFF111113) : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              badgeIcon,
                              size: 8,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Notification Content Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category Tag, Subtitle Context & Relative Timestamp
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          AppDateUtils.formatTimeAgo(item.rawCreatedAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Actor Name & Action Title
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(
                            text: item.actorUsername ?? 'Seseorang',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (item.isActorVerified)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 3, right: 3),
                                child: Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  size: 12,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          TextSpan(
                            text: ' ${item.title}',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Preview Text Bubble (if available)
                    if (item.previewText != null && item.previewText!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(
                              color: isDark ? Colors.white30 : Colors.black26,
                              width: 2.2,
                            ),
                          ),
                        ),
                        child: Text(
                          item.previewText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            height: 1.25,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Unread Dot Indicator
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white : Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Swipe-to-delete for comment notifications
    if (item.isComment) {
      final commentNotif = item.originalObject as CommentNotificationModel;
      return Dismissible(
        key: Key('unified_notif_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.black12,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            CupertinoIcons.trash,
            color: isDark ? Colors.white : Colors.black,
            size: 18,
          ),
        ),
        onDismissed: (_) => _deleteCommentNotif(commentNotif),
        child: contentWidget,
      );
    }

    return contentWidget;
  }
}
