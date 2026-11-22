import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// True iOS Native Search Bar matching:
/// [ 🔍  Search query...      ✕ ]   Cancel
///
/// Features:
/// - Capsule pill container (border radius 22, height ~42)
/// - Inside leading: iOS Search magnifying glass icon [🔍]
/// - Inside body: Clean Cupertino text input
/// - Inside trailing: Circle clear button [✕] when text is not empty
/// - Outside trailing: iOS blue "Cancel" button (optional, default true)
class IosCapsuleSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCancel;
  final VoidCallback? onClear;
  final bool showCancelButton;
  final String cancelText;
  final Color? cancelColor;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Widget? trailing;
  final Color? backgroundColor;
  final double height;
  final Color? cursorColor;

  const IosCapsuleSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Cari...',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.onClear,
    this.showCancelButton = true,
    this.cancelText = 'Cancel',
    this.cancelColor,
    this.focusNode,
    this.autoFocus = false,
    this.trailing,
    this.backgroundColor,
    this.height = 42,
    this.cursorColor,
  });

  @override
  State<IosCapsuleSearchBar> createState() => _IosCapsuleSearchBarState();
}

class _IosCapsuleSearchBarState extends State<IosCapsuleSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final capsuleBg = widget.backgroundColor ??
        (isDark
            ? const Color(0xFF1C1C1E) // iOS Dark Search Field Background
            : const Color(0xFFE5E5EA)); // iOS Light Search Field Background

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    final clearIconColor = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : const Color(0xFF8E8E93);

    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : const Color(0xFF8E8E93);

    final cancelBtnColor = widget.cancelColor ?? const Color(0xFF0A84FF); // iOS System Blue

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. THE CAPSULE SEARCH FIELD ──
        Expanded(
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: capsuleBg,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: borderColor,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Inside Leading: Magnifying Glass [🔍]
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 19,
                    color: iconColor,
                  ),
                ),

                // Middle: Text Field
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autofocus: widget.autoFocus,
                    textInputAction: TextInputAction.search,
                    cursorColor: widget.cursorColor ?? const Color(0xFF0A84FF),
                    cursorWidth: 2.0,
                    cursorRadius: const Radius.circular(1.5),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: 15,
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                  ),
                ),

                // Inside Trailing: Clear Button [✕]
                if (widget.controller.text.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      widget.onClear?.call();
                      if (mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: clearIconColor,
                      ),
                    ),
                  ),

                if (widget.trailing != null) ...[
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),

        // ── 2. OUTSIDE TRAILING: CANCEL BUTTON ──
        if (widget.showCancelButton) ...[
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onCancel != null) {
                widget.onCancel!();
              } else {
                FocusScope.of(context).unfocus();
                Navigator.maybePop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.cancelText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: cancelBtnColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
