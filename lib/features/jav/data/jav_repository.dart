import '../../../core/network/api_client.dart';
import 'models/jav_model.dart';

class JavRepository {
  JavRepository._();
  static final JavRepository instance = JavRepository._();

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

  /// Get featured and latest JAV videos from Home
  Future<List<JavVideoModel>> getHome() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.javHome);
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get paginated videos with optional filter and sort
  Future<List<JavVideoModel>> getVideos({
    int page = 1,
    String? sort,
    String? type,
  }) async {
    try {
      final endpoint = ApiEndpoints.javVideos(
        page: page,
        sort: sort,
        type: type,
      );
      final resp = await ApiClient.instance.get(endpoint);
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Search videos on Javtiful
  Future<List<JavVideoModel>> search(
    String query, {
    int page = 1,
    String? sort,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final endpoint = ApiEndpoints.javSearch(
        query.trim(),
        page: page,
        sort: sort,
      );
      final resp = await ApiClient.instance.get(endpoint);
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get full video detail, streaming URL and related videos
  Future<JavDetailModel?> getDetail(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.javDetail(id.trim()));
      if (resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        if (map['data'] is Map<String, dynamic>) {
          return JavDetailModel.fromJson(map['data'] as Map<String, dynamic>);
        }
        return JavDetailModel.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get list of categories
  Future<List<JavCategoryModel>> getCategories() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.javCategories);
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavCategoryModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get list of popular actresses
  Future<List<JavActressModel>> getActresses() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.javActresses);
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavActressModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get actress details, bio stats, and her video catalog
  Future<JavActressDetailModel?> getActressDetail({
    required String slug,
    int page = 1,
    String? videoType,
    String? sort,
    String? q,
  }) async {
    if (slug.trim().isEmpty) return null;
    try {
      final endpoint = ApiEndpoints.javActressDetail(
        slug.trim(),
        page: page,
        videoType: videoType,
        sort: sort,
        q: q,
      );
      final resp = await ApiClient.instance.get(endpoint);
      if (resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        final d = map['data'];
        if (d is Map<String, dynamic>) {
          return JavActressDetailModel.fromJson(d);
        }
        return JavActressDetailModel.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get short preview reels / teasers for JAV
  Future<List<JavVideoModel>> getReels({int page = 1}) async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.javReels(page: page));
      final list = _asList(resp.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(JavVideoModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Helper to build stream proxy URL if direct Cloudflare R2 has CORS or expiration issues
  String getStreamProxyUrl(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    return '${ApiConfig.apiBase}${ApiEndpoints.javStreamProxy(videoUrl)}';
  }
}
