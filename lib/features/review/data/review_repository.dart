import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../profile/data/profile_repository.dart';
import 'models/user_review_model.dart';

class ReviewRepository {
  ReviewRepository._();
  static final ReviewRepository instance = ReviewRepository._();

  /// Ambil ulasan (scope: 'community' | 'friends' | 'mine', filter itemType: 'anime' | 'comic', sort: 'latest' | 'popular' | 'random')
  Future<List<UserReviewModel>> getReviews({
    String? itemType,
    String? scope, // 'community' | 'friends' | 'mine'
    String? sort, // 'latest' | 'popular' | 'random'
    String? status,
    String? targetId,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'scope': scope ?? 'community',
      };
      if (sort != null && sort.isNotEmpty) {
        query['sort'] = sort;
      }
      if (itemType != null && itemType.isNotEmpty && itemType != 'all') {
        query['type'] = itemType;
      }
      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }
      if (targetId != null && targetId.isNotEmpty) {
        query['target_id'] = targetId;
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.reviews,
        queryParameters: query,
      );

      List<UserReviewModel> result = [];
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['data'] as List<dynamic>? ?? [];
        result = list
            .map((e) => UserReviewModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      // Jika scope == 'friends':
      // Pastikan hasil benar-benar dari teman (baik didukung langsung oleh server,
      // maupun fallback filter cerdas berbasis pertemanan lokal).
      if (scope == 'friends') {
        final friends = await ProfileRepository.instance.getFriendsList();
        final friendNames = friends
            .map((f) => f.username.trim().toLowerCase())
            .where((u) => u.isNotEmpty)
            .toSet();
        final friendIds = friends.map((f) => f.id).where((id) => id > 0).toSet();

        if (friendNames.isEmpty && friendIds.isEmpty) {
          // Pengguna belum memiliki teman
          return [];
        }

        final hasNonFriends = result.any(
          (r) =>
              !friendNames.contains((r.username ?? '').trim().toLowerCase()) &&
              !friendIds.contains(r.userId),
        );

        // Jika backend belum memfilter teman di server atau mengembalikan semua feed,
        // fallback ambil ulasan komunitas lalu saring khusus teman
        if (hasNonFriends || result.isEmpty) {
          final communityQuery = Map<String, dynamic>.from(query);
          communityQuery['scope'] = 'community';
          communityQuery['per_page'] = 100;
          final commResp = await ApiClient.instance.get(
            ApiEndpoints.reviews,
            queryParameters: communityQuery,
          );
          if (commResp.statusCode == 200 && commResp.data != null) {
            final commList = commResp.data['data'] as List<dynamic>? ?? [];
            final allReviews = commList
                .map((e) => UserReviewModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            final filtered = allReviews.where((r) {
              final uname = (r.username ?? '').trim().toLowerCase();
              return friendNames.contains(uname) || friendIds.contains(r.userId);
            }).toList();
            if (filtered.isNotEmpty) {
              return filtered;
            }
          }
          return result.where((r) {
            final uname = (r.username ?? '').trim().toLowerCase();
            return friendNames.contains(uname) || friendIds.contains(r.userId);
          }).toList();
        }
      }

      return result;
    } catch (_) {}
    return [];
  }

  /// Cek apakah suatu target (anime/episode/komik/chapter) sudah diulas
  Future<UserReviewModel?> checkReview({
    required String targetId,
    String? subId,
  }) async {
    try {
      final query = <String, dynamic>{'target_id': targetId};
      if (subId != null && subId.isNotEmpty) {
        query['sub_id'] = subId;
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.reviewCheck,
        queryParameters: query,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['is_reviewed'] == true && response.data['review'] != null) {
          return UserReviewModel.fromJson(
            Map<String, dynamic>.from(response.data['review'] as Map),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Simpan atau update ulasan (Support teks saja, atau lampiran foto/GIF)
  Future<UserReviewModel?> saveReview({
    required String itemType,
    required String targetId,
    required String targetTitle,
    String? targetCover,
    String? subId,
    String? subTitle,
    String? content,
    double rating = 0.0,
    String status = 'completed',
    File? mediaFile,
    String? mediaUrl,
  }) async {
    try {
      dynamic dataPayload;

      if (mediaFile != null && await mediaFile.exists()) {
        final fileName = mediaFile.path.split(Platform.pathSeparator).last;
        dataPayload = FormData.fromMap({
          'item_type': itemType,
          'target_id': targetId,
          'target_title': targetTitle,
          if (targetCover != null) 'target_cover': targetCover,
          if (subId != null) 'sub_id': subId,
          if (subTitle != null) 'sub_title': subTitle,
          if (content != null) 'content': content,
          'rating': rating,
          'status': status,
          'media_file': await MultipartFile.fromFile(
            mediaFile.path,
            filename: fileName,
          ),
        });
      } else {
        dataPayload = {
          'item_type': itemType,
          'target_id': targetId,
          'target_title': targetTitle,
          if (targetCover != null) 'target_cover': targetCover,
          if (subId != null) 'sub_id': subId,
          if (subTitle != null) 'sub_title': subTitle,
          if (content != null) 'content': content,
          'rating': rating,
          'status': status,
          'media_url': mediaUrl,
        };
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.reviews,
        data: dataPayload,
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final resData = response.data['data'];
        if (resData is Map) {
          return UserReviewModel.fromJson(Map<String, dynamic>.from(resData));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Hapus ulasan
  Future<bool> deleteReview(int reviewId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.reviewDetail(reviewId),
      );
      return response.statusCode == 200 && response.data?['success'] == true;
    } catch (_) {}
    return false;
  }

  /// Toggle like ulasan
  Future<Map<String, dynamic>?> toggleLike(int reviewId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.reviewLike(reviewId),
      );
      if (response.statusCode == 200 && response.data != null) {
        return {
          'liked': response.data['liked'] == true,
          'likes_count': response.data['likes_count'] is int
              ? response.data['likes_count'] as int
              : int.tryParse('${response.data['likes_count']}') ?? 0,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Ambil daftar komentar untuk ulasan tertentu
  Future<List<UserReviewCommentModel>> getComments(int reviewId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.reviewComments(reviewId),
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['data'] as List<dynamic>? ?? [];
        return list
            .map((e) => UserReviewCommentModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Tambah komentar pada ulasan
  Future<UserReviewCommentModel?> addComment(int reviewId, String content) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.reviewComments(reviewId),
        data: {'content': content},
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final commentData = response.data['data'];
        if (commentData is Map) {
          return UserReviewCommentModel.fromJson(Map<String, dynamic>.from(commentData));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Hapus komentar ulasan
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.reviewCommentDelete(commentId),
      );
      return response.statusCode == 200 && response.data?['success'] == true;
    } catch (_) {}
    return false;
  }
}
