/// MyAnimeList Models
class MalUser {
  final int id;
  final String name;
  final String? picture;
  final MalUserStats? stats;

  const MalUser({
    required this.id,
    required this.name,
    this.picture,
    this.stats,
  });

  factory MalUser.fromJson(Map<String, dynamic> json) {
    return MalUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      picture: json['picture']?.toString() ??
          (json['images']?['jpg']?['image_url']?.toString()),
      stats: json['anime_statistics'] != null
          ? MalUserStats.fromJson(
              Map<String, dynamic>.from(json['anime_statistics'] as Map),
            )
          : (json['statistics']?['anime'] != null
              ? MalUserStats.fromJson(
                  Map<String, dynamic>.from(json['statistics']['anime'] as Map),
                )
              : null),
    );
  }
}

class MalUserStats {
  final num daysWatched;
  final num meanScore;
  final int watching;
  final int completed;
  final int onHold;
  final int dropped;
  final int planToWatch;
  final int totalEntries;
  final int episodesWatched;

  const MalUserStats({
    this.daysWatched = 0,
    this.meanScore = 0,
    this.watching = 0,
    this.completed = 0,
    this.onHold = 0,
    this.dropped = 0,
    this.planToWatch = 0,
    this.totalEntries = 0,
    this.episodesWatched = 0,
  });

  factory MalUserStats.fromJson(Map<String, dynamic> json) {
    return MalUserStats(
      daysWatched: (json['num_days_watched'] ?? json['days_watched']) as num? ?? 0,
      meanScore: (json['mean_score']) as num? ?? 0,
      watching: (json['num_items_watching'] ?? json['watching']) as int? ?? 0,
      completed: (json['num_items_completed'] ?? json['completed']) as int? ?? 0,
      onHold: (json['num_items_on_hold'] ?? json['on_hold']) as int? ?? 0,
      dropped: (json['num_items_dropped'] ?? json['dropped']) as int? ?? 0,
      planToWatch: (json['num_items_plan_to_watch'] ?? json['plan_to_watch']) as int? ?? 0,
      totalEntries: (json['num_items'] ?? json['total_entries']) as int? ?? 0,
      episodesWatched: (json['num_episodes'] ?? json['episodes_watched']) as int? ?? 0,
    );
  }
}

/// Status dari MyAnimeList untuk item yang ada di daftar pengguna
class MalMediaListStatus {
  final String status;
  final int score;
  final int numEpisodesWatched;
  final int numChaptersRead;
  final String? updatedAt;
  final List<String> tags;
  final String? comments;

  const MalMediaListStatus({
    required this.status,
    this.score = 0,
    this.numEpisodesWatched = 0,
    this.numChaptersRead = 0,
    this.updatedAt,
    this.tags = const [],
    this.comments,
  });

  factory MalMediaListStatus.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().isNotEmpty) tags.add(t.toString());
      }
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return MalMediaListStatus(
      status: json['status']?.toString() ?? 'watching',
      score: (json['score'] as num?)?.toInt() ?? 0,
      numEpisodesWatched: (json['num_episodes_watched'] ?? json['episodes_watched'] as num?)?.toInt() ?? 0,
      numChaptersRead: (json['num_chapters_read'] ?? json['chapters_read'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at']?.toString(),
      tags: tags,
      comments: json['comments']?.toString(),
    );
  }

  String get localizedStatus {
    switch (status) {
      case 'watching':
        return 'Sedang Ditonton';
      case 'reading':
        return 'Sedang Dibaca';
      case 'completed':
        return 'Selesai';
      case 'on_hold':
        return 'Ditunda';
      case 'dropped':
        return 'Dibatalkan';
      case 'plan_to_watch':
        return 'Rencana Tonton';
      case 'plan_to_read':
        return 'Rencana Baca';
      default:
        return status;
    }
  }
}

/// Anime Item representation from MyAnimeList
class MalAnimeItem {
  final int id;
  final String title;
  final String? mainPicture;
  final int? numEpisodes;
  final double? meanScore;
  final String? status;
  final String? synopsis;
  final List<String> alternativeTitles;
  final MalMediaListStatus? myListStatus;

  const MalAnimeItem({
    required this.id,
    required this.title,
    this.mainPicture,
    this.numEpisodes,
    this.meanScore,
    this.status,
    this.synopsis,
    this.alternativeTitles = const [],
    this.myListStatus,
  });

