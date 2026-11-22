import 'dart:io' show Platform, HttpServer, HttpRequest, HttpStatus, ContentType, InternetAddress;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/mal_service.dart';

/// In-App WebView untuk login MyAnimeList via OAuth 2.0 PKCE (Mobile)
/// atau Desktop Browser Dialog (Windows / macOS / Linux / Web)
class MalOAuthWebView extends StatefulWidget {
  const MalOAuthWebView({super.key});

  static const String redirectUri = 'http://localhost/mal-callback';

  static Future<bool?> show(BuildContext context) {
    if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const DesktopMalAuthDialog(),
      );
    }
    return showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MalOAuthWebView(),
    );
  }

  @override
  State<MalOAuthWebView> createState() => _MalOAuthWebViewState();
}

class _MalOAuthWebViewState extends State<MalOAuthWebView> {
  late final WebViewController _controller;
  late final String _codeVerifier;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeVerifier = MalService.generateCodeVerifier();
    final authUrl = MalService.instance.getAuthorizationUrl(
      codeVerifier: _codeVerifier,
      redirectUri: MalOAuthWebView.redirectUri,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            // Abaikan error koneksi saat redirect ke localhost
            if (error.url?.startsWith(MalOAuthWebView.redirectUri) != true) {
              setState(() => _errorMessage = error.description);
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(MalOAuthWebView.redirectUri)) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<void> _handleRedirect(String url) async {
    setState(() => _isLoading = true);
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];

    if (code != null && code.isNotEmpty) {
      final success = await MalService.instance.exchangeAuthCode(
        code: code,
        codeVerifier: _codeVerifier,
        redirectUri: MalOAuthWebView.redirectUri,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Gagal menukarkan token otorisasi MAL.';
          });
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag indicator handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masuk ke MyAnimeList',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'Otorisasi resmi untuk sinkronisasi otomatis',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const CupertinoActivityIndicator(radius: 10),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Content / WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton.filled(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog otorisasi MyAnimeList ramah Desktop (Windows, macOS, Linux, Web)
/// Otorisasi Otomatis 100% via Local Loopback Server di Browser Default
class DesktopMalAuthDialog extends StatefulWidget {
  const DesktopMalAuthDialog({super.key});

  @override
  State<DesktopMalAuthDialog> createState() => _DesktopMalAuthDialogState();
}

class _DesktopMalAuthDialogState extends State<DesktopMalAuthDialog> {
  late final String _codeVerifier;
  late final String _authUrl;
  HttpServer? _loopbackServer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeVerifier = MalService.generateCodeVerifier();
    _authUrl = MalService.instance.getAuthorizationUrl(
      codeVerifier: _codeVerifier,
      redirectUri: MalOAuthWebView.redirectUri,
    );
    _startAutoOAuth();
  }

  @override
  void dispose() {
    _loopbackServer?.close(force: true);
    super.dispose();
  }

  Future<void> _startAutoOAuth() async {
    try {
      _loopbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 80);
      _listenToLoopback();
    } catch (_) {}
    await _openBrowser();
  }

  void _listenToLoopback() {
    _loopbackServer?.listen((request) async {
      final uri = request.uri;
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (code != null && code.isNotEmpty) {
        _respondHtml(
          request,
          title: 'Otorisasi Berhasil!',
          message: 'Akun MyAnimeList berhasil terhubung. Anda dapat menutup tab ini dan kembali ke aplikasi Moko.',
          isSuccess: true,
        );
        await _loopbackServer?.close();

        if (mounted) {
          setState(() => _isLoading = true);
          final success = await MalService.instance.exchangeAuthCode(
            code: code,
            codeVerifier: _codeVerifier,
            redirectUri: MalOAuthWebView.redirectUri,
          );
          if (mounted) {
            if (success) {
              Navigator.of(context).pop(true);
            } else {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Gagal menukarkan token otorisasi MAL.';
              });
            }
          }
        }
      } else if (error != null) {
        _respondHtml(
          request,
          title: 'Otorisasi Dibatalkan',
          message: 'Proses otorisasi MyAnimeList dibatalkan.',
          isSuccess: false,
        );
        await _loopbackServer?.close();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Otorisasi dibatalkan di browser.';
          });
        }
      }
    });
  }

  void _respondHtml(
    HttpRequest request, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    try {
      final response = request.response;
      response.statusCode = isSuccess ? HttpStatus.ok : HttpStatus.badRequest;
      response.headers.contentType = ContentType.html;
      final badgeColor = isSuccess ? '#34c759' : '#ff3b30';
      final icon = isSuccess ? '&#10004;' : '&#10008;';

      response.write('''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
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
      max-width: 400px;
      box-shadow: 0 12px 40px rgba(0,0,0,0.6);
    }
    .icon {
      font-size: 48px;
      color: $badgeColor;
      margin-bottom: 12px;
    }
    h1 {
      font-size: 22px;
      margin: 0 0 10px;
      font-weight: 700;
    }
    p {
      font-size: 14px;
      color: #8e8e93;
      line-height: 1.5;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="box">
    <div class="icon">$icon</div>
    <h1>$title</h1>
    <p>$message</p>
  </div>
</body>
</html>
''');
      response.close();
    } catch (_) {}
  }

  Future<void> _openBrowser() async {
    final uri = Uri.parse(_authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.link, color: Color(0xFF2E51A2), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hubungkan MyAnimeList',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Login via browser default Anda',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, size: 18, color: isDark ? Colors.white60 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2E51A2))
                            : const CupertinoActivityIndicator(radius: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isLoading ? 'Menghubungkan Akun...' : 'Menunggu Otorisasi di Browser...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Halaman login MyAnimeList telah dibuka di browser Anda.\n'
                    'Cukup klik "Allow" / "Authorize" di browser, aplikasi akan otomatis mendeteksi dan menyelesaikan login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _openBrowser,
                    icon: const Icon(CupertinoIcons.compass, size: 16),
                    label: const Text('Buka Ulang Browser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E51A2),
                      side: const BorderSide(color: Color(0xFF2E51A2)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
