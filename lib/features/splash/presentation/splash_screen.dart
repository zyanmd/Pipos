import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/presentation/welcome_screen.dart';
import '../../../features/main/presentation/root_shell.dart';
import '../../../shared/providers/auth_provider.dart';

/// Screen loading awal (Splash Screen) dengan logo Moko dan animasi dot circle spinner
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _logoAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _logoAnimController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoAnimController.forward();

    // Waktu tunggu loading awal (380ms) agar transisi ke halaman utama instan & responsif
    _transitionTimer = Timer(const Duration(milliseconds: 380), _navigateToNextScreen);
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetWidget = auth.isAuthenticated ? const RootShell() : const WelcomeScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetWidget,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _logoAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final spinnerColor = isDark ? Colors.white : Colors.black;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  // Logo Moko di area tengah atas (optical center ~47% dari tinggi layar)
                  Positioned(
                    top: h * 0.47 - 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: Image.asset(
                              'assets/icons/moko.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                CupertinoIcons.play_rectangle_fill,
                                size: 64,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Spinner lingkaran titik yang mengikuti tema (Hitam di terang, Putih di gelap)
                  Positioned(
                    top: h * 0.79 - 22,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DotCircleSpinner(
                        size: 44,
                        color: spinnerColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Widget dot circle spinner berputar dengan 8 titik bergradasi ukuran & opasitas
class DotCircleSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;

  const DotCircleSpinner({
    super.key,
    this.size = 44.0,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<DotCircleSpinner> createState() => _DotCircleSpinnerState();
}

class _DotCircleSpinnerState extends State<DotCircleSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.color ?? (isDark ? Colors.white : Colors.black);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _DotCircleSpinnerPainter(
            progress: _controller.value,
            color: effectiveColor,
          ),
        );
      },
    );
  }
}

class _DotCircleSpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DotCircleSpinnerPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int dotCount = 8;
    final double center = size.width / 2;
    final double orbitRadius = size.width * 0.38;
    final double rotationAngle = progress * 2 * math.pi;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final double angle = rotationAngle + (i * 2 * math.pi / dotCount);
      final double x = center + orbitRadius * math.cos(angle);
      final double y = center + orbitRadius * math.sin(angle);

      // t berkisar dari 0.0 (ekor terkecil) ke 1.0 (kepala terbesar)
      final double t = i / (dotCount - 1);

      // Ukuran radius titik bergradasi dari ~1.5 hingga ~4.5
      final double dotRadius = (size.width * 0.035) + (size.width * 0.070 * t);

      // Opasitas bergradasi dari 0.18 hingga 1.0
      final double opacity = (0.18 + (0.82 * t)).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotCircleSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
