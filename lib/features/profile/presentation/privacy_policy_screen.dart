import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/donation_service.dart';
import '../../../core/utils/responsive.dart';

/// Apple iOS HIG compliant Privacy Policy Screen ("Kebijakan Privasi").
/// Explains transparent data handling, Google Sign-In, permanent account deletion rights,
/// third-party ad networks, and user privacy protections.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Kebijakan Privasi',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                        : [Colors.white, const Color(0xFFF9F9FB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34C759), Color(0xFF30D158)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF34C759).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_shield_fill,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Privasi & Keamanan Data Pengguna',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MOKO Anime & Manga Streaming Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Diperbarui: Oktober 2026',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sections
              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.info_circle_fill,
                iconColor: const Color(0xFF007AFF),
                title: '1. Pendahuluan',
                content:
                    'Selamat datang di MOKO! Privasi dan perlindungan data pribadi Anda adalah prioritas utama kami. Dokumen Kebijakan Privasi ini menjelaskan bagaimana MOKO mengumpulkan, menggunakan, menyimpan, dan melindungi informasi pribadi Anda saat menggunakan aplikasi kami di seluruh platform (Android, Web, dan Desktop).',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.person_crop_circle_fill_badge_checkmark,
                iconColor: const Color(0xFF5856D6),
                title: '2. Data yang Kami Kumpulkan',
                content:
                    'Kami mengumpulkan informasi yang minimal dan relevan semata-mata untuk mengoptimalkan pengalaman Anda:\n\n'
                    '• Informasi Akun: Nama, alamat email, dan foto profil yang diperoleh secara aman melalui Google Sign-In. Pengaturan tanggal lahir bersifat opsional dengan kontrol privasi penuh.\n'
                    '• Data Aktivitas & Personalisasi: Riwayat tontonan anime, bab komik yang dibaca, daftar favorit/bookmark, serta kustomisasi tema dan bubble chat.\n'
                    '• Interaksi Komunitas: Pesan pada Chat Global dan komentar pada episode/bab yang Anda kirimkan.\n'
                    '• Informasi Perangkat & Diagnostik: Model perangkat, versi OS, resolusi layar, dan laporan error (crash log) anonim untuk meningkatkan performa dan stabilitas pemutar video.',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.sparkles,
                iconColor: const Color(0xFFFF9500),
                title: '3. Tujuan Penggunaan Data',
                content:
                    'Data yang dikumpulkan digunakan untuk:\n\n'
                    '1. Menyediakan layanan streaming video anime dan reader komik yang cepat dan responsif.\n'
                    '2. Menyinkronkan progres tontonan dan bacaan Anda antar perangkat.\n'
                    '3. Memfasilitasi interaksi sosial yang sehat pada fitur komentar dan chat komunitas.\n'
                    '4. Mendeteksi serta mencegah aktivitas penyalahgunaan, spam, atau pelanggaran ketentuan komunitas.\n'
                    '5. Mengoptimalkan performa aplikasi dan konsumsi memori cache perangkat.',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.lock_shield_fill,
                iconColor: const Color(0xFF34C759),
                title: '4. Keamanan & Perlindungan Data',
                content:
                    'Kami menerapkan langkah-langkah keamanan berstandar industri:\n\n'
                    '• Seluruh transmisi data antar aplikasi dan server dilindungi enkripsi SSL/TLS (HTTPS) standar perbankan.\n'
                    '• Token sesi autentikasi disimpan secara aman di penyimpanan terenkripsi lokal perangkat Anda.\n'
                    '• Kami TIDAK PERNAH menjual, menyewakan, atau menukar data pribadi Anda kepada pihak ketiga mana pun.',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.link,
                iconColor: const Color(0xFFAF52DE),
                title: '5. Layanan Pihak Ketiga & Iklan',
                content:
                    'Aplikasi MOKO berintegrasi dengan beberapa mitra tepercaya:\n\n'
                    '• Google Identity Services: Autentikasi Google Sign-In yang aman tanpa menyimpan kata sandi Anda di server kami.\n'
                    '• Jaringan Iklan (Google AdMob & Adsterra): Menampilkan iklan banner dan rewarded secara wajar guna membiayai operasional server, bandwidth, dan hosting gratis bagi seluruh pengguna.\n'
                    '• SociaBuzz: Platform donasi sukarela yang aman bagi pengguna yang ingin memberikan apresiasi/dukungan finansial bagi pengembangan MOKO.',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.trash_circle_fill,
                iconColor: const Color(0xFFFF3B30),
                title: '6. Hak Pengguna & Hapus Akun',
                content:
                    'Anda memegang kendali penuh atas data Anda:\n\n'
                    '• Hak Akses & Perubahan: Anda dapat memperbarui nama, avatar, visibilitas tanggal lahir, dan preferensi kapan saja di menu Profil.\n'
                    '• Hak Penghapusan Akun Permanen: Anda berhak menghapus akun Anda sewaktu-waktu. Cukup buka Pengaturan > Akun > Hapus Akun. Seluruh data riwayat, bookmark, profil, dan token Anda akan dihapus secara permanen dari server kami seketika.',
              ),

              _buildSection(
                context: context,
                isDark: isDark,
                icon: CupertinoIcons.envelope_fill,
                iconColor: const Color(0xFF007AFF),
                title: '7. Kontak & Pengaduan',
                content:
                    'Apabila Anda memiliki pertanyaan, saran, atau permintaan terkait privasi data Anda, silakan hubungi tim pengembang MOKO melalui kanal komunitas atau kirimkan dukungan melalui platform Sociabuzz.',
              ),

              const SizedBox(height: 12),

              // Donation CTA Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFD60000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        color: Color(0xFFFF0000),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Beri Dukungan MOKO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Dukung server & pengembangan via Sociabuzz @zanegg',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => DonationService.openDonation(context),
                      child: const Text(
                        'Donasi',
                        style: TextStyle(
                          color: Color(0xFFFF0000),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.82)
                  : const Color(0xFF3C3C43),
            ),
          ),
        ],
      ),
    );
  }
}

