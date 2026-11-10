import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// Centralized error message sanitizer that shields end users from technical,
/// debug stack traces, socket errors, Dio internals, video source URLs, and unparsed exceptions.
class AppErrorFormatter {
  AppErrorFormatter._();

  /// Convert any error or exception to a polite, reassuring Indonesian user message.
  static String format(dynamic error, {String? fallback}) {
    if (error == null) {
      return fallback ?? 'Terjadi kesalahan tidak terduga. Silakan coba lagi.';
    }

    // 1. DioException handling
    if (error is DioException) {
      return _formatDioError(error, fallback: fallback);
    }

    // 2. Core Dart network exceptions
    if (error is SocketException) {
      return 'Tidak dapat terhubung ke jaringan. Periksa koneksi internet Anda.';
    }
    if (error is HttpException) {
      return 'Gagal menghubungi server. Periksa koneksi internet Anda.';
    }
    if (error is TimeoutException) {
      return 'Waktu permintaan habis. Silakan coba beberapa saat lagi.';
    }
    if (error is FormatException) {
      return 'Format data tidak sesuai. Silakan muat ulang halaman.';
    }

    // 3. String / General Exception inspection
    final rawMsg = error.toString().trim();
    if (rawMsg.isEmpty) {
      return fallback ?? 'Terjadi kesalahan. Silakan coba lagi.';
    }

    return _sanitizeRawString(rawMsg, fallback: fallback);
  }

