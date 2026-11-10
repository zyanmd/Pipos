import '../../../auth/data/models/user_model.dart';

enum FriendStatus {
  self,
  none,
  pendingSent,
  pendingReceived,
  friends,
}

extension FriendStatusExtension on FriendStatus {
  static FriendStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'self':
        return FriendStatus.self;
      case 'pending_sent':
        return FriendStatus.pendingSent;
      case 'pending_received':
        return FriendStatus.pendingReceived;
      case 'friends':
      case 'accepted':
        return FriendStatus.friends;
      case 'none':
      default:
        return FriendStatus.none;
    }
  }

  String get label {
    switch (this) {
      case FriendStatus.self:
        return 'Profil Anda';
      case FriendStatus.pendingSent:
        return 'Menunggu Persetujuan';
      case FriendStatus.pendingReceived:
        return 'Minta Berteman';
      case FriendStatus.friends:
        return 'Berteman';
      case FriendStatus.none:
        return 'Tambah Teman';
    }
  }
}

class FriendshipInfo {
  final FriendStatus status;
  final int? requestId;
  final String? message;
  final Map<String, dynamic>? raw;

  FriendshipInfo({
    required this.status,
    this.requestId,
    this.message,
    this.raw,
  });

  factory FriendshipInfo.fromJson(Map<String, dynamic> json) {
    return FriendshipInfo(
      status: FriendStatusExtension.fromString(json['status']?.toString()),
      requestId: json['request_id'] is int ? json['request_id'] : int.tryParse('${json['request_id']}'),
      message: json['message']?.toString(),
      raw: json,
    );
  }
}

class FriendUserItem {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? avatarDecorationUrl;
  final bool isVerified;
  final bool verifiedBadge;
  final String? bio;

  FriendUserItem({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.avatarDecorationUrl,
    this.isVerified = false,
    this.verifiedBadge = false,
    this.bio,
  });

  factory FriendUserItem.fromJson(Map<String, dynamic> json) {
    final rawAvatar = json['avatar_url'] ?? json['avatar'];
    final bool hasBadge = (json['verified_badge'] is int)
        ? (json['verified_badge'] as int) == 1
        : (json['verified_badge'] == true ||
            json['verified_badge']?.toString() == '1' ||
            json['verified_badge']?.toString().toLowerCase() == 'true');

    final bool isEmailVerified = (json['is_verified'] is int)
        ? (json['is_verified'] as int) == 1
        : (json['is_verified'] == true ||
            json['is_verified']?.toString() == '1' ||
            json['is_verified']?.toString().toLowerCase() == 'true');

    return FriendUserItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString(),
      avatarUrl: UserModel.normalizeAvatarUrl(rawAvatar) ?? rawAvatar?.toString(),
      avatarDecorationUrl: json['avatar_decoration_url']?.toString(),
      isVerified: isEmailVerified,
      verifiedBadge: hasBadge,
      bio: json['bio']?.toString(),
    );
  }

  /// Parses a friendship database row (which may contain `sender` and `receiver` objects).
  /// Resolves the friend relative to [targetUsername] or [currentUserId].
  static FriendUserItem? fromFriendshipRow(
    Map<String, dynamic> row, {
    String? targetUsername,
    int? currentUserId,
  }) {
    if (row['other_user'] is Map) {
      return FriendUserItem.fromJson(Map<String, dynamic>.from(row['other_user']));
    }
    if (row['friend'] is Map) {
      return FriendUserItem.fromJson(Map<String, dynamic>.from(row['friend']));
    }

    final senderRaw = row['sender'];
    final receiverRaw = row['receiver'];

    if (senderRaw is Map && receiverRaw is Map) {
      final sender = Map<String, dynamic>.from(senderRaw);
      final receiver = Map<String, dynamic>.from(receiverRaw);

      final senderUsername = sender['username']?.toString().toLowerCase() ?? '';
      final receiverUsername = receiver['username']?.toString().toLowerCase() ?? '';
      final senderId = (row['sender_id'] as num?)?.toInt() ?? sender['id'];
      final receiverId = (row['receiver_id'] as num?)?.toInt() ?? receiver['id'];

      final targetClean = targetUsername?.trim().toLowerCase();

      // If target user is specified (viewing another user's profile friend list)
      if (targetClean != null && targetClean.isNotEmpty) {
        if (senderUsername == targetClean) {
          return FriendUserItem.fromJson(receiver);
        }
        if (receiverUsername == targetClean) {
          return FriendUserItem.fromJson(sender);
        }
        // Neither party is the target user; do not leak current user's friends
        return null;
      }

      // If viewing logged-in user's own friends
      if (currentUserId != null) {
        if (senderId == currentUserId) return FriendUserItem.fromJson(receiver);
        if (receiverId == currentUserId) return FriendUserItem.fromJson(sender);
      }

      // Default: if target is not specified, prefer receiver, unless receiver is current user
      if (currentUserId != null && receiverId == currentUserId) {
        return FriendUserItem.fromJson(sender);
      }
      return FriendUserItem.fromJson(receiver);
    }

    if (row['user'] is Map) {
      return FriendUserItem.fromJson(Map<String, dynamic>.from(row['user']));
    }
    if (row['username'] != null) {
      return FriendUserItem.fromJson(row);
    }
    return null;
  }
}

class FriendRequestItem {
  final int id;
  final int senderId;
  final int receiverId;
  final String status;
  final String? message;
  final bool isSender;
  final FriendUserItem? otherUser;
  final DateTime? createdAt;

  FriendRequestItem({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.message,
    this.isSender = false,
    this.otherUser,
    this.createdAt,
  });

  factory FriendRequestItem.fromJson(
    Map<String, dynamic> json, {
    String? myUsername,
    int? myUserId,
  }) {
    final senderId = (json['sender_id'] as num?)?.toInt() ?? 0;
    final receiverId = (json['receiver_id'] as num?)?.toInt() ?? 0;

    bool isSender = json['is_sender'] == true;
    if (myUserId != null && senderId > 0) {
      isSender = senderId == myUserId;
    }

    FriendUserItem? other;
    if (json['other_user'] != null && json['other_user'] is Map) {
      other = FriendUserItem.fromJson(Map<String, dynamic>.from(json['other_user']));
    } else {
      final senderMap = json['sender'] is Map ? Map<String, dynamic>.from(json['sender']) : null;
      final receiverMap = json['receiver'] is Map ? Map<String, dynamic>.from(json['receiver']) : null;

      if (senderMap != null && receiverMap != null) {
        if (myUsername != null && myUsername.isNotEmpty) {
          final sName = senderMap['username']?.toString().toLowerCase();
          if (sName == myUsername.toLowerCase()) {
            isSender = true;
            other = FriendUserItem.fromJson(receiverMap);
          } else {
            isSender = false;
            other = FriendUserItem.fromJson(senderMap);
          }
        } else if (myUserId != null) {
          if (senderId == myUserId) {
            isSender = true;
            other = FriendUserItem.fromJson(receiverMap);
          } else {
            isSender = false;
            other = FriendUserItem.fromJson(senderMap);
          }
        } else {
          other = isSender
              ? FriendUserItem.fromJson(receiverMap)
              : FriendUserItem.fromJson(senderMap);
        }
      } else if (senderMap != null) {
        other = FriendUserItem.fromJson(senderMap);
      } else if (receiverMap != null) {
        other = FriendUserItem.fromJson(receiverMap);
      }
    }

    return FriendRequestItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      senderId: senderId,
      receiverId: receiverId,
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString(),
      isSender: isSender,
      otherUser: other,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
