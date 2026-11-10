import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/auth/presentation/welcome_screen.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/profile_repository.dart';

const String _kGoogleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
  <path fill="none" d="M0 0h48v48H0z"/>
</svg>
''';

/// Shows a secure dialog requiring confirmation (password or Google) before permanently deleting an account.
Future<void> showDeleteAccountDialog(BuildContext context) {
  HapticFeedback.heavyImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  final _repo = ProfileRepository.instance;
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool? _useGoogleMode;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onSuccessDelete() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.logout();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFFF3B30),
        content: Row(
          children: [
            Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Akun Anda telah berhasil dihapus secara permanen.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteWithPassword() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan kata sandi akun Anda untuk konfirmasi.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    try {
      await _repo.deleteAccount(password: password);
      _onSuccessDelete();
    } catch (e) {
      if (mounted) {
        String msg = _repo.errorMessage(e);
        if (msg.toLowerCase().contains('incorrect password')) {
          msg = 'Kata sandi salah. Silakan periksa kembali.';
        } else if (msg.toLowerCase().contains('password is required')) {
          msg = 'Kata sandi wajib diisi.';
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  Future<void> _handleDeleteWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser;

      // Autentikasi akun Google
      final googleAuth = await AuthRepository.instance.signInWithGoogleAccount();

      // Verifikasi bahwa email Google yang dipilih sesuai dengan user yang login
      final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
      final selectedEmail = googleAuth.email.trim().toLowerCase();

      if (currentEmail.isNotEmpty && selectedEmail != currentEmail) {
        throw Exception(
          'Akun Google ($selectedEmail) tidak sesuai dengan akun Anda ($currentEmail). Harap samakan dengan akun Google Anda.',
        );
      }

      await _repo.deleteAccountWithGoogle(
        googleId: googleAuth.googleId,
        email: googleAuth.email,
      );

      _onSuccessDelete();
    } catch (e) {
      if (mounted) {
        String msg = _repo.errorMessage(e);
        final lower = msg.toLowerCase();
        if (lower.contains('login google dibatalkan') ||
            lower.contains('dibatalkan') ||
            lower.contains('sign_in_canceled') ||
            lower.contains('canceled') ||
            lower.contains('cancelled')) {
          msg = 'Verifikasi Google dibatalkan.';
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final email = (currentUser?.email ?? '').trim();
    final bool isGoogleUser = (currentUser?.isGoogleUser == true) ||
        email.toLowerCase().endsWith('@gmail.com') ||
        (currentUser?.googleId != null && currentUser!.googleId!.isNotEmpty);

    final bool useGoogleAuth = _useGoogleMode ?? isGoogleUser;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning Icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: Color(0xFFFF3B30),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Hapus Akun Permanen?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Explanatory Text
              Text(
                'Semua riwayat tontonan, bookmark, koleksi tersimpan, komentar, dan avatar kustom akan dihapus secara permanen dari server.\n\nTindakan ini TIDAK DAPAT dibatalkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 18),

              // Mode Konfirmasi Google (Tanpa Kata Sandi):
              if (useGoogleAuth) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SvgPicture.string(_kGoogleSvg, width: 22, height: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Konfirmasi Akun Google',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email.isNotEmpty
                            ? 'Tidak perlu kata sandi. Cukup samakan dan login dengan akun Google yang sesuai ($email) untuk konfirmasi penghapusan.'
                            : 'Tidak perlu kata sandi. Cukup login dan pastikan akun Google yang Anda pilih sesuai untuk konfirmasi penghapusan.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Tombol Hapus dengan Google
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleDeleteWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFFFF3B30).withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.string(_kGoogleSvg, width: 18, height: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'Konfirmasi Hapus dengan Akun Google',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _errorMessage = null;
                              _useGoogleMode = false;
                            });
                          },
                    child: Text(
                      'Gunakan kata sandi saja',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Mode Kata Sandi untuk akun reguler
                Text(
                  'Masukkan kata sandi untuk konfirmasi:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  enabled: !_isLoading,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Kata Sandi Akun',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(
                      CupertinoIcons.lock_shield,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF3B30),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleDeleteWithPassword(),
                ),

                const SizedBox(height: 14),

                // Tombol Hapus Akun dengan Password
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleDeleteWithPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFFFF3B30).withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Hapus Akun dengan Kata Sandi',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),

                const SizedBox(height: 12),

                // Atau tombol Hapus dengan Google
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _errorMessage = null;
                            _useGoogleMode = true;
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.string(_kGoogleSvg, width: 18, height: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Konfirmasi via Google (Tanpa Kata Sandi)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle, color: Color(0xFFFF3B30), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Tombol Batal
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: isDark ? Colors.white60 : Colors.black54,
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
