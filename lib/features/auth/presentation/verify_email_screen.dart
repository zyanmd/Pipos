import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../main/presentation/root_shell.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? username;
  final String? password;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.username,
    this.password,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;

  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        if (mounted) setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (_countdown > 0 || _resending) return;
    HapticFeedback.lightImpact();
    setState(() {
      _resending = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.resendVerification(widget.email);
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Kode verifikasi baru telah dikirimkan ke email Anda.'),
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
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Masukkan kode verifikasi');
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.verifyEmail(code, widget.email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Email berhasil diverifikasi!'),
        ),
      );

      // If user came from registration with password, attempt automatic login
      if (widget.password != null && widget.password!.isNotEmpty) {
        final loginId = widget.username ?? widget.email;
        final ok = await context.read<AuthProvider>().login(
              emailOrUsername: loginId,
              password: widget.password!,
            );

        if (!mounted) return;
        if (ok) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RootShell()),
            (route) => false,
          );
          return;
        }
      }

      // If no password or auto-login wasn't possible, go to LoginScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthRepository.instance.errorMessage(e);
      });
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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.mail_solid,
                        color: isDark ? Colors.white : Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Verifikasi Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle with email
                  Text(
                    'Kami telah mengirimkan kode verifikasi ke alamat email:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Input Card Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // OTP Code Field
                        Text(
                          'Kode Verifikasi (OTP)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeCtrl,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _verify(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                          decoration: InputDecoration(
                            hintText: '123456',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              letterSpacing: 6,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkBackground.withValues(alpha: 0.6)
                                : const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Verify Button
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _loading ? null : _verify,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                child: Center(
                                  child: _loading
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: isDark ? Colors.black : Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Text(
                                          'Verifikasi Akun',
                                          style: TextStyle(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend countdown or button
                        Center(
                          child: _countdown > 0
                              ? Text(
                                  'Kirim ulang kode dalam ${_countdown}s',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _resending ? null : _resendCode,
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: _resending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Kirim Ulang Kode',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Back to login
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(CupertinoIcons.arrow_left, size: 16),
                      label: const Text('Kembali ke Halaman Masuk'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
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
}

