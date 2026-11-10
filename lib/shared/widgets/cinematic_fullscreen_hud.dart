import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cinematic Fullscreen Transition & HUD Overlay.
/// Menampilkan animasi futuristik/sinematik saat masuk dan keluar dari mode Fullscreen:
/// 1. Viewfinder bracket expansion (4 sudut kamera sinematik membesar ke tepi layar).
/// 2. Radial shockwave pulse (gelombang cahaya melingkar dari tengah).
/// 3. Smooth video scale bounce (zoom sinematik 0.93 -> 1.0).
/// 4. Dynamic Island Glass Bubble HUD (pil mengambang dengan efek blur, ikon berputar, dan neon status).
class CinematicFullscreenWrapper extends StatefulWidget {
  final Widget child;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  const CinematicFullscreenWrapper({
    super.key,
    required this.child,
    required this.isFullscreen,
    this.onToggleFullscreen,
  });

  @override
  State<CinematicFullscreenWrapper> createState() => _CinematicFullscreenWrapperState();
}

class _CinematicFullscreenWrapperState extends State<CinematicFullscreenWrapper>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shockwaveAnimation;
  late Animation<double> _bracketExpandAnimation;
  late Animation<double> _hudOpacityAnimation;
  late Animation<double> _hudScaleAnimation;

  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Zoom scale: video scales smoothly on transition
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.93, end: 1.02)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.45),
      ),
    );

    // Radial shockwave ring expanding outwards
    _shockwaveAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutQuart),
    );

    // Viewfinder 4-corner brackets expansion
    _bracketExpandAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    );

    // Floating HUD pill entrance and exit
    _hudOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_transitionController);

    _hudScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.90)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 15,
      ),
    ]).animate(_transitionController);
  }

  @override
  void didUpdateWidget(covariant CinematicFullscreenWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      _playTransitionAnimation();
    }
  }

  void _playTransitionAnimation() {
    if (widget.isFullscreen) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() => _isTransitioning = true);
    _transitionController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _isTransitioning = false);
      }
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, _) {
        final double scale = _isTransitioning ? _scaleAnimation.value : 1.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Konten Video Utama dengan Zoom Transform
            Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: widget.child,
            ),

            // Layer Efek Transisi (Hanya aktif selama animasi)
            if (_isTransitioning) ...[
              // 1. Radial Shockwave Ring Pulse
              IgnorePointer(
                child: CustomPaint(
                  painter: _ShockwavePainter(
                    progress: _shockwaveAnimation.value,
                    color: widget.isFullscreen
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFFFF2D55),
                  ),
                ),
              ),

              // 2. Cinematic 4-Corner Viewfinder Brackets
              if (widget.isFullscreen)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ViewfinderPainter(
                      progress: _bracketExpandAnimation.value,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                ),

              // 3. Floating Dynamic Island HUD Bubble
              Positioned(
                top: widget.isFullscreen ? 28 : 16,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: _hudOpacityAnimation,
                    child: Transform.scale(
                      scale: _hudScaleAnimation.value,
                      child: _buildHudPill(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHudPill() {
    final isEnter = widget.isFullscreen;
    final primaryColor = isEnter ? const Color(0xFF00E5FF) : const Color(0xFFFF9500);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Status Dot with Pulse
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Rotating Animated Icon
              AnimatedRotation(
                turns: isEnter ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: Icon(
                  isEnter
                      ? CupertinoIcons.fullscreen_exit
                      : CupertinoIcons.fullscreen,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),

              // Label Text & Pill Badge
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEnter ? 'MODE LAYAR PENUH' : 'MODE NORMAL',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isEnter ? 'SINEMATIK' : 'STANDAR',
                          style: GoogleFonts.inter(
                            color: primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isEnter ? 'Rotasi otomatis & kontrol sentuh aktif' : 'Tampilan vertikal standar',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk efek cincin gelombang radial (Shockwave)
class _ShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.75;
    final currentRadius = maxRadius * progress;

    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 8.0 + 1.5
      ..color = color.withValues(alpha: opacity * 0.70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Custom painter untuk efek sudut kamera sinematik (Viewfinder Brackets)
class _ViewfinderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ViewfinderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Jarak dari tepi layar (mengecil mendekati tepi saat progress -> 1)
    final margin = (1.0 - progress) * 60.0 + 16.0;
    const bracketSize = 24.0;

    final left = margin;
    final top = margin;
    final right = size.width - margin;
    final bottom = size.height - margin;

    // Top-Left ┌
    final pathTL = Path()
      ..moveTo(left, top + bracketSize)
      ..lineTo(left, top)
      ..lineTo(left + bracketSize, top);
    canvas.drawPath(pathTL, paint);

    // Top-Right ┐
    final pathTR = Path()
      ..moveTo(right - bracketSize, top)
      ..lineTo(right, top)
      ..lineTo(right, top + bracketSize);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left └
    final pathBL = Path()
      ..moveTo(left, bottom - bracketSize)
      ..lineTo(left, bottom)
      ..lineTo(left + bracketSize, bottom);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right ┘
    final pathBR = Path()
      ..moveTo(right - bracketSize, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, bottom - bracketSize);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Widget tombol Fullscreen interaktif dengan rotasi dan animasi spring bouncy
class AnimatedFullscreenButton extends StatefulWidget {
  final bool isFullscreen;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const AnimatedFullscreenButton({
    super.key,
    required this.isFullscreen,
    required this.onTap,
    this.size = 36,
    this.iconSize = 20,
  });

  @override
  State<AnimatedFullscreenButton> createState() => _AnimatedFullscreenButtonState();
}

class _AnimatedFullscreenButtonState extends State<AnimatedFullscreenButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: widget.isFullscreen ? 0.40 : 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isFullscreen ? const Color(0xFF00E5FF) : Colors.black)
                    .withValues(alpha: widget.isFullscreen ? 0.35 : 0.25),
                blurRadius: 8,
                spreadRadius: widget.isFullscreen ? 1 : 0,
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: widget.isFullscreen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              child: Icon(
                widget.isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: widget.isFullscreen ? const Color(0xFF00E5FF) : Colors.white,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