  /// Specialized video error sanitizer that NEVER exposes underlying video URLs,
  /// streaming hostnames, media player internals (MediaKit/libmpv), or provider endpoints.
  static String formatVideoError(dynamic error, {String? fallback}) {
    const defaultFallback = 'Gagal memutar video. Silakan coba ganti server atau kualitas lain.';

    if (error == null) {
      return fallback ?? defaultFallback;
    }

    final raw = error.toString().trim();
    final lower = raw.toLowerCase();

    // 1. Check for connection / network issues
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timeout') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out')) {
      return 'Koneksi terputus atau lambat. Periksa jaringan internet kamu.';
    }

    // 2. Check for security / SSL issues
    if (lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('tls') ||
        lower.contains('ssl')) {
      return 'Koneksi keamanan ke server video gagal. Silakan coba server lain.';
    }

    // 3. Check for forbidden / expired stream / geoblock / 403 / 401
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('access denied') ||
        lower.contains('unauthorized') ||
        lower.contains('401')) {
      return 'Akses video dibatasi oleh server. Silakan coba server cadangan atau ganti kualitas.';
    }

    // 4. Check for not found / 404
    if (lower.contains('404') || lower.contains('not found')) {
      return 'Video tidak ditemukan di server ini. Silakan coba server atau kualitas lain.';
    }

    // 5. Check for server errors / 5xx
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('bad gateway') ||
        lower.contains('internal server error')) {
      return 'Server video sedang sibuk atau offline. Silakan coba server lain.';
    }

    // 6. Check for media player internal errors (libmpv, MediaKit, codec, format)
    if (lower.contains('demux') ||
        lower.contains('codec') ||
        lower.contains('decoder') ||
        lower.contains('unsupported') ||
        lower.contains('corrupt') ||
        lower.contains('cannot open') ||
        lower.contains('failed to open') ||
        lower.contains('mediakit') ||
        lower.contains('libmpv') ||
        lower.contains('mpv')) {
      return 'Format video tidak didukung atau file bermasalah. Coba ganti server atau kualitas.';
    }

    // 7. DioException with status code
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == 401 || code == 403) {
        return 'Akses video dibatasi. Silakan coba server cadangan.';
      }
      if (code == 404) {
        return 'Video tidak ditemukan. Silakan coba server lain.';
      }
      if (code != null && code >= 500) {
        return 'Server video sedang bermasalah. Silakan coba server lain.';
      }
    }

    // 8. General formatting with strict URL/domain sanitization
    final formatted = format(error, fallback: fallback ?? defaultFallback);

    // If the formatted string still contains any URL, domain, or technical trace, return clean default!
    if (_containsUrlOrSource(formatted) || _isTechnicalDebugMessage(formatted)) {
      return fallback ?? defaultFallback;
    }

    return formatted;
  }

  static String _formatDioError(DioException error, {String? fallback}) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Silakan periksa jaringan internet Anda.';

      case DioExceptionType.badCertificate:
        return 'Koneksi keamanan ke server bermasalah.';

      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';

      case DioExceptionType.cancel:
        return 'Permintaan telah dibatalkan.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        // Check if server returned a human-readable error message
        if (data is Map) {
          final serverMsg = data['message'] ?? data['msg'] ?? data['error'] ?? data['detail'];
          if (serverMsg is String && serverMsg.trim().isNotEmpty) {
            final sanitized = _sanitizeRawString(serverMsg.trim(), fallback: null);
            if (sanitized.isNotEmpty && !_isTechnicalDebugMessage(serverMsg)) {
              return sanitized;
            }
          }
        } else if (data is String && data.trim().isNotEmpty) {
          if (!_isTechnicalDebugMessage(data)) {
            final sanitized = _sanitizeRawString(data.trim(), fallback: null);
            if (sanitized.isNotEmpty && !_isTechnicalDebugMessage(sanitized)) {
              return sanitized;
            }
          }
        }

        // Status code fallbacks
        if (statusCode == 401 || statusCode == 403) {
          return 'Sesi Anda telah berakhir atau akses ditolak. Silakan login kembali.';
        }
        if (statusCode == 404) {
          return 'Konten atau halaman yang Anda cari tidak ditemukan.';
        }
        if (statusCode == 429) {
          return 'Terlalu banyak permintaan. Harap tunggu beberapa saat.';
        }
        if (statusCode != null && statusCode >= 500) {
          return 'Server sedang sibuk atau dalam pemeliharaan. Coba lagi nanti.';
        }
        return fallback ?? 'Permintaan gagal diproses (${statusCode ?? "Error"}). Coba lagi nanti.';

      case DioExceptionType.unknown:
      default:
        if (error.error != null) {
          return format(error.error, fallback: fallback);
        }
        return fallback ?? 'Gagal memuat data. Periksa jaringan internet Anda.';
    }
  }

  static String _sanitizeRawString(String raw, {String? fallback}) {
    final lower = raw.toLowerCase();

    // Check for common socket / DNS / network traces
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }

    if (lower.contains('handshakeexception') ||
        lower.contains('certificate_verify_failed') ||
        lower.contains('tlsexception')) {
      return 'Gagal memverifikasi koneksi aman ke server.';
    }

    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Waktu permintaan habis. Silakan coba kembali.';
    }

    // Check for HTML response from server (e.g. Cloudflare error / 502 HTML)
    if (lower.contains('<!doctype html') ||
        lower.contains('<html') ||
        lower.contains('502 bad gateway') ||
        lower.contains('504 gateway time-out') ||
        lower.contains('cloudflare')) {
      return 'Layanan server sedang mengalami kendala sementara. Coba lagi nanti.';
    }

    // Check for Dart runtime / debug errors
    if (lower.contains('formatexception') ||
        lower.contains('unexpected character') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('null check operator') ||
        lower.contains('is not a subtype of') ||
        lower.contains('rangeerror') ||
        lower.contains('lateinitializationerror') ||
        lower.contains('stateerror') ||
        lower.contains('assertionfailed')) {
      return 'Terjadi kendala saat memproses data. Silakan muat ulang.';
    }

    // Strip "Exception: " or "Error: " prefix if present
    String cleaned = raw;
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    } else if (cleaned.startsWith('Error: ')) {
      cleaned = cleaned.substring('Error: '.length).trim();
    }

    // If cleaned string looks like a technical traceback, URL leak, or JSON blob, return fallback
    if (_isTechnicalDebugMessage(cleaned)) {
      return fallback ?? 'Terjadi kesalahan sistem. Silakan coba beberapa saat lagi.';
    }

    return cleaned;
  }

  /// Strictly checks if text exposes video sources, URLs, hostnames, stream paths, or debug traces.
  static bool _containsUrlOrSource(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('ftp://') ||
        lower.contains('rtmp://') ||
        lower.contains('://') ||
        lower.contains('.com') ||
        lower.contains('.net') ||
        lower.contains('.org') ||
        lower.contains('.io') ||
        lower.contains('.art') ||
        lower.contains('.xyz') ||
        lower.contains('.site') ||
        lower.contains('.click') ||
        lower.contains('.me') ||
        lower.contains('.co') ||
        lower.contains('.tv') ||
        lower.contains('.to') ||
        lower.contains('.cc') ||
        lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('pixeldrain') ||
        lower.contains('ylnime') ||
        lower.contains('nekopoi') ||
        lower.contains('blogger') ||
        lower.contains('googleusercontent') ||
        lower.contains('googleapis') ||
        lower.contains('libmpv') ||
        lower.contains('mediakit') ||
        lower.contains('ffmpeg')) {
      return true;
    }
    // Regex for any URI or URL pattern
    if (RegExp(r'https?://[^\s]+', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    return false;
  }

  static bool _isTechnicalDebugMessage(String msg) {
    final lower = msg.toLowerCase();
    return _containsUrlOrSource(msg) ||
        lower.contains('dioexception') ||
        lower.contains('stack trace') ||
        lower.contains('traceback') ||
        lower.contains('sqlstate') ||
        lower.contains('errno') ||
        lower.contains('line ') ||
        lower.contains('column ') ||
        lower.contains('package:') ||
        lower.contains('dart:') ||
        lower.contains('exception:') ||
        lower.contains('error:') ||
        lower.startsWith('{') ||
        lower.startsWith('[') ||
        lower.contains('<script') ||
        lower.contains('<div') ||
        lower.contains('unhandled') ||
        lower.contains('failed to open') ||
        lower.contains('cannot open');
  }
}
