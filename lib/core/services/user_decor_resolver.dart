import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/anime/data/anime_repository.dart';
import '../../features/anime/data/models/genre_role_model.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/profile/data/models/profile_font_model.dart';
import '../../features/profile/data/profile_repository.dart';

/// Lightweight data holder for resolved user decoration, avatar, and font.
class UserDecorData {
  final String username;
  final String? avatarUrl;
  final String? decorationUrl;
  final String? decorationCode;
  final double decorationScale;
  final int decorationOffsetX;
  final int decorationOffsetY;
  final ProfileFontModel? profileFontData;
  final bool verifiedBadge;
  final GenreRoleItem? genreRole;

  const UserDecorData({
    required this.username,
    this.avatarUrl,
    this.decorationUrl,
    this.decorationCode,
    this.decorationScale = 1.0,
    this.decorationOffsetX = 0,
    this.decorationOffsetY = 0,
    this.profileFontData,
    this.verifiedBadge = false,
    this.genreRole,
  });

  bool get hasDecoration =>
      (decorationUrl != null && decorationUrl!.isNotEmpty) ||
      (decorationCode != null && decorationCode!.isNotEmpty);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserDecorData &&
        other.username == username &&
        other.avatarUrl == avatarUrl &&
        other.decorationUrl == decorationUrl &&
        other.decorationCode == decorationCode &&
        other.decorationScale == decorationScale &&
        other.decorationOffsetX == decorationOffsetX &&
        other.decorationOffsetY == decorationOffsetY &&
        other.profileFontData == profileFontData &&
        other.verifiedBadge == verifiedBadge &&
        other.genreRole == genreRole;
  }

  @override
  int get hashCode => Object.hash(
        username,
        avatarUrl,
        decorationUrl,
        decorationCode,
        decorationScale,
        decorationOffsetX,
        decorationOffsetY,
        profileFontData,
        verifiedBadge,
        genreRole,
      );
}

/// Global resolver and cache for other users' avatar frames, covers, and custom fonts.
///
/// Automatically fetches and caches public profile decorations for authors of comments
/// and chat messages so their Discord-style avatar frames (bingkai) and Google fonts
/// are displayed consistently across the app.
class UserDecorResolver extends ChangeNotifier {
  UserDecorResolver._();
  static final UserDecorResolver instance = UserDecorResolver._();

  final Map<String, UserDecorData> _cache = {};
  final Set<String> _inFlight = {};
  final Set<String> _resolved = {};

  UserDecorData? get(String? username) {
    if (username == null) return null;
    final key = username.trim().toLowerCase();
    return _cache[key];
  }

  bool has(String? username) {
    if (username == null) return false;
    final key = username.trim().toLowerCase();
    return _cache.containsKey(key);
  }

