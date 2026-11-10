library;

/// Models for YLnime extended features:
/// - Continue Watching (Lanjut Nonton) with real progress %
/// - Hyper (Top 20 Anime TerHype, Champion #1, & Hype Discussions)
/// - Polling (Duel Karakter & Leaderboard)

import './anime_model.dart';

class ContinueWatchingItem {
  final String title;
  final String? cover;
  final String? episode;
  final String? url;
  final double progress; // percentage 0 - 100
  final int currentTime;
  final String? animeId;
  final String? episodeId;
  final String? episodeUrl;

  const ContinueWatchingItem({
    required this.title,
    this.cover,
    this.episode,
    this.url,
    this.progress = 0.0,
    this.currentTime = 0,
    this.animeId,
    this.episodeId,
    this.episodeUrl,
  });

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    double prog = 0.0;
    if (json['progress'] is num) {
      prog = (json['progress'] as num).toDouble();
    } else if (json['progress_percent'] is num) {
      prog = (json['progress_percent'] as num).toDouble();
    } else if (json['progress'] != null) {
      prog = double.tryParse(json['progress'].toString()) ?? 0.0;
    }
    final curTime = AnimeHistoryModel.parseTimeInSeconds(
      json['current_time'] ??
          json['currentTime'] ??
          json['watch_duration'] ??
          json['watchDuration'] ??
          json['position'] ??
          json['position_seconds'] ??
          json['last_position'] ??
          json['last_pos'],
    );
    return ContinueWatchingItem(
      title: json['title'] ?? json['anime_title'] ?? '',
      cover: json['cover'] ?? json['thumbnail'],
      episode: json['episode'] ?? json['episode_title'],
      url: json['url'] ?? json['episode_url'],
      progress: prog.clamp(0.0, 100.0),
      currentTime: curTime,
      animeId: json['anime_id']?.toString() ?? json['series_key']?.toString(),
      episodeId: json['episode_id']?.toString() ?? json['id']?.toString(),
      episodeUrl: json['episode_url']?.toString() ?? json['url']?.toString(),
    );
  }
}

class HyperChampionModel {
  final int rank;
  final String title;
  final String? backdrop;
  final String? cover;
  final int? views;
  final String? viewsText;
  final String? url;
  final String? seriesKey;
  final String badge;

  const HyperChampionModel({
    required this.rank,
    required this.title,
    this.backdrop,
    this.cover,
    this.views,
    this.viewsText,
    this.url,
    this.seriesKey,
    this.badge = 'ANIME OF THE MONTH',
  });

  factory HyperChampionModel.fromJson(Map<String, dynamic> json) {
    return HyperChampionModel(
      rank: json['rank'] ?? 1,
      title: json['title'] ?? '',
      backdrop: json['backdrop'],
      cover: json['cover'],
      views: json['views'],
      viewsText: json['views_text'],
      url: json['url'],
      seriesKey: json['series_key'],
      badge: json['badge'] ?? 'ANIME OF THE MONTH',
    );
  }
}

class HyperRankingModel {
  final int rank;
  final String title;
  final String? cover;
  final int? views;
  final double? popularityPercent;
  final String? url;
  final String? seriesKey;

  const HyperRankingModel({
    required this.rank,
    required this.title,
    this.cover,
    this.views,
    this.popularityPercent,
    this.url,
    this.seriesKey,
  });

  factory HyperRankingModel.fromJson(Map<String, dynamic> json) {
    return HyperRankingModel(
      rank: json['rank'] ?? 0,
      title: json['title'] ?? '',
      cover: json['cover'],
      views: json['views'],
      popularityPercent: (json['popularity_percent'] is num)
          ? (json['popularity_percent'] as num).toDouble()
          : null,
      url: json['url'],
      seriesKey: json['series_key'],
    );
  }
}

class HyperDiscussionComment {
  final String username;
  final String? avatar;
  final String? time;
  final String? content;
  final int likes;

  const HyperDiscussionComment({
    required this.username,
    this.avatar,
    this.time,
    this.content,
    this.likes = 0,
  });

  factory HyperDiscussionComment.fromJson(Map<String, dynamic> json) {
    return HyperDiscussionComment(
      username: json['username'] ?? 'User',
      avatar: json['avatar'],
      time: json['time'],
      content: json['content'],
      likes: json['likes'] ?? 0,
    );
  }
}

