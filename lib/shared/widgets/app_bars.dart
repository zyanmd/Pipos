import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Hero-style large title app bar that collapses into a blurred compact bar.
/// iOS-style large title with shrink-on-scroll behavior.
class LargeTitleAppBar extends StatelessWidget {
  const LargeTitleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.subtitle,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 116,
      floating: false,
      pinned: true,
      stretch: true,
      leading: leading,
      actions: actions,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final shrink = 1 -
              ((constraints.maxHeight - kToolbarHeight) /
                  (116 - kToolbarHeight))
                  .clamp(0.0, 1.0);
          final isShrunk = shrink > 0.6;
          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: EdgeInsets.only(
              left: 16 + (isShrunk ? 0 : 0),
              bottom: isShrunk ? 13 : 12,
            ),
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.lightTextPrimary,
                fontSize: isShrunk ? 17 : 32,
                fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                letterSpacing: isShrunk ? 0 : -0.5,
                fontFamily: 'Poppins',
              ),
              child: Text(title),
            ),
          );
        },
      ),
    );
  }
}

/// Compact bar with translucent blur background — used on detail screens.
class BlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlurAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.transparent = false,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool transparent;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: transparent
          ? Colors.transparent
          : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xF20F0F12)
              : const Color(0xF8FFFFFF)),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      actions: actions,
      title: title == null
          ? null
          : Text(
              title!,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
    );
  }
}
