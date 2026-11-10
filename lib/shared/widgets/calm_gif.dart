import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';

class _GifFrameData {
  final List<ui.Image> images;
  final List<int> durationsMs;

  _GifFrameData({
    required this.images,
    required this.durationsMs,
  });

  void dispose() {
    for (final img in images) {
      try {
        img.dispose();
      } catch (_) {}
    }
    images.clear();
    durationsMs.clear();
  }
}

/// A smooth, calm GIF player widget that prevents hyperactive 60-100fps playback
/// and allows slowing down GIF animations to a relaxed, natural, aesthetic speed.
///
/// Features bulletproof fallback to Flutter's native [Image.network] / [Image.file]
/// so that GIFs NEVER fail to render or disappear even when custom multi-frame
/// decoding is waiting, throttled, or encounters unconventional codecs.
class CalmGif extends StatefulWidget {
  final String source;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final double speed;
  final int minFrameDurationMs;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CalmGif({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.speed = 0.70, // 0.70x = calm and relaxed
    this.minFrameDurationMs = 85, // Enforces standard calm minimum delay per frame
    this.placeholder,
    this.errorWidget,
  });

  /// Normalizes any image/GIF source into a valid, reachable URL or local file path.
  static String resolveUrl(String src) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return trimmed;

    // 1. If already full URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 2. If existing local file path (e.g. from ImagePicker)
    try {
      final localFile = File(trimmed);
      if (localFile.existsSync()) return trimmed;
    } catch (_) {}

    // 3. Relative server paths
    final clean = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (clean.startsWith('api/')) {
      return '${ApiConfig.baseUrl}/$clean';
    }
    if (clean.startsWith('uploads/')) {
      return '${ApiConfig.baseUrl}/api/users/$clean';
    }
    if (clean.startsWith('avatars/') || clean.startsWith('covers/')) {
      return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
    }
    return '${ApiConfig.baseUrl}/api/users/uploads/$clean';
  }

  @override
  State<CalmGif> createState() => _CalmGifState();
}

class _CalmGifState extends State<CalmGif> {
  static final Map<String, _GifFrameData> _cache = {};
  static final Map<String, Future<_GifFrameData?>> _inFlight = {};
  static const int _maxCachedGifs = 6;

  _GifFrameData? _frameData;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadGif();
  }

  @override
  void didUpdateWidget(CalmGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _timer?.cancel();
      _currentIndex = 0;
      _loadGif();
    } else if (oldWidget.speed != widget.speed) {
      _startLoop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadGif() async {
    final rawSrc = widget.source.trim();
    if (rawSrc.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    final resolved = CalmGif.resolveUrl(rawSrc);

    // 1. Check memory cache
    if (_cache.containsKey(resolved)) {
      if (mounted) {
        setState(() {
          _frameData = _cache[resolved];
          _isLoading = false;
          _hasError = false;
        });
        _startLoop();
      }
      return;
    }

    // 2. Reuse in-flight request or initiate fetch
    try {
      final future = _inFlight[resolved] ??= _fetchAndDecode(resolved);
      final data = await future;
      if (!mounted) return;

      if (data != null && data.images.isNotEmpty) {
        _cache[resolved] = data;
        while (_cache.length > _maxCachedGifs) {
          final oldestKey = _cache.keys.first;
          final oldest = _cache.remove(oldestKey);
          oldest?.dispose();
        }
        setState(() {
          _frameData = data;
          _isLoading = false;
          _hasError = false;
        });
        _startLoop();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _inFlight.remove(resolved);
    }
  }

  static Future<_GifFrameData?> _fetchAndDecode(String resolvedSrc) async {
    try {
      final trimmed = resolvedSrc.trim();
      if (trimmed.isEmpty) return null;

      Uint8List? bytes;

      // 1. Check local file
      final localFile = File(trimmed);
      if (await localFile.exists()) {
        bytes = await localFile.readAsBytes();
      } else {
        // 2. Network URL with robust headers, redirect following and SSL support
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 25);
        client.badCertificateCallback = ((cert, host, port) => true);

        final uri = Uri.parse(trimmed);
        final req = await client.getUrl(uri);
        req.followRedirects = true;
        req.maxRedirects = 5;
        req.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        );
        req.headers.set(
          HttpHeaders.acceptHeader,
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        );
        req.headers.set(HttpHeaders.refererHeader, '${ApiConfig.baseUrl}/');

        final resp = await req.close();
        if (resp.statusCode != 200) {
          client.close();
          return null;
        }
        bytes = await consolidateHttpClientResponseBytes(resp);
        client.close();
      }

      if (bytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frameCount = codec.frameCount;
      if (frameCount == 0) return null;

      final images = <ui.Image>[];
      final durations = <int>[];

      // Limit max frames to 24 to guarantee lightweight memory footprint
      const maxFrames = 24;
      final step = (frameCount > maxFrames) ? (frameCount / maxFrames).ceil() : 1;

      for (int i = 0; i < frameCount; i++) {
        final info = await codec.getNextFrame();
        if (i % step == 0 && images.length < maxFrames) {
          images.add(info.image);
          durations.add(info.duration.inMilliseconds * step);
        } else {
          try {
            info.image.dispose();
          } catch (_) {}
        }
      }

      return _GifFrameData(images: images, durationsMs: durations);
    } catch (_) {
      return null;
    }
  }

  void _startLoop() {
    _timer?.cancel();
    if (!mounted || _frameData == null || _frameData!.images.length <= 1) return;

    final durations = _frameData!.durationsMs;
    final rawMs = durations[_currentIndex % durations.length];

    // If caller requests high frame rate (minFrameDurationMs <= 25), do not artificially clamp to 100ms
    final normalizedMs = (rawMs <= 10 ? (widget.minFrameDurationMs <= 25 ? 16 : 100) : rawMs);
    final targetMs = (normalizedMs / widget.speed.clamp(0.2, 3.0)).round()
        .clamp(widget.minFrameDurationMs, 4000);

    _timer = Timer(Duration(milliseconds: targetMs), () {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _frameData!.images.length;
      });
      _startLoop();
    });
  }

  Widget _buildNativeFallback() {
    final rawSrc = widget.source.trim();
    if (rawSrc.isEmpty) return widget.errorWidget ?? const SizedBox.shrink();

    final isLocal = File(rawSrc).existsSync();
    if (isLocal) {
      return Image.file(
        File(rawSrc),
        fit: widget.fit,
        alignment: widget.alignment,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, __, ___) => widget.errorWidget ?? const SizedBox.shrink(),
      );
    }

    final resolved = CalmGif.resolveUrl(rawSrc);
    return Image.network(
      resolved,
      fit: widget.fit,
      alignment: widget.alignment,
      width: widget.width,
      height: widget.height,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': '${ApiConfig.baseUrl}/',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      },
      errorBuilder: (_, __, ___) => widget.errorWidget ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. If custom frame extraction succeeded, render calm frame-by-frame
    if (_frameData != null && _frameData!.images.isNotEmpty) {
      final currentImage = _frameData!.images[_currentIndex % _frameData!.images.length];
      return RawImage(
        image: currentImage,
        fit: widget.fit,
        alignment: widget.alignment,
        width: widget.width,
        height: widget.height,
      );
    }

    // 2. On error or fallback, render native animated Image fallback
    if (_hasError) {
      return _buildNativeFallback();
    }

    // 3. While loading, show placeholder if specified, or start native animation immediately
    if (_isLoading) {
      if (widget.placeholder != null) {
        return widget.placeholder!;
      }
      return _buildNativeFallback();
    }

    return _buildNativeFallback();
  }
}
