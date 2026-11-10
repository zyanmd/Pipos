import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// iOS-style gradient button — wide, rounded, with subtle shadow.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 52,
    this.gradient,
    this.borderRadius = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;
  final List<Color>? gradient;
  final double borderRadius;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.loading;
    final gradient = widget.gradient ?? AppColors.sakuraGradient;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.expanded ? double.infinity : null,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDisabled
                  ? gradient.map((c) => c.withValues(alpha: 0.4)).toList()
                  : gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.35),
                      blurRadius: _pressed ? 6 : 14,
                      offset: Offset(0, _pressed ? 1 : 5),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
