import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Modern light & dark theme with smooth bubble design and fluid transitions.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildLight(animationsEnabled: true);
  static ThemeData get dark => _buildDark(animationsEnabled: true);

  static ThemeData buildLight({required bool animationsEnabled}) =>
      _buildLight(animationsEnabled: animationsEnabled);

  static ThemeData buildDark({required bool animationsEnabled}) =>
      _buildDark(animationsEnabled: animationsEnabled);

  static ThemeData _buildLight({bool animationsEnabled = true}) {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.lightTextPrimary,
      displayColor: AppColors.lightTextPrimary,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF262626),
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
      brightness: Brightness.light,
    ).copyWith(
      primaryContainer: const Color(0xFFE5E5EA),
      onPrimaryContainer: Colors.black,
      secondaryContainer: const Color(0xFFEFEFEF),
      onSecondaryContainer: Colors.black,
      surfaceContainerHighest: const Color(0xFFE8E8E8),
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightDivider,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      canvasColor: AppColors.lightBackground,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightDivider,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: const Color(0x06000000),
      primaryColor: AppColors.primary,
      primaryColorDark: AppColors.primaryDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightTextMuted,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      inputDecorationTheme: _inputDecoration(true),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.20),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black87, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.lightTextPrimary, size: 22),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.lightTextPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 0.5,
        space: 1,
      ),
      pageTransitionsTheme: _buildPageTransitionsTheme(animationsEnabled),
    );
  }

  static ThemeData _buildDark({bool animationsEnabled = true}) {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.white,
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: const Color(0xFFE0E0E0),
      onSecondary: Colors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
      brightness: Brightness.dark,
    ).copyWith(
      primaryContainer: const Color(0xFF2C2C2E),
      onPrimaryContainer: Colors.white,
      secondaryContainer: const Color(0xFF1E1E1E),
      onSecondaryContainer: Colors.white,
      surfaceContainerHighest: const Color(0xFF242424),
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkDivider,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkDivider,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: const Color(0x0CFFFFFF),
      primaryColor: Colors.white,
      primaryColorDark: const Color(0xFFE0E0E0),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.darkTextMuted,
        indicatorColor: Colors.white,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      inputDecorationTheme: _inputDecoration(false),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
          shadowColor: Colors.white.withValues(alpha: 0.30),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary, size: 22),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: AppColors.darkTextPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C2C2E),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: Colors.white),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
        space: 1,
      ),
      pageTransitionsTheme: _buildPageTransitionsTheme(animationsEnabled),
    );
  }

  static PageTransitionsTheme _buildPageTransitionsTheme(bool animationsEnabled) {
    if (!animationsEnabled) {
      const noAnim = _NoAnimationPageTransitionsBuilder();
      return const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: noAnim,
          TargetPlatform.iOS: noAnim,
          TargetPlatform.windows: noAnim,
          TargetPlatform.macOS: noAnim,
          TargetPlatform.linux: noAnim,
        },
      );
    }

    const smoothAnim = CupertinoPageTransitionsBuilder();
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: smoothAnim,
        TargetPlatform.iOS: smoothAnim,
        TargetPlatform.windows: smoothAnim,
        TargetPlatform.macOS: smoothAnim,
        TargetPlatform.linux: smoothAnim,
      },
    );
  }

  static InputDecorationTheme _inputDecoration(bool light) {
    final bgColor = light ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E);
    final borderColor = light ? AppColors.lightDivider : AppColors.darkDivider;
    final hintColor = light ? AppColors.lightTextMuted : AppColors.darkTextMuted;

    return InputDecorationTheme(
      filled: true,
      fillColor: bgColor,
      hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 15, fontWeight: FontWeight.w400),
      labelStyle: GoogleFonts.inter(color: hintColor, fontSize: 14, fontWeight: FontWeight.w500),
      floatingLabelStyle: GoogleFonts.inter(
        color: light ? Colors.black : Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: light ? Colors.black : Colors.white, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      prefixIconColor: hintColor,
      suffixIconColor: hintColor,
      alignLabelWithHint: true,
    );
  }
}

/// Transisi instan tanpa animasi untuk mode hemat baterai.
class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
