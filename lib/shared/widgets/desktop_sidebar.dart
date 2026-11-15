import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/adult_content_service.dart';
import '../../core/services/pip_service.dart';
import '../../features/anime/presentation/anime_schedule_screen.dart';
import '../../features/anime/presentation/anime_search_screen.dart';
import '../../features/genre/presentation/unified_genre_screen.dart';
import '../../features/jav/presentation/jav_home_screen.dart';
import '../../features/novel/presentation/novel_home_screen.dart';
import '../../features/profile/presentation/history_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'decorated_avatar.dart';

/// Desktop Navigation Sidebar styled for Windows & Desktop screens:
/// - Modern aesthetic (OLED Dark / Crisp Light with subtle borders)
/// - Integrated Quick Search bar with Ctrl+K shortcut cue
/// - Comprehensive navigation (Beranda, Komik, Novel, Ulas, Jadwal, Genre, Riwayat, 18+)
/// - Collapsible to compact icon-only rail (74px) or full width (236px)
/// - Modern typography, hover highlights, user avatar ring, and XP level badge
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

  void _pushScreen(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final width = _isCollapsed ? 74.0 : 236.0;
    final bgColor = isDark ? const Color(0xFF0D0D11) : const Color(0xFFF9F9FB);
    final borderColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFE4E4E7);

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
                  width: 0.75,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BRAND LOGO & BADGE
                  _buildBrandHeader(isDark),

                  // 2. QUICK SEARCH BAR
                  _buildSearchBar(isDark),

                  const SizedBox(height: 10),

                  // 3. MAIN NAVIGATION SCROLL AREA
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECTION: MENU UTAMA
                          _buildSectionHeader('MENU', isDark),
                          _buildNavItem(
                            icon: CupertinoIcons.play_circle,
                            activeIcon: CupertinoIcons.play_circle_fill,
                            label: 'Beranda',
                            active: widget.currentIndex == 0,
                            isDark: isDark,
                            onTap: () => widget.onTap(0),
                          ),
                          _buildNavItem(
                            icon: CupertinoIcons.book,
                            activeIcon: CupertinoIcons.book_fill,
                            label: 'Komik',
                            active: widget.currentIndex == 1,
                            isDark: isDark,
                            onTap: () => widget.onTap(1),
                          ),
                          _buildNavItem(
                            icon: CupertinoIcons.text_quote,
                            activeIcon: CupertinoIcons.text_quote,
                            label: 'Novel',
                            active: false,
                            isDark: isDark,
                            onTap: () => _pushScreen(const NovelHomeScreen()),
                          ),
                          _buildNavItem(
                            icon: CupertinoIcons.square_pencil,
                            activeIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                            label: 'Ulas',
                            active: widget.currentIndex == 2,
                            isDark: isDark,
                            onTap: () => widget.onTap(2),
                          ),

                          const SizedBox(height: 14),

                          // SECTION: JELAJAH
                          _buildSectionHeader('JELAJAH', isDark),
                          _buildNavItem(
                            icon: CupertinoIcons.calendar,
                            activeIcon: CupertinoIcons.calendar_today,
                            label: 'Jadwal Rilis',
                            active: false,
                            isDark: isDark,
                            onTap: () => _pushScreen(const AnimeScheduleScreen()),
                          ),
                          _buildNavItem(
                            icon: CupertinoIcons.square_grid_2x2,
                            activeIcon: CupertinoIcons.square_grid_2x2_fill,
                            label: 'Kategori Genre',
                            active: false,
                            isDark: isDark,
                            onTap: () => _pushScreen(const UnifiedGenreScreen()),
                          ),

                          const SizedBox(height: 14),

                          // SECTION: KOLEKSI
                          _buildSectionHeader('KOLEKSI', isDark),
                          _buildNavItem(
                            icon: CupertinoIcons.time,
                            activeIcon: CupertinoIcons.time_solid,
                            label: 'Riwayat Tonton',
                            active: false,
                            isDark: isDark,
                            onTap: () => _pushScreen(const HistoryScreen()),
                          ),

                          // SECTION: 18+ (KONTEN DEWASA - OTOMATIS TAMPIL JIKA TERBUKA)
                          ListenableBuilder(
                            listenable: AdultContentService.instance,
                            builder: (context, _) {
                              if (!AdultContentService.instance.is18Unlocked) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 14),
                                  _buildSectionHeader('DEWASA (18+)', isDark),
                                  _buildNavItem(
                                    icon: CupertinoIcons.flame_fill,
                                    activeIcon: CupertinoIcons.flame_fill,
                                    label: 'JAV (18+)',
                                    active: false,
                                    isDark: isDark,
                                    customColor: const Color(0xFFFF2D55),
                                    onTap: () => _pushScreen(const JavHomeScreen()),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // 4. FOOTER: USER PROFILE & UTILITY CONTROLS
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: borderColor,
                          width: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Profile Item (Tab 3)
                        _buildProfileNavItem(
                          user: user,
                          active: widget.currentIndex == 3,
                          isDark: isDark,
                          onTap: () => widget.onTap(3),
                        ),

                        const SizedBox(height: 8),

                        // Utility Buttons Row: Theme, Settings, Collapse
                        _isCollapsed
                            ? Column(
                                children: [
                                  _buildIconOnlyUtility(
                                    icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                                    tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      themeProvider.toggle();
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  _buildIconOnlyUtility(
                                    icon: CupertinoIcons.gear_alt,
                                    tooltip: 'Pengaturan',
                                    isDark: isDark,
                                    onTap: () => _pushScreen(const SettingsScreen()),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildIconOnlyUtility(
                                    icon: CupertinoIcons.sidebar_right,
                                    tooltip: 'Perbesar Menu',
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _isCollapsed = false);
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  // Theme Switcher Button
                                  Expanded(
                                    child: _buildFooterAction(
                                      icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                                      label: isDark ? 'Gelap' : 'Terang',
                                      tooltip: isDark ? 'Beralih ke Mode Terang (Ctrl+D)' : 'Beralih ke Mode Gelap (Ctrl+D)',
                                      isDark: isDark,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        themeProvider.toggle();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Settings Button
                                  _buildFooterIconButton(
                                    icon: CupertinoIcons.gear_alt,
                                    tooltip: 'Pengaturan',
                                    isDark: isDark,
                                    onTap: () => _pushScreen(const SettingsScreen()),
                                  ),
                                  const SizedBox(width: 6),
                                  // Collapse Toggle
                                  _buildFooterIconButton(
                                    icon: CupertinoIcons.sidebar_left,
                                    tooltip: 'Kecilkan Menu',
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _isCollapsed = true);
                                    },
                                  ),
                                ],
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isCollapsed ? 0 : 16,
        18,
        _isCollapsed ? 0 : 14,
        12,
      ),
      child: _isCollapsed
          ? Center(
              child: GestureDetector(
                onTap: () => widget.onTap(0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/moko.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onTap(0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/icons/moko.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Moko',
                        style: GoogleFonts.outfit(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.40),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          'DESKTOP',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Tooltip(
            message: 'Cari Anime & Komik (Ctrl+K)',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pushScreen(const AnimeSearchScreen()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16161B) : const Color(0xFFEBEBF0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF262630) : const Color(0xFFDFDFE6),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _pushScreen(const AnimeSearchScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161B) : const Color(0xFFEBEBF0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF262630) : const Color(0xFFDFDFE6),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.search,
                  size: 15,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cari anime, komik...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262630) : const Color(0xFFDCDCE2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ctrl K',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          height: 8,
          thickness: 0.5,
          indent: 14,
          endIndent: 14,
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
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
    Color? customColor,
  }) {
    final effectiveColor = customColor ??
        (active
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? Colors.white70 : Colors.black87));

    final activeBgColor = active
        ? (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08))
        : Colors.transparent;

    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: _isCollapsed ? label : '',
        waitDuration: const Duration(milliseconds: 300),
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
                horizontal: _isCollapsed ? 0 : 10,
                vertical: 9,
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
                    size: 21,
                    color: effectiveColor,
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: effectiveColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (active)
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(2),
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

    final level = user?.level ?? 1;
    final xp = user?.xp ?? 0;

    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white70 : Colors.black87);

    final activeBgColor = active
        ? (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08))
        : Colors.transparent;

    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Tooltip(
      message: _isCollapsed ? '$displayName (Lv. $level • $xp XP)' : '',
      waitDuration: const Duration(milliseconds: 300),
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
              horizontal: _isCollapsed ? 0 : 8,
              vertical: 8,
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
                          : (isDark ? Colors.white24 : Colors.black12),
                      width: 1.5,
                    ),
                  ),
                  child: DecoratedAvatar(
                    avatarUrl: user?.avatarUrl,
                    decorationUrl: user?.fullAvatarDecorationUrl ?? user?.avatarDecorationUrl,
                    decorationCode: user?.avatarDecorationCode,
                    radius: 13,
                    fallbackName: displayName,
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Lv. $level • $xp XP',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterAction({
    required IconData icon,
    required String label,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161B) : const Color(0xFFEAEAEF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterIconButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161B) : const Color(0xFFEAEAEF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 15,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconOnlyUtility({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161B) : const Color(0xFFEAEAEF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
