import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/pip_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'decorated_avatar.dart';

/// Desktop Navigation Sidebar styled after Instagram Web:
/// - Minimalist aesthetic (OLED Black / Crisp White, 0.5px hairline border)
/// - Exactly matches Mobile Bottom Bar: Beranda, Komik, Profil
/// - Collapsible to compact icon-only rail (72px) or full width (220px)
/// - Modern typography and user avatar ring on Profil tab
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final width = _isCollapsed ? 72.0 : 220.0;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB);

    return ValueListenableBuilder<bool>(
      valueListenable: PipService.instance.isFullscreen,
      builder: (context, isFullscreen, _) => ValueListenableBuilder<bool>(
        valueListenable: PipService.instance.isInPip,
        builder: (context, isInPip, _) {
          if (isFullscreen || isInPip) {
            return const SizedBox.shrink();
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: width,
            height: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                right: BorderSide(
                  color: borderColor,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BRAND LOGO / WORDMARK (INSTAGRAM WEB STYLE)
                  _buildBrandHeader(isDark),

                  const SizedBox(height: 12),

                  // 2. MAIN NAVIGATION ITEMS (EXACT SAME AS MOBILE NAVBAR)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tab 0: Beranda
                          _buildNavItem(
                            icon: CupertinoIcons.house,
                            activeIcon: CupertinoIcons.house_fill,
                            label: 'Beranda',
                            active: widget.currentIndex == 0,
                            isDark: isDark,
                            onTap: () => widget.onTap(0),
                          ),

                          // Tab 1: Komik
                          _buildNavItem(
                            icon: CupertinoIcons.book,
                            activeIcon: CupertinoIcons.book_fill,
                            label: 'Komik',
                            active: widget.currentIndex == 1,
                            isDark: isDark,
                            onTap: () => widget.onTap(1),
                          ),

                          // Tab 2: Ulas (Review & Re-watch)
                          _buildNavItem(
                            icon: CupertinoIcons.square_pencil,
                            activeIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                            label: 'Ulas',
                            active: widget.currentIndex == 2,
                            isDark: isDark,
                            onTap: () => widget.onTap(2),
                          ),

                          // Tab 3: Profil (DecoratedAvatar & active ring)
                          _buildProfileNavItem(
                            user: user,
                            active: widget.currentIndex == 3,
                            isDark: isDark,
                            onTap: () => widget.onTap(3),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. BOTTOM ACTIONS (THEME & COLLAPSE)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      children: [
                        // Theme Switcher
                        _buildNavItem(
                          icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                          activeIcon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                          label: isDark ? 'Mode Gelap' : 'Mode Terang',
                          active: false,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            themeProvider.toggle();
                          },
                        ),

                        // Collapse / Expand Sidebar Toggle
                        _buildNavItem(
                          icon: _isCollapsed
                              ? CupertinoIcons.sidebar_right
                              : CupertinoIcons.sidebar_left,
                          activeIcon: _isCollapsed
                              ? CupertinoIcons.sidebar_right
                              : CupertinoIcons.sidebar_left,
                          label: _isCollapsed ? 'Perbesar' : 'Perkecil',
                          active: false,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isCollapsed = !_isCollapsed);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark) {
    final logoBg = isDark ? Colors.white : Colors.black;
    final logoIconColor = isDark ? Colors.black : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isCollapsed ? 0 : 18,
        22,
        _isCollapsed ? 0 : 12,
        14,
      ),
      child: _isCollapsed
          ? Center(
              child: GestureDetector(
                onTap: () => widget.onTap(0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: logoBg,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.play_arrow_solid,
                      color: logoIconColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onTap(0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: logoBg,
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.play_arrow_solid,
                            color: logoIconColor,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Moko',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white70 : Colors.black87);
    final activeBgColor = active
        ? (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.07))
        : Colors.transparent;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: _isCollapsed ? label : '',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            hoverColor: hoverColor,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: EdgeInsets.symmetric(
                horizontal: _isCollapsed ? 0 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: activeBgColor,
              ),
              child: Row(
                mainAxisAlignment:
                    _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    active ? activeIcon : icon,
                    size: 24,
                    color: textColor,
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem({
    required dynamic user,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.username?.isNotEmpty == true ? user!.username! : 'Profil');
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white70 : Colors.black87);
    final activeBgColor = active
        ? (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.07))
        : Colors.transparent;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: _isCollapsed ? displayName : '',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            hoverColor: hoverColor,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: EdgeInsets.symmetric(
                horizontal: _isCollapsed ? 0 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: activeBgColor,
              ),
              child: Row(
                mainAxisAlignment:
                    _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: DecoratedAvatar(
                      avatarUrl: user?.avatarUrl,
                      decorationUrl: user?.fullAvatarDecorationUrl ?? user?.avatarDecorationUrl,
                      decorationCode: user?.avatarDecorationCode,
                      radius: 12,
                      fallbackName: displayName,
                    ),
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
