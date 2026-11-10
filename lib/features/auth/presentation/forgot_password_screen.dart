import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/auth/data/auth_repository.dart';

/// Forgot password flow:
///   Step 0 (request otp) → Step 1 (verify otp) → Step 2 (set new password)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0; // 0=email, 1=otp, 2=reset
  bool _loading = false;
  bool _resendingOtp = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _resetToken;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    if (_resendingOtp) return;
    HapticFeedback.lightImpact();
    setState(() => _resendingOtp = true);
    try {
      await AuthRepository.instance.resendOtp(_emailCtrl.text.trim());
      if (!mounted) return;
      _resetToken = null;
      _otpCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Kode OTP baru telah dikirim ke email Anda'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(AuthRepository.instance.errorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _resendingOtp = false);
    }
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      if (_step == 0) {
        await AuthRepository.instance.forgotPassword(_emailCtrl.text.trim());
        if (!mounted) return;
        _resetToken = null;
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Kode OTP telah dikirim ke email Anda'),
          ),
        );
      } else if (_step == 1) {
        final token = await AuthRepository.instance.verifyOtp(
          _emailCtrl.text.trim(),
          _otpCtrl.text.trim(),
        );
        if (!mounted) return;
        _resetToken = token;
        setState(() => _step = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('OTP terverifikasi. Buat kata sandi baru.'),
          ),
        );
      } else if (_step == 2) {
        final tokenToUse = (_resetToken != null && _resetToken!.isNotEmpty)
            ? _resetToken!
            : _otpCtrl.text.trim();

        await AuthRepository.instance.resetPassword(
          email: _emailCtrl.text.trim(),
          newPassword: _passCtrl.text,
          token: tokenToUse,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Kata sandi berhasil diubah. Silakan masuk.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(AuthRepository.instance.errorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          onPressed: () {
            if (_step > 0) {
              setState(() {
                if (_step == 2) {
                  _resetToken = null;
                }
                _step -= 1;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Indicator (Apple Pill Indicator)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _step == i ? 24 : 8,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: _step == i
                                ? (isDark ? Colors.white : Colors.black)
                                : (_step > i
                                    ? AppColors.iosGreen
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.black.withValues(alpha: 0.12))),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title & Description
                    Text(
                      _step == 0
                          ? 'Lupa Kata Sandi?'
                          : (_step == 1 ? 'Verifikasi Kode OTP' : 'Atur Kata Sandi Baru'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == 0
                          ? 'Masukkan email yang terdaftar untuk menerima kode verifikasi OTP.'
                          : (_step == 1
                              ? 'Masukkan kode OTP 6-digit yang telah dikirim ke email Anda.'
                              : 'Buat kata sandi baru untuk akun Anda.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 28),

                    if (_step == 0)
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _next(),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Alamat Email Terdaftar',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.mail,
                            size: 19,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),

                    if (_step == 1) ...[
                      TextFormField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _next(),
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kode OTP (6 digit)',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            letterSpacing: 0,
                            fontWeight: FontWeight.normal,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.number,
                            size: 19,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Kode OTP wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: (_loading || _resendingOtp) ? null : _resendOtp,
                          icon: _resendingOtp
                              ? const CupertinoActivityIndicator(radius: 7)
                              : Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  size: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                          label: Text(
                            _resendingOtp ? 'Mengirim ulang...' : 'Kirim Ulang OTP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_step == 2) ...[
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kata Sandi Baru',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.lock,
                            size: 19,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                              size: 19,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Kata sandi baru wajib diisi';
                          }
                          if (v.length < 6) {
                            return 'Kata sandi minimal 6 karakter';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _next(),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Konfirmasi Kata Sandi',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.lock_shield,
                            size: 19,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                              size: 19,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Konfirmasi kata sandi wajib diisi';
                          }
                          if (v != _passCtrl.text) {
                            return 'Kata sandi tidak cocok';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Primary Action Button (Welcome Screen Pill Style)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          disabledBackgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                          elevation: 4,
                          shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _loading
                            ? CupertinoActivityIndicator(color: isDark ? Colors.black : Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _step == 0
                                        ? 'Kirim Kode Verifikasi'
                                        : (_step == 1 ? 'Verifikasi Kode' : 'Simpan Kata Sandi Baru'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Back to login button
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Kembali ke Halaman Masuk',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}