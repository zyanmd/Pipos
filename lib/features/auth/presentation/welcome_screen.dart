import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main/presentation/root_shell.dart';
import 'login_screen.dart';

/// Halaman Welcome / Onboarding dengan latar belakang poster anime bergerak (infinite kinetic scroll)
/// sesuai dengan referensi desain Animax:
/// - Grid 3 kolom poster anime dengan kemiringan dinamis (slanted/tilted ~ -5 derajat)
/// - Animasi pergerakan poster otomatis ke atas & ke bawah secara berkelanjutan (infinite loop)
/// - Gradient overlay gelap yang elegan untuk keterbacaan teks
/// - PageView 3 slide dengan indikator dot berbentuk pill hijau
/// - Tombol utama "Get Started" berbentuk pill hijau mencolok (#00C853)
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scrollController;
  late final PageController _pageController;
  int _currentPage = 0;

  // Daftar poster anime terverifikasi dengan metadata title & accentColor untuk fallback error yang jelas
  static const List<_PosterItem> _column1Posters = [
    _PosterItem(
      title: 'Attack on Titan',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1000/110531.jpg',
      accentColor: Color(0xFF3F2B2B),
    ),
    _PosterItem(
      title: 'Demon Slayer',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1286/99889.jpg',
      accentColor: Color(0xFF1E3A3A),
    ),
    _PosterItem(
      title: 'Chainsaw Man',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1806/126216.jpg',
      accentColor: Color(0xFF4A2818),
    ),
    _PosterItem(
      title: 'Bleach: TYBW',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1764/126627.jpg',
      accentColor: Color(0xFF1E283F),
    ),
    _PosterItem(
      title: 'Naruto Shippuden',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/13/17405.jpg',
      accentColor: Color(0xFF442D15),
    ),
    _PosterItem(
      title: 'Cyberpunk',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1839/122012.jpg',
      accentColor: Color(0xFF3C1F42),
    ),
  ];

  static const List<_PosterItem> _column2Posters = [
    _PosterItem(
      title: 'Spy x Family',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1441/122795.jpg',
      accentColor: Color(0xFF1C3A33),
    ),
    _PosterItem(
      title: 'Belle',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1498/134443.jpg',
      accentColor: Color(0xFF3A1F30),
    ),
    _PosterItem(
      title: 'Tensura Slime',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1694/93337.jpg',
      accentColor: Color(0xFF1F2F45),
    ),
    _PosterItem(
      title: 'Oshi no Ko',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1812/134736.jpg',
      accentColor: Color(0xFF421E36),
    ),
    _PosterItem(
      title: 'Eminence in Shadow',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1874/121869.jpg',
      accentColor: Color(0xFF261E38),
    ),
    _PosterItem(
      title: 'Your Name',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1935/127974.jpg',
      accentColor: Color(0xFF1E2E40),
    ),
  ];

  static const List<_PosterItem> _column3Posters = [
    _PosterItem(
      title: 'Jujutsu Kaisen',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1171/109222.jpg',
      accentColor: Color(0xFF3B1E28),
    ),
    _PosterItem(
      title: 'JJK Season 2',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1792/138022.jpg',
      accentColor: Color(0xFF22283C),
    ),
    _PosterItem(
      title: 'One Piece',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1244/138851.jpg',
      accentColor: Color(0xFF3F1D1D),
    ),
    _PosterItem(
      title: 'Mushoku Tensei',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1530/117776.jpg',
      accentColor: Color(0xFF34301B),
    ),
    _PosterItem(
      title: 'Hunter x Hunter',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/1337/99013.jpg',
      accentColor: Color(0xFF1E3A2E),
    ),
    _PosterItem(
      title: 'Sword Art Online',
      imageUrl: 'https://cdn.myanimelist.net/images/anime/11/39717.jpg',
      accentColor: Color(0xFF1C2C3D),
    ),
  ];

  static const List<_WelcomeSlideData> _slides = [
    _WelcomeSlideData(
      title: 'Welcome to Moko',
      subtitle:
          'The best streaming anime app of the century to entertain you every day',
    ),
    _WelcomeSlideData(
      title: 'Stream in Crystal 1080p',
      subtitle:
          'Watch thousands of the latest subbed & dubbed anime episodes with zero buffering',
    ),
    _WelcomeSlideData(
      title: 'Explore Endless Comics',
      subtitle:
          'Read trending manga, manhwa & manhua with lightning fast full-immersion reader',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Durasi pergerakan poster (loop halus berkelanjutan)
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();

    _pageController = PageController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    HapticFeedback.mediumImpact();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _onSkipToGuest() {
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. LATAR BELAKANG POSTER ANIME BERGERAK (KINETIC SLANTED MULTI-COLUMN)
            Positioned.fill(
              child: _buildAnimatedPostersBackground(screenSize),
            ),

            // 2. GRADIENT OVERLAY (VIGNETTE ATAS & GELAP PEKAT BAWAH)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.20, 0.45, 0.72, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.90),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. KONTEN DEPAN: TITLE, SUBTITLE, DOTS, & TOMBOL GET STARTED
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Carousel Teks (Slide Title & Subtitle)
                      SizedBox(
                        height: 155,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (idx) {
                            setState(() => _currentPage = idx);
                          },
                          itemBuilder: (ctx, idx) {
                            final slide = _slides[idx];
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: Colors.white,
                                    height: 1.15,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 16,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    slide.subtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.2,
                                      color: Colors.white.withValues(alpha: 0.88),
                                      height: 1.35,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Indikator Titik (Dots Indicator)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (idx) {
                          final isActive = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: isActive ? 28 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 24),

                      // Tombol Utama "Get Started" (Pill Putih Terang - Moko Theme)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shadowColor: Colors.white.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            _currentPage == _slides.length - 1 ? 'Mulai Sekarang' : 'Get Started',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Tombol Sekunder: Sudah Punya Akun & Masuk Tamu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                'Masuk dengan Google',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.90),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: _onSkipToGuest,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                'Masuk Tamu',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.70),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun grid 3 kolom yang bergerak otomatis ke atas & ke bawah secara infinite
  Widget _buildAnimatedPostersBackground(Size screenSize) {
    // Ukuran kartu poster anime
    const double cardWidth = 145.0;
    const double cardHeight = 215.0;
    const double spacing = 14.0;
    const double itemTotalHeight = cardHeight + spacing;
    final double loopHeight = itemTotalHeight * _column1Posters.length;

    return OverflowBox(
      maxWidth: screenSize.width * 1.5,
      maxHeight: screenSize.height * 1.5,
      child: Transform.rotate(
        angle: -0.09,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 1.22,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, _) {
            final progress = _scrollController.value;

            // Kolom 1 bergerak ke atas
            final offset1 = (progress * loopHeight) % loopHeight;
            // Kolom 2 bergerak ke bawah (arah berlawanan untuk kedalaman visual!)
            final offset2 = ((1.0 - progress) * loopHeight) % loopHeight;
            // Kolom 3 bergerak ke atas dengan jeda fase
            final offset3 = ((progress + 0.45) * loopHeight) % loopHeight;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RepaintBoundary(
                  child: _buildScrollingColumn(
                    posters: _column1Posters,
                    offsetY: -offset1,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    spacing: spacing,
                  ),
                ),
                const SizedBox(width: spacing),
                RepaintBoundary(
                  child: _buildScrollingColumn(
                    posters: _column2Posters,
                    offsetY: -offset2,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    spacing: spacing,
                  ),
                ),
                const SizedBox(width: spacing),
                RepaintBoundary(
                  child: _buildScrollingColumn(
                    posters: _column3Posters,
                    offsetY: -offset3,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    spacing: spacing,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  /// Satu kolom poster vertikal yang berulang secara infinite tanpa batasan RenderFlex
  Widget _buildScrollingColumn({
    required List<_PosterItem> posters,
    required double offsetY,
    required double cardWidth,
    required double cardHeight,
    required double spacing,
  }) {
    // Kita gandakan poster 3x agar animasi wrap-around berjalan mulus tanpa celah kosong
    final repeated = [...posters, ...posters, ...posters];

    return SizedBox(
      width: cardWidth,
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: cardWidth,
          maxWidth: cardWidth,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: repeated.map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: _AnimePosterCard(
                  poster: item,
                  width: cardWidth,
                  height: cardHeight,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Model data poster untuk kinetic background & fallback visual saat offline/error
class _PosterItem {
  final String title;
  final String imageUrl;
  final Color accentColor;

  const _PosterItem({
    required this.title,
    required this.imageUrl,
    required this.accentColor,
  });
}

/// Kartu satu poster anime dengan sudut tumpul rounded (r: 16) & border halus
/// Dilengkapi fallback error UI yang jelas dan estetik (gradient card + judul anime)
class _AnimePosterCard extends StatelessWidget {
  final _PosterItem poster;
  final double width;
  final double height;

  const _AnimePosterCard({
    required this.poster,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.2),
        child: Image.network(
          poster.imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 290,
          cacheHeight: 430,
          frameBuilder: (ctx, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return Container(
              color: const Color(0xFF23232A),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.play_rectangle,
                size: 24,
                color: Colors.white24,
              ),
            );
          },
          // Fallback UI yang jelas & estetik jika poster gagal dimuat / offline
          errorBuilder: (ctx, _, __) => _buildFallbackErrorCard(),
        ),
      ),
    );
  }

  Widget _buildFallbackErrorCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            poster.accentColor,
            const Color(0xFF16161C),
            Colors.black,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ANIME',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.film,
                size: 14,
                color: Colors.white54,
              ),
            ],
          ),
          const Center(
            child: Icon(
              CupertinoIcons.play_circle_fill,
              size: 34,
              color: Colors.white30,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                poster.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Moko Series',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeSlideData {
  final String title;
  final String subtitle;

  const _WelcomeSlideData({
    required this.title,
    required this.subtitle,
  });
}
