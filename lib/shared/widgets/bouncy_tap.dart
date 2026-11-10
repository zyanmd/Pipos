import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/theme_provider.dart';

/// Interactive tactile spring-touch widget (Bouncy Tap).
/// Memberikan efek pegas fisik saat ditekan (scale squish + spring bounce)
/// dan getaran mikro-haptic yang sangat memuaskan di tangan.
///
/// Jika mode hemat baterai (isAnimationEnabled == false) aktif di pengaturan,
/// efek pegas dinonaktifkan secara instan untuk efisiensi CPU/GPU.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool haptic;
  final HitTestBehavior behavior;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.965,
    this.pressDuration = const Duration(milliseconds: 110),
    this.releaseDuration = const Duration(milliseconds: 200),
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    if (ThemeProvider.instance.isAnimationEnabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    if (ThemeProvider.instance.isAnimationEnabled) {
      _controller.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (ThemeProvider.instance.isAnimationEnabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = ThemeProvider.instance.isAnimationEnabled
              ? _scaleAnimation.value
              : 1.0;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
