import 'package:flutter/material.dart';

/// Centralized responsive design utilities for Mobile, Tablet, and Desktop layouts.
class Responsive {
  Responsive._();

  /// Standard screen width breakpoints (in logical pixels)
  static const double mobileMaxWidth = 699.0;
  static const double tabletMinWidth = 700.0;
  static const double tabletMaxWidth = 899.0;
  static const double desktopMinWidth = 900.0;
  static const double wideDesktopMinWidth = 1400.0;

  /// Content max width for desktop readable layout
  static const double maxContentWidth = 1280.0;
  static const double maxProfileWidth = 920.0;

  /// True when the available screen width qualifies as a desktop/large screen
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMinWidth;
  }

  /// True when the available screen width is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMinWidth && width <= tabletMaxWidth;
  }

  /// True when the available screen width is phone/mobile-sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletMinWidth;
  }

  /// Dynamic grid column count for poster cards across all screen sizes
  static int gridColumns(
    BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 5,
    int wideDesktop = 6,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= wideDesktopMinWidth) return wideDesktop;
    if (width >= desktopMinWidth) return desktop;
    if (width >= tabletMinWidth) return tablet;
    return mobile;
  }

  /// Bottom scroll spacer: 120 on mobile for the floating bottom bar, 28 on desktop
  static double bottomNavPadding(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return isDesktop(context) ? 28.0 : (120.0 + bottomInset);
  }

  /// Responsive horizontal page padding
  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= wideDesktopMinWidth) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    if (width >= desktopMinWidth) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}

