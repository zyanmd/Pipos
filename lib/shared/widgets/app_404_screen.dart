import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../features/anime/presentation/anime_search_screen.dart';
import '../../features/main/presentation/root_shell.dart';

/// Modern, sleek 404 screen with Apple/Netflix-grade ambient glow,
/// neon typography, and anime-themed aesthetics.
class App404Screen extends StatefulWidget {
  const App404Screen({
    super.key,
    this.title = 'Halaman Tidak Ditemukan',
    this.message = 'Sepertinya kamu tersesat di dimensi lain. Konten yang kamu cari mungkin telah dipindahkan atau sudah tidak tersedia.',
    this.showHomeButton = true,
    this.showSearchButton = true,
  });

  final String title;
  final String message;
  final bool showHomeButton;
  final bool showSearchButton;

  @override
  State<App404Screen> createState() => _App404ScreenState();
}

class _App404ScreenState extends State<App404Screen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090A0F) : const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          // Background ambient gradient orbs
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              return Positioned(
                top: size.height * 0.15,
                left: size.width * 0.5 - 150,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark ? const Color(0xFF6C5CE7) : const Color(0xFF8E7CFF)).withValues(alpha: 0.28),
                          (isDark ? const Color(0xFFFF2D55) : const Color(0xFFFF5252)).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Main scrollable content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button if navigation stack exists
                    if (Navigator.canPop(context))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          onPressed: () => Navigator.maybePop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              border: Border.all(
                                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.arrow_left,
                              size: 18,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Stylized Glowing 404 Badge with Radar Icon
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF6C5CE7).withValues(alpha: 0.25)
                                    : const Color(0xFF8E7CFF).withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Rotating radar sweep
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Transform.rotate(
                                angle: _pulseController.value * 2 * math.pi,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Central Icon Container
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF14151F) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? const Color(0xFF6C5CE7) : const Color(0xFF8E7CFF)).withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.compass,
                              size: 40,
                              color: Color(0xFF8E7CFF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Big Bold Neon Gradient 404
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF8E7CFF),
                          Color(0xFFFF2D55),
                          Color(0xFFFF8A00),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        '404',
                        style: GoogleFonts.inter(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Title
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF111111),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Action Buttons Row / Column
                    if (widget.showHomeButton || widget.showSearchButton)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            if (widget.showHomeButton)
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      CupertinoPageRoute(builder: (_) => const RootShell()),
                                      (route) => false,
                                    );
                                  },
                                  icon: const Icon(CupertinoIcons.house_fill, size: 18),
                                  label: Text(
                                    'Kembali ke Beranda',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 4,
                                    shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                ),
                              ),

                            if (widget.showHomeButton && widget.showSearchButton)
                              const SizedBox(height: 12),

                            if (widget.showSearchButton)
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(builder: (_) => const AnimeSearchScreen()),
                                    );
                                  },
                                  icon: const Icon(CupertinoIcons.search, size: 18),
                                  label: Text(
                                    'Cari Anime / Konten',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
                                    side: BorderSide(
                                      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline 404 widget for empty or not-found results inside screens
class AppNotFoundWidget extends StatelessWidget {
  const AppNotFoundWidget({
    super.key,
    this.title = 'Tidak Ditemukan',
    this.subtitle = 'Konten yang kamu cari tidak dapat ditemukan.',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1A1C24) : const Color(0xFFEDEBF5),
                border: Border.all(
                  color: const Color(0xFF8E7CFF).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.compass,
                size: 40,
                color: Color(0xFF8E7CFF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 4,
                  shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
