import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Lightweight iOS-style frosted-glass container.
/// Used for navigation bars, FABs, floating cards over hero images.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.borderRadius = 16,
    this.sigma = 8,
    this.opacity = 0.65,
    this.tint,
    this.showBorder = true,
    this.padding,
    this.margin,
  });

  final Widget? child;
  final double borderRadius;
  final double sigma;
  final double opacity;
  final Color? tint;
  final bool showBorder;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardTint = tint ??
        (isDark
            ? AppColors.darkCard.withValues(alpha: opacity)
            : Colors.white.withValues(alpha: opacity));
    final borderColor = isDark
        ? AppColors.iosHairlineDark
        : AppColors.iosHairlineLight;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: borderColor, width: 0.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(
              color: cardTint,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
