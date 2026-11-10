import 'package:flutter/material.dart';

/// Brand palette for Moko matching Slider / Streaming Theme
class AppColors {
  AppColors._();

  // ───── Brand (Pure Apple Monochrome) ──────────────────────
  static const Color primary = Color(0xFF000000);
  static const Color primaryDark = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF1C1C1E);
  static const Color accent = Color(0xFF000000);
  static const Color brandGreen = Color(0xFF34C759);

  /// Monochrome gradient (pure black → dark charcoal)
  static const List<Color> sakuraGradient = [
    Color(0xFF000000),
    Color(0xFF2C2C2E),
  ];

  /// Sunset gradient for cover/hero overlays.
  static const List<Color> sunsetGradient = [
    Color(0xFF000000),
    Color(0xFF141416),
    Color(0xFF202022),
  ];

  /// Dark hero gradient (for dark-mode hero overlays).
  static const List<Color> darkHeroGradient = [
    Color(0xFF000000),
    Color(0xFF0D0D0E),
    Color(0xFF1A1A1C),
  ];

  // ───── Light Theme (Apple iOS System Grouped) ─────────────
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFE5E5EA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF3C3C43);
  static const Color lightTextMuted = Color(0xFF8E8E93);
  static const Color lightDivider = Color(0xFFC6C6C8);
  static const Color lightBorder = Color(0x0F000000);

  // ───── Dark Theme (Apple iOS OLED True Black & System Grays)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121214);
  static const Color darkSurfaceAlt = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B8);
  static const Color darkTextMuted = Color(0xFF8E8E93);
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkBorder = Color(0x1FFFFFFF);

  // ───── Semantic (Native iOS System Colors) ─────────────────
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  // ───── Apple iOS Semantic Aliases ──────────────────────────
  static const Color iosBlue = Color(0xFF000000);
  static const Color iosRed = error;
  static const Color iosGreen = success;
  static const Color iosOrange = warning;
  static const Color iosBackgroundDark = darkBackground;
  static const Color iosBackgroundLight = lightBackground;
  static const Color iosCardDark = darkCard;
  static const Color iosCardLight = lightCard;
  static const Color iosHairlineDark = darkBorder;
  static const Color iosHairlineLight = lightBorder;
  static const Color iosTextPrimaryDark = darkTextPrimary;
  static const Color iosTextPrimaryLight = lightTextPrimary;
  static const Color iosTextSecondaryDark = darkTextSecondary;
  static const Color iosTextSecondaryLight = lightTextSecondary;
  static const Color iosTextTertiaryDark = darkTextMuted;
  static const Color iosTextTertiaryLight = lightTextMuted;

  // ───── Helpers ────────────────────────────────────────────
  static Color withAlpha(Color c, double a) =>
      c.withValues(alpha: a.clamp(0.0, 1.0));

  /// Returns crisp high-contrast color for the active theme (White in Dark, Black in Light)
  static Color adaptive(bool isDark) =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// Returns high-contrast text color for the active theme
  static Color adaptiveText(bool isDark) =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
}
