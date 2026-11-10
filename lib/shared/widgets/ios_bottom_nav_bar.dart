import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/update/data/models/app_update_model.dart';
import '../../features/update/services/app_update_service.dart';
import '../providers/auth_provider.dart';
import 'bouncy_tap.dart';
import 'decorated_avatar.dart';

/// Minimalist Instagram / Desktop-matched Navigation Bar for Mobile:
/// - Exact same 3 buttons as Desktop Sidebar: Beranda, Komik, Profil
/// - Exact same appearance: OLED Black / Crisp White, 0.5px hairline border
/// - Active item uses bold pure white/black typography and icon
/// - Profil item renders the user\'s DecoratedAvatar with active ring border
class MokoBottomNavBar extends StatelessWidget {
  const MokoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomMargin = bottomInset > 0 ? bottomInset + 8 : 18.0;

    final bgColor = isDark
        ? const Color(0xF20F0F12)
        : const Color(0xF8FFFFFF);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB);

    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.09),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                  // Tab 0: Beranda
                  Expanded(
                    child: _BottomNavItem(
                      icon: CupertinoIcons.house,
                      activeIcon: CupertinoIcons.house_fill,
                      label: 'Beranda',
                      active: currentIndex == 0,
                      isDark: isDark,
                      onTap: () => onTap(0),
                    ),
                  ),

                  // Tab 1: Komik
                  Expanded(
                    child: _BottomNavItem(
                      icon: CupertinoIcons.book,
                      activeIcon: CupertinoIcons.book_fill,
                      label: 'Komik',
                      active: currentIndex == 1,
                      isDark: isDark,
                      onTap: () => onTap(1),
                    ),
                  ),

                  // Tab 2: Ulas (Review & Re-watch)
                  Expanded(
                    child: _BottomNavItem(
                      icon: CupertinoIcons.square_pencil,
                      activeIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                      label: 'Ulas',
                      active: currentIndex == 2,
                      isDark: isDark,
                      onTap: () => onTap(2),
                    ),
                  ),

                  // Tab 3: Profil (with DecoratedAvatar & active ring)
                  Expanded(
                    child: _BottomProfileNavItem(
                      user: user,
                      label: 'Profil',
                      active: currentIndex == 3,
                      isDark: isDark,
                      onTap: () => onTap(3),
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

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final textColor = active
        ? activeColor
        : (isDark ? Colors.white54 : Colors.black54);

    return BouncyTap(
      scaleDown: 0.88,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: active ? 1.08 : 0.94,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.10))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  size: 21,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomProfileNavItem extends StatelessWidget {
  const _BottomProfileNavItem({
    required this.user,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final dynamic user;
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final textColor = active
        ? activeColor
        : (isDark ? Colors.white54 : Colors.black54);

    return BouncyTap(
      scaleDown: 0.88,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: active ? 1.08 : 0.94,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.10))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ValueListenableBuilder<AppUpdateModel?>(
                  valueListenable: AppUpdateService.instance.availableUpdateNotifier,
                  builder: (context, update, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? activeColor : Colors.transparent,
                              width: 1.8,
                            ),
                          ),
                          child: DecoratedAvatar(
                            avatarUrl: user?.avatarUrl,
                            decorationUrl: user?.fullAvatarDecorationUrl ?? user?.avatarDecorationUrl,
                            decorationCode: user?.avatarDecorationCode,
                            radius: 10,
                            fallbackName: 'Profil',
                          ),
                        ),
                        if (update != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 7.5,
                              height: 7.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


typedef IOSBottomNavBar = MokoBottomNavBar;
