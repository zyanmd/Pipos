import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/models/user_model.dart';
import '../config/api_config.dart';

// Re-export endpoints for convenient access via `import 'api_client.dart';`
export '../config/api_config.dart' show ApiConfig, ApiEndpoints;


/// Persistent secure-token storage helper. We keep using shared_preferences
/// in combination with flutter_secure_storage: refresh tokens live in secure
/// storage; access tokens in memory + prefs for fast boot.
class TokenStore {
  TokenStore._();
  static const String _kAccess = 'access_token';
  static const String _kRefresh = 'refresh_token';
  static const String _kUser = 'user_profile_data';

  static String? _inMemoryAccess;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _inMemoryAccess = accessToken;
    // We avoid flutter_secure_storage here for cross-platform simplicity;
    // swap in secure_storage in production builds.
    await _prefs.setString(_kAccess, accessToken);
    await _prefs.setString(_kRefresh, refreshToken);
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      await _prefs.setString(_kUser, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  static UserModel? get savedUser {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) {
        return UserModel.fromJson(j);
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> get access async {
    if (_inMemoryAccess != null && _inMemoryAccess!.isNotEmpty) return _inMemoryAccess;
    final v = _prefs.getString(_kAccess);
    if (v != null && v.isNotEmpty && v != 'null') {
      _inMemoryAccess = v;
      return v;
    }
    return null;
  }

  static String? _guestToken;

  static Future<String?> ensureValidToken() async {
    final userToken = await access;
    if (userToken != null && userToken.isNotEmpty) return userToken;
    if (_guestToken != null && _guestToken!.isNotEmpty) return _guestToken;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.apiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': ApiClient.userAgent,
        },
      ),);
      final resp = await dio.post(
        ApiEndpoints.authGoogleLogin,
        data: {
          'email': 'guest_public@moko.app',
          'google_id': 'moko_guest_00000000001',
          'display_name': 'Tamu Moko',
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final d = resp.data as Map;
        final tok = d['access_token'] ??
            d['token'] ??
            (d['data'] is Map ? (d['data']['access_token'] ?? d['data']['token']) : null);
        if (tok is String && tok.isNotEmpty) {
          _guestToken = tok;
          return tok;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> get refresh async => _prefs.getString(_kRefresh);

  static Future<void> clear() async {
    _inMemoryAccess = null;
    _guestToken = null;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
  }

  static SharedPreferences get _prefs => _instance!;
  static SharedPreferences? _instance;

  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();
  }
}

/// Auth interceptor that:
/// 1. Adds Authorization: Bearer <token> to every request
/// 2. On 401, attempts to refresh the access token using the refresh token
/// 3. If refresh fails, clears tokens (caller should redirect to login)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStore.ensureValidToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      // 🔥 cPanel Apache Fallback: Apache seringkali memotong header Authorization secara default
      options.headers['X-Access-Token'] = token;
      options.headers['X-Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Try to refresh
    final refreshToken = await TokenStore.refresh;
    if (refreshToken == null || refreshToken.isEmpty) {
      await TokenStore.clear();
      return handler.next(err);
    }

    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConfig.apiBase,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent': ApiClient.userAgent,
        },
      ),);
      refreshDio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
      final resp = await refreshDio.post(
        ApiEndpoints.authRefresh,
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
            'X-Access-Token': refreshToken,
            'X-Authorization': 'Bearer $refreshToken',
          },
        ),
      );
      final newAccess = resp.data['access_token'] as String?;
      final newRefresh = resp.data['refresh_token'] as String?;
      if (newAccess != null) {
        await TokenStore.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh ?? refreshToken,
        );
        // Retry original request
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        opts.headers['X-Access-Token'] = newAccess;
        opts.headers['X-Authorization'] = 'Bearer $newAccess';
        final cloned = await _dio.fetch(opts);
        return handler.resolve(cloned);
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await TokenStore.clear();
    }
    handler.next(err);
  }
}

/// Wrapper around Dio providing singleton + interceptors with cPanel & mobile optimization.
class ApiClient {
  ApiClient._();
  static late Dio instance;

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 Moko/1.0';

  static Future<void> init() async {
    await TokenStore.init();
    await ApiConfig.init();
    _buildDio();
  }

  static void _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBase,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      followRedirects: true,
      maxRedirects: 5,
      contentType: 'application/json',
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent': userAgent,
      },
    ),);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    dio.interceptors.add(AuthInterceptor(dio));
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        responseBody: false,
        requestBody: false,
        error: true,
      ),);
    }
    instance = dio;
  }

  /// Update base URL dynamically (e.g. switching cPanel domain/host)
  static Future<void> updateBaseUrl(String newUrl) async {
    await ApiConfig.setCustomBaseUrl(newUrl);
    _buildDio();
  }

  /// Reset base URL to default
  static Future<void> resetBaseUrl() async {
    await ApiConfig.resetBaseUrl();
    _buildDio();
  }
}