class HyperPageData {
  final String? title;
  final String? description;
  final String period;
  final HyperChampionModel? champion;
  final List<HyperRankingModel> rankings;
  final List<HyperDiscussionComment> comments;

  const HyperPageData({
    this.title,
    this.description,
    this.period = '30 hari terakhir',
    this.champion,
    this.rankings = const [],
    this.comments = const [],
  });

  factory HyperPageData.fromJson(Map<String, dynamic> json) {
    HyperChampionModel? champ;
    if (json['champion'] is Map) {
      champ = HyperChampionModel.fromJson(Map<String, dynamic>.from(json['champion'] as Map));
    }

    final ranks = <HyperRankingModel>[];
    if (json['rankings'] is List) {
      for (final r in json['rankings'] as List) {
        if (r is Map) {
          ranks.add(HyperRankingModel.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    final comms = <HyperDiscussionComment>[];
    if (json['comments'] is List) {
      for (final c in json['comments'] as List) {
        if (c is Map) {
          comms.add(HyperDiscussionComment.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }

    return HyperPageData(
      title: json['title'],
      description: json['description'],
      period: json['period'] ?? '30 hari terakhir',
      champion: champ,
      rankings: ranks,
      comments: comms,
    );
  }
}

class PollingDuelCard {
  final String? id;
  final String? img;
  final String nama;
  final String? anime;
  final String? rekor;
  final bool isCouple;

  const PollingDuelCard({
    this.id,
    this.img,
    required this.nama,
    this.anime,
    this.rekor,
    this.isCouple = false,
  });

  factory PollingDuelCard.fromJson(Map<String, dynamic> json) {
    return PollingDuelCard(
      id: json['id']?.toString(),
      img: json['img'],
      nama: json['nama'] ?? 'Karakter',
      anime: json['anime'],
      rekor: json['rekor'],
      isCouple: json['is_couple'] ?? false,
    );
  }
}

class PollingLeaderboardRow {
  final int? rank;
  final String name;
  final String? img;
  final String? subtitle;
  final String? score;
  final String? detail;

  const PollingLeaderboardRow({
    this.rank,
    required this.name,
    this.img,
    this.subtitle,
    this.score,
    this.detail,
  });

  factory PollingLeaderboardRow.fromJson(Map<String, dynamic> json) {
    String? thumb;
    if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      final first = (json['images'] as List).first;
      if (first is Map) thumb = first['src'];
    }
    if (thumb == null || thumb.isEmpty) {
      thumb = json['img']?.toString() ??
          json['image']?.toString() ??
          json['thumb']?.toString() ??
          json['cover']?.toString();
    }
    return PollingLeaderboardRow(
      rank: json['rank'],
      name: json['name'] ?? '',
      img: thumb,
      subtitle: json['subtitle'],
      score: json['score'],
      detail: json['detail'],
    );
  }
}

class PollingPageData {
  final String kategori;
  final String? title;
  final String? pertanyaan;
  final PollingDuelCard? cardA;
  final PollingDuelCard? cardB;
  final List<PollingLeaderboardRow> leaderboard;
  final String tipe;

  const PollingPageData({
    required this.kategori,
    this.title,
    this.pertanyaan,
    this.cardA,
    this.cardB,
    this.leaderboard = const [],
    this.tipe = 'duel',
  });

  factory PollingPageData.fromJson(Map<String, dynamic> json) {
    PollingDuelCard? a;
    PollingDuelCard? b;
    if (json['duel'] is Map) {
      final duel = json['duel'] as Map;
      if (duel['card_a'] is Map) {
        a = PollingDuelCard.fromJson(Map<String, dynamic>.from(duel['card_a'] as Map));
      }
      if (duel['card_b'] is Map) {
        b = PollingDuelCard.fromJson(Map<String, dynamic>.from(duel['card_b'] as Map));
      }
    }

    final lb = <PollingLeaderboardRow>[];
    if (json['leaderboard'] is List) {
      for (final r in json['leaderboard'] as List) {
        if (r is Map) {
          lb.add(PollingLeaderboardRow.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    return PollingPageData(
      kategori: json['kategori'] ?? 'cantik',
      title: json['title'],
      pertanyaan: json['pertanyaan'],
      cardA: a,
      cardB: b,
      leaderboard: lb,
      tipe: json['tipe'] ?? 'duel',
    );
  }
}