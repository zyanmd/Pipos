import '../../../core/network/api_client.dart';
import 'models/zpic_model.dart';

class ZpicRepository {
  ZpicRepository._();
  static final ZpicRepository instance = ZpicRepository._();

  dynamic _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) return data['data'];
    }
    return data;
  }

  List<dynamic> _asList(dynamic data) {
    final unwrapped = _unwrap(data);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map<String, dynamic>) {
      if (unwrapped.containsKey('videos') && unwrapped['videos'] is List) {
        return unwrapped['videos'] as List;
      }
      if (unwrapped.containsKey('items') && unwrapped['items'] is List) {
        return unwrapped['items'] as List;
      }
      if (unwrapped.containsKey('results') && unwrapped['results'] is List) {
        return unwrapped['results'] as List;
      }
      if (unwrapped.containsKey('data') && unwrapped['data'] is List) {
        return unwrapped['data'] as List;
      }
    }
    return [];
  }

  /// Get video list from Home (NSFW by default from Golang backend)
  Future<List<ZpicVideoModel>> getHome({int page = 1}) async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.zpicHomePaged(page: page),
      );
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(ZpicVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Search videos on zPic
  Future<List<ZpicVideoModel>> search(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.zpicSearchQuery(query, page: page),
      );
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(ZpicVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get video streaming details and source URLs
  Future<ZpicVideoModel?> getDetail(String videoId) async {
    if (videoId.trim().isEmpty) return null;
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.zpicDetail(videoId),
      );
      if (resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        // If wrapped in 'data'
        if (map['data'] is Map<String, dynamic>) {
          return ZpicVideoModel.fromJson(map['data'] as Map<String, dynamic>);
        }
        return ZpicVideoModel.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get random video
  Future<ZpicVideoModel?> getRandom() async {
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.zpicRandom,
      );
      if (resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        final data = map['data'];
        if (data is Map<String, dynamic>) {
          return ZpicVideoModel.fromJson(data);
        }
        return ZpicVideoModel.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
