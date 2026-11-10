import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/apng_sanitizer.dart';
import 'smooth_avatar_decoration.dart';

/// ImageProvider that intercepts APNG byte streams to sanitize `dispose_op`
/// chunks in-memory before passing to the Flutter / Skia / Impeller image decoder.
///
/// Prevents the common APNG frame accumulation ("ghosting/jejak animasi")
/// where previous transparent frames fail to dispose and stack on top of each other.
class SanitizedApngImageProvider extends ImageProvider<SanitizedApngImageProvider> {
  final String? url;
  final File? file;
  final Uint8List? bytes;
  final double scale;

  const SanitizedApngImageProvider.network(this.url, {this.scale = 1.0})
      : file = null,
        bytes = null;

  const SanitizedApngImageProvider.file(this.file, {this.scale = 1.0})
      : url = null,
        bytes = null;

  const SanitizedApngImageProvider.memory(this.bytes, {this.scale = 1.0})
      : url = null,
        file = null;

  static final Map<String, Uint8List> _memoryCache = {};

  @override
  Future<SanitizedApngImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<SanitizedApngImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(SanitizedApngImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url ?? key.file?.path ?? 'SanitizedApngImageProvider',
    );
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  Future<ui.Codec> _loadAsync(
    SanitizedApngImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      Uint8List bytes;

      if (key.bytes != null) {
        bytes = ApngSanitizer.sanitize(key.bytes!);
      } else if (key.file != null) {
        final rawBytes = await key.file!.readAsBytes();
        bytes = ApngSanitizer.sanitize(rawBytes);
      } else if (key.url != null && key.url!.isNotEmpty) {
        final cacheKey = key.url!;
        if (_memoryCache.containsKey(cacheKey)) {
          bytes = _memoryCache[cacheKey]!;
        } else {
          // Download and sanitize in memory (RAM only, no permanent disk storage)
          final rawBytes = await _downloadBytes(key.url!);
          bytes = ApngSanitizer.sanitize(rawBytes);
          _memoryCache[cacheKey] = bytes;
          if (_memoryCache.length > 20) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
        }
      } else {
        throw ArgumentError('SanitizedApngImageProvider requires url, file, or bytes.');
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (e) {
      debugPrint('SanitizedApngImageProvider error: $e');
      rethrow;
    }
  }

  Future<Uint8List> _downloadBytes(String urlString) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(urlString));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      request.headers.set(
        HttpHeaders.refererHeader,
        'https://discord-decoration.art/discord_avatar_decoration',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'image/png,image/apng,image/*,*/*;q=0.8',
      );

      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode} while fetching APNG: $urlString');
      }
      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      final resultBytes = bytesBuilder.takeBytes();

      // If server returned WebP instead of pure PNG, automatically fallback to direct PNG
      if (ApngSanitizer.isWebp(resultBytes)) {
        final code = SmoothAvatarDecoration.extractCode(urlString, null);
        if (code != null && code.isNotEmpty) {
          final directPngUrl = 'https://discord-decoration.art/decorations/$code.png';
          if (urlString != directPngUrl) {
            debugPrint('[SanitizedApng] WebP detected from $urlString. Redirecting to pure PNG: $directPngUrl');
            return await _downloadBytes(directPngUrl);
          }
        }
      }

      return resultBytes;
    } finally {
      client.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is SanitizedApngImageProvider &&
        other.url == url &&
        other.file?.path == file?.path &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, file?.path, scale);
}

/// Widget that renders an APNG with automated background disposal sanitization.
class SanitizedApngImage extends StatelessWidget {
  final String? url;
  final File? file;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SanitizedApngImage.network(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  })  : file = null,
        bytes = null;

  const SanitizedApngImage.file(
    this.file, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  })  : url = null,
        bytes = null;

  const SanitizedApngImage.memory(
    this.bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  })  : url = null,
        file = null;

  @override
  Widget build(BuildContext context) {
    ImageProvider provider;
    if (bytes != null) {
      provider = SanitizedApngImageProvider.memory(bytes!);
    } else if (file != null) {
      provider = SanitizedApngImageProvider.file(file!);
    } else if (url != null && url!.isNotEmpty) {
      provider = SanitizedApngImageProvider.network(url!);
    } else {
      return errorWidget ?? const SizedBox.shrink();
    }

    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return placeholder ?? const SizedBox.shrink();
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const SizedBox.shrink();
      },
    );
  }
}