  /// Manually seed or update the cache (e.g. from currentUser or explicit payload).
  void register({
    required String username,
    String? avatarUrl,
    String? decorationUrl,
    String? decorationCode,
    double decorationScale = 1.0,
    int decorationOffsetX = 0,
    int decorationOffsetY = 0,
    ProfileFontModel? profileFontData,
    bool verifiedBadge = false,
    GenreRoleItem? genreRole,
    bool clearGenreRole = false,
  }) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty || key == 'unknown' || key == 'pengguna') return;

    final existing = _cache[key];
    final updated = UserDecorData(
      username: username,
      avatarUrl: avatarUrl ?? existing?.avatarUrl,
      decorationUrl: decorationUrl ?? existing?.decorationUrl,
      decorationCode: decorationCode ?? existing?.decorationCode,
      decorationScale: decorationScale != 1.0 ? decorationScale : (existing?.decorationScale ?? 1.0),
      decorationOffsetX: decorationOffsetX != 0 ? decorationOffsetX : (existing?.decorationOffsetX ?? 0),
      decorationOffsetY: decorationOffsetY != 0 ? decorationOffsetY : (existing?.decorationOffsetY ?? 0),
      profileFontData: profileFontData ?? existing?.profileFontData,
      verifiedBadge: verifiedBadge || (existing?.verifiedBadge ?? false),
      genreRole: clearGenreRole ? null : (genreRole ?? existing?.genreRole),
    );
    if (genreRole != null || clearGenreRole) {
      _resolved.add(key);
    }
    if (existing != null && existing == updated) {
      return;
    }
    _cache[key] = updated;
    notifyListeners();
  }

  /// Register from UserModel
  void registerUserModel(UserModel user) {
    register(
      username: user.username,
      avatarUrl: user.avatarUrl,
      decorationUrl: user.fullAvatarDecorationUrl,
      decorationCode: user.avatarDecorationCode,
      decorationScale: user.avatarDecorationScale ?? 1.0,
      decorationOffsetX: user.avatarDecorationOffsetX ?? 0,
      decorationOffsetY: user.avatarDecorationOffsetY ?? 0,
      profileFontData: user.profileFontData ?? ProfileFontModel.fromKey(user.profileFont),
      verifiedBadge: user.verifiedBadge,
    );
  }

  /// Resolves decorations for a list of usernames in the background.
  /// Deduplicates in-flight requests and avoids re-fetching already cached users.
  Future<void> resolveUsers(Iterable<String?> usernames) async {
    final targets = <String>[];
    for (final raw in usernames) {
      if (raw == null) continue;
      final key = raw.trim().toLowerCase();
      if (key.isEmpty || key == 'unknown' || key == 'pengguna' || key == 'user') continue;
      if (_resolved.contains(key) || _inFlight.contains(key)) continue;
      targets.add(raw.trim());
      _inFlight.add(key);
    }

    if (targets.isEmpty) return;

    bool anyUpdated = false;

    // Process in batches of 4 concurrent requests to be gentle on network
    const batchSize = 4;
    for (var i = 0; i < targets.length; i += batchSize) {
      final batch = targets.sublist(i, (i + batchSize > targets.length) ? targets.length : i + batchSize);
      await Future.wait(
        batch.map((u) async {
          final key = u.toLowerCase();
          try {
            final userFuture = ProfileRepository.instance.byUsername(u);
            final genreFuture = AnimeRepository.instance.getUserGenreRoles(u);

            final results = await Future.wait([
              userFuture,
              genreFuture.catchError((_) => const UserGenreSummary()),
            ]);

            final user = results[0] as UserModel;
            final genreSummary = results[1] as UserGenreSummary;
            final primaryRole = genreSummary.primaryRole ??
                (genreSummary.roles.isNotEmpty ? genreSummary.roles.first : null);

            final existing = _cache[key];
            _cache[key] = UserDecorData(
              username: user.username,
              avatarUrl: user.avatarUrl ?? existing?.avatarUrl,
              decorationUrl: user.fullAvatarDecorationUrl ?? existing?.decorationUrl,
              decorationCode: user.avatarDecorationCode ?? existing?.decorationCode,
              decorationScale: user.avatarDecorationScale ?? existing?.decorationScale ?? 1.0,
              decorationOffsetX: user.avatarDecorationOffsetX ?? existing?.decorationOffsetX ?? 0,
              decorationOffsetY: user.avatarDecorationOffsetY ?? existing?.decorationOffsetY ?? 0,
              profileFontData: user.profileFontData ?? ProfileFontModel.fromKey(user.profileFont) ?? existing?.profileFontData,
              verifiedBadge: user.verifiedBadge || (existing?.verifiedBadge ?? false),
              genreRole: primaryRole ?? existing?.genreRole,
            );
            _resolved.add(key);
            anyUpdated = true;
          } catch (_) {
            _resolved.add(key);
            // Store fallback decor if not exists to avoid spamming failed fetches
            if (!_cache.containsKey(key)) {
              _cache[key] = UserDecorData(username: u);
            }
          } finally {
            _inFlight.remove(key);
          }
        }),
      );
    }

    if (anyUpdated) {
      notifyListeners();
    }
  }

  /// Clear in-memory cache
  void clear() {
    _cache.clear();
    _inFlight.clear();
    _resolved.clear();
    notifyListeners();
  }
}

