import 'package:flutter/material.dart';

/// Reusable iOS Capsule Text Field matching the iOS Search Bar aesthetic:
/// - Smooth rounded pill shape (BorderRadius.circular(22))
/// - Native iOS dark (#1C1C1E) and light (#E5E5EA) background
/// - Optional leading icon (CupertinoIcons)
/// - Optional trailing widget (e.g. toggle password, clear)
/// - Completely disables Material default borders to prevent double-border glitches
class IosCapsuleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autoFocus;
  final double height;
  final TextStyle? style;
  final Color? backgroundColor;
  final int maxLines;

  const IosCapsuleTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.prefixIcon,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autoFocus = false,
    this.height = 46,
    this.style,
    this.backgroundColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final capsuleBg = backgroundColor ??
        (isDark
            ? const Color(0xFF1C1C1E) // iOS Dark Search/Field Background
            : const Color(0xFFE5E5EA)); // iOS Light Field Background

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : const Color(0xFF8E8E93);

    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF8E8E93);

    final isSingleLine = maxLines == 1;

    return Container(
      height: isSingleLine ? height : null,
      decoration: BoxDecoration(
        color: capsuleBg,
        borderRadius: BorderRadius.circular(isSingleLine ? height / 2 : 18),
        border: Border.all(
          color: borderColor,
          width: 0.8,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isSingleLine ? 0 : 10,
      ),
      child: Row(
        crossAxisAlignment: isSingleLine ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (prefixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(
                right: 10,
                top: isSingleLine ? 0 : 4,
              ),
              child: Icon(
                prefixIcon,
                size: 18,
                color: iconColor,
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autoFocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              maxLines: maxLines,
              cursorColor: const Color(0xFF0A84FF), // iOS System Blue
              cursorWidth: 2.0,
              cursorRadius: const Radius.circular(1.5),
              style: style ??
                  TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: hintColor,
                  letterSpacing: -0.2,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: isSingleLine ? 12 : 2),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (trailing != null) ...[
            trailing!,
          ],
        ],
      ),
    );
  }
}
