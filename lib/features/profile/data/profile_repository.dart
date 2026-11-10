import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../auth/data/models/user_model.dart';
import 'models/profile_font_model.dart';
import 'models/friendship_model.dart';
import 'models/user_activity_model.dart';

class ProfileRepository {
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  /// Get current user's profile
  Future<UserModel> me() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.userProfileMe);
    final data = _unwrap(resp.data);
    var user = UserModel.fromJson(Map<String, dynamic>.from(data));
    if (user.birthdayVisibility == null || user.birthdayVisibility == 'public') {
      try {
        final vis = await getBirthdayVisibility();
        if (vis.isNotEmpty && vis != 'public') {
          user = user.copyWith(birthdayVisibility: vis);
        }
      } catch (_) {}
    }
    return user;
  }

  /// Update current user's profile
  Future<UserModel> updateProfile({
    String? username,
    String? displayName,
    String? bio,
    String? email,
    String? location,
    String? website,
    String? tanggalLahir,
    String? birthdayVisibility,
    bool? is18Enabled,
  }) async {
    final cleanUsername = username?.trim().replaceAll('@', '');
    final resp = await ApiClient.instance.put(
      ApiEndpoints.userProfileMe,
      data: {
        if (cleanUsername != null && cleanUsername.isNotEmpty) ...{
          'username': cleanUsername,
          'name': cleanUsername,
        },
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (email != null) 'email': email,
        if (location != null) 'location': location,
        if (website != null) 'website': website,
        if (tanggalLahir != null) ...{
          'tanggal_lahir': tanggalLahir,
          'date_of_birth': tanggalLahir,
        },
        if (birthdayVisibility != null) ...{
          'birthday_visibility': birthdayVisibility,
          'visibility': birthdayVisibility,
        },
        if (is18Enabled != null) ...{
          '18': is18Enabled ? 1 : 0,
          'is_18': is18Enabled ? 1 : 0,
          'is_18_enabled': is18Enabled,
        },
      },
    );

    // Concurrently ensure birthday-specific endpoints are updated if modified
    if (birthdayVisibility != null) {
      try {
        await setBirthdayVisibility(birthdayVisibility);
      } catch (_) {}
    }
    if (tanggalLahir != null && tanggalLahir.isNotEmpty) {
      try {
        await updateBirthday(tanggalLahir, visibility: birthdayVisibility);
      } catch (_) {}
    }

    final data = _unwrap(resp.data);
    UserModel user;
    if (data is Map && data.containsKey('id') && data['id'] != 0 && data.containsKey('username')) {
      user = UserModel.fromJson(Map<String, dynamic>.from(data));
    } else {
      user = await me();
    }
    if (cleanUsername != null && cleanUsername.isNotEmpty && user.username != cleanUsername) {
      user = user.copyWith(username: cleanUsername);
    }
    if (birthdayVisibility != null && user.birthdayVisibility != birthdayVisibility) {
      user = user.copyWith(birthdayVisibility: birthdayVisibility);
    }
    return user;
  }

  /// Get current user's birthday info
  Future<Map<String, dynamic>> getBirthday() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.userBirthday);
    final data = _unwrap(resp.data);
    return Map<String, dynamic>.from(data is Map ? data : {});
  }

  /// Update current user's birthday directly
  Future<Map<String, dynamic>> updateBirthday(String dateOfBirth, {String? visibility}) async {
    final resp = await ApiClient.instance.put(
      ApiEndpoints.userBirthday,
      data: {
        'date_of_birth': dateOfBirth,
        'tanggal_lahir': dateOfBirth,
        if (visibility != null) 'visibility': visibility,
        if (visibility != null) 'birthday_visibility': visibility,
      },
    );
    final data = _unwrap(resp.data);
    return Map<String, dynamic>.from(data is Map ? data : {});
  }

  /// Get current user's birthday visibility setting ('public', 'age_only', 'private')
  Future<String> getBirthdayVisibility() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userBirthdayVisibility);
      final data = _unwrap(resp.data);
      if (data is Map && data['visibility'] != null) {
        return data['visibility'].toString();
      }
      return 'public';
    } catch (_) {
      return 'public';
    }
  }

  /// Update current user's birthday visibility ('public', 'age_only', 'private')
  Future<bool> setBirthdayVisibility(String visibility) async {
    bool ok = false;
    try {
      final resp = await ApiClient.instance.put(
        ApiEndpoints.userBirthdayVisibility,
        data: {
          'birthday_visibility': visibility,
          'visibility': visibility,
        },
      );
      final d = resp.data;
      if (d is Map && (d['success'] == true || d['success'] == 1 || !d.containsKey('error'))) {
        ok = true;
      }
    } catch (_) {}

    try {
      await ApiClient.instance.put(
        ApiEndpoints.userBirthday,
        data: {
          'birthday_visibility': visibility,
          'visibility': visibility,
        },
      );
      ok = true;
    } catch (_) {}

    try {
      await ApiClient.instance.put(
        ApiEndpoints.userProfileMe,
        data: {
          'birthday_visibility': visibility,
          'visibility': visibility,
        },
      );
      ok = true;
    } catch (_) {}

    return ok;
  }

  /// Toggle 18+ content setting directly
  Future<bool> toggle18(bool enabled) async {
    try {
      final resp = await ApiClient.instance.put(
        ApiEndpoints.userProfileMe,
        data: {
          '18': enabled ? 1 : 0,
          'is_18': enabled ? 1 : 0,
          'is_18_enabled': enabled,
        },
      );
      final d = resp.data;
      if (d is Map && d['success'] == true) {
        return true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete current user's profile (account deletion) with password
  Future<void> deleteAccount({required String password}) async {
    await ApiClient.instance.delete(
      ApiEndpoints.userDeleteMe,
      data: {'password': password},
    );
    await TokenStore.clear();
  }

  /// Delete current user's profile with Google confirmation
  Future<void> deleteAccountWithGoogle({
    required String googleId,
    required String email,
  }) async {
    await ApiClient.instance.delete(
      ApiEndpoints.userDeleteMe,
      data: {
        'google_id': googleId,
        'email': email,
        'is_google': true,
      },
    );
    await TokenStore.clear();
  }

  /// Get user by username (public profile with fallback)
  Future<UserModel> byUsername(String username) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.userPublicProfile(username),
      );
      final data = _unwrap(resp.data);
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.userProfileByUsername(username),
      );
      final data = _unwrap(resp.data);
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
  }

  /// Get user by slug
  Future<UserModel> bySlug(String slug) async {
    final resp = await ApiClient.instance.get(
      ApiEndpoints.userBySlug(slug),
    );
    final data = _unwrap(resp.data);
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Get user stats (anime watched, comics read, bookmarks etc.).
  /// Returns an empty map if the endpoint is unavailable (404).
  Future<Map<String, dynamic>> stats(String username) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userStats(username));
      final d = resp.data;
      if (d is Map) {
        if (d['data'] is Map) {
          return Map<String, dynamic>.from(d['data'] as Map);
        }
        if (d['stats'] is Map) {
          return Map<String, dynamic>.from(d['stats'] as Map);
        }
        return Map<String, dynamic>.from(d);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Upload avatar (multipart, supports PNG, JPG, JPEG, GIF, WEBP)
  Future<UserModel> uploadAvatar(String username, File image) async {
    final filename = image.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        image.path,
        filename: filename,
      ),
    });
    final resp = await ApiClient.instance.post(
      ApiEndpoints.userAvatar(username),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = _unwrap(resp.data);
    if (data is Map && data.containsKey('id') && data['id'] != 0 && data.containsKey('username')) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    final fresh = await me();
    if (data is Map) {
      final raw = data['avatar_url'] ?? data['avatar'] ?? data['user']?['avatar_url'] ?? data['user']?['avatar'];
      if (raw != null) {
        return fresh.copyWith(avatarUrl: UserModel.normalizeAvatarUrl(raw));
      }
    }
    return fresh;
  }

  /// Upload cover (multipart, supports PNG, JPG, JPEG, GIF, WEBP)
  Future<UserModel> uploadCover(String username, File image) async {
    final filename = image.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'cover': await MultipartFile.fromFile(
        image.path,
        filename: filename,
      ),
    });
    final resp = await ApiClient.instance.post(
      ApiEndpoints.userCover(username),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = _unwrap(resp.data);
    if (data is Map && data.containsKey('id') && data['id'] != 0 && data.containsKey('username')) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    final fresh = await me();
    if (data is Map) {
      final raw = data['cover_url'] ?? data['cover_photo'] ?? data['cover'] ?? data['user']?['cover_url'] ?? data['user']?['cover_photo'];
      if (raw != null) {
        return fresh.copyWith(coverUrl: UserModel.normalizeCoverUrl(raw));
      }
    }
    return fresh;
  }

  /// Delete avatar and reset to default
  Future<UserModel> deleteAvatar(String username) async {
    await ApiClient.instance.delete(ApiEndpoints.userAvatar(username));
    final fresh = await me();
    return fresh.copyWith(avatarUrl: null);
  }

  /// Delete cover photo and reset to default
  Future<UserModel> deleteCover(String username) async {
    await ApiClient.instance.delete(ApiEndpoints.userCover(username));
    final fresh = await me();
    return fresh.copyWith(coverUrl: null);
  }

  /// Set avatar decoration (Free) via /users/profile/me/avatar-decoration
  Future<Map<String, dynamic>> setAvatarDecoration({
    required String code,
    double scale = 1.0,
    int offsetX = 0,
    int offsetY = 0,
  }) async {
    final resp = await ApiClient.instance.post(
      ApiEndpoints.userAvatarDecoration,
      data: {
        'code': code,
        'scale': scale,
        'offset_x': offsetX,
        'offset_y': offsetY,
      },
    );
    final data = _unwrap(resp.data);
    return data is Map<String, dynamic> ? data : (data is Map ? Map<String, dynamic>.from(data) : {});
  }

  /// Remove avatar decoration via /users/profile/me/avatar-decoration
  Future<void> removeAvatarDecoration() async {
    await ApiClient.instance.delete(ApiEndpoints.userAvatarDecoration);
  }

  /// Get profile fonts catalog
  Future<List<ProfileFontModel>> getProfileFonts() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userProfileFonts);
      final d = resp.data;
      if (d is Map && d['flat'] is List) {
        final list = (d['flat'] as List)
            .map((item) => ProfileFontModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return ProfileFontModel.defaultCatalog;
  }

  /// Update profile font
  Future<UserModel> setProfileFont({required String font, int? size}) async {
    final resp = await ApiClient.instance.put(
      ApiEndpoints.userProfileFont,
      data: {
        'font': font,
        if (size != null) 'size': size,
      },
    );
    final data = _unwrap(resp.data);
    if (data is Map && data.containsKey('id') && data['id'] != 0 && data.containsKey('username')) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    return await me();
  }

  /// Reset profile font to default
  Future<UserModel> resetProfileFont() async {
    final resp = await ApiClient.instance.delete(ApiEndpoints.userProfileFont);
    final data = _unwrap(resp.data);
    if (data is Map && data.containsKey('id') && data['id'] != 0 && data.containsKey('username')) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    return await me();
  }

  // ─── FRIENDSHIP API ───

  /// Cek status pertemanan dengan user lain
  Future<FriendshipInfo> getFriendStatus(String username) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.friendStatus(username));
      final d = resp.data;
      if (d is Map) {
        final data = d['data'] is Map ? d['data'] : d;
        final info = FriendshipInfo.fromJson(Map<String, dynamic>.from(data));
        if (info.status != FriendStatus.none) {
          return info;
        }
      }
    } catch (_) {}

    // Fallback: cek apakah username ada dalam daftar teman pengguna yang login
    try {
      final friends = await getFriendsList();
      final isFriend = friends.any(
        (f) => f.username.toLowerCase() == username.trim().toLowerCase(),
      );
      if (isFriend) {
        return FriendshipInfo(status: FriendStatus.friends);
      }
    } catch (_) {}

    return FriendshipInfo(status: FriendStatus.none);
  }

  /// Kirim permintaan berteman
  Future<Map<String, dynamic>> sendFriendRequest(String username, {String? message}) async {
    final resp = await ApiClient.instance.post(
      ApiEndpoints.friendRequest,
      data: {
        'username': username,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
    return Map<String, dynamic>.from(resp.data is Map ? resp.data : {});
  }

  /// Terima permintaan berteman
  Future<bool> acceptFriendRequest(int requestId) async {
    final resp = await ApiClient.instance.post(ApiEndpoints.friendAccept(requestId));
    final d = resp.data;
    return d is Map && d['success'] == true;
  }

  /// Tolak permintaan berteman
  Future<bool> rejectFriendRequest(int requestId) async {
    final resp = await ApiClient.instance.post(ApiEndpoints.friendReject(requestId));
    final d = resp.data;
    return d is Map && d['success'] == true;
  }

  /// Batalkan permintaan berteman yang dikirim
  Future<bool> cancelFriendRequest(int requestId) async {
    final resp = await ApiClient.instance.post(ApiEndpoints.friendCancel(requestId));
    final d = resp.data;
    return d is Map && d['success'] == true;
  }

  /// Hapus pertemanan (unfriend)
  Future<bool> unfriend(String username) async {
    final resp = await ApiClient.instance.delete(ApiEndpoints.friendUnfriend(username));
    final d = resp.data;
    return d is Map && d['success'] == true;
  }

  /// Ambil daftar permintaan berteman (masuk & keluar)
  Future<Map<String, dynamic>> getFriendRequests() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.friendRequests);
      final d = resp.data;
      final authUser = TokenStore.savedUser;
      final myId = authUser?.id;
      final myUsername = authUser?.username;

      if (d is Map) {
        if (d['data'] is Map) {
          final data = Map<String, dynamic>.from(d['data']);
          final incoming = (data['incoming'] as List? ?? [])
              .map((e) => FriendRequestItem.fromJson(Map<String, dynamic>.from(e), myUsername: myUsername, myUserId: myId))
              .toList();
          final outgoing = (data['outgoing'] as List? ?? [])
              .map((e) => FriendRequestItem.fromJson(Map<String, dynamic>.from(e), myUsername: myUsername, myUserId: myId))
              .toList();
          return {
            'incoming': incoming,
            'outgoing': outgoing,
            'incoming_count': data['incoming_count'] ?? incoming.length,
            'outgoing_count': data['outgoing_count'] ?? outgoing.length,
          };
        } else if (d['data'] is List) {
          final list = d['data'] as List;
          final incoming = <FriendRequestItem>[];
          final outgoing = <FriendRequestItem>[];
          for (final e in list) {
            if (e is Map) {
              final item = FriendRequestItem.fromJson(
                Map<String, dynamic>.from(e),
                myUsername: myUsername,
                myUserId: myId,
              );
              if (item.isSender) {
                outgoing.add(item);
              } else {
                incoming.add(item);
              }
            }
          }
          return {
            'incoming': incoming,
            'outgoing': outgoing,
            'incoming_count': incoming.length,
            'outgoing_count': outgoing.length,
          };
        }
      }
      return {'incoming': <FriendRequestItem>[], 'outgoing': <FriendRequestItem>[]};
    } catch (_) {
      return {'incoming': <FriendRequestItem>[], 'outgoing': <FriendRequestItem>[]};
    }
  }

  /// Ambil daftar teman (mendukung akun sendiri dan user lain)
  Future<List<FriendUserItem>> getFriendsList({String? username}) async {
    try {
      final path = username != null && username.isNotEmpty
          ? ApiEndpoints.friendsListUser(username)
          : ApiEndpoints.friendsList;
      final resp = await ApiClient.instance.get(path);
      final d = resp.data;

      List rawList = [];
      if (d is List) {
        rawList = d;
      } else if (d is Map) {
        if (d['data'] is List) {
          rawList = d['data'] as List;
        } else if (d['data'] is Map && d['data']['friends'] is List) {
          rawList = d['data']['friends'] as List;
        } else if (d['friends'] is List) {
          rawList = d['friends'] as List;
        }
      }

      if (rawList.isNotEmpty) {
        final authUser = TokenStore.savedUser;
        final currentUserId = authUser?.id;
        final targetUser = (username != null && username.isNotEmpty)
            ? username
            : authUser?.username;

        final items = <FriendUserItem>[];
        for (final item in rawList) {
          if (item is Map) {
            final parsed = FriendUserItem.fromFriendshipRow(
              Map<String, dynamic>.from(item),
              targetUsername: targetUser,
              currentUserId: currentUserId,
            );
            if (parsed != null && parsed.username.isNotEmpty) {
              items.add(parsed);
            }
          }
        }
        return items;
      }
      return [];
    } catch (e) {
      debugPrint('[ProfileRepo] getFriendsList error: $e');
      return [];
    }
  }

  // ─── USER ACTIVITY API ───

  /// Ambil anime & komik favorit
  Future<Map<String, dynamic>> getUserFavorites(String username) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userFavorites(username));
      final d = resp.data;
      if (d is Map) {
        if (d['data'] is Map) {
          final data = Map<String, dynamic>.from(d['data']);
          final anime = (data['anime'] as List? ?? [])
              .whereType<Map>()
              .map((e) => UserAnimeFavorite.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          final comics = (data['comics'] as List? ?? [])
              .whereType<Map>()
              .map((e) => UserComicFavorite.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return {
            'anime': anime,
            'comics': comics,
            'total_anime': data['total_anime'] ?? anime.length,
            'total_comics': data['total_comics'] ?? comics.length,
            'has_profile_favorites': data['has_profile_favorites'] == true || anime.isNotEmpty || comics.isNotEmpty,
          };
        } else if (d['data'] is List) {
          final list = (d['data'] as List).whereType<Map>().toList();
          final anime = <UserAnimeFavorite>[];
          final comics = <UserComicFavorite>[];
          for (final item in list) {
            final m = Map<String, dynamic>.from(item);
            final type = m['type']?.toString().toLowerCase() ?? '';
            if (type == 'comic' || m.containsKey('comic_slug') || m.containsKey('chapter_slug')) {
              comics.add(UserComicFavorite.fromJson(m));
            } else {
              anime.add(UserAnimeFavorite.fromJson(m));
            }
          }
          return {
            'anime': anime,
            'comics': comics,
            'total_anime': anime.length,
            'total_comics': comics.length,
            'has_profile_favorites': anime.isNotEmpty || comics.isNotEmpty,
          };
        }
      }
      return {'anime': <UserAnimeFavorite>[], 'comics': <UserComicFavorite>[], 'has_profile_favorites': false};
    } catch (_) {
      return {'anime': <UserAnimeFavorite>[], 'comics': <UserComicFavorite>[], 'has_profile_favorites': false};
    }
  }

  /// Cek apakah anime/komik sudah disukai di profil
  Future<bool> checkProfileLiked({required String itemType, required String itemId}) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userProfileLikedCheck(itemType, itemId));
      final d = resp.data;
      if (d is Map && d['success'] == true) {
        return d['is_liked'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Toggle suka anime atau komik untuk profil
  Future<Map<String, dynamic>> toggleProfileLiked({
    required String itemType,
    required String itemId,
    required String title,
    String? thumbnail,
  }) async {
    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.userProfileLikedToggle,
        data: {
          'item_type': itemType,
          'item_id': itemId,
          'title': title,
          'thumbnail': thumbnail,
        },
      );
      final d = resp.data;
      if (d is Map && d['success'] == true) {
        return {
          'success': true,
          'is_liked': d['is_liked'] == true,
          'message': d['message']?.toString() ?? '',
        };
      }
      return {
        'success': false,
        'message': d is Map ? d['error']?.toString() ?? 'Gagal memproses' : 'Gagal memproses',
      };
    } catch (e) {
      return {
        'success': false,
        'message': errorMessage(e),
      };
    }
  }

  /// Hapus anime atau komik yang disukai di profil
  Future<bool> deleteProfileLiked(int favId) async {
    try {
      final resp = await ApiClient.instance.delete(ApiEndpoints.userProfileLikedDelete(favId));
      final d = resp.data;
      return d is Map && d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Ambil komentar user
  Future<List<UserCommentItem>> getUserComments(String username, {int page = 1, int perPage = 20}) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userComments(username, page: page, perPage: perPage));
      final d = resp.data;
      if (d is Map) {
        if (d['data'] is List) {
          return (d['data'] as List)
              .whereType<Map>()
              .map((e) => UserCommentItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (d['data'] is Map && d['data']['comments'] is List) {
          return (d['data']['comments'] as List)
              .whereType<Map>()
              .map((e) => UserCommentItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (d['comments'] is List) {
          return (d['comments'] as List)
              .whereType<Map>()
              .map((e) => UserCommentItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Ambil riwayat chat user
  Future<List<UserChatItem>> getUserChats(String username, {int page = 1, int perPage = 20}) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.userChats(username, page: page, perPage: perPage));
      final d = resp.data;
      if (d is Map) {
        if (d['data'] is List) {
          return (d['data'] as List)
              .whereType<Map>()
              .map((e) => UserChatItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (d['data'] is Map && d['data']['messages'] is List) {
          return (d['data']['messages'] as List)
              .whereType<Map>()
              .map((e) => UserChatItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (d['messages'] is List) {
          return (d['messages'] as List)
              .whereType<Map>()
              .map((e) => UserChatItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      final inner = data['data'] as Map;
      if (inner.containsKey('user') && inner['user'] is Map) {
        return inner['user'];
      }
      return inner;
    }
    if (data is Map && data.containsKey('user') && data['user'] is Map) {
      return data['user'];
    }
    return data;
  }

  String errorMessage(dynamic e) {
    return AppErrorFormatter.format(e, fallback: 'Terjadi kendala pada profil. Silakan coba lagi.');
  }
}
