import 'dart:math' as math;
import '../../../profile/data/models/profile_font_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../shared/widgets/smooth_avatar_decoration.dart';

/// User model (returned from /auth/me and /users/profile/me).
class UserModel {
  final int id;
  final String username;
  final String email;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? slug;
  final bool isVerified;
  final bool verifiedBadge;
  final String? role;
  final String? location;
  final String? website;
  final bool is18Enabled;
  final DateTime? createdAt;
  final int? avatarDecorationId;
  final String? avatarDecorationCode;
  final String? avatarDecorationUrl;
  final double? avatarDecorationScale;
  final int? avatarDecorationOffsetX;
  final int? avatarDecorationOffsetY;
  final String? profileFont;
  final int? profileFontSize;
  final ProfileFontModel? profileFontData;
  final String? tanggalLahir;
  final String? birthdayVisibility;
  final int? age;
  final String? zodiac;
  final bool isBirthdayToday;
  final String? googleId;
  final bool is18Plus;
  final String? notifMode;
  final String? animeNotifMode;
  final String? comicNotifMode;
  final bool birthdayNotifEnabled;
  final int xp;
  final int level;
  final String? rank;
  final int streak;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.slug,
    this.isVerified = false,
    this.verifiedBadge = false,
    this.role,
    this.location,
    this.website,
    this.is18Enabled = false,
    this.createdAt,
    this.avatarDecorationId,
    this.avatarDecorationCode,
    this.avatarDecorationUrl,
    this.avatarDecorationScale,
    this.avatarDecorationOffsetX,
    this.avatarDecorationOffsetY,
    this.profileFont,
    this.profileFontSize,
    this.profileFontData,
    this.tanggalLahir,
    this.birthdayVisibility,
    this.age,
    this.zodiac,
    this.isBirthdayToday = false,
    this.is18Plus = false,
    this.googleId,
    this.notifMode,
    this.animeNotifMode,
    this.comicNotifMode,
    this.birthdayNotifEnabled = true,
    this.xp = 0,
    int? level,
    this.rank,
    this.streak = 0,
  }) : level = level ?? calculateLevel(xp);

  /// Quadratic Level progression: BaseXP(L) = 50 * (L - 1) * L
  static int calculateLevel(int xp) {
    if (xp <= 0) return 1;
    final val = (1.0 + math.sqrt(1.0 + 0.08 * xp.toDouble())) / 2.0;
    final lvl = val.floor();
    return lvl < 1 ? 1 : lvl;
  }

  static int levelBaseXp(int lvl) {
    if (lvl <= 1) return 0;
    return 50 * (lvl - 1) * lvl;
  }

  static int nextLevelRequiredXp(int lvl) {
    if (lvl < 1) lvl = 1;
    return 50 * lvl * (lvl + 1);
  }

  static String rankTitleForLevel(int lvl) {
    if (lvl <= 2) return 'Ashigaru V';
    if (lvl <= 4) return 'Ashigaru IV';
    if (lvl <= 6) return 'Ashigaru III';
    if (lvl <= 8) return 'Ashigaru II';
    if (lvl <= 10) return 'Ashigaru I';
    if (lvl <= 13) return 'Samurai V';
    if (lvl <= 16) return 'Samurai IV';
    if (lvl <= 19) return 'Samurai III';
    if (lvl <= 22) return 'Samurai II';
    if (lvl <= 25) return 'Samurai I';
    if (lvl <= 30) return 'Hatamoto III';
    if (lvl <= 35) return 'Hatamoto II';
    if (lvl <= 40) return 'Hatamoto I';
    if (lvl <= 50) return 'Daimyo';
    if (lvl <= 65) return 'Shogun';
    if (lvl <= 80) return 'Hashira';
    if (lvl <= 99) return 'S-Rank Hunter';
    return 'Legenda Animeverse';
  }

  int get currentLevelBaseXp => levelBaseXp(level);
  int get nextLevelXp => nextLevelRequiredXp(level);
  int get currentLevelProgressXp => (xp - currentLevelBaseXp).clamp(0, nextLevelXp - currentLevelBaseXp);
  int get currentLevelSpanXp => (nextLevelXp - currentLevelBaseXp).clamp(1, 99999999);
  double get levelProgressFraction => (currentLevelProgressXp / currentLevelSpanXp).clamp(0.0, 1.0);
  String get displayRank => (rank != null && rank!.isNotEmpty) ? rank! : rankTitleForLevel(level);

  bool get isGoogleUser =>
      (googleId != null && googleId!.isNotEmpty) ||
      email.toLowerCase().endsWith('@gmail.com');

  String? get fullAvatarDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(avatarDecorationUrl, avatarDecorationCode);
  }

  bool get hasVerifiedBadge => verifiedBadge;
  bool get isAdmin => (role ?? '').toLowerCase() == 'admin';

  bool get isBirthdayPrivate {
    final v = (birthdayVisibility ?? 'public').toLowerCase().trim();
    return v == 'private' || v == 'privat' || v == 'hidden' || v == 'sembunyi' || v == 'sembunyikan';
  }

  bool get isBirthdayAgeOnly {
    final v = (birthdayVisibility ?? 'public').toLowerCase().trim();
    return v == 'age_only' || v == 'hanya_umur' || v == 'age';
  }

  bool get isAvatarAnimated {
    if (avatarUrl == null || avatarUrl!.isEmpty) return false;
    final lower = avatarUrl!.toLowerCase();
    return lower.contains('.gif') || lower.contains('.webp');
  }

  bool get isCoverAnimated {
    if (coverUrl == null || coverUrl!.isEmpty) return false;
    final lower = coverUrl!.toLowerCase();
    return lower.contains('.gif') || lower.contains('.webp');
  }

  factory UserModel.fromJson(Map<String, dynamic> j) {
    // If wrapped in 'user' or 'data.user', unwrap it
    if (j.containsKey('user') && j['user'] is Map) {
      j = Map<String, dynamic>.from(j['user'] as Map);
    } else if (j.containsKey('data') && j['data'] is Map) {
      final inner = Map<String, dynamic>.from(j['data'] as Map);
      if (inner.containsKey('user') && inner['user'] is Map) {
        j = Map<String, dynamic>.from(inner['user'] as Map);
      } else {
        j = inner;
      }
    }

    int? decorId = (j['avatar_decoration_id'] as num?)?.toInt() ?? int.tryParse(j['avatar_decoration_id']?.toString() ?? '');
    String? decorUrl = j['avatar_decoration_url']?.toString();
    String? decorCode = j['avatar_decoration_code']?.toString();
    double? decorScale = (j['avatar_decoration_scale'] is num)
        ? (j['avatar_decoration_scale'] as num).toDouble()
        : double.tryParse(j['avatar_decoration_scale']?.toString() ?? '');
    int? decorOffX = (j['avatar_decoration_offset_x'] is num)
        ? (j['avatar_decoration_offset_x'] as num).toInt()
        : int.tryParse(j['avatar_decoration_offset_x']?.toString() ?? '');
    int? decorOffY = (j['avatar_decoration_offset_y'] is num)
        ? (j['avatar_decoration_offset_y'] as num).toInt()
        : int.tryParse(j['avatar_decoration_offset_y']?.toString() ?? '');

    if (j['avatar_decoration'] is Map) {
      final dMap = Map<String, dynamic>.from(j['avatar_decoration'] as Map);
      decorId ??= (dMap['id'] as num?)?.toInt() ?? int.tryParse(dMap['id']?.toString() ?? '');
      decorCode ??= dMap['code']?.toString();
      decorUrl ??= dMap['image_url']?.toString() ?? dMap['url']?.toString();
      decorScale ??= (dMap['scale'] is num)
          ? (dMap['scale'] as num).toDouble()
          : double.tryParse(dMap['scale']?.toString() ?? '');
      decorOffX ??= (dMap['offset_x'] is num)
          ? (dMap['offset_x'] as num).toInt()
          : int.tryParse(dMap['offset_x']?.toString() ?? '');
      decorOffY ??= (dMap['offset_y'] is num)
          ? (dMap['offset_y'] as num).toInt()
          : int.tryParse(dMap['offset_y']?.toString() ?? '');
    }

    if ((decorCode == null || decorCode.isEmpty) && decorUrl != null && decorUrl.isNotEmpty) {
      final uri = Uri.tryParse(decorUrl);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : decorUrl.split('/').last;
      final extracted = seg.replaceAll('.png', '').replaceAll('.webp', '').replaceAll('.gif', '').trim();
      if (extracted.isNotEmpty) decorCode = extracted;
    }

    String? pFont = j['profile_font']?.toString();
    int? pFontSize = (j['profile_font_size'] is num)
        ? (j['profile_font_size'] as num).toInt()
        : int.tryParse(j['profile_font_size']?.toString() ?? '');
    ProfileFontModel? pFontData;
    if (j['profile_font_data'] is Map) {
      pFontData = ProfileFontModel.fromJson(Map<String, dynamic>.from(j['profile_font_data'] as Map));
    } else if (pFont != null && pFont.isNotEmpty) {
      pFontData = ProfileFontModel.fromKey(pFont);
    }
    if (pFontData != null && pFontSize != null && pFontData.size == null) {
      pFontData = ProfileFontModel(
        key: pFontData.key,
        name: pFontData.name,
        googleKey: pFontData.googleKey,
        category: pFontData.category,
        fallback: pFontData.fallback,
        sample: pFontData.sample,
        size: pFontSize,
        isDefault: pFontData.isDefault,
      );
    }

    Map<String, dynamic>? bMap;
    if (j['birthday'] is Map) {
      bMap = Map<String, dynamic>.from(j['birthday'] as Map);
    } else if (j['birthday_info'] is Map) {
      bMap = Map<String, dynamic>.from(j['birthday_info'] as Map);
    }

    final String? tLahir = j['tanggal_lahir']?.toString() ??
        j['date_of_birth']?.toString() ??
        bMap?['tanggal_lahir']?.toString() ??
        bMap?['date_of_birth']?.toString();

    final String? rawVis = j['birthday_visibility']?.toString() ??
        j['visibility']?.toString() ??
        j['birthday_privacy']?.toString() ??
        j['privacy']?.toString() ??
        bMap?['birthday_visibility']?.toString() ??
        bMap?['visibility']?.toString() ??
        bMap?['privacy']?.toString() ??
        bMap?['birthday_privacy']?.toString();

    String? bVis = rawVis?.toLowerCase().trim();
    if (bVis == 'privat' || bVis == 'hidden' || bVis == 'sembunyi' || bVis == 'sembunyikan') {
      bVis = 'private';
    } else if (bVis == 'hanya_umur' || bVis == 'age' || bVis == 'age_only') {
      bVis = 'age_only';
    } else if (bVis == 'publik') {
      bVis = 'public';
    }

    dynamic rawAge = j['umur'] ?? j['age'] ?? bMap?['umur'] ?? bMap?['age'];
    int? parsedAge = (rawAge is num) ? rawAge.toInt() : int.tryParse(rawAge?.toString() ?? '');

    final String? zSign = j['zodiac']?.toString() ?? bMap?['zodiac']?.toString();

    final dynamic rawBToday = j['is_birthday_today'] ?? bMap?['is_birthday_today'];
    final bool bToday = rawBToday == true ||
        rawBToday?.toString() == '1' ||
        rawBToday?.toString().toLowerCase() == 'true';

    final dynamic raw18Plus = j['is_18_plus'] ?? bMap?['is_18_plus'];
    final bool is18 = raw18Plus == true ||
        raw18Plus?.toString() == '1' ||
        (parsedAge != null && parsedAge >= 18);

    return UserModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      username: j['username'] as String? ?? '',
      email: j['email'] as String? ?? '',
      displayName: j['display_name'] as String? ?? j['name'] as String?,
      bio: j['bio'] as String?,
      avatarUrl: _normalizeAvatar(j['avatar'] ?? j['avatar_url']),
      coverUrl: _normalizeCover(j['cover_photo'] ?? j['cover_url'] ?? j['cover']),
      slug: j['slug'] as String?,
      isVerified: (j['is_verified'] is int)
          ? (j['is_verified'] as int) == 1
          : (j['is_verified'] == true || j['is_verified']?.toString() == '1'),
      verifiedBadge: (j['verified_badge'] is int)
          ? (j['verified_badge'] as int) == 1
          : (j['verified_badge'] == true ||
              j['verified_badge']?.toString() == '1' ||
              j['verified_badge']?.toString().toLowerCase() == 'true'),
      role: j['role'] as String?,
      location: j['location'] as String?,
      website: j['website'] as String?,
      is18Enabled: _parse18(j),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      avatarDecorationId: decorId,
      avatarDecorationCode: decorCode,
      avatarDecorationUrl: decorUrl,
      avatarDecorationScale: decorScale,
      avatarDecorationOffsetX: decorOffX,
      avatarDecorationOffsetY: decorOffY,
      profileFont: pFont,
      profileFontSize: pFontSize,
      profileFontData: pFontData,
      tanggalLahir: tLahir,
      birthdayVisibility: bVis,
      age: parsedAge,
      zodiac: zSign,
      isBirthdayToday: bToday,
      is18Plus: is18,
      googleId: j['google_id']?.toString() ?? j['googleId']?.toString(),
      notifMode: j['notif_mode']?.toString(),
      animeNotifMode: j['anime_notif_mode']?.toString() ?? j['notif_mode']?.toString(),
      comicNotifMode: j['comic_notif_mode']?.toString() ?? j['notif_mode']?.toString(),
      birthdayNotifEnabled: j['birthday_notif_enabled'] == null
          ? true
          : (j['birthday_notif_enabled'] == true ||
              j['birthday_notif_enabled']?.toString() == '1' ||
              j['birthday_notif_enabled']?.toString().toLowerCase() == 'true'),
      xp: (j['xp'] as num?)?.toInt() ?? int.tryParse(j['xp']?.toString() ?? '') ?? 0,
      level: (j['level'] as num?)?.toInt() ?? int.tryParse(j['level']?.toString() ?? ''),
      rank: j['rank']?.toString(),
      streak: (j['streak'] as num?)?.toInt() ?? int.tryParse(j['streak']?.toString() ?? '') ?? 0,
    );
  }

  String? get effectiveGoogleFont => profileFontData?.googleKey ?? (profileFont != null && profileFont!.isNotEmpty ? profileFont : null);

  static bool _parse18(Map<String, dynamic> j) {
    final v = j['18'] ??
        j['is_18'] ??
        j['is_18_enabled'] ??
        j['is18'] ??
        j['is18Enabled'];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v == 1;
    final str = v.toString().trim().toLowerCase();
    return str == '1' || str == 'true';
  }

  static String? normalizeAvatarUrl(dynamic v) {
    if (v == null) return null;
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    if (str == 'default-avatar.jpg' || str.endsWith('/default-avatar.jpg')) return null;
    if (str.startsWith('http://') || str.startsWith('https://')) return str;

    final clean = str.replaceFirst(RegExp(r'^/+'), '');
    if (clean.startsWith('api/')) {
      return '${ApiConfig.baseUrl}/$clean';
    }
    if (clean.startsWith('uploads/')) {
      return '${ApiConfig.baseUrl}/api/users/$clean';
    }
    if (clean.startsWith('avatars/') || clean.startsWith('covers/')) {
      return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
    }
    return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
  }

  static String? normalizeCoverUrl(dynamic v) {
    if (v == null) return null;
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    if (str == 'default-cover.jpg' || str.endsWith('/default-cover.jpg')) return null;
    if (str.startsWith('http://') || str.startsWith('https://')) return str;

    final clean = str.replaceFirst(RegExp(r'^/+'), '');
    if (clean.startsWith('api/')) {
      return '${ApiConfig.baseUrl}/$clean';
    }
    if (clean.startsWith('uploads/')) {
      return '${ApiConfig.baseUrl}/api/users/$clean';
    }
    if (clean.startsWith('avatars/') || clean.startsWith('covers/')) {
      return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
    }
    return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
  }

  static String? _normalizeAvatar(dynamic v) => normalizeAvatarUrl(v);

  static String? _normalizeCover(dynamic v) => normalizeCoverUrl(v);

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'display_name': displayName,
        'bio': bio,
        'avatar_url': avatarUrl,
        'cover_url': coverUrl,
        'slug': slug,
        'is_verified': isVerified ? 1 : 0,
        'verified_badge': verifiedBadge ? 1 : 0,
        'role': role,
        'location': location,
        'website': website,
        '18': is18Enabled ? 1 : 0,
        'is_18': is18Enabled ? 1 : 0,
        'is_18_enabled': is18Enabled ? 1 : 0,
        'avatar_decoration_id': avatarDecorationId,
        'avatar_decoration_code': avatarDecorationCode,
        'avatar_decoration_url': avatarDecorationUrl,
        'avatar_decoration_scale': avatarDecorationScale,
        'avatar_decoration_offset_x': avatarDecorationOffsetX,
        'avatar_decoration_offset_y': avatarDecorationOffsetY,
        'profile_font': profileFont,
        'profile_font_size': profileFontSize,
        'profile_font_data': profileFontData?.toJson(),
        'tanggal_lahir': tanggalLahir,
        'date_of_birth': tanggalLahir,
        'birthday_visibility': birthdayVisibility ?? 'public',
        'umur': age,
        'age': age,
        'zodiac': zodiac,
        'is_birthday_today': isBirthdayToday,
        'is_18_plus': is18Plus,
        'notif_mode': notifMode,
        'anime_notif_mode': animeNotifMode ?? notifMode,
        'comic_notif_mode': comicNotifMode ?? notifMode,
        'birthday_notif_enabled': birthdayNotifEnabled,
        'xp': xp,
        'level': level,
        'rank': rank,
        'streak': streak,
      };

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? slug,
    bool? isVerified,
    bool? verifiedBadge,
    String? role,
    String? location,
    String? website,
    bool? is18Enabled,
    DateTime? createdAt,
    int? avatarDecorationId,
    String? avatarDecorationCode,
    String? avatarDecorationUrl,
    double? avatarDecorationScale,
    int? avatarDecorationOffsetX,
    int? avatarDecorationOffsetY,
    bool clearAvatarDecoration = false,
    String? profileFont,
    int? profileFontSize,
    ProfileFontModel? profileFontData,
    bool clearProfileFont = false,
    String? tanggalLahir,
    String? birthdayVisibility,
    int? age,
    String? zodiac,
    bool? isBirthdayToday,
    bool? is18Plus,
    bool clearBirthday = false,
    String? notifMode,
    int? xp,
    int? level,
    String? rank,
    int? streak,
  }) =>
      UserModel(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        slug: slug ?? this.slug,
        isVerified: isVerified ?? this.isVerified,
        verifiedBadge: verifiedBadge ?? this.verifiedBadge,
        role: role ?? this.role,
        location: location ?? this.location,
        website: website ?? this.website,
        is18Enabled: is18Enabled ?? this.is18Enabled,
        createdAt: createdAt ?? this.createdAt,
        avatarDecorationId: clearAvatarDecoration ? null : (avatarDecorationId ?? this.avatarDecorationId),
        avatarDecorationCode: clearAvatarDecoration ? null : (avatarDecorationCode ?? this.avatarDecorationCode),
        avatarDecorationUrl: clearAvatarDecoration ? null : (avatarDecorationUrl ?? this.avatarDecorationUrl),
        avatarDecorationScale: clearAvatarDecoration ? null : (avatarDecorationScale ?? this.avatarDecorationScale),
        avatarDecorationOffsetX: clearAvatarDecoration ? null : (avatarDecorationOffsetX ?? this.avatarDecorationOffsetX),
        avatarDecorationOffsetY: clearAvatarDecoration ? null : (avatarDecorationOffsetY ?? this.avatarDecorationOffsetY),
        profileFont: clearProfileFont ? null : (profileFont ?? this.profileFont),
        profileFontSize: clearProfileFont ? null : (profileFontSize ?? this.profileFontSize),
        profileFontData: clearProfileFont ? null : (profileFontData ?? this.profileFontData),
        tanggalLahir: clearBirthday ? null : (tanggalLahir ?? this.tanggalLahir),
        birthdayVisibility: birthdayVisibility ?? this.birthdayVisibility,
        age: clearBirthday ? null : (age ?? this.age),
        zodiac: clearBirthday ? null : (zodiac ?? this.zodiac),
        isBirthdayToday: isBirthdayToday ?? this.isBirthdayToday,
        is18Plus: is18Plus ?? this.is18Plus,
        notifMode: notifMode ?? this.notifMode,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        rank: rank ?? this.rank,
        streak: streak ?? this.streak,
      );
}

