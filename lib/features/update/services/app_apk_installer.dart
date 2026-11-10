import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Service for downloading and installing APKs directly in-app on Android.
class AppApkInstaller {
  AppApkInstaller._();
  static final AppApkInstaller instance = AppApkInstaller._();

  static const MethodChannel _channel = MethodChannel('com.moko.app/updater');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
      maxRedirects: 10,
      headers: {
        'User-Agent': 'Moko-InAppUpdater (Android; Mobile)',
        'Accept': '*/*',
      },
    ),
  );

  /// Check if the platform is Android
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Get supported ABIs from Android (e.g. ['arm64-v8a', 'armeabi-v7a'])
  Future<List<String>> getSupportedAbis() async {
    if (!isAndroid) return [];
    try {
      final List<dynamic>? abis = await _channel.invokeMethod<List<dynamic>>('getSupportedAbis');
      return abis?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('[AppApkInstaller] getSupportedAbis error: $e');
      return [];
    }
  }

  /// Check if the app has permission to install unknown apps (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (!isAndroid) return false;
    try {
      final bool? allowed = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (e) {
      debugPrint('[AppApkInstaller] canRequestPackageInstalls error: $e');
      return true;
    }
  }

  /// Open Android system settings to grant "Install Unknown Apps" permission
  Future<void> openInstallPermissionSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('[AppApkInstaller] openInstallPermissionSettings error: $e');
    }
  }

  /// Install downloaded APK file via native Android PackageInstaller
  Future<bool> installApk(String filePath) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AppApkInstaller] installApk error: $e');
      return false;
    }
  }

  /// Resolves the direct APK download URL.
  /// 
  /// If [url] is already a direct `.apk` URL, returns it immediately.
  /// If [url] is a GitHub release page, queries the GitHub API to find the best
  /// APK asset matching the device's CPU architecture (e.g. arm64-v8a vs armeabi-v7a).
  Future<String> resolveDirectApkUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.toLowerCase().endsWith('.apk')) {
      return cleanUrl;
    }

    // Check if URL is from GitHub
    final ghMatch = RegExp(r'github\.com/([^/]+)/([^/]+)(?:/releases(?:/tag/([^/?#]+))?)?').firstMatch(cleanUrl);
    if (ghMatch != null) {
      final owner = ghMatch.group(1);
      final repo = ghMatch.group(2);
      final tag = ghMatch.group(3);

      final apiUrl = (tag != null && tag.isNotEmpty && tag != 'latest')
          ? 'https://api.github.com/repos/$owner/$repo/releases/tags/$tag'
          : 'https://api.github.com/repos/$owner/$repo/releases/latest';

      try {
        final resp = await _dio.get<Map<String, dynamic>>(
          apiUrl,
          options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
        );
        if (resp.statusCode == 200 && resp.data != null) {
          final assets = resp.data!['assets'] as List<dynamic>?;
          if (assets != null && assets.isNotEmpty) {
            final abis = await getSupportedAbis();
            final directUrl = _selectBestApkAsset(assets, abis);
            if (directUrl != null && directUrl.isNotEmpty) {
              return directUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('[AppApkInstaller] Failed to resolve GitHub release assets: $e');
      }
    }

    // Default fallback
    return cleanUrl;
  }

  /// Pick the best APK from a list of GitHub release assets based on device ABI
  String? _selectBestApkAsset(List<dynamic> assets, List<String> abis) {
    final apkAssets = assets.where((a) {
      final name = (a['name']?.toString() ?? '').toLowerCase();
      return name.endsWith('.apk');
    }).toList();

    if (apkAssets.isEmpty) return null;

    // Check device supported ABIs in order of preference
    for (final abi in abis) {
      final abiClean = abi.toLowerCase();
      for (final asset in apkAssets) {
        final name = (asset['name']?.toString() ?? '').toLowerCase();
        if (name.contains(abiClean)) {
          return asset['browser_download_url']?.toString();
        }
      }
    }

    // Default architecture heuristic: prefer arm64-v8a if modern, else universal or any
    for (final asset in apkAssets) {
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      if (name.contains('arm64') || name.contains('v8a')) {
        return asset['browser_download_url']?.toString();
      }
    }

    // Pick first available APK
    return apkAssets.first['browser_download_url']?.toString();
  }

  /// Downloads the APK to temporary directory with progress tracking.
  Future<String> downloadApk({
    required String downloadUrl,
    required void Function(int receivedBytes, int totalBytes) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'moko_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    final savePath = '${tempDir.path}/$fileName';

    // Delete existing stale APK files from tempDir
    try {
      final dir = Directory(tempDir.path);
      final files = dir.listSync();
      for (final f in files) {
        if (f is File && f.path.contains('moko_update') && f.path.endsWith('.apk')) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}

    await _dio.download(
      downloadUrl,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
      ),
    );

    final file = File(savePath);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Berkas APK gagal diunduh atau kosong.');
    }

    return savePath;
  }
}

