import 'package:flutter/material.dart';

/// Centralized color palette for Moko (Pure Monochrome Black & White).
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF000000); // Pure black
  static const Color primaryDark  = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF333333);
  static const Color error        = Color(0xFF555555);

  // ── Light theme (Pure Monochrome) ─────────────────────────────────────────
  static const Color lightBackground  = Color(0xFFFFFFFF);
  static const Color lightSurface     = Color(0xFFF7F7F8);
  static const Color lightSurfaceAlt  = Color(0xFFEFEFEF);
  static const Color lightCard        = Color(0xFFFFFFFF);
  static const Color lightDivider     = Color(0xFFE5E5E5);
  static const Color lightBorder      = Color(0xFFD8D8D8);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextMuted   = Color(0xFF737373);

  // ── Dark theme (Pure OLED True Black & Neutral Grays) ───────────────────
  static const Color darkBackground  = Color(0xFF000000);
  static const Color darkSurface     = Color(0xFF121212);
  static const Color darkSurfaceAlt  = Color(0xFF1E1E1E);
  static const Color darkCard        = Color(0xFF161616);
  static const Color darkDivider     = Color(0xFF262626);
  static const Color darkBorder      = Color(0xFF2E2E2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextMuted   = Color(0xFFA3A3A3);
}