/// Auth response wrapping user + tokens.
class AuthSession {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map = Map<String, dynamic>.from(j);
    if (map.containsKey('data') && map['data'] is Map) {
      final d = Map<String, dynamic>.from(map['data'] as Map);
      // Merge data into map so tokens & user are accessible at top level
      map = {...map, ...d};
    }

    final token = (map['access_token'] ??
            map['token'] ??
            map['accessToken'] ??
            (map['tokens'] is Map ? (map['tokens']['access_token'] ?? map['tokens']['access']) : null) ??
            '')
        .toString();

    final refreshToken = (map['refresh_token'] ??
            map['refreshToken'] ??
            (map['tokens'] is Map ? (map['tokens']['refresh_token'] ?? map['tokens']['refresh']) : null) ??
            '')
        .toString();

    // Extract user map
    dynamic userRaw = map['user'];
    if (userRaw == null && map.containsKey('data') && map['data'] is Map) {
      userRaw = map['data']['user'] ?? map['data'];
    }
    userRaw ??= map;

    final userJson = userRaw is Map ? Map<String, dynamic>.from(userRaw) : <String, dynamic>{};

    return AuthSession(
      user: UserModel.fromJson(userJson),
      accessToken: token,
      refreshToken: refreshToken,
    );
  }
}
