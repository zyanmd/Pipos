import 'package:flutter/material.dart';

/// Utility sanitasi dan normalisasi genre agar sinkron dengan backend
class GenreUtils {
  GenreUtils._();

  /// Bersihkan genre dari koma/titik/semicolon/spasi/separator berlebih.
  ///
  /// Contoh:
  ///   "comedy,"     → "comedy"
  ///   "Romance."    → "romance"
  ///   " Action , "  → "action"
  ///   "Sci-Fi,"     → "sci-fi"
  ///   ",Action,"    → "action"
  ///   "Comedy, "    → "comedy"
  static String? sanitizeGenre(dynamic raw) {
    if (raw == null) return null;
    var g = raw.toString().trim().toLowerCase();
    if (g.isEmpty) return null;

    final edgePunct = RegExp(r'^[.,;:!?\-–—\s]+|[.,;:!?\-–—\s]+$');
    for (int i = 0; i < 10; i++) {
      final old = g;
      g = g.replaceAll(edgePunct, '').trim();
      if (old == g) break;
    }

    if (g.contains(',')) {
      g = g.split(',').first.trim();
    }

    g = g.replaceAll('.', '-');
    g = g.replaceAll('_', '-').replaceAll(' ', '-');

    while (g.contains('--')) {
      g = g.replaceAll('--', '-');
    }

    g = g.replaceAll(edgePunct, '').trim();
    return g.isNotEmpty ? g : null;
  }

  /// Format genre label untuk display yang bersih
  static String formatGenreLabel(String? genre, [String? fallbackLabel]) {
    if (fallbackLabel != null && fallbackLabel.trim().isNotEmpty) {
      final cleanFallback = fallbackLabel.replaceAll(RegExp(r'^[.,;:!?\-–—\s]+|[.,;:!?\-–—\s]+$'), '').trim();
      if (cleanFallback.isNotEmpty) return cleanFallback;
    }
    final clean = sanitizeGenre(genre);
    if (clean == null || clean.isEmpty) return '';
    return clean.split('-').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join('-');
  }
}

/// Progress menuju level/tier berikutnya
class GenreRoleProgress {
  final String? nextTier;
  final String? nextName;
  final int nextMinCount;
  final int current;
  final int needed;
  final double percent;

  const GenreRoleProgress({
    this.nextTier,
    this.nextName,
    this.nextMinCount = 0,
    this.current = 0,
    this.needed = 0,
    this.percent = 0.0,
  });

