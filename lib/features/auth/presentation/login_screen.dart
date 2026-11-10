import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../main/presentation/root_shell.dart';
import 'widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _loginWithGoogle() async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final ok = await context.read<AuthProvider>().loginWithGoogle();
    if (!mounted) return;

    if (ok) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootShell()),
        (route) => false,
      );
    } else {
      final err = context.read<AuthProvider>().error;
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text(err),
          ),
        );
      }
    }
  }

  void _continueAsGuest() {
    HapticFeedback.lightImpact();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RootShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(CupertinoIcons.chevron_back),
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Icon with Bubble Squircle Card
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        'assets/icons/moko.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          CupertinoIcons.play_rectangle_fill,
                          color: isDark ? Colors.white : Colors.black,
                          size: 38,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Header Title & Subtitle (Apple HIG Typography + Bubble theme)
                  Text(
                    'Masuk ke Moko',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Gunakan akun Google Anda untuk mengakses semua fitur, sinkronisasi koleksi, dan bergabung dalam obrolan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        height: 1.4,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Features Bubble Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          icon: CupertinoIcons.cloud_fill,
                          iconColor: const Color(0xFF0A84FF),
                          title: 'Sinkronisasi Cloud',
                          subtitle: 'Bookmark, favorit, dan riwayat tontonan aman tersimpan',
                          isDark: isDark,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 0.5,
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        _buildFeatureRow(
                          icon: CupertinoIcons.sparkles,
                          iconColor: const Color(0xFFFF9500),
                          title: 'Koleksi & Kustomisasi',
                          subtitle: 'Bingkai avatar, tema komentar, dan lencana profil',
                          isDark: isDark,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 0.5,
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        _buildFeatureRow(
                          icon: CupertinoIcons.chat_bubble_2_fill,
                          iconColor: const Color(0xFF34C759),
                          title: 'Komunitas Penggemar',
                          subtitle: 'Komentar di setiap episode dan obrolan grup interaktif',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Masuk dengan Google (Primary Pill Button)
                  GoogleSignInButton(
                    onPressed: auth.loading ? null : _loginWithGoogle,
                    isLoading: auth.loading,
                    text: 'Masuk dengan Google',
                  ),

                  const SizedBox(height: 14),

                  // Masuk sebagai Tamu (Secondary Pill Button)
                  SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: auth.loading ? null : _continueAsGuest,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        'Lanjutkan sebagai Tamu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Text(
                    'Dengan masuk, Anda menyetujui Ketentuan Layanan\ndan Kebijakan Privasi Moko.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
