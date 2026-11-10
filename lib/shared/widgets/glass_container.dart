import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Glassmorphism / Frosted-Glass container widget conforming to Apple iOS Materials.
/// Provides a clean blurred background with translucent surface and 0.5pt hairline border.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 10.0,
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(14);

    final defaultColor = color ??
        (isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.82));

    final defaultBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? defaultColor : null,
        gradient: gradient,
        borderRadius: radius,
        border: defaultBorder,
      ),
      child: child,
    );

    if (blur > 0) {
      content = RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}

/// Ambient background for Native iPhone dark / light aesthetic.
/// Replaces generic noisy neon meshes with clean Apple OLED True Black and subtle depth.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
              gradient: isDark
                  ? const RadialGradient(
                      center: Alignment(0.0, -0.85),
                      radius: 1.1,
                      colors: [
                        Color(0xFF141416), // Clean Apple OLED depth
                        Color(0xFF0A0A0C),
                        Color(0xFF000000),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF2F2F7),
                        Color(0xFFEBEBF0),
                      ],
                    ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