  factory MalAnimeItem.fromJson(Map<String, dynamic> json) {
    final titles = <String>[];
    if (json['alternative_titles'] is Map) {
      final alt = json['alternative_titles'] as Map;
      if (alt['en'] != null && alt['en'].toString().isNotEmpty) titles.add(alt['en'].toString());
      if (alt['ja'] != null && alt['ja'].toString().isNotEmpty) titles.add(alt['ja'].toString());
      if (alt['synonyms'] is List) {
        for (final s in alt['synonyms']) {
          if (s != null && s.toString().isNotEmpty) titles.add(s.toString());
        }
      }
    } else if (json['titles'] is List) {
      for (final t in json['titles']) {
        if (t is Map && t['title'] != null) titles.add(t['title'].toString());
      }
    }

    String? pic;
    if (json['main_picture'] is Map) {
      pic = json['main_picture']['medium']?.toString() ?? json['main_picture']['large']?.toString();
    } else if (json['images']?['jpg'] is Map) {
      pic = json['images']['jpg']['large_image_url']?.toString() ?? json['images']['jpg']['image_url']?.toString();
    }

    final mean = (json['mean'] ?? json['score']) as num?;

    MalMediaListStatus? listStatus;
    if (json['my_list_status'] is Map) {
      listStatus = MalMediaListStatus.fromJson(Map<String, dynamic>.from(json['my_list_status'] as Map));
    }

    return MalAnimeItem(
      id: (json['id'] ?? json['mal_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      mainPicture: pic,
      numEpisodes: (json['num_episodes'] ?? json['episodes'] as num?)?.toInt(),
      meanScore: mean?.toDouble(),
      status: json['status']?.toString(),
      synopsis: json['synopsis']?.toString(),
      alternativeTitles: titles,
      myListStatus: listStatus,
    );
  }
}

/// User's Entry on their MyAnimeList Watchlist
class MalAnimeListEntry {
  final MalAnimeItem anime;
  final String status; // watching, completed, on_hold, dropped, plan_to_watch
  final int score; // 0 - 10
  final int numWatchedEpisodes;
  final String? updatedAt;
  final bool isAvailableLocally; // Matched with Animeverse streaming server
  final List<String> tags;
  final String? comments;

  const MalAnimeListEntry({
    required this.anime,
    required this.status,
    required this.score,
    required this.numWatchedEpisodes,
    this.updatedAt,
    this.isAvailableLocally = false,
    this.tags = const [],
    this.comments,
  });

  /// Ekstrak ID Anime server Animeverse yang tersimpan di Cloud MyAnimeList (via tags / comments)
  String? get customMappedId {
    for (final t in tags) {
      final clean = t.trim();
      final l = clean.toLowerCase();
      if (l.startsWith('moko_anime:')) {
        return clean.substring('moko_anime:'.length).trim();
      }
      if (l.startsWith('moko:')) {
        return clean.substring('moko:'.length).trim();
      }
    }
    if (comments != null && comments!.isNotEmpty) {
      for (final line in comments!.split('\n')) {
        final clean = line.trim();
        final l = clean.toLowerCase();
        if (l.startsWith('moko_anime:')) {
          return clean.substring('moko_anime:'.length).trim();
        }
        if (l.startsWith('moko:')) {
          return clean.substring('moko:'.length).trim();
        }
      }
    }
    return null;
  }

  MalAnimeListEntry copyWith({
    bool? isAvailableLocally,
    String? status,
    int? score,
    int? numWatchedEpisodes,
    List<String>? tags,
    String? comments,
  }) {
    return MalAnimeListEntry(
      anime: anime,
      status: status ?? this.status,
      score: score ?? this.score,
      numWatchedEpisodes: numWatchedEpisodes ?? this.numWatchedEpisodes,
      updatedAt: updatedAt,
      isAvailableLocally: isAvailableLocally ?? this.isAvailableLocally,
      tags: tags ?? this.tags,
      comments: comments ?? this.comments,
    );
  }

  factory MalAnimeListEntry.fromMalJson(Map<String, dynamic> nodeJson, Map<String, dynamic>? listStatusJson) {
    final anime = MalAnimeItem.fromJson(nodeJson);
    final status = listStatusJson?['status']?.toString() ?? 'plan_to_watch';
    final score = (listStatusJson?['score'] as num?)?.toInt() ?? 0;
    final watched = (listStatusJson?['num_episodes_watched'] as num?)?.toInt() ?? 0;
    final updated = listStatusJson?['updated_at']?.toString();

    final rawTags = listStatusJson?['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().isNotEmpty) tags.add(t.toString());
      }
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return MalAnimeListEntry(
      anime: anime,
      status: status,
      score: score,
      numWatchedEpisodes: watched,
      updatedAt: updated,
      tags: tags,
      comments: listStatusJson?['comments']?.toString(),
    );
  }

  factory MalAnimeListEntry.fromJikanJson(Map<String, dynamic> json) {
    final entry = json['entry'] is Map ? Map<String, dynamic>.from(json['entry'] as Map) : json;
    final anime = MalAnimeItem.fromJson(entry);
    final score = (json['score'] as num?)?.toInt() ?? 0;
    final watched = (json['episodes_watched'] as num?)?.toInt() ?? 0;

    // Jikan status mapping: 1: Watching, 2: Completed, 3: On Hold, 4: Dropped, 6: Plan to watch
    String status = 'watching';
    final rawStatus = json['status']?.toString().toLowerCase();
    if (rawStatus == '1' || rawStatus == 'watching') {
      status = 'watching';
    } else if (rawStatus == '2' || rawStatus == 'completed') {
      status = 'completed';
    } else if (rawStatus == '3' || rawStatus == 'on_hold' || rawStatus == 'onhold') {
      status = 'on_hold';
    } else if (rawStatus == '4' || rawStatus == 'dropped') {
      status = 'dropped';
    } else if (rawStatus == '6' || rawStatus == 'plan_to_watch' || rawStatus == 'plantowatch') {
      status = 'plan_to_watch';
    }

    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().isNotEmpty) tags.add(t.toString());
      }
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return MalAnimeListEntry(
      anime: anime,
      status: status,
      score: score,
      numWatchedEpisodes: watched,
      updatedAt: json['updated_at']?.toString(),
      tags: tags,
      comments: json['comments']?.toString(),
    );
  }

