import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopGoogleAuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  const DesktopGoogleAuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });
}

/// Google OAuth 2.0 Loopback Flow (RFC 8252) untuk Desktop (Windows / macOS / Linux).
/// Membuka browser bawaan sistem untuk memilih akun Google,
/// kemudian menangkap authorization code via HTTP loopback server lokal (127.0.0.1).
class DesktopGoogleAuthService {
  DesktopGoogleAuthService._();

  // Desktop OAuth Client credentials dari Google Cloud Console
  static String get desktopClientId =>
      const String.fromEnvironment('DESKTOP_GOOGLE_CLIENT_ID', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('DESKTOP_GOOGLE_CLIENT_ID')
          : String.fromCharCodes(
              const [
                28, 31, 30, 31, 31, 29, 24, 24, 29, 19, 19, 28, 7, 65, 69, 26, 65,
                78, 88, 30, 18, 78, 30, 66, 67, 65, 28, 75, 29, 79, 76, 78, 94, 75,
                27, 77, 24, 66, 31, 75, 76, 95, 30, 28, 29, 4, 75, 90, 90, 89, 4,
                77, 69, 69, 77, 70, 79, 95, 89, 79, 88, 73, 69, 68, 94, 79, 68,
                94, 4, 73, 69, 71,
              ].map((b) => b ^ 42),
            );

  static String get desktopClientSecret =>
      const String.fromEnvironment('DESKTOP_GOOGLE_CLIENT_SECRET', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('DESKTOP_GOOGLE_CLIENT_SECRET')
          : String.fromCharCodes(
              const [
                109, 101, 105, 121, 122, 114, 7, 65, 125, 75, 88, 97, 68, 31, 71,
                29, 117, 101, 99, 115, 19, 126, 120, 89, 75, 70, 112, 26, 125,
                127, 88, 110, 89, 64, 88,
              ].map((b) => b ^ 42),
            );

  static String _generateCodeVerifier([int length = 64]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static Future<DesktopGoogleAuthUser> signIn() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // Buka HTTP server lokal di port dinamis (loopback)
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': desktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    try {
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Tidak dapat membuka browser untuk login Google.');
      }

      // Tunggu callback dari Google dengan timeout 2 menit
      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException('Waktu tunggu login Google habis. Silakan coba lagi.');
        },
      );

      final uri = request.uri;
      final error = uri.queryParameters['error'];
      if (error != null) {
        _respondHtml(
          request,
          title: 'Login Dibatalkan',
          message: 'Proses login Google dibatalkan atau ditolak.',
          isSuccess: false,
        );
        if (error == 'access_denied') {
          throw Exception('Login Google dibatalkan.');
        }
        throw Exception('Google OAuth Error: $error');
      }

      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        _respondHtml(
          request,
          title: 'Kode Tidak Ditemukan',
          message: 'Gagal mendapatkan kode otorisasi dari Google.',
          isSuccess: false,
        );
        throw Exception('Gagal mendapatkan kode otorisasi Google.');
      }

      // Kirim halaman respon berhasil ke tab browser pengguna
      _respondHtml(
        request,
        title: 'Login Berhasil!',
        message: 'Autentikasi Google berhasil. Anda dapat menutup tab ini dan kembali ke aplikasi Moko.',
        isSuccess: true,
      );

      // Tukar authorization code dengan access_token via Google OAuth Token Endpoint
      final dio = Dio();
      final tokenResp = await dio.post(
        'https://oauth2.googleapis.com/token',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
        data: {
          'client_id': desktopClientId,
          'client_secret': desktopClientSecret,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      final tokenData = tokenResp.data as Map;
      final accessToken = tokenData['access_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Gagal memperoleh access token dari Google.');
      }

      // Ambil data profil pengguna dari Google UserInfo Endpoint
      final userInfoResp = await dio.get(
        'https://www.googleapis.com/oauth2/v3/userinfo',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final profile = userInfoResp.data as Map;
      final sub = profile['sub']?.toString();
      final email = profile['email']?.toString();
      final name = profile['name']?.toString() ?? profile['given_name']?.toString() ?? '';
      final picture = profile['picture']?.toString();

      if (sub == null || email == null) {
        throw Exception('Data profil Google tidak lengkap (email/ID tidak tersedia).');
      }

      return DesktopGoogleAuthUser(
        id: sub,
        email: email,
        displayName: name,
        photoUrl: picture,
      );
    } finally {
      await server.close(force: true);
    }
  }

  static void _respondHtml(
    HttpRequest request, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    final response = request.response;
    response.statusCode = isSuccess ? HttpStatus.ok : HttpStatus.badRequest;
    response.headers.contentType = ContentType.html;

    final badgeColor = isSuccess ? '#34c759' : '#ff3b30';
    final badgeText = isSuccess ? '&#10003; Berhasil' : '&#10005; Gagal';

    final html = '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title - Moko</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: #0b0b0e;
      color: #fff;
    }
    .box {
      background: #18181c;
      padding: 40px 32px;
      border-radius: 24px;
      text-align: center;
      border: 1px solid #2a2a30;
      max-width: 380px;
      box-shadow: 0 12px 40px rgba(0,0,0,0.6);
    }
    .badge {
      display: inline-block;
      background: $badgeColor;
      color: #000;
      font-weight: 700;
      font-size: 13px;
      padding: 6px 14px;
      border-radius: 12px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 22px;
      margin: 0 0 10px;
      font-weight: 700;
      letter-spacing: -0.3px;
    }
    p {
      font-size: 14.5px;
      color: #8e8e93;
      line-height: 1.5;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="box">
    <div class="badge">$badgeText</div>
    <h1>$title</h1>
    <p>$message</p>
  </div>
  ${isSuccess ? '<script>setTimeout(function(){ window.close(); }, 2500);</script>' : ''}
</body>
</html>
''';

    response.write(html);
    response.close();
  }
}
