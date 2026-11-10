import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/smooth_entrance_transition.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import 'delete_account_dialog.dart';
import 'profile_font_picker_modal.dart';
import 'edit_profile_screen.dart';
import '../../update/data/models/app_update_model.dart';
import '../../update/services/app_update_service.dart';
import '../../../core/services/donation_service.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import 'privacy_policy_screen.dart';
import '../../../core/services/onesignal_service.dart';
import '../../announcement/presentation/app_features_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pengaturan',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context)
                ? Responsive.maxProfileWidth
                : double.infinity,
          ),
          child: SmoothEntranceTransition(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
              // ── 0. Telegram Profile Header Card ───────────
              if (user != null)
                BouncyTap(
                  scaleDown: 0.97,
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => EditProfileScreen(user: user)),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        DecoratedAvatar(
                          radius: 26,
                          avatarUrl: user.avatarUrl,
                          decorationUrl: user.fullAvatarDecorationUrl,
                          decorationCode: user.avatarDecorationCode,
                          decorationScale: user.avatarDecorationScale ?? 1.0,
                          fallbackName: user.displayName ?? user.username,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? user.username,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${user.username}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── 1. Tampilan (Theme & Animasi) ─────────────
              _sectionTitle('TAMPILAN & PENGALAMAN', isDark),
              const SizedBox(height: 8),
              _buildGroupContainer(
                isDark: isDark,
                children: [
                  _buildSettingTile(
                    icon: CupertinoIcons.paintbrush_fill,
                    iconBg: const Color(0xFF007AFF),
                    title: 'Tema Aplikasi',
                    subtitle: theme.mode.label,
                    isDark: isDark,
                    onTap: () => _showThemePicker(isDark),
                  ),
                  _buildDivider(isDark),
                  _buildSettingTile(
                    icon: CupertinoIcons.sparkles,
                    iconBg: const Color(0xFF5856D6),
                    title: 'Animasi Halus',
                    subtitle: theme.isAnimationEnabled
                        ? 'Aktif (Transisi geser & efek visual mulus)'
                        : 'Hemat Baterai (Animasi dinonaktifkan)',
                    isDark: isDark,
                    trailing: CupertinoSwitch(
                      value: theme.isAnimationEnabled,
                      activeTrackColor: const Color(0xFF34C759),
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        theme.setAnimationEnabled(val);
                      },
                    ),
                    onTap: () {
                      theme.setAnimationEnabled(!theme.isAnimationEnabled);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 2. Notifikasi ─────────────────────────────
              _sectionTitle('NOTIFIKASI', isDark),
              const SizedBox(height: 8),
              _buildGroupContainer(
                isDark: isDark,
                children: [
                  _buildSettingTile(
                    icon: CupertinoIcons.bell_fill,
                    iconBg: const Color(0xFFFF9500),
                    title: 'Notifikasi Rilisan (Anime & Komik)',
                    subtitle: OneSignalService.instance.summaryLabel,
                    isDark: isDark,
                    onTap: () => OneSignalService.showPreferenceModal(context).then((_) {
                      if (mounted) setState(() {});
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. Tentang & Informasi ────────────────────
              _sectionTitle('TENTANG & BANTUAN', isDark),
              const SizedBox(height: 8),
              _buildGroupContainer(
                isDark: isDark,
                children: [
                  _buildSettingTile(
                    icon: CupertinoIcons.sparkles,
                    iconBg: const Color(0xFFAF52DE),
                    title: 'Semua Fitur Aplikasi',
                    subtitle: 'Daftar lengkap kemampuan & keunggulan Moko',
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AppFeaturesScreen()),
                    ),
                  ),
                  _buildDivider(isDark),
                  _buildSettingTile(
                    icon: CupertinoIcons.arrow_down_circle_fill,
                    iconBg: const Color(0xFF34C759),
                    title: 'Versi Aplikasi',
                    subtitle: 'Ketuk untuk periksa pembaruan',
                    isDark: isDark,
                    trailing: ValueListenableBuilder<AppUpdateModel?>(
                      valueListenable: AppUpdateService.instance.availableUpdateNotifier,
                      builder: (context, update, _) {
                        if (update != null) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Update Baru',
                              style: TextStyle(
                                color: Color(0xFF34C759),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppUpdateService.currentVersion,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () => AppUpdateService.instance.checkAndShowUpdate(context, isManual: true),
                  ),
                  _buildDivider(isDark),
                  _buildSettingTile(
                    icon: CupertinoIcons.heart_fill,
                    iconBg: const Color(0xFFFF2D55),
                    title: 'Beri Dukungan (Donasi)',
                    subtitle: 'Dukung server MOKO via Sociabuzz @zanegg',
                    isDark: isDark,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => DonationService.openDonation(context),
                  ),
                  _buildDivider(isDark),
                  _buildSettingTile(
                    icon: CupertinoIcons.shield_fill,
                    iconBg: const Color(0xFF5856D6),
                    title: 'Kebijakan Privasi',
                    subtitle: 'Perlindungan data & keamanan pengguna',
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    ),
                  ),
                ],
              ),

              // ── 4. Akun (Jika Login) ──────────────────────
              if (user != null) ...[
                const SizedBox(height: 20),
                _sectionTitle('AKUN PENGGUNA', isDark),
                const SizedBox(height: 8),
                _buildGroupContainer(
                  isDark: isDark,
                  children: [
                    _buildSettingTile(
                      icon: CupertinoIcons.textformat,
                      iconBg: const Color(0xFF30B0C7),
                      title: 'Font Profil Card',
                      subtitle: user.profileFontData != null ? user.profileFontData!.name : 'System Default',
                      isDark: isDark,
                      onTap: () => showProfileFontPicker(context, user: user),
                    ),
                    _buildDivider(isDark),
                    _buildSettingTile(
                      icon: CupertinoIcons.arrow_right_square_fill,
                      iconBg: const Color(0xFFFF9500),
                      title: 'Keluar Akun',
                      subtitle: 'Keluar dari akun di perangkat ini',
                      isDark: isDark,
                      onTap: () => _confirmLogout(context, isDark),
                    ),
                    _buildDivider(isDark),
                    _buildSettingTile(
                      icon: CupertinoIcons.trash_fill,
                      iconBg: const Color(0xFFFF3B30),
                      title: 'Hapus Akun',
                      subtitle: 'Hapus permanen akun & seluruh data dari server',
                      titleColor: const Color(0xFFFF3B30),
                      isDark: isDark,
                      onTap: () => showDeleteAccountDialog(context),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // ── Centered Footer Pill ─────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'MOKO Anime & Komik • v${AppUpdateService.currentVersion}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const AdBannerWidget(
                margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildGroupContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    Color? titleColor,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return BouncyTap(
      scaleDown: 0.982,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: iconBg.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: titleColor ?? (isDark ? Colors.white : Colors.black),
            letterSpacing: -0.2,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 62,
      color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Batal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Keluar'),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showThemePicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final t = context.watch<ThemeProvider>();
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.black12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Grabber(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Pilih Tema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              for (final m in ThemeModeOption.values)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: m == ThemeModeOption.dark
                          ? const Color(0xFF1C1C1E)
                          : (m == ThemeModeOption.light
                              ? Colors.grey.shade100
                              : (isDark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.grey.shade200)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      m.icon,
                      color: m == ThemeModeOption.dark
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    m.label,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: t.mode == m
                      ? Icon(Icons.check_circle_rounded,
                          color: isDark ? Colors.white : Colors.black,)
                      : null,
                  onTap: () {
                    t.setMode(m);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