  String get localizedStatus {
    switch (status) {
      case 'watching':
        return 'Sedang Ditonton';
      case 'completed':
        return 'Selesai';
      case 'on_hold':
        return 'Ditunda';
      case 'dropped':
        return 'Dibatalkan';
      case 'plan_to_watch':
      default:
        return 'Rencana Nonton';
    }
  }
}

/// Manga Item representation from MyAnimeList
class MalMangaItem {
  final int id;
  final String title;
  final String? mainPicture;
  final int? numChapters;
  final int? numVolumes;
  final double? meanScore;
  final String? status;
  final String? synopsis;
  final List<String> alternativeTitles;
  final MalMediaListStatus? myListStatus;

  const MalMangaItem({
    required this.id,
    required this.title,
    this.mainPicture,
    this.numChapters,
    this.numVolumes,
    this.meanScore,
    this.status,
    this.synopsis,
    this.alternativeTitles = const [],
    this.myListStatus,
  });

  factory MalMangaItem.fromJson(Map<String, dynamic> json) {
    final titles = <String>[];
    if (json['alternative_titles'] is Map) {
      final alt = json['alternative_titles'] as Map;
      if (alt['en'] != null && alt['en'].toString().isNotEmpty) titles.add(alt['en'].toString());
      if (alt['ja'] != null && alt['ja'].toString().isNotEmpty) titles.add(alt['ja'].toString());
      if (alt['synonyms'] is List) {
        for (final s in alt['synonyms']) {
          if (s != null && s.toString().isNotEmpty) titles.add(s.toString());
        }
      }
    } else if (json['titles'] is List) {
      for (final t in json['titles']) {
        if (t is Map && t['title'] != null) titles.add(t['title'].toString());
      }
    }

    String? pic;
    if (json['main_picture'] is Map) {
      pic = json['main_picture']['medium']?.toString() ?? json['main_picture']['large']?.toString();
    } else if (json['images']?['jpg'] is Map) {
      pic = json['images']['jpg']['large_image_url']?.toString() ?? json['images']['jpg']['image_url']?.toString();
    }

    final mean = (json['mean'] ?? json['score']) as num?;

    MalMediaListStatus? listStatus;
    if (json['my_list_status'] is Map) {
      listStatus = MalMediaListStatus.fromJson(Map<String, dynamic>.from(json['my_list_status'] as Map));
    }

    return MalMangaItem(
      id: (json['id'] ?? json['mal_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      mainPicture: pic,
      numChapters: (json['num_chapters'] ?? json['chapters'] as num?)?.toInt(),
      numVolumes: (json['num_volumes'] ?? json['volumes'] as num?)?.toInt(),
      meanScore: mean?.toDouble(),
      status: json['status']?.toString(),
      synopsis: json['synopsis']?.toString(),
      alternativeTitles: titles,
      myListStatus: listStatus,
    );
  }
}

/// User's Entry on their MyAnimeList Manga Watchlist
class MalMangaListEntry {
  final MalMangaItem manga;
  final String status; // reading, completed, on_hold, dropped, plan_to_read
  final int score; // 0 - 10
  final int numChaptersRead;
  final int numVolumesRead;
  final String? updatedAt;
  final bool isAvailableLocally;
  final List<String> tags;
  final String? comments;

  const MalMangaListEntry({
    required this.manga,
    required this.status,
    required this.score,
    required this.numChaptersRead,
    this.numVolumesRead = 0,
    this.updatedAt,
    this.isAvailableLocally = false,
    this.tags = const [],
    this.comments,
  });

  /// Ekstrak slug komik server Animeverse yang tersimpan di Cloud MyAnimeList (via tags / comments)
  String? get customMappedSlug {
    for (final t in tags) {
      final clean = t.trim();
      final l = clean.toLowerCase();
      if (l.startsWith('moko_manga:')) {
        return clean.substring('moko_manga:'.length).trim();
      }
      if (l.startsWith('moko_comic:')) {
        return clean.substring('moko_comic:'.length).trim();
      }
    }
    if (comments != null && comments!.isNotEmpty) {
      for (final line in comments!.split('\n')) {
        final clean = line.trim();
        final l = clean.toLowerCase();
        if (l.startsWith('moko_manga:')) {
          return clean.substring('moko_manga:'.length).trim();
        }
        if (l.startsWith('moko_comic:')) {
          return clean.substring('moko_comic:'.length).trim();
        }
      }
    }
    return null;
  }

  MalMangaListEntry copyWith({
    bool? isAvailableLocally,
    String? status,
    int? score,
    int? numChaptersRead,
    int? numVolumesRead,
    List<String>? tags,
    String? comments,
  }) {
    return MalMangaListEntry(
      manga: manga,
      status: status ?? this.status,
      score: score ?? this.score,
      numChaptersRead: numChaptersRead ?? this.numChaptersRead,
      numVolumesRead: numVolumesRead ?? this.numVolumesRead,
      updatedAt: updatedAt,
      isAvailableLocally: isAvailableLocally ?? this.isAvailableLocally,
      tags: tags ?? this.tags,
      comments: comments ?? this.comments,
    );
  }

  factory MalMangaListEntry.fromMalJson(Map<String, dynamic> nodeJson, Map<String, dynamic>? listStatusJson) {
    final manga = MalMangaItem.fromJson(nodeJson);
    final status = listStatusJson?['status']?.toString() ?? 'plan_to_read';
    final score = (listStatusJson?['score'] as num?)?.toInt() ?? 0;
    final chapters = (listStatusJson?['num_chapters_read'] as num?)?.toInt() ?? 0;
    final volumes = (listStatusJson?['num_volumes_read'] as num?)?.toInt() ?? 0;
    final updated = listStatusJson?['updated_at']?.toString();

    final rawTags = listStatusJson?['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().isNotEmpty) tags.add(t.toString());
      }
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return MalMangaListEntry(
      manga: manga,
      status: status,
      score: score,
      numChaptersRead: chapters,
      numVolumesRead: volumes,
      updatedAt: updated,
      tags: tags,
      comments: listStatusJson?['comments']?.toString(),
    );
  }

  factory MalMangaListEntry.fromJikanJson(Map<String, dynamic> json) {
    final entry = json['entry'] is Map ? Map<String, dynamic>.from(json['entry'] as Map) : json;
    final manga = MalMangaItem.fromJson(entry);
    final score = (json['score'] as num?)?.toInt() ?? 0;
    final chapters = (json['chapters_read'] as num?)?.toInt() ?? 0;
    final volumes = (json['volumes_read'] as num?)?.toInt() ?? 0;

    String status = 'reading';
    final rawStatus = json['status']?.toString().toLowerCase();
    if (rawStatus == '1' || rawStatus == 'reading') {
      status = 'reading';
    } else if (rawStatus == '2' || rawStatus == 'completed') {
      status = 'completed';
    } else if (rawStatus == '3' || rawStatus == 'on_hold' || rawStatus == 'onhold') {
      status = 'on_hold';
    } else if (rawStatus == '4' || rawStatus == 'dropped') {
      status = 'dropped';
    } else if (rawStatus == '6' || rawStatus == 'plan_to_read' || rawStatus == 'plantoread') {
      status = 'plan_to_read';
    }

    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().isNotEmpty) tags.add(t.toString());
      }
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return MalMangaListEntry(
      manga: manga,
      status: status,
      score: score,
      numChaptersRead: chapters,
      numVolumesRead: volumes,
      updatedAt: json['updated_at']?.toString(),
      tags: tags,
      comments: json['comments']?.toString(),
    );
  }

  String get localizedStatus {
    switch (status) {
      case 'reading':
        return 'Sedang Dibaca';
      case 'completed':
        return 'Selesai';
      case 'on_hold':
        return 'Ditunda';
      case 'dropped':
        return 'Dibatalkan';
      case 'plan_to_read':
      default:
        return 'Rencana Baca';
    }
  }
}
