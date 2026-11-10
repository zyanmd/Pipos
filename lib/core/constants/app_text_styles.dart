import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// iOS-style typography using SF Pro Display fallback (Inter for body, Poppins for display).
class AppTextStyles {
  AppTextStyles._();

  /// Large title — used at the top of home screens.
  static TextStyle largeTitle(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
        letterSpacing: -0.5,
        height: 1.1,
      );

  /// Title 1
  static TextStyle title1(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
        letterSpacing: -0.3,
      );

  /// Title 2
  static TextStyle title2(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
      );

  /// Title 3
  static TextStyle title3(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
      );

  /// Headline
  static TextStyle headline(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
      );

  /// Body — 17pt regular
  static TextStyle body(BuildContext ctx, {bool dark = false}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: dark ? const Color(0xFFF7EFF3) : const Color(0xFF1A0B14),
        height: 1.4,
      );

  /// Callout — 16pt
  static TextStyle callout(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: dark ? Colors.white : const Color(0xFF1A0B14),
      );

  /// Subheadline — 15pt
  static TextStyle subheadline(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: dark ? const Color(0xFFB5A3B0) : const Color(0xFF6B5560),
      );

  /// Footnote — 13pt
  static TextStyle footnote(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: dark ? const Color(0xFFA89AA1) : const Color(0xFF6B5560),
      );

  /// Caption — 12pt
  static TextStyle caption(BuildContext ctx, {bool dark = false}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: dark ? const Color(0xFF7A6B76) : const Color(0xFFA89AA1),
      );

  /// Button label
  static TextStyle buttonLabel({bool dark = false}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      );
}
