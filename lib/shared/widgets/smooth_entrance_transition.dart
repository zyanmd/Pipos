import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Lightweight smooth entrance animation (Slide-Up + Fade).
/// Jika mode hemat baterai (isAnimationEnabled == false) aktif di pengaturan,
/// widget langsung menampilkan child tanpa overhead AnimationController.
class SmoothEntranceTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const SmoothEntranceTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 360),
    this.delay = Duration.zero,
    this.offset = const Offset(0.0, 0.05),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothEntranceTransition> createState() => _SmoothEntranceTransitionState();
}

class _SmoothEntranceTransitionState extends State<SmoothEntranceTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (!ThemeProvider.instance.isAnimationEnabled) return;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller!,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller!.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted && _controller != null) {
          _controller!.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ThemeProvider.instance.isAnimationEnabled || _controller == null) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: widget.child,
      ),
    );
  }
}

