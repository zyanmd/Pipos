import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import 'models/reel_model.dart';

class ReelsRepository {
  ReelsRepository._();
  static final ReelsRepository instance = ReelsRepository._();

  final Dio _fallbackDio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.apiBase,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ),
  );

  Dio get _client {
    try {
      return ApiClient.instance;
    } catch (_) {
      return _fallbackDio;
    }
  }

  /// Fetch list of reels from Go backend (/api/ylnime/reels)
  Future<ReelPagination> getReels({int page = 1, int limit = 10}) async {
    final endpoint = ApiEndpoints.ylnimeReelsPaged(page: page, limit: limit);
    final fullUrl = '${ApiConfig.apiBase}$endpoint';
    try {
      final response = await _client.get(
        fullUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        return ReelPagination.fromJson(data);
      } else if (data is Map) {
        return ReelPagination.fromJson(Map<String, dynamic>.from(data));
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return ReelPagination.fromJson(decoded);
        } else if (decoded is Map) {
          return ReelPagination.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      debugPrint('Reels fetch primary error: $e');
      try {
        final response = await _fallbackDio.get(fullUrl);
        final dynamic data = response.data;
        if (data is Map) {
          return ReelPagination.fromJson(Map<String, dynamic>.from(data));
        }
      } catch (err2) {
        debugPrint('Reels fetch fallback error: $err2');
      }
    }
    return const ReelPagination(items: [], hasMore: true);
  }

  /// Fetch a single random reel from Go backend (/api/ylnime/reels/random)
  Future<ReelModel?> getRandomReel() async {
    const endpoint = ApiEndpoints.ylnimeReelsRandom;
    try {
      final response = await _client.get(
        endpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      final dynamic data = response.data;
      if (data is Map && data['data'] is Map) {
        return ReelModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['data'] is Map) {
          return ReelModel.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
        }
      }
    } catch (e) {
      debugPrint('Reels getRandomReel primary error: $e');
      try {
        final fullUrl = '${ApiConfig.apiBase}$endpoint';
        final response = await _fallbackDio.get(fullUrl);
        final dynamic data = response.data;
        if (data is Map && data['data'] is Map) {
          return ReelModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
        }
      } catch (err2) {
        debugPrint('Reels getRandomReel fallback error: $err2');
      }
    }
    return null;
  }

  /// Like/unlike a reel via backend Go API (/api/ylnime/reels/{id}/like)
  Future<({bool success, bool isLiked, int likes})> toggleLike(String reelId) async {
    final endpoint = ApiEndpoints.ylnimeReelsLike(reelId);
    try {
      final response = await _client.post(
        endpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      final dynamic data = response.data;
      if (data is Map) {
        final isLiked = data['is_liked'] == true || data['liked'] == true;
        final likes = int.tryParse(data['total_likes']?.toString() ?? data['likes']?.toString() ?? '0') ?? 0;
        return (success: data['success'] == true, isLiked: isLiked, likes: likes);
      }
    } catch (e) {
      debugPrint('Reels toggleLike primary error: $e');
      try {
        final fullUrl = '${ApiConfig.apiBase}$endpoint';
        final response = await _fallbackDio.post(fullUrl);
        final dynamic data = response.data;
        if (data is Map) {
          final isLiked = data['is_liked'] == true || data['liked'] == true;
          final likes = int.tryParse(data['total_likes']?.toString() ?? data['likes']?.toString() ?? '0') ?? 0;
          return (success: data['success'] == true, isLiked: isLiked, likes: likes);
        }
      } catch (err2) {
        debugPrint('Reels toggleLike fallback error: $err2');
      }
    }
    return (success: false, isLiked: false, likes: 0);
  }
}

