import '../../../../shared/widgets/smooth_avatar_decoration.dart';
import '../../../auth/data/models/user_model.dart';

class LeaderboardUserModel {
  final int rankPosition;
  final int id;
  final String username;
  final String avatarUrl;
  final int xp;
  final int level;
  final String rank;
  final int streak;
  final String? avatarDecorationCode;
  final String? avatarDecorationUrl;
  final bool verifiedBadge;

  LeaderboardUserModel({
    required this.rankPosition,
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.xp,
    required this.level,
    required this.rank,
    this.streak = 0,
    this.avatarDecorationCode,
    this.avatarDecorationUrl,
    this.verifiedBadge = false,
  });

  String? get fullAvatarDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(avatarDecorationUrl, avatarDecorationCode);
  }

  factory LeaderboardUserModel.fromJson(Map<String, dynamic> json, {int? rankPositionFallback}) {
    String? decorCode = json['avatar_decoration_code']?.toString();
    String? decorUrl = json['avatar_decoration_url']?.toString();

    if (json['avatar_decoration'] is Map) {
      final dMap = json['avatar_decoration'] as Map;
      decorCode ??= dMap['code']?.toString();
      decorUrl ??= dMap['image_url']?.toString() ?? dMap['url']?.toString();
    }

    final rawAvatar = json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? '';
    final avatar = UserModel.normalizeAvatarUrl(rawAvatar) ?? '';

    return LeaderboardUserModel(
      rankPosition: (json['rank_position'] as num?)?.toInt() ?? rankPositionFallback ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? 'Pengguna',
      avatarUrl: avatar,
      xp: (json['xp'] as num?)?.toInt() ?? int.tryParse(json['xp']?.toString() ?? '') ?? 0,
      level: (json['level'] as num?)?.toInt() ?? int.tryParse(json['level']?.toString() ?? '') ?? 1,
      rank: json['rank']?.toString() ?? 'Ashigaru V',
      streak: (json['streak'] as num?)?.toInt() ?? int.tryParse(json['streak']?.toString() ?? '') ?? 0,
      avatarDecorationCode: decorCode,
      avatarDecorationUrl: decorUrl,
      verifiedBadge: json['verified_badge'] == true || json['verified_badge']?.toString() == '1',
    );
  }
}

class LeaderboardResponse {
  final String period;
  final List<LeaderboardUserModel> users;
  final LeaderboardUserModel? myRank;

  LeaderboardResponse({
    required this.period,
    required this.users,
    this.myRank,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final period = json['period']?.toString() ?? 'all';
    final rawUsers = json['users'] as List? ?? [];
    final users = <LeaderboardUserModel>[];

    for (int i = 0; i < rawUsers.length; i++) {
      if (rawUsers[i] is Map<String, dynamic>) {
        users.add(LeaderboardUserModel.fromJson(rawUsers[i] as Map<String, dynamic>, rankPositionFallback: i + 1));
      } else if (rawUsers[i] is Map) {
        users.add(LeaderboardUserModel.fromJson(Map<String, dynamic>.from(rawUsers[i] as Map), rankPositionFallback: i + 1));
      }
    }

    LeaderboardUserModel? myRank;
    if (json['my_rank'] is Map) {
      final mr = Map<String, dynamic>.from(json['my_rank'] as Map);
      myRank = LeaderboardUserModel.fromJson(mr);
    }

    return LeaderboardResponse(
      period: period,
      users: users,
      myRank: myRank,
    );
  }
}

class XpSummaryModel {
  final int xp;
  final int level;
  final String rank;
  final int streak;
  final int currentLevelXp;
  final int nextLevelXp;
  final int totalNextXp;
  final double progress;
  final bool canClaimDaily;
  final List<XpHistoryModel> history;

  XpSummaryModel({
    required this.xp,
    required this.level,
    required this.rank,
    required this.streak,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.totalNextXp,
    required this.progress,
    required this.canClaimDaily,
    required this.history,
  });

  factory XpSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawHist = json['history'] as List? ?? [];
    final hist = <XpHistoryModel>[];
    for (final item in rawHist) {
      if (item is Map) {
        hist.add(XpHistoryModel.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return XpSummaryModel(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: json['rank']?.toString() ?? 'Ashigaru V',
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      currentLevelXp: (json['current_level_xp'] as num?)?.toInt() ?? 0,
      nextLevelXp: (json['next_level_xp'] as num?)?.toInt() ?? 100,
      totalNextXp: (json['total_next_xp'] as num?)?.toInt() ?? 100,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      canClaimDaily: json['can_claim_daily'] == true,
      history: hist,
    );
  }
}

class XpHistoryModel {
  final int id;
  final int xpAmount;
  final String xpType;
  final String? description;
  final DateTime? createdAt;

  XpHistoryModel({
    required this.id,
    required this.xpAmount,
    required this.xpType,
    this.description,
    this.createdAt,
  });

  factory XpHistoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['created_at'] != null) {
      dt = DateTime.tryParse(json['created_at'].toString());
    }
    return XpHistoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      xpAmount: (json['xp_amount'] as num?)?.toInt() ?? 0,
      xpType: json['xp_type']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: dt,
    );
  }
}
