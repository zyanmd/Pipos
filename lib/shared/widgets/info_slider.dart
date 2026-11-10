import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple App Store / Apple TV Editorial Announcement Banner.
/// Replaces generic noisy AI-rainbow cards with polished iOS frosted glass cards,
/// SF/Cupertino iconography, and refined typography.
class InfoSlider extends StatefulWidget {
  const InfoSlider({super.key});

  @override
  State<InfoSlider> createState() => _InfoSliderState();
}

class _InfoSliderState extends State<InfoSlider> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _slides = [
    {
      'tag': 'FITUR BARU',
      'icon': CupertinoIcons.textformat_abc,
      'title': 'Katalog Anime A-Z',
      'subtitle': 'Jelajahi seluruh koleksi anime lengkap berdasarkan abjad dan filter cepat.',
      'accent': Color(0xFF333333),
    },
    {
      'tag': 'PEMBARUAN APLIKASI',
      'icon': CupertinoIcons.sparkles,
      'title': 'Moko v1.1.0',
      'subtitle': 'Peningkatan kecepatan streaming, perbaikan player, dan antarmuka baru.',
      'accent': Color(0xFF222222),
    },
    {
      'tag': 'KOMUNITAS',
      'icon': CupertinoIcons.chat_bubble_2_fill,
      'title': 'Diskusi Episode',
      'subtitle': 'Bagikan pendapat dan teori anime favoritmu di kolom komentar tiap episode.',
      'accent': Color(0xFF444444),
    },
    {
      'tag': 'KOLEKSI KOMIK',
      'icon': CupertinoIcons.book_fill,
      'title': 'Manga, Manhwa & Manhua',
      'subtitle': 'Ribuan judul komik terpopuler siap dibaca dengan reader layar penuh yang nyaman.',
      'accent': Color(0xFF333333),
    },
    {
      'tag': 'SINKRONISASI',
      'icon': CupertinoIcons.bookmark_fill,
      'title': 'Bookmark & Riwayat Tonton',
      'subtitle': 'Lanjutkan tontonan atau bacaan terakhirmu kapan saja dengan mudah.',
      'accent': Color(0xFF222222),
    },
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 116,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return _EditorialCard(
                  tag: slide['tag'] as String,
                  icon: slide['icon'] as IconData,
                  title: slide['title'] as String,
                  subtitle: slide['subtitle'] as String,
                  accent: slide['accent'] as Color,
                  isDark: isDark,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Apple-style pill indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: _currentPage == i ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  color: _currentPage == i
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialCard extends StatelessWidget {
  final String tag;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isDark;

  const _EditorialCard({
    required this.tag,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Ultra-subtle Apple accent wash on the right side
            Positioned(
              right: -24,
              top: -24,
              bottom: -24,
              width: 140,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // SF Icon Squircle Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 22,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tag,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1,
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF636366),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
