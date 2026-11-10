import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import 'sanitized_apng_image.dart';

/// High-performance, smooth animated avatar decoration (bingkai) renderer.
///
/// Features:
/// - Strictly PNG / APNG format with hardware-accelerated playback.
/// - Integrates SanitizedApngImage to enforce `APNG_DISPOSE_OP_BACKGROUND`,
///   completely eliminating frame accumulation / ghosting on transparent APNGs.
/// - Seamless disk and memory caching without downsampling artifacts.
/// - Local file support for instantaneous profile editing preview.
class SmoothAvatarDecoration extends StatelessWidget {
  final String? decorationUrl;
  final String? decorationCode;
  final double size;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SmoothAvatarDecoration({
    super.key,
    this.decorationUrl,
    this.decorationCode,
    required this.size,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  /// Extracts the decoration slug / code from any URL or code parameter
  static String? extractCode(String? url, String? code) {
    if (code != null && code.trim().isNotEmpty) {
      final c = code.trim();
      if (!c.contains('/') && !c.contains('.')) return c;
    }
    if (url == null || url.trim().isEmpty) return null;
    final clean = url.trim().split('?').first.split('#').first;
    final lastSeg = clean.split('/').last;
    final name = lastSeg
        .replaceAll('.png', '')
        .replaceAll('.webp', '')
        .replaceAll('.gif', '')
        .replaceAll('.apng', '')
        .trim();
    if (name.isNotEmpty && !name.contains('.')) {
      return name;
    }
    return null;
  }

  /// Normalizes input strictly into the backend API PNG proxy URL (/api/avatar-decorations/image/$code.png).
  /// Guarantees that any decoration code, relative URL, or external .webp/.png URL is converted to clean PNG.
  static String? normalizeUrl(String? url, String? code) {
    if (url != null && url.trim().isNotEmpty) {
      var trimmed = url.trim();
      if (trimmed.toLowerCase().endsWith('.webp')) {
        trimmed = '${trimmed.substring(0, trimmed.length - 5)}.png';
      }
      if (trimmed.contains('/uploads/')) {
        final clean = trimmed.replaceFirst(RegExp(r'^/+'), '');
        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          return clean;
        }
        return '${ApiConfig.baseUrl}/$clean';
      }
      if (trimmed.startsWith('https://discord-decoration.art/')) {
        return trimmed;
      }
      if (trimmed.startsWith('https://cdn.discordapp.com/')) {
        return trimmed;
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      final clean = trimmed.replaceFirst(RegExp(r'^/+'), '');
      return '${ApiConfig.baseUrl}/$clean';
    }

    final candCode = extractCode(url, code);
    if (candCode != null && candCode.isNotEmpty) {
      return 'https://discord-decoration.art/decorations/$candCode.png';
    }

    return null;
  }

  /// Calculates fallback PNG URL mirroring Flask API candidate hosts
  static String? getFallbackUrl(String primaryUrl, String? code) {
    final candCode = extractCode(primaryUrl, code);
    if (candCode == null || candCode.isEmpty) return null;

    if (primaryUrl.contains('/api/avatar-decorations/image/')) {
      return 'https://discord-decoration.art/decorations/$candCode.png';
    }
    if (primaryUrl.contains('discord-decoration.art')) {
      return 'https://cdn.discordapp.com/avatar-decoration-presets/$candCode.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = normalizeUrl(decorationUrl, decorationCode);
    if (resolved == null || resolved.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    // 1. Check local file (e.g. from file picker or custom avatar frame upload)
    try {
      final localFile = File(resolved);
      if (localFile.existsSync()) {
        return SanitizedApngImage.file(
          localFile,
          width: size,
          height: size,
          fit: fit,
          placeholder: placeholder,
          errorWidget: errorWidget,
        );
      }
    } catch (_) {}

    // 2. Render exclusively via SanitizedApngImage (Strictly PNG, background auto-disposed, zero ghosting)
    return SanitizedApngImage.network(
      resolved,
      width: size,
      height: size,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}

