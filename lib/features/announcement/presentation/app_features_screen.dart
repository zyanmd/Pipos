import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../update/services/app_update_service.dart';

/// Halaman dokumentasi interaktif yang merangkum seluruh fitur aplikasi Moko / Animeverse
/// secara lengkap, mendalam, dan terstruktur dengan gaya Apple iOS HIG Frosted Design.
class AppFeaturesScreen extends StatefulWidget {
  const AppFeaturesScreen({super.key});

  @override
  State<AppFeaturesScreen> createState() => _AppFeaturesScreenState();
}

class _AppFeaturesScreenState extends State<AppFeaturesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Anime & Player',
    'Komik & Manga',
    'Komunitas & Chat',
    'Profil & Gamifikasi',
    'Keamanan & Sistem',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final allFeatures = _getAllFeatures();
    final filteredFeatures = allFeatures.where((f) {
      final matchesCategory = _selectedCategory == 'Semua' || f.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          f.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.highlights.any((h) => h.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight,
      appBar: AppBar(
        title: Text(
          'Semua Fitur Aplikasi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackgroundLight,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.maybePop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.transparent,
                width: 0.5,
              ),
            ),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 18,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context) ? 800 : double.infinity,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HERO HEADER ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.sparkles,
                                size: 24,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Moko / Animeverse',
                                        style: GoogleFonts.inter(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'v${AppUpdateService.currentVersion}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Platform Streaming Anime & Komik Bebas Iklan',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Aplikasi ini didesain dari nol dengan fokus pada kecepatan tinggi, pemutar video jernih dan lancar, pembaca komik interaktif yang nyaman, serta kenyamanan dan privasi maksimal.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── SEARCH BAR ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Cari fitur (misal: Pemutar Video, Komik, Notifikasi, Spoiler)...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  size: 16,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),

              // ── CATEGORY PILLS ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = cat);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : borderColor,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── FEATURE CARDS LIST ─────────────────────────────────────────
              if (filteredFeatures.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            size: 40,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada fitur yang cocok dengan kata kunci.',
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = filteredFeatures[index];
                        return _buildFeatureItem(f, isDark, cardBg, borderColor, primaryColor);
                      },
                      childCount: filteredFeatures.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    _FeatureItem item,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon, Category Badge, Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: item.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.badge!.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: const Color(0xFF34C759),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              item.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Bullet Highlights
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.highlights.map((h) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        h,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<_FeatureItem> _getAllFeatures() {
    return [
      // ── ANIME & PLAYER ──────────────────────────────────────────────────────
      _FeatureItem(
        category: 'Anime & Player',
        title: 'Pemutar Video Super Cepat & Jernih',
        badge: 'Unggulan',
        icon: CupertinoIcons.play_circle_fill,
        iconColor: const Color(0xFF007AFF),
        description:
            'Nonton anime favorit dengan gambar jernih berkualitas tinggi tanpa jeda buffering. Video dimuat seketika, sangat hemat kuota internet, dan mendukung berbagai format video secara langsung.',
        highlights: [
          'Streaming Video Tanpa Buffer',
          'Kualitas Jernih Hingga Full HD',
          'Hemat Kuota Internet & Baterai',
          'Subtitle & Suara Jernih Otomatis',
        ],
      ),
      _FeatureItem(
        category: 'Anime & Player',
        title: 'Pilihan Server Alternatif Otomatis',
        badge: 'Lancar',
        icon: Icons.dns_rounded,
        iconColor: const Color(0xFF5856D6),
        description:
            'Tersedia beragam server cadangan berkecepatan tinggi. Jika salah satu server sedang bermasalah atau lambat, aplikasi secara otomatis merekomendasikan server alternatif agar tontonan Anda tetap lancar.',
        highlights: [
          'Pilihan Server Cadangan Cepat',
          'Otomatis Ganti Saat Gangguan',
          'Pilihan Resolusi 360p Hingga 1080p',
          'Streaming Stabil Bebas Hambatan',
        ],
      ),
      _FeatureItem(
        category: 'Anime & Player',
        title: 'Mode Layar Mengambang (PiP)',
        badge: 'Multitasking',
        icon: Icons.picture_in_picture_alt_rounded,
        iconColor: const Color(0xFFFF9500),
        description:
            'Tonton anime di jendela kecil yang mengambang di layar ponsel atau laptop sambil membalas pesan WhatsApp, browsing, atau membuka aplikasi lain tanpa menghentikan pemutaran.',
        highlights: [
          'Nonton Sambil Buka Aplikasi Lain',
          'Ukuran & Posisi Bebas Digeser',
          'Suara Tetap Berjalan di Layar Kunci',
          'Jeda Otomatis Saat Ada Panggilan',
        ],
      ),
      _FeatureItem(
        category: 'Anime & Player',
        title: 'Kontrol Sentuh Praktis & Lanjut Nonton',
        badge: 'Praktis',
        icon: CupertinoIcons.hand_draw_fill,
        iconColor: const Color(0xFFFF2D55),
        description:
            'Navigasi video serba mudah: Ketuk dua kali untuk maju/mundur 10 detik, tahan layar untuk kecepatan 2x instan, kunci sentuhan layar, dan otomatis melanjutkan dari menit terakhir tontonan Anda.',
        highlights: [
          'Ketuk Ganda Maju/Mundur 10 Detik',
          'Tahan Layar Kecepatan 2x Cepat',
          'Kunci Layar Anti Sentuhan Tak Sengaja',
          'Lanjut Menit Terakhir Tersimpan Otomatis',
        ],
      ),
      _FeatureItem(
        category: 'Anime & Player',
        title: 'Jadwal Rilis Anime Setiap Hari',
        badge: 'Terjadwal',
        icon: CupertinoIcons.calendar_today,
        iconColor: const Color(0xFF34C759),
        description:
            'Pantau jadwal tayang anime ongoing setiap harinya dari hari Senin sampai Minggu. Informasi update selalu tepat waktu sesuai jam penayangan dan ketersediaan takarir bahasa Indonesia.',
        highlights: [
          'Jadwal Harian Senin Sampai Minggu',
          'Penanda Episode Terbaru',
          'Cari Berdasarkan Musim & Kategori',
          'Daftar Anime Sedang Berjalan',
        ],
      ),

      // ── KOMIK & MANGA ───────────────────────────────────────────────────────
      _FeatureItem(
        category: 'Komik & Manga',
        title: 'Pembaca Komik & Webtoon Sangat Mulus',
        badge: 'Nyaman',
        icon: CupertinoIcons.book_fill,
        iconColor: const Color(0xFFAF52DE),
        description:
            'Nikmati puluhan ribu judul Manga, Manhwa, dan Manhua dalam Bahasa Indonesia dengan mode gulir vertikal tanpa jeda unduhan antar gambar. Tampilan gambar tajam dan ramah untuk mata.',
        highlights: [
          'Mode Gulir Vertikal Tanpa Putus',
          'Kualitas Gambar Tajam & Bersih',
          'Hemat Ruang Penyimpanan Ponsel',
          'Buka Bab Instan Tanpa Menunggu',
        ],
      ),
      _FeatureItem(
        category: 'Komik & Manga',
        title: 'Koleksi Favorit & Riwayat Baca',
        badge: 'Tersimpan',
        icon: CupertinoIcons.bookmark_fill,
        iconColor: const Color(0xFFFFCC00),
        description:
            'Simpan komik favorit kamu ke daftar bookmark dan akses kembali kapan saja. Riwayat membaca tersinkronisasi otomatis sehingga kamu tidak akan lupa bab terakhir yang telah diselesaikan.',
        highlights: [
          'Daftar Favorit Tersimpan di Akun',
          'Penanda Bab yang Sudah Dibaca',
          'Urutan Bab Selalu Terperbarui',
          'Akses Cepat Langsung dari Profil',
        ],
      ),

      // ── KOMUNITAS & CHAT ────────────────────────────────────────────────────
      _FeatureItem(
        category: 'Komunitas & Chat',
        title: 'Komentar Episode & Diskusi Bersama',
        badge: 'Sosial',
        icon: CupertinoIcons.chat_bubble_2_fill,
        iconColor: const Color(0xFF007AFF),
        description:
            'Diskusikan momen terbaik tiap episode bersama ribuan sesama penggemar anime. Kamu bisa melampirkan gambar meme reaksi, membalas komentar teman dengan geser jari, dan memberi like pada ulasan seru.',
        highlights: [
          'Kirim Gambar & Meme Reaksi',
          'Balas Komentar dengan Mudah',
          'Beri Dukungan & Suka pada Komentar',
          'Komunitas Penggemar Positif & Seru',
        ],
      ),
      _FeatureItem(
        category: 'Komunitas & Chat',
        title: 'Perlindungan Anti Bocoran Cerita (Spoiler)',
        badge: 'Aman',
        icon: CupertinoIcons.eye_slash_fill,
        iconColor: const Color(0xFFFF3B30),
        description:
            'Nonton tenang tanpa takut bocoran cerita penting! Komentar yang mengandung spoiler akan otomatis diburamkan dan hanya dapat dilihat jika kamu sengaja mengetuknya.',
        highlights: [
          'Sensor Otomatis Komentar Bocoran',
          'Ketuk untuk Menampilkan Isi Teks',
          'Bebas Menonton Tanpa Khawatir',
          'Opsi Tag Spoiler Saat Menulis',
        ],
      ),
      _FeatureItem(
        category: 'Komunitas & Chat',
        title: 'Kustomisasi Tema & Tampilan Komentar',
        badge: 'Kustom',
        icon: CupertinoIcons.photo_fill_on_rectangle_fill,
        iconColor: const Color(0xFF5AC8FA),
        description:
            'Ekspresikan kepribadianmu dengan memilih gambar latar belakang estetis untuk kartu komentarmu, lengkap dengan efek transparan elegan yang membuat komentarmu tampil menonjol.',
        highlights: [
          'Pilihan Wallpaper Menawan',
          'Efek Transparan Elegan Modern',
          'Pratinjau Langsung Sebelum Dipakai',
          'Komentar Tampil Beda dan Menarik',
        ],
      ),

      // ── PROFIL & GAMIFIKASI ────────────────────────────────────────────────
      _FeatureItem(
        category: 'Profil & Gamifikasi',
        title: 'Level Penonton & Gelar Penggemar',
        badge: 'Peringkat',
        icon: CupertinoIcons.shield_lefthalf_fill,
        iconColor: const Color(0xFFFF9500),
        description:
            'Aplikasi mencatat waktu menontonmu di berbagai genre anime. Semakin sering kamu menonton, semakin tinggi level akun dan semakin banyak gelar kehormatan penggemar anime yang terbuka!',
        highlights: [
          'Pencatat Jam Menonton Otomatis',
          'Gelar & Lencana Khusus Tiap Genre',
          'Papan Peringkat Penonton Setia',
          'Tampilan Statistik Lengkap di Profil',
        ],
      ),
      _FeatureItem(
        category: 'Profil & Gamifikasi',
        title: 'Dekorasi Bingkai Foto & Gaya Tulisan',
        badge: 'Kreatif',
        icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        iconColor: const Color(0xFF30B0C7),
        description:
            'Perindah foto profil akunmu dengan berbagai bingkai animasi menarik. Kamu bebas menyesuaikan ukuran dan letak bingkai, serta memilih jenis font kartu profil yang paling kamu suka.',
        highlights: [
          'Koleksi Bingkai Profil Animasi',
          'Pengaturan Ukuran & Letak Bingkai',
          'Pilihan Gaya Tulisan Elegan',
          'Sinkronisasi Otomatis ke Seluruh Aplikasi',
        ],
      ),

      // ── KEAMANAN & SISTEM ───────────────────────────────────────────────────
      _FeatureItem(
        category: 'Keamanan & Sistem',
        title: 'Panggilan Darurat Cepat (SOS 112)',
        badge: 'Keamanan',
        icon: CupertinoIcons.phone_badge_plus,
        iconColor: const Color(0xFFFF3B30),
        description:
            'Bantuan darurat saat dibutuhkan: Jika berada dalam situasi bahaya nyata, cukup guncangkan ponsel Anda. Aplikasi akan memunculkan konfirmasi keselamatan darurat dan segera membuka panggilan bantuan 112.',
        highlights: [
          'Guncang Ponsel Saat Dalam Bahaya',
          'Peringatan Konfirmasi Cepat',
          'Akses Panggilan Darurat 112 Langsung',
          'Tombol Batal Jika Tak Sengaja Terguncang',
        ],
      ),
      _FeatureItem(
        category: 'Keamanan & Sistem',
        title: 'Pemberitahuan Rilis & Ulang Tahun',
        badge: 'Pengingat',
        icon: CupertinoIcons.bell_fill,
        iconColor: const Color(0xFFFFCC00),
        description:
            'Dapatkan pemberitahuan tepat waktu untuk episode anime baru, bab komik rilis, dan ucapan selamat hari ulang tahun spesial untukmu. Kamu bebas mengatur notifikasi sesuai kenyamanan.',
        highlights: [
          'Pemberitahuan Episode & Bab Baru',
          'Ucapan Hari Ulang Tahun Spesial',
          'Opsi Notifikasi Hanya Bookmark atau Semua',
          'Bisa Diatur & Dimatikan Kapan Saja',
        ],
      ),
      _FeatureItem(
        category: 'Keamanan & Sistem',
        title: 'Tampilan Halus & Ramah Baterai',
        badge: 'Performa',
        icon: CupertinoIcons.bolt_fill,
        iconColor: const Color(0xFF34C759),
        description:
            'Navigasi dan animasi aplikasi dirancang sangat halus, cepat, dan ringan di ponsel mana pun. Tema Gelap murni membuat mata tidak lelah di malam hari sekaligus menghemat daya baterai.',
        highlights: [
          'Animasi Layar Halus & Responsif',
          'Tema Gelap Hemat Baterai Ponsel',
          'Aplikasi Ringan & Bebas Lemot',
          'Penyimpanan Memori Efisien',
        ],
      ),
    ];
  }
}

class _FeatureItem {
  final String category;
  final String title;
  final String? badge;
  final IconData icon;
  final Color iconColor;
  final String description;
  final List<String> highlights;

  const _FeatureItem({
    required this.category,
    required this.title,
    this.badge,
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.highlights,
  });
}
