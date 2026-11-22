import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../features/update/data/models/app_update_model.dart';
import '../../features/update/services/app_update_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'bouncy_tap.dart';
import 'decorated_avatar.dart';
import 'glass_container.dart';

/// Minimalist iOS Frosted Glass Navigation Bar for Mobile:
/// - Exact same design language as the rest of the app (GlassContainer)
/// - Pure monochrome iOS aesthetic: clean blur, no chromatic aberration or distortion
/// - Active item uses bold typography and icon
/// - Profil item renders the user's DecoratedAvatar with clean active indicator
/// - Gestural Scrubbing / Slide: tekan tahan & geser ke tab lain dengan haptic responsif
class MokoBottomNavBar extends StatefulWidget {
  const MokoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  State<MokoBottomNavBar> createState() => _MokoBottomNavBarState();
}

class _MokoBottomNavBarState extends State<MokoBottomNavBar> {
  final GlobalKey _barKey = GlobalKey();
  Timer? _holdTimer;
  bool _isHolding = false;
  bool _isScrubbing = false;
  bool _suppressTap = false;
  Offset? _pointerDownPos;
  int? _activeScrubIndex;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPos = event.localPosition;
    _suppressTap = false;
    _isHolding = false;
    _isScrubbing = false;
    _activeScrubIndex = widget.currentIndex;

    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _isHolding = true;
      HapticFeedback.mediumImpact();
      setState(() {});
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownPos == null) return;
    final dxDelta = (event.localPosition.dx - _pointerDownPos!.dx).abs();

    // Aktifkan mode geser jika ditahan atau pergeseran horizontal melebihi 10px
    if (_isHolding || dxDelta > 10) {
      _holdTimer?.cancel();
      if (!_isScrubbing) {
        _isScrubbing = true;
        _suppressTap = true;
        HapticFeedback.selectionClick();
      }

      _updateScrubIndex(event.localPosition.dx);
    }
  }

  void _updateScrubIndex(double localDx) {
    final renderBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final barWidth = renderBox?.size.width ?? 0;
    if (barWidth <= 0) return;

    const horizontalPadding = 6.0;
    final contentWidth = barWidth - (horizontalPadding * 2);
    if (contentWidth <= 0) return;

    final clampedX = (localDx - horizontalPadding).clamp(0.0, contentWidth - 0.001);
    final tabWidth = contentWidth / 4.0;
    final targetIndex = (clampedX / tabWidth).floor().clamp(0, 3);

    if (targetIndex != _activeScrubIndex) {
      _activeScrubIndex = targetIndex;
      HapticFeedback.selectionClick();
      widget.onTap(targetIndex);
      setState(() {});
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _holdTimer?.cancel();
    if (_isScrubbing) {
      HapticFeedback.lightImpact();
      _suppressTap = true;
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) {
          setState(() => _suppressTap = false);
        }
      });
    }
    setState(() {
      _isHolding = false;
      _isScrubbing = false;
      _activeScrubIndex = null;
      _pointerDownPos = null;
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _isScrubbing = false;
      _suppressTap = false;
      _activeScrubIndex = null;
      _pointerDownPos = null;
    });
  }

  void _handleItemTap(int index) {
    if (_isScrubbing || _suppressTap) return;
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomMargin = bottomInset > 0 ? bottomInset + 4 : 14.0;
    final effectiveIndex = (_isScrubbing && _activeScrubIndex != null)
        ? _activeScrubIndex!
        : widget.currentIndex;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        child: Row(
          children: [
            // Main Navigation Pill (4 tabs)
            Expanded(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                behavior: HitTestBehavior.translucent,
                child: AnimatedScale(
                  scale: (_isHolding || _isScrubbing) ? 1.025 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: GlassContainer(
                    key: _barKey,
                    borderRadius: BorderRadius.circular(32),
                    blur: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.7,
                    ),
                    color: isDark
                        ? const Color(0xFF141418).withValues(alpha: 0.80)
                        : Colors.white.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: (_isHolding || _isScrubbing) ? 24 : 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          // Tab 0: Beranda
                          Expanded(
                            child: _BottomNavItem(
                              icon: CupertinoIcons.house,
                              activeIcon: CupertinoIcons.house_fill,
                              label: 'Beranda',
                              active: effectiveIndex == 0,
                              isDark: isDark,
                              isScrubbing: _isScrubbing,
                              onTap: () => _handleItemTap(0),
                            ),
                          ),

                          // Tab 1: Komik
                          Expanded(
                            child: _BottomNavItem(
                              icon: CupertinoIcons.book,
                              activeIcon: CupertinoIcons.book_fill,
                              label: 'Komik',
                              active: effectiveIndex == 1,
                              isDark: isDark,
                              isScrubbing: _isScrubbing,
                              onTap: () => _handleItemTap(1),
                            ),
                          ),

                          // Tab 2: Nobar (Watch Party & Komunitas)
                          Expanded(
                            child: _BottomNavItem(
                              icon: CupertinoIcons.play_rectangle,
                              activeIcon: CupertinoIcons.play_rectangle_fill,
                              label: 'Nobar',
                              active: effectiveIndex == 2,
                              isDark: isDark,
                              isScrubbing: _isScrubbing,
                              onTap: () => _handleItemTap(2),
                            ),
                          ),

                          // Tab 3: Profil (with DecoratedAvatar & active ring)
                          Expanded(
                            child: _BottomProfileNavItem(
                              user: user,
                              label: 'Profil',
                              active: effectiveIndex == 3,
                              isDark: isDark,
                              isScrubbing: _isScrubbing,
                              onTap: () => _handleItemTap(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Separate Theme Toggle Bubble
            _ThemeToggleBubble(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

/// Floating Companion Bubble for Quick Light/Dark Theme Switching
class _ThemeToggleBubble extends StatelessWidget {
  const _ThemeToggleBubble({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      scaleDown: 0.88,
      onTap: () {
        HapticFeedback.mediumImpact();
        context.read<ThemeProvider>().toggle();
      },
      child: GlassContainer(
        width: 54,
        height: 60,
        borderRadius: BorderRadius.circular(27),
        blur: 20,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.7,
        ),
        color: isDark
            ? const Color(0xFF141418).withValues(alpha: 0.80)
            : Colors.white.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: Icon(
              isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
              key: ValueKey<bool>(isDark),
              size: 22,
              color: isDark
                  ? const Color(0xFFFFD60A)
                  : const Color(0xFFFF9500),
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
    required this.isScrubbing,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final bool isDark;
  final bool isScrubbing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    final color = active ? activeColor : inactiveColor;

    return BouncyTap(
      scaleDown: 0.90,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: active && isScrubbing ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.2,
                ),
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
    required this.isScrubbing,
    required this.onTap,
  });

  final dynamic user;
  final String label;
  final bool active;
  final bool isDark;
  final bool isScrubbing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    final color = active ? activeColor : inactiveColor;

    return BouncyTap(
      scaleDown: 0.90,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: active && isScrubbing ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<AppUpdateModel?>(
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
                            width: 1.6,
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
                            width: 7,
                            height: 7,
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
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef IOSBottomNavBar = MokoBottomNavBar;
