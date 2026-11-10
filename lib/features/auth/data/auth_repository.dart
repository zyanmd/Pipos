import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/desktop_google_auth_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import './models/user_model.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '654557227996-vurfir2n689tkhcdde2mjlmbqegehgq9.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final resp = await ApiClient.instance.post(
      ApiEndpoints.authRegister,
      data: {
        'username': username,
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
      },
    );
    return _parseAuth(resp.data);
  }

  Future<AuthSession> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final resp = await ApiClient.instance.post(
      ApiEndpoints.authLogin,
      data: {
        // Backend uses `email` field — but accepts username too based on auth_routes.
        'email': emailOrUsername,
        'password': password,
      },
    );
    return _parseAuth(resp.data);
  }

  /// Sign in with Google on Desktop (RFC 8252 Loopback) or Android/iOS (GoogleSignIn).
  /// Returns the authenticated email, googleId, and optional displayName.
  Future<({String email, String googleId, String? displayName})> signInWithGoogleAccount() async {
    final String email;
    final String googleId;
    final String? displayName;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Windows / Desktop: Gunakan RFC 8252 Loopback OAuth Flow
      final desktopUser = await DesktopGoogleAuthService.signIn();
      email = desktopUser.email;
      googleId = desktopUser.id;
      displayName = desktopUser.displayName;
    } else {
      // Android / iOS: Gunakan Google Play Services native
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Login Google dibatalkan.');
      }
      email = account.email;
      googleId = account.id;
      displayName = account.displayName;
    }

    return (email: email, googleId: googleId, displayName: displayName);
  }

  Future<AuthSession> loginWithGoogle() async {
    final gAuth = await signInWithGoogleAccount();
    final email = gAuth.email;
    final googleId = gAuth.googleId;
    final displayName = gAuth.displayName;

    // Prepare payload matching routes/auth_routes.py (/api/auth/google-login)
    final rawName = displayName?.trim() ?? '';
    final rawUsername = rawName.isNotEmpty
        ? rawName.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        : email.split('@').first;
    final username = rawUsername.isNotEmpty ? rawUsername : 'user_${googleId.substring(0, 6)}';

    final resp = await ApiClient.instance.post(
      ApiEndpoints.authGoogleLogin,
      data: {
        'email': email,
        'google_id': googleId,
        'username': username,
      },
    );
    return _parseAuth(resp.data);
  }

  Future<UserModel> me() async {
    final resp = await ApiClient.instance.get(ApiEndpoints.authMe);
    final data = resp.data;
    // Server returns user data possibly under 'user' or at top level.
    final u = (data is Map && data.containsKey('user')) ? data['user'] : data;
    return UserModel.fromJson(Map<String, dynamic>.from(u as Map));
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.post(ApiEndpoints.authLogout);
    } catch (e) {
      debugPrint('Logout request failed (ignored): $e');
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (_) {}
    }
    await TokenStore.clear();
  }

  Future<void> resendVerification(String email) async {
    final cleanEmail = email.trim();
    try {
      await ApiClient.instance.post(
        ApiEndpoints.authResendVerification,
        data: {'email': cleanEmail},
      );
    } catch (_) {
      try {
        await ApiClient.instance.post(
          ApiEndpoints.authResendOtp,
          data: {'email': cleanEmail},
        );
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> verifyEmail(String code, String email) async {
    final cleanCode = code.trim();
    final cleanEmail = email.trim();
    try {
      await ApiClient.instance.post(
        ApiEndpoints.authVerifyEmail,
        data: {
          'code': cleanCode,
          'otp': cleanCode,
          'token': cleanCode,
          'email': cleanEmail,
        },
      );
    } catch (e) {
      try {
        await ApiClient.instance.post(
          ApiEndpoints.authVerifyOtp,
          data: {
            'code': cleanCode,
            'otp': cleanCode,
            'email': cleanEmail,
          },
        );
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> forgotPassword(String email) async {
    await ApiClient.instance.post(
      ApiEndpoints.authForgotPassword,
      data: {'email': email},
    );
  }

  Future<String?> verifyOtp(String email, String code) async {
    final cleanEmail = email.trim();
    final cleanCode = code.trim();
    final res = await ApiClient.instance.post(
      ApiEndpoints.authVerifyOtp,
      data: {
        'email': cleanEmail,
        'code': cleanCode,
      },
    );

    final data = res.data;
    if (data is Map) {
      if (data['data'] is Map) {
        final inner = Map<String, dynamic>.from(data['data'] as Map);
        final token = inner['reset_token'] ?? inner['token'];
        if (token != null && token.toString().isNotEmpty) {
          return token.toString();
        }
      }
      final token = data['reset_token'] ?? data['token'];
      if (token != null && token.toString().isNotEmpty) {
        return token.toString();
      }
    }
    return null;
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String token,
  }) async {
    await ApiClient.instance.post(
      ApiEndpoints.authResetPassword,
      data: {
        'email': email.trim(),
        'new_password': newPassword,
        'token': token.trim(),
      },
    );
  }

  Future<void> resendOtp(String email) async {
    await ApiClient.instance.post(
      ApiEndpoints.authResendOtp,
      data: {'email': email},
    );
  }

  AuthSession _parseAuth(dynamic data) {
    final j = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    // Handle both shapes: { user, access_token, refresh_token } or { data: {...} }
    final payload = j.containsKey('data') && j['data'] is Map
        ? Map<String, dynamic>.from(j['data'] as Map)
        : j;
    return AuthSession.fromJson(payload);
  }

  String errorMessage(dynamic e) {
    if (e != null) {
      final str = e.toString();
      if (str.contains('10') || str.contains('ApiException: 10')) {
        return 'Gagal menghubungkan Google (Code 10: Developer Error). Pastikan SHA-1 dan package name com.moko.app sudah sesuai di Google Cloud.';
      }
      if (str.contains('12500')) {
        return 'Gagal menghubungkan Google (Code 12500). Pastikan OAuth Consent Screen sudah dikonfigurasi di Google Cloud Console.';
      }
      if (str.contains('network_error') || str.contains('7:')) {
        return 'Koneksi ke layanan Google bermasalah. Periksa jaringan Anda.';
      }
      if (str.contains('MissingPluginException')) {
        return 'Aplikasi perlu di-restart penuh (Stop & Run ulang) agar plugin Google aktif.';
      }
      if (str.contains('PlatformException')) {
        return str;
      }
    }
    return AppErrorFormatter.format(e, fallback: 'Terjadi kesalahan saat otentikasi. Silakan coba lagi.');
  }
}