  factory GenreRoleProgress.fromJson(Map<String, dynamic> json) {
    return GenreRoleProgress(
      nextTier: json['next_tier']?.toString(),
      nextName: json['next_name']?.toString(),
      nextMinCount: (json['next_min_count'] as num?)?.toInt() ?? 0,
      current: (json['current'] as num?)?.toInt() ?? 0,
      needed: (json['needed'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Satu role genre yang telah dibuka oleh user
class GenreRoleItem {
  final int? id;
  final int userId;
  final String genre;
  final String genreLabel;
  final String emoji;
  final String colorHex;
  final String roleName;
  final String roleKey;
  final String roleTier; // 'bronze', 'silver', 'gold', 'platinum'
  final int tierWeight;
  final int watchCount;
  final DateTime? unlockedAt;
  final bool isPrimary;
  final bool isPinned;
  final GenreRoleProgress? progress;

  const GenreRoleItem({
    this.id,
    this.userId = 0,
    required this.genre,
    required this.genreLabel,
    required this.emoji,
    required this.colorHex,
    required this.roleName,
    required this.roleKey,
    required this.roleTier,
    this.tierWeight = 0,
    this.watchCount = 0,
    this.unlockedAt,
    this.isPrimary = false,
    this.isPinned = false,
    this.progress,
  });

  /// Hitung bobot tier (1 untuk wood hingga 6 untuk platinum)
  static int tierWeightFor(String? tier) {
    switch (tier?.toLowerCase().trim()) {
      case 'platinum':
        return 6;
      case 'gold':
        return 5;
      case 'silver':
        return 4;
      case 'bronze':
        return 3;
      case 'stone':
        return 2;
      case 'wood':
        return 1;
      default:
        return 0;
    }
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  Color get tierColor {
    switch (roleTier.toLowerCase().trim()) {
      case 'platinum':
        return const Color(0xFF00E5FF);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'stone':
        return const Color(0xFF78716C);
      case 'wood':
        return const Color(0xFF8B5A2B);
      default:
        return const Color(0xFF8B5A2B);
    }
  }

  String get tierBadgeLabel {
    switch (roleTier.toLowerCase().trim()) {
      case 'platinum':
        return 'PLATINUM';
      case 'gold':
        return 'GOLD';
      case 'silver':
        return 'SILVER';
      case 'bronze':
        return 'BRONZE';
      case 'stone':
        return 'STONE';
      case 'wood':
        return 'WOOD';
      default:
        return roleTier.toUpperCase();
    }
  }

  GenreRoleItem copyWith({
    int? id,
    int? userId,
    String? genre,
    String? genreLabel,
    String? emoji,
    String? colorHex,
    String? roleName,
    String? roleKey,
    String? roleTier,
    int? tierWeight,
    int? watchCount,
    DateTime? unlockedAt,
    bool? isPrimary,
    bool? isPinned,
    GenreRoleProgress? progress,
  }) {
    return GenreRoleItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      genre: genre ?? this.genre,
      genreLabel: genreLabel ?? this.genreLabel,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      roleName: roleName ?? this.roleName,
      roleKey: roleKey ?? this.roleKey,
      roleTier: roleTier ?? this.roleTier,
      tierWeight: tierWeight ?? this.tierWeight,
      watchCount: watchCount ?? this.watchCount,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isPrimary: isPrimary ?? this.isPrimary,
      isPinned: isPinned ?? this.isPinned,
      progress: progress ?? this.progress,
    );
  }

  factory GenreRoleItem.fromJson(Map<String, dynamic> json) {
    final cleanGenre = GenreUtils.sanitizeGenre(json['genre']) ?? json['genre']?.toString() ?? '';
    final label = GenreUtils.formatGenreLabel(cleanGenre, json['genre_label']?.toString());
    final rawTier = json['role_tier']?.toString() ?? 'wood';
    final rawWeight = (json['tier_weight'] as num?)?.toInt() ?? 0;
    final pinned = json['is_pinned'] == true || json['is_equipped'] == true;
    final primary = json['is_primary'] == true || pinned;

    var roleName = json['role_name']?.toString() ?? '';
    var emoji = json['emoji']?.toString() ?? '🎬';
    var colorHex = (json['color'] ?? json['color_hex'])?.toString() ?? '#888888';

    if ((roleName.isEmpty || emoji == '🎬') && cleanGenre.isNotEmpty) {
      try {
        final cat = defaultGenreRoleCatalog.firstWhere(
          (c) => c.genre.toLowerCase() == cleanGenre.toLowerCase(),
          orElse: () => const GenreRoleCatalogItem(genre: '', label: '', emoji: '🎬', colorHex: '#888888'),
        );
        if (cat.genre.isNotEmpty) {
          if (emoji == '🎬' && cat.emoji.isNotEmpty) emoji = cat.emoji;
          if (colorHex == '#888888' && cat.colorHex.isNotEmpty) colorHex = cat.colorHex;
          if (roleName.isEmpty && cat.tiers.isNotEmpty) {
            final tItem = cat.tiers.firstWhere(
              (t) => t.tier.toLowerCase() == rawTier.toLowerCase(),
              orElse: () => cat.tiers.last,
            );
            if (tItem.name.isNotEmpty) roleName = tItem.name;
          }
        }
      } catch (_) {}
    }

    return GenreRoleItem(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      genre: cleanGenre,
      genreLabel: label.isNotEmpty ? label : cleanGenre,
      emoji: emoji,
      colorHex: colorHex,
      roleName: roleName.isNotEmpty ? roleName : '$label Fan',
      roleKey: json['role_key']?.toString() ?? '',
      roleTier: rawTier,
      tierWeight: rawWeight > 0 ? rawWeight : tierWeightFor(rawTier),
      watchCount: (json['watch_count'] as num?)?.toInt() ?? 0,
      unlockedAt: json['unlocked_at'] != null ? DateTime.tryParse(json['unlocked_at'].toString()) : null,
      isPrimary: primary,
      isPinned: pinned,
      progress: json['progress'] is Map ? GenreRoleProgress.fromJson(Map<String, dynamic>.from(json['progress'])) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'genre': genre,
        'genre_label': genreLabel,
        'emoji': emoji,
        'color': colorHex,
        'color_hex': colorHex,
        'role_name': roleName,
        'role_key': roleKey,
        'role_tier': roleTier,
        'tier_weight': tierWeight,
        'watch_count': watchCount,
        'is_pinned': isPinned,
        'is_primary': isPrimary,
        if (unlockedAt != null) 'unlocked_at': unlockedAt!.toIso8601String(),
        if (progress != null)
          'progress': {
            'next_tier': progress!.nextTier,
            'next_name': progress!.nextName,
            'next_min_count': progress!.nextMinCount,
            'current': progress!.current,
            'needed': progress!.needed,
            'percent': progress!.percent,
          },
      };
}

/// Genre yang paling sering ditonton
class TopGenre {
  final String genre;
  final String label;
  final String emoji;
  final String colorHex;
  final int watchCount;

  const TopGenre({
    required this.genre,
    required this.label,
    required this.emoji,
    required this.colorHex,
    this.watchCount = 0,
  });

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  factory TopGenre.fromJson(Map<String, dynamic> json) {
    final cleanGenre = GenreUtils.sanitizeGenre(json['genre']) ?? json['genre']?.toString() ?? '';
    final label = GenreUtils.formatGenreLabel(cleanGenre, json['label']?.toString() ?? json['genre_label']?.toString());
    return TopGenre(
      genre: cleanGenre,
      label: label.isNotEmpty ? label : cleanGenre,
      emoji: json['emoji']?.toString() ?? '🎬',
      colorHex: (json['color'] ?? json['color_hex'])?.toString() ?? '#888888',
      watchCount: (json['watch_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Statistik tontonan per genre
class GenreStatsItem {
  final String genre;
  final String genreLabel;
  final String emoji;
  final String colorHex;
  final int watchCount;
  final int totalWatchTime;
  final double totalWatchTimeMinutes;
  final DateTime? lastWatchedAt;

  final String? formattedTime;

  const GenreStatsItem({
    required this.genre,
    required this.genreLabel,
    required this.emoji,
    required this.colorHex,
    this.watchCount = 0,
    this.totalWatchTime = 0,
    this.totalWatchTimeMinutes = 0.0,
    this.lastWatchedAt,
    this.formattedTime,
  });

  String get totalWatchTimeFormatted {
    if (formattedTime != null && formattedTime!.isNotEmpty) {
      return formattedTime!;
    }
    if (totalWatchTime < 60) return '${totalWatchTime}s';
    final mins = totalWatchTime ~/ 60;
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  factory GenreStatsItem.fromJson(Map<String, dynamic> json) {
    final cleanGenre = GenreUtils.sanitizeGenre(json['genre']) ?? json['genre']?.toString() ?? '';
    final label = GenreUtils.formatGenreLabel(cleanGenre, json['genre_label']?.toString());
    return GenreStatsItem(
      genre: cleanGenre,
      genreLabel: label.isNotEmpty ? label : cleanGenre,
      emoji: json['emoji']?.toString() ?? '🎬',
      colorHex: (json['color'] ?? json['color_hex'])?.toString() ?? '#888888',
      watchCount: (json['watch_count'] as num?)?.toInt() ?? 0,
      totalWatchTime: (json['total_watch_time'] as num?)?.toInt() ?? 0,
      totalWatchTimeMinutes: (json['total_watch_time_minutes'] as num?)?.toDouble() ?? 0.0,
      lastWatchedAt: json['last_watched_at'] != null ? DateTime.tryParse(json['last_watched_at'].toString()) : null,
      formattedTime: json['total_watch_time_formatted']?.toString(),
    );
  }
}

/// Ringkasan lengkap role dan statistik genre user
class UserGenreSummary {
  final List<GenreRoleItem> roles;
  final List<GenreStatsItem> stats;
  final TopGenre? topGenre;
  final GenreRoleItem? pinnedRole;
  final int totalGenresWatched;
  final bool hasRoles;

  const UserGenreSummary({
    this.roles = const [],
    this.stats = const [],
    this.topGenre,
    this.pinnedRole,
    this.totalGenresWatched = 0,
    this.hasRoles = false,
  });

  GenreRoleItem? get primaryRole {
    if (pinnedRole != null) return pinnedRole;
    if (roles.isEmpty) return null;
    try {
      return roles.firstWhere((r) => r.isPinned || r.isPrimary);
    } catch (_) {
      // Prioritaskan role dengan bobot tier tertinggi, lalu jumlah tonton terbanyak
      final sorted = List<GenreRoleItem>.from(roles)
        ..sort((a, b) {
          final w = b.tierWeight.compareTo(a.tierWeight);
          if (w != 0) return w;
          return b.watchCount.compareTo(a.watchCount);
        });
      return sorted.first;
    }
  }

  factory UserGenreSummary.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] as List? ?? [];
    final rawStats = json['stats'] as List? ?? [];
    var parsedRoles = rawRoles
        .whereType<Map>()
        .map((e) => GenreRoleItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    GenreRoleItem? pinned;
    if (json['pinned_role'] is Map) {
      pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['pinned_role'])).copyWith(
        isPinned: true,
        isPrimary: true,
      );
    } else if (json['equipped_role'] is Map) {
      pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['equipped_role'])).copyWith(
        isPinned: true,
        isPrimary: true,
      );
    } else if (json['genre_role'] is Map) {
      pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['genre_role'])).copyWith(
        isPinned: true,
        isPrimary: true,
      );
    } else if (json['role_genre'] is Map) {
      pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['role_genre'])).copyWith(
        isPinned: true,
        isPrimary: true,
      );
    } else if (json['primary_role'] is Map) {
      pinned = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['primary_role'])).copyWith(
        isPinned: true,
        isPrimary: true,
      );
    } else {
      // Check if any item in parsedRoles is pinned
      for (final r in parsedRoles) {
        if (r.isPinned) {
          pinned = r;
          break;
        }
      }
    }

    if (pinned != null) {
      // Ensure the pinned role in parsedRoles has isPinned=true
      parsedRoles = parsedRoles.map((r) {
        final matches = (r.id != null && pinned?.id != null && r.id == pinned?.id) ||
            (r.genre.toLowerCase() == pinned?.genre.toLowerCase()) ||
            (r.roleKey.toLowerCase() == pinned?.roleKey.toLowerCase());
        return matches ? r.copyWith(isPinned: true, isPrimary: true) : r;
      }).toList();

      if (!parsedRoles.any((r) => r.genre == pinned?.genre)) {
        parsedRoles.insert(0, pinned);
      }
    }

    if (json['primary_role'] is Map && pinned == null) {
      final pRole = GenreRoleItem.fromJson(Map<String, dynamic>.from(json['primary_role']));
      if (!parsedRoles.any((r) => r.genre == pRole.genre)) {
        parsedRoles.insert(0, pRole);
      }
    }

    return UserGenreSummary(
      roles: parsedRoles,
      stats: rawStats
          .whereType<Map>()
          .map((e) => GenreStatsItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topGenre: json['top_genre'] is Map ? TopGenre.fromJson(Map<String, dynamic>.from(json['top_genre'])) : null,
      pinnedRole: pinned,
      totalGenresWatched: (json['total_genres_watched'] as num?)?.toInt() ?? 0,
      hasRoles: json['has_roles'] == true || parsedRoles.isNotEmpty,
    );
  }

  factory UserGenreSummary.empty() => const UserGenreSummary();
}

// Typedef aliases untuk fleksibilitas integrasi
typedef GenreRole = GenreRoleItem;
typedef RoleProgress = GenreRoleProgress;
typedef GenreSummary = UserGenreSummary;
typedef GenreStat = GenreStatsItem;

/// Tier dalam katalog role genre
class GenreRoleCatalogTier {
  final String tier;
  final int minCount;
  final String key;
  final String name;

  const GenreRoleCatalogTier({
    required this.tier,
    required this.minCount,
    required this.key,
    required this.name,
  });

  int get tierWeight => GenreRoleItem.tierWeightFor(tier);

  Color get tierColor {
    switch (tier.toLowerCase().trim()) {
      case 'platinum':
        return const Color(0xFF00E5FF);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'stone':
        return const Color(0xFF78716C);
      case 'wood':
        return const Color(0xFF8B5A2B);
      default:
        return const Color(0xFF8B5A2B);
    }
  }

  String get tierBadgeLabel {
    switch (tier.toLowerCase().trim()) {
      case 'platinum':
        return 'PLATINUM';
      case 'gold':
        return 'GOLD';
      case 'silver':
        return 'SILVER';
      case 'bronze':
        return 'BRONZE';
      case 'stone':
        return 'STONE';
      case 'wood':
        return 'WOOD';
      default:
        return tier.toUpperCase();
    }
  }

  factory GenreRoleCatalogTier.fromJson(Map<String, dynamic> json) {
    return GenreRoleCatalogTier(
      tier: json['tier']?.toString() ?? 'wood',
      minCount: (json['min_count'] as num?)?.toInt() ?? 0,
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Item katalog genre dengan seluruh level tier
class GenreRoleCatalogItem {
  final String genre;
  final String label;
  final String emoji;
  final String colorHex;
  final List<GenreRoleCatalogTier> tiers;

  const GenreRoleCatalogItem({
    required this.genre,
    required this.label,
    required this.emoji,
    required this.colorHex,
    this.tiers = const [],
  });

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  factory GenreRoleCatalogItem.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['tiers'] as List? ?? [];
    return GenreRoleCatalogItem(
      genre: json['genre']?.toString() ?? '',
      label: json['label']?.toString() ?? json['genre']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎬',
      colorHex: json['color']?.toString() ?? '#888888',
      tiers: rawTiers
          .whereType<Map>()
          .map((e) => GenreRoleCatalogTier.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Default fallback catalog genre role (38 genre dengan 6 tier)
final List<GenreRoleCatalogItem> defaultGenreRoleCatalog = [
  GenreRoleCatalogItem(
    genre: 'action',
    label: 'Action',
    emoji: '⚔️',
    colorHex: '#ef4444',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'action_platinum', name: '🗿 Aura Infinite'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'action_gold', name: '🔥 Crashout King'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'action_silver', name: '🥊 Hantam Kromo'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'action_bronze', name: '👀 Pengamat Tawuran'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'action_stone', name: '🪨 Batu Beraksi'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'action_wood', name: '🪵 Kayu Bergetar'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'adventure',
    label: 'Adventure',
    emoji: '🗺️',
    colorHex: '#f59e0b',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'adventure_platinum', name: '🧭 Map Hack'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'adventure_gold', name: '🎒 Backpacker Ghaib'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'adventure_silver', name: '🏃 Side Quest'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'adventure_bronze', name: '🚶 Turis Nyasar'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'adventure_stone', name: '🪨 Jalan Kaki'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'adventure_wood', name: '🪵 Keluar Rumah'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'comedy',
    label: 'Comedy',
    emoji: '😂',
    colorHex: '#eab308',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'comedy_platinum', name: '💀 Brainrot Final'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'comedy_gold', name: '🤡 Shitpost CEO'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'comedy_silver', name: '😭 Real Cok'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'comedy_bronze', name: '🗿 Ketawa Batin'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'comedy_stone', name: '🪨 Senyum Tipis'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'comedy_wood', name: '🪵 Tersenyum Kaku'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'drama',
    label: 'Drama',
    emoji: '🎭',
    colorHex: '#8b5cf6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'drama_platinum', name: '🥀 It\'s Over'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'drama_gold', name: '🚬 Trauma Core'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'drama_silver', name: '🌧️ Galau Brutal'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'drama_bronze', name: '🥲 Nyesek Dikit'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'drama_stone', name: '🪨 Hmm Sedih'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'drama_wood', name: '🪵 Batuk Dikit'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'fantasy',
    label: 'Fantasy',
    emoji: '🧙',
    colorHex: '#a855f7',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'fantasy_platinum', name: '🧙 Grand Wizard'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'fantasy_gold', name: '🔮 Shadow Wizard'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'fantasy_silver', name: '✨ Puh Sepuh'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'fantasy_bronze', name: '🍄 NPC Hutan'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'fantasy_stone', name: '🪨 Batu Sihir'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'fantasy_wood', name: '🪵 Tongkat Kayu'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'horror',
    label: 'Horror',
    emoji: '👻',
    colorHex: '#dc2626',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'horror_platinum', name: '💀 Uncanny Valley'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'horror_gold', name: '🧟 Pawang Khodam'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'horror_silver', name: '😱 Jump scare Bait'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'horror_bronze', name: '🫣 Intip Selimut'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'horror_stone', name: '🪨 Merinding Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'horror_wood', name: '🪵 Nonton Pelan-Pelan'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'isekai',
    label: 'Isekai',
    emoji: '🌀',
    colorHex: '#8b5cf6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'isekai_platinum', name: '🚚 Truck Victim'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'isekai_gold', name: '👑 Cheat Engine'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'isekai_silver', name: '🌀 Pindah Server'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'isekai_bronze', name: '🪦 Reinkarnasi Gagal'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'isekai_stone', name: '🪨 Kebangun Tengah Malam'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'isekai_wood', name: '🪵 Ketiduran Sebentar'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'romance',
    label: 'Romance',
    emoji: '💕',
    colorHex: '#ec4899',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'romance_platinum', name: '💍 Certified Rizzler'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'romance_gold', name: '🥵 Down Bad'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'romance_silver', name: '🥺 Salting Brutal'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'romance_bronze', name: '🤡 Jomblo Halusinasi'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'romance_stone', name: '🪨 Suka Tapi Malu'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'romance_wood', name: '🪵 Stalking Medsos'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'sci-fi',
    label: 'Sci-Fi',
    emoji: '🚀',
    colorHex: '#06b6d4',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'scifi_platinum', name: '🤖 Cyber Psycho'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'scifi_gold', name: '🛸 Konspirasi NASA'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'scifi_silver', name: '🧬 Kloning Elite'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'scifi_bronze', name: '📡 Cari Sinyal'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'scifi_stone', name: '🪨 Nonton Robot'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'scifi_wood', name: '🪵 Liat Bintang'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'sports',
    label: 'Sports',
    emoji: '⚽',
    colorHex: '#22c55e',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'sports_platinum', name: '🔥 Egoist Sejati'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'sports_gold', name: '⚡ Gym Rat'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'sports_silver', name: '🪑 Camat (Cadangan)'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'sports_bronze', name: '🥤 Beli Es'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'sports_stone', name: '🪨 Nonton Bola'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'sports_wood', name: '🪵 Rebahan Sport'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'supernatural',
    label: 'Supernatural',
    emoji: '✨',
    colorHex: '#a78bfa',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'supernatural_platinum', name: '🧿 Dukun Skena'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'supernatural_gold', name: '👁️ Mata Ketiga'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'supernatural_silver', name: '🔮 Spill Ramalan'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'supernatural_bronze', name: '🕯️ Merinding Tipis'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'supernatural_stone', name: '🪨 Nonton Mistis'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'supernatural_wood', name: '🪵 Pura-pura Berani'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'mystery',
    label: 'Mystery',
    emoji: '🔍',
    colorHex: '#64748b',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'mystery_platinum', name: '🕵️ FBI Agent'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'mystery_gold', name: '🧐 Overthinker Pro'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'mystery_silver', name: '📱 Intel Facebook'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'mystery_bronze', name: '❓ Planga Plongo'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'mystery_stone', name: '🪨 Nebak-nebak'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'mystery_wood', name: '🪵 Hmm Menarik'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'mecha',
    label: 'Mecha',
    emoji: '🤖',
    colorHex: '#0ea5e9',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'mecha_platinum', name: '🦾 Optimus KW'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'mecha_gold', name: '⚙️ Tukang Rakit'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'mecha_silver', name: '🔩 Baut Karatan'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'mecha_bronze', name: '🔋 Lowbat Brutal'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'mecha_stone', name: '🪨 Baterai Lemah'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'mecha_wood', name: '🪵 Nonton Robot'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'school',
    label: 'School',
    emoji: '🏫',
    colorHex: '#3b82f6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'school_platinum', name: '🏫 Penguasa Rooftop'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'school_gold', name: '🎒 Senior Skena'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'school_silver', name: '🚬 Nongkrong Warjok'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'school_bronze', name: '🪑 Murid Pojokan'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'school_stone', name: '🪨 Anak Baru'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'school_wood', name: '🪵 Bolos Dikit'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'shounen',
    label: 'Shounen',
    emoji: '🔥',
    colorHex: '#f97316',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'shounen_platinum', name: '🗿 Main Character'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'shounen_gold', name: '🤝 Power of Teman'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'shounen_silver', name: '⚡ Nakama FB'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'shounen_bronze', name: '😤 Mode Serius'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'shounen_stone', name: '🪨 Semangat Tipis'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'shounen_wood', name: '🪵 Nonton Berantem'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'seinen',
    label: 'Seinen',
    emoji: '🍺',
    colorHex: '#78716c',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'seinen_platinum', name: '🚬 Literally Me'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'seinen_gold', name: '🍺 Capek Kerja'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'seinen_silver', name: '🥀 Doomscrolling'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'seinen_bronze', name: '☕ Kopi Pahit'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'seinen_stone', name: '🪨 Nonton Serius'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'seinen_wood', name: '🪵 Mikir Tipis'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'shoujo',
    label: 'Shoujo',
    emoji: '🌸',
    colorHex: '#f472b6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'shoujo_platinum', name: '💖 Coquette Queen'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'shoujo_gold', name: '✨ Aesthetic Lord'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'shoujo_silver', name: '🎀 Soft Launch'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'shoujo_bronze', name: '🌸 Gemas Abiez'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'shoujo_stone', name: '🪨 Pink Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'shoujo_wood', name: '🪵 Suka Bunga'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'ecchi',
    label: 'Ecchi',
    emoji: '💋',
    colorHex: '#f43f5e',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'ecchi_platinum', name: '🕶️ Puh Puh Sepuh'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'ecchi_gold', name: '🧐 Man of Culture'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'ecchi_silver', name: '👀 Mata Elang'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'ecchi_bronze', name: '🙈 Istighfar Bro'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'ecchi_stone', name: '🪨 Nonton Hati-hati'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'ecchi_wood', name: '🪵 Nonton Diam-diam'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'harem',
    label: 'Harem',
    emoji: '💗',
    colorHex: '#d946ef',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'harem_platinum', name: '👑 Giga Chad'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'harem_gold', name: '🌹 Playmaker'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'harem_silver', name: '📑 List Gebetan'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'harem_bronze', name: '😳 Maruk Amat'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'harem_stone', name: '🪨 Suka Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'harem_wood', name: '🪵 Nonton Saja'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'psychological',
    label: 'Psychological',
    emoji: '🧠',
    colorHex: '#7c3aed',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'psychological_platinum', name: '🧠 Galaxy Brain'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'psychological_gold', name: '🌀 Manipulator Skena'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'psychological_silver', name: '🤯 Konslet Dikit'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'psychological_bronze', name: '😵‍💫 Pusing Sir'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'psychological_stone', name: '🪨 Mikir Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'psychological_wood', name: '🪵 Nonton Santai'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'thriller',
    label: 'Thriller',
    emoji: '⚡',
    colorHex: '#dc2626',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'thriller_platinum', name: '🚨 Panik King'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'thriller_gold', name: '🫀 Tensi Naik'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'thriller_silver', name: '😰 Keringat Dingin'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'thriller_bronze', name: '🫣 Tegang Santai'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'thriller_stone', name: '🪨 Sedikit Panik'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'thriller_wood', name: '🪵 Nonton Pelan'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'magic',
    label: 'Magic',
    emoji: '🪄',
    colorHex: '#8b5cf6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'magic_platinum', name: '🪄 Magic Rizz'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'magic_gold', name: '✨ Gendam Pro'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'magic_silver', name: '🪬 Trik Sulap'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'magic_bronze', name: '🃏 Beli Burung'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'magic_stone', name: '🪨 Sulap Receh'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'magic_wood', name: '🪵 Nonton Sulap'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'historical',
    label: 'Historical',
    emoji: '📜',
    colorHex: '#a16207',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'historical_platinum', name: '📜 Fosil Purba'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'historical_gold', name: '🏛️ Lore Master'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'historical_silver', name: '📖 Buku Sejarah'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'historical_bronze', name: '🕰️ Nostalgia Tipis'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'historical_stone', name: '🪨 Nonton Zaman Old'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'historical_wood', name: '🪵 Suka Cerita Lama'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'music',
    label: 'Music',
    emoji: '🎵',
    colorHex: '#ec4899',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'music_platinum', name: '🎸 Rockstar Skena'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'music_gold', name: '🎤 Wota Sepuh'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'music_silver', name: '🎧 Headset Rusak'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'music_bronze', name: '📻 Dengar Radio'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'music_stone', name: '🪨 Nyanyi Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'music_wood', name: '🪵 Dengerin Lagu'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'game',
    label: 'Game',
    emoji: '🎮',
    colorHex: '#10b981',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'game_platinum', name: '🎮 Tryhard Final'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'game_gold', name: '👾 No Life'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'game_silver', name: '🕹️ Bocah Warnet'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'game_bronze', name: '🎲 Player Bot'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'game_stone', name: '🪨 Main Receh'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'game_wood', name: '🪵 Coba-coba'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'demons',
    label: 'Demons',
    emoji: '😈',
    colorHex: '#991b1b',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'demons_platinum', name: '😈 Villain Arc'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'demons_gold', name: '👹 Bos Iblis'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'demons_silver', name: '👺 Masih Badung'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'demons_bronze', name: '😈 Senggol Bacok'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'demons_stone', name: '🪨 Nakal Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'demons_wood', name: '🪵 Nonton Setan'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'military',
    label: 'Military',
    emoji: '🎖️',
    colorHex: '#4b5563',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'military_platinum', name: '🎖️ Jenderal Lobby'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'military_gold', name: '🪖 Call of Duty'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'military_silver', name: '🎯 Camper Handal'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'military_bronze', name: '🪖 Rekrut Pasrah'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'military_stone', name: '🪨 Latihan Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'military_wood', name: '🪵 Nonton Perang'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'vampire',
    label: 'Vampire',
    emoji: '🧛',
    colorHex: '#7f1d1d',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'vampire_platinum', name: '🧛 Vamp Skena'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'vampire_gold', name: '🦇 Begadang Terus'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'vampire_silver', name: '🩸 Nyari Darah'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'vampire_bronze', name: '🦷 Gingsul Doang'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'vampire_stone', name: '🪨 Suka Gelap'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'vampire_wood', name: '🪵 Nonton Malam'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'slice-of-life',
    label: 'Slice of Life',
    emoji: '🌱',
    colorHex: '#84cc16',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'sliceoflife_platinum', name: '🌱 Chill Guy'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'sliceoflife_gold', name: '☕ Kaum Rebahan'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'sliceoflife_silver', name: '🛋️ Santuy Abis'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'sliceoflife_bronze', name: '🍃 Angin Sepoi'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'sliceoflife_stone', name: '🪨 Rebahan Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'sliceoflife_wood', name: '🪵 Nonton Santai'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'josei',
    label: 'Josei',
    emoji: '👩',
    colorHex: '#be185d',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'josei_platinum', name: '💅 Sugar Mommy'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'josei_gold', name: '🍷 Tante Girang'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'josei_silver', name: '💄 Paham Realita'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'josei_bronze', name: '👧 Bocil Nonton'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'josei_stone', name: '🪨 Nonton Dewasa'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'josei_wood', name: '🪵 Belajar Hidup'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'kids',
    label: 'Kids',
    emoji: '🧒',
    colorHex: '#fbbf24',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'kids_platinum', name: '🍼 Bocil Kematian'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'kids_gold', name: '🧃 iPad Kid'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'kids_silver', name: '🧸 Nonton Kartun'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'kids_bronze', name: '👶 Masih Tk'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'kids_stone', name: '🪨 Bocil Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'kids_wood', name: '🪵 Nonton Anak'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'cars',
    label: 'Cars',
    emoji: '🏎️',
    colorHex: '#dc2626',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'cars_platinum', name: '🏎️ Takumi KW'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'cars_gold', name: '🚗 Gas Pol'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'cars_silver', name: '🛞 Tukang Sunmori'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'cars_bronze', name: '🛵 Knalpot Brong'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'cars_stone', name: '🪨 Nyetir Pelan'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'cars_wood', name: '🪵 Nonton Balap'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'dementia',
    label: 'Dementia',
    emoji: '🌀',
    colorHex: '#6366f1',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'dementia_platinum', name: '😵‍💫 Lobotomy Enjoyer'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'dementia_gold', name: '🌀 Mind Freak'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'dementia_silver', name: '🤔 Linglung Bro'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'dementia_bronze', name: '🤷 Hah Gimana?'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'dementia_stone', name: '🪨 Bingung Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'dementia_wood', name: '🪵 Nonton Ngawur'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'parody',
    label: 'Parody',
    emoji: '🤪',
    colorHex: '#f472b6',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'parody_platinum', name: '🤪 Certified Yap'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'parody_gold', name: '😂 Sering Lawak'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'parody_silver', name: '🤡 Garing Parah'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'parody_bronze', name: '🦗 Krik Krik'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'parody_stone', name: '🪨 Ngakak Dikit'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'parody_wood', name: '🪵 Senyum Kaku'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'samurai',
    label: 'Samurai',
    emoji: '⚔️',
    colorHex: '#1e40af',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'samurai_platinum', name: '🗡️ No Enemies'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'samurai_gold', name: '⚔️ Ronin Liar'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'samurai_silver', name: '🥢 Tebas Angin'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'samurai_bronze', name: '🎋 Asah Golok'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'samurai_stone', name: '🪨 Latihan Pedang'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'samurai_wood', name: '🪵 Nonton Samurai'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'space',
    label: 'Space',
    emoji: '🌌',
    colorHex: '#4c1d95',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'space_platinum', name: '🌌 Interstellar Lord'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'space_gold', name: '🚀 Menuju Mars'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'space_silver', name: '🛸 Teman Alien'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'space_bronze', name: '⭐ Bengong Langit'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'space_stone', name: '🪨 Liat Awan'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'space_wood', name: '🪵 Nonton Galaksi'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'super-power',
    label: 'Super Power',
    emoji: '💪',
    colorHex: '#f97316',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'superpower_platinum', name: '🗿 Real Gojo'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'superpower_gold', name: '💥 Overpowered Bro'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'superpower_silver', name: '🔥 Mode Chuni'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'superpower_bronze', name: '✨ Lentik Jari'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'superpower_stone', name: '🪨 Kekuatan Tipis'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'superpower_wood', name: '🪵 Nonton OP'),
    ],
  ),
  GenreRoleCatalogItem(
    genre: 'martial-arts',
    label: 'Martial Arts',
    emoji: '🥋',
    colorHex: '#dc2626',
    tiers: [
      GenreRoleCatalogTier(tier: 'platinum', minCount: 100, key: 'martialarts_platinum', name: '🥋 Guru Padepokan'),
      GenreRoleCatalogTier(tier: 'gold', minCount: 75, key: 'martialarts_gold', name: '👊 One Punch'),
      GenreRoleCatalogTier(tier: 'silver', minCount: 50, key: 'martialarts_silver', name: '🦵 Tendangan Maut'),
      GenreRoleCatalogTier(tier: 'bronze', minCount: 30, key: 'martialarts_bronze', name: '🥋 Sabuk Putih'),
      GenreRoleCatalogTier(tier: 'stone', minCount: 15, key: 'martialarts_stone', name: '🪨 Latihan Dasar'),
      GenreRoleCatalogTier(tier: 'wood', minCount: 5, key: 'martialarts_wood', name: '🪵 Nonton Bela Diri'),
    ],
  ),
];
