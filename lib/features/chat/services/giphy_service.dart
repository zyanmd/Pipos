import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GiphyItem {
  final String id;
  final String title;
  final String originalUrl;
  final String previewUrl;
  final double? width;
  final double? height;

  const GiphyItem({
    required this.id,
    required this.title,
    required this.originalUrl,
    required this.previewUrl,
    this.width,
    this.height,
  });

  factory GiphyItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] is Map ? json['images'] as Map : const {};
    final original = images['original'] is Map ? images['original'] as Map : const {};
    final fixedHeight = images['fixed_height'] is Map ? images['fixed_height'] as Map : const {};
    final downsized = images['downsized'] is Map ? images['downsized'] as Map : const {};

    final origUrl = (original['url'] ?? downsized['url'] ?? fixedHeight['url'] ?? '').toString();
    final prevUrl = (fixedHeight['url'] ?? images['fixed_height_small']?['url'] ?? origUrl).toString();

    final w = double.tryParse((fixedHeight['width'] ?? original['width'])?.toString() ?? '');
    final h = double.tryParse((fixedHeight['height'] ?? original['height'])?.toString() ?? '');

    return GiphyItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'GIF').toString(),
      originalUrl: origUrl,
      previewUrl: prevUrl,
      width: w,
      height: h,
    );
  }
}

class GiphyService {
  GiphyService._();
  static final GiphyService instance = GiphyService._();

  static const String apiKey = 'jOe45nxPtOK3jrKPspDo6lZ5NCPfKlD0';
  static const String _baseUrl = 'https://api.giphy.com/v1/gifs';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Fetch trending GIFs from Giphy
  Future<List<GiphyItem>> getTrending({int offset = 0, int limit = 24, String rating = 'pg-13'}) async {
    try {
      final resp = await _dio.get(
        '$_baseUrl/trending',
        queryParameters: {
          'api_key': apiKey,
          'limit': limit,
          'offset': offset,
          'rating': rating,
        },
      );
      if (resp.data is Map && resp.data['data'] is List) {
        final list = resp.data['data'] as List;
        return list
            .whereType<Map>()
            .map((e) => GiphyItem.fromJson(Map<String, dynamic>.from(e)))
            .where((item) => item.originalUrl.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GiphyService] getTrending error: $e');
    }
    return [];
  }

  /// Search GIFs on Giphy
  Future<List<GiphyItem>> search({
    required String query,
    int offset = 0,
    int limit = 24,
    String rating = 'pg-13',
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getTrending(offset: offset, limit: limit, rating: rating);
    }
    try {
      final resp = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'api_key': apiKey,
          'q': cleanQuery,
          'limit': limit,
          'offset': offset,
          'rating': rating,
          'lang': 'id',
        },
      );
      if (resp.data is Map && resp.data['data'] is List) {
        final list = resp.data['data'] as List;
        return list
            .whereType<Map>()
            .map((e) => GiphyItem.fromJson(Map<String, dynamic>.from(e)))
            .where((item) => item.originalUrl.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GiphyService] search error: $e');
    }
    return [];
  }
}

