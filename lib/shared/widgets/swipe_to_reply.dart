import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SwipeToReplyDirection {
  startToEnd, // Swipe right (left to right)
  endToStart, // Swipe left (right to left)
  both,       // Can swipe either left or right
}

/// A modern, fluid iOS & Telegram style swipe-to-reply gesture wrapper.
/// Smoothly translates the child horizontally, reveals a reply icon with haptic feedback,
/// and triggers [onReply] upon release when threshold is exceeded.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final SwipeToReplyDirection direction;
  final double threshold;
  final double maxOffset;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final IconData icon;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.direction = SwipeToReplyDirection.startToEnd,
    this.threshold = 44.0,
    this.maxOffset = 64.0,
    this.iconColor,
    this.iconBackgroundColor,
    this.icon = CupertinoIcons.reply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating) _controller.stop();

    double delta = details.primaryDelta ?? 0.0;
    double newOffset = _dragOffset + delta;

    // Constrain by direction
    switch (widget.direction) {
      case SwipeToReplyDirection.startToEnd:
        if (newOffset < 0) newOffset = 0;
        break;
      case SwipeToReplyDirection.endToStart:
        if (newOffset > 0) newOffset = 0;
        break;
      case SwipeToReplyDirection.both:
        break;
    }

    // Apply progressive friction/resistance as offset exceeds threshold
    final absOffset = newOffset.abs();
    if (absOffset > widget.threshold) {
      final excess = absOffset - widget.threshold;
      final dampedExcess = excess * 0.35;
      newOffset = (newOffset.isNegative ? -1 : 1) * (widget.threshold + dampedExcess);
    }

    // Clamp to max offset
    newOffset = newOffset.clamp(-widget.maxOffset, widget.maxOffset);

    // Haptic feedback trigger upon passing threshold
    final passed = newOffset.abs() >= widget.threshold;
    if (passed && !_thresholdReached) {
      HapticFeedback.lightImpact();
      _thresholdReached = true;
    } else if (!passed && _thresholdReached) {
      _thresholdReached = false;
    }

    setState(() {
      _dragOffset = newOffset;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
    _animateBack();
  }

  void _onHorizontalDragCancel() {
    _animateBack();
  }

  void _animateBack() {
    _thresholdReached = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isRight = _dragOffset > 0;
    final progress = (_dragOffset.abs() / widget.threshold).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor = widget.iconColor ??
        (_thresholdReached
            ? (isDark ? Colors.white : Colors.black87)
            : (isDark ? Colors.white70 : Colors.black54));

    final effectiveBgColor = widget.iconBackgroundColor ??
        (_thresholdReached
            ? (isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.12))
            : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05)));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: Stack(
        alignment: isRight ? Alignment.centerLeft : Alignment.centerRight,
        children: [
          // Reply icon indicator revealed behind the swiped child
          if (_dragOffset.abs() > 2)
            Positioned(
              left: isRight ? 12 : null,
              right: !isRight ? 12 : null,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.65 + (0.35 * progress),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: effectiveBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 16,
                      color: effectiveIconColor,
                    ),
                  ),
                ),
              ),
            ),

          // Swiped content
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

