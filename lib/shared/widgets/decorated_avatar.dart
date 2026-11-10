import 'package:flutter/material.dart';
import '../../features/auth/data/models/user_model.dart';
import 'calm_gif.dart';
import 'smooth_avatar_decoration.dart';

/// Apple iOS HIG styled Decorated Avatar with overlay PNG frame.
/// Supports custom radius, custom border, initials fallback, and precision decoration scaling.
/// Apple iOS HIG styled Decorated Avatar with overlay frame decoration.
/// Supports custom radius, custom border, initials fallback, and fluid 60fps animated frames.
class DecoratedAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? decorationUrl;
  final String? decorationCode;
  final String fallbackName;
  final double radius;
  final double decorationScale;
  final int offsetX;
  final int offsetY;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const DecoratedAvatar({
    super.key,
    this.avatarUrl,
    this.decorationUrl,
    this.decorationCode,
    this.fallbackName = 'User',
    this.radius = 24,
    this.decorationScale = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
  });

  String get _normalizedAvatarUrl {
    final norm = UserModel.normalizeAvatarUrl(avatarUrl);
    if (norm == null || norm.isEmpty) {
      final n = fallbackName.isNotEmpty ? fallbackName : 'User';
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(n)}&size=128&background=FF2D55&color=fff&bold=true';
    }
    return norm;
  }

  String? get _normalizedDecorationUrl {
    return SmoothAvatarDecoration.normalizeUrl(decorationUrl, decorationCode);
  }

  bool get _hasDecoration {
    return (decorationUrl != null && decorationUrl!.isNotEmpty) ||
        (decorationCode != null && decorationCode!.isNotEmpty);
  }

  bool get _isGifAvatar {
    final norm = _normalizedAvatarUrl.split('?').first.toLowerCase();
    return norm.endsWith('.gif') || _normalizedAvatarUrl.toLowerCase().contains('.gif') || norm.endsWith('.webp');
  }

  Widget _buildFallback(double radius, [BuildContext? context]) {
    final isDark = context != null ? Theme.of(context).brightness == Brightness.dark : true;
    final color = isDark ? Colors.white : Colors.black;
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarDiameter = radius * 2;
    // Discord avatar decoration canonical geometry: 288x288 canvas with 240px avatar cutout (288 / 240 = 1.20 exactly).
    // Using 1.20 ensures the decoration frame snaps perfectly flush against the avatar circle edges.
    final decorationSize = avatarDiameter * 1.20 * decorationScale;
    final effectiveBorderWidth = _hasDecoration ? 0.0 : borderWidth;

    Widget content = SizedBox(
      width: avatarDiameter > decorationSize ? avatarDiameter : decorationSize,
      height: avatarDiameter > decorationSize ? avatarDiameter : decorationSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Base Avatar Circle
          Container(
            width: avatarDiameter,
            height: avatarDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: effectiveBorderWidth > 0
                  ? Border.all(
                      color: borderColor ?? Colors.white,
                      width: effectiveBorderWidth,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _isGifAvatar
                  ? CalmGif(
                      source: _normalizedAvatarUrl,
                      fit: BoxFit.cover,
                      width: avatarDiameter,
                      height: avatarDiameter,
                      speed: 1.0,
                      minFrameDurationMs: 20,
                      placeholder: _buildFallback(radius, context),
                      errorWidget: Image.network(
                        _normalizedAvatarUrl,
                        fit: BoxFit.cover,
                        width: avatarDiameter,
                        height: avatarDiameter,
                        errorBuilder: (_, __, ___) => _buildFallback(radius, context),
                      ),
                    )
                  : Image.network(
                      _normalizedAvatarUrl,
                      fit: BoxFit.cover,
                      width: avatarDiameter,
                      height: avatarDiameter,
                      cacheWidth: (avatarDiameter * 2.5).toInt().clamp(60, 400),
                      cacheHeight: (avatarDiameter * 2.5).toInt().clamp(60, 400),
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) return child;
                        return _buildFallback(radius, context);
                      },
                      errorBuilder: (_, __, ___) => _buildFallback(radius, context),
                    ),
            ),
          ),

          // Overlay Avatar Decoration Frame (Hardware-accelerated 60fps Native Animation)
          if (_hasDecoration && _normalizedDecorationUrl != null)
            IgnorePointer(
              child: Transform.translate(
                offset: Offset(offsetX.toDouble(), offsetY.toDouble()),
                child: SizedBox(
                  width: decorationSize,
                  height: decorationSize,
                  child: SmoothAvatarDecoration(
                    decorationUrl: _normalizedDecorationUrl,
                    decorationCode: decorationCode,
                    size: decorationSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

