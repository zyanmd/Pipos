import 'package:flutter/material.dart';

/// Centralized color palette for Moko (Pure Monochrome Black & White).
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF000000); // Pure black
  static const Color primaryDark  = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF333333);
  static const Color error        = Color(0xFF555555);

  // ── iOS 26 Liquid Glass tokens ────────────────────────────────────────────
  /// Translucent surfaces applied globally through ThemeData.
  static const Color glassLight = Color(0xB3FFFFFF);
  static const Color glassLightStrong = Color(0xE6FFFFFF);
  static const Color glassLightBorder = Color(0x66FFFFFF);
  static const Color glassLightTint = Color(0x12007AFF);

  static const Color glassDark = Color(0x241C1C1E);
  static const Color glassDarkStrong = Color(0x401C1C1E);
  static const Color glassDarkBorder = Color(0x33FFFFFF);
  static const Color glassDarkTint = Color(0x140A84FF);

  /// Specular highlight painted on the top edge of glass surfaces.
  static const Color glassHighlight = Color(0x4DFFFFFF);
  static const Color glassShadow = Color(0x44000000);

  // ── Light theme (Apple iOS System Grouped) ─────────────────────────────────
  static const Color lightBackground  = Color(0xFFF2F2F7);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt  = Color(0xFFE5E5EA);
  static const Color lightCard        = Color(0xFFFFFFFF);
  static const Color lightDivider     = Color(0xFFC6C6C8);
  static const Color lightBorder      = Color(0x0F000000);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextMuted   = Color(0xFF8E8E93);

  // ── Dark theme (Pure OLED True Black & System Grays) ─────────────────────
  static const Color darkBackground  = Color(0xFF000000);
  static const Color darkSurface     = Color(0xFF1C1C1E);
  static const Color darkSurfaceAlt  = Color(0xFF2C2C2E);
  static const Color darkCard        = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkDivider     = Color(0xFF38383A);
  static const Color darkBorder      = Color(0x1FFFFFFF);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextMuted   = Color(0xFF8E8E93);
}
