import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mal_models.dart';
import '../../../../core/services/mal_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/bouncy_tap.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../../../shared/widgets/count_up_text.dart';
import '../../../../shared/widgets/ios_capsule_text_field.dart';
import 'widgets/mal_oauth_webview.dart';

/// Halaman Integrasi dan Sinkronisasi MyAnimeList (Anime & Komik)
class MalIntegrationScreen extends StatefulWidget {
  final String initialMedia;

  const MalIntegrationScreen({
    super.key,
    this.initialMedia = 'anime',
  });

  @override
  State<MalIntegrationScreen> createState() => _MalIntegrationScreenState();
}

class _MalIntegrationScreenState extends State<MalIntegrationScreen> {
  bool _isLoading = false;
  late String _selectedMedia; // 'anime' or 'manga'
  String _selectedFilter = 'all'; // all, watching/reading, plan_to_watch/plan_to_read, completed
  List<MalAnimeListEntry> _animeWatchlist = [];
  List<MalMangaListEntry> _mangaWatchlist = [];
  MalUser? _userProfile;

  @override
  void initState() {
    super.initState();
    _selectedMedia = widget.initialMedia;
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!MalService.instance.isConnected) return;
    setState(() => _isLoading = true);
    try {
      final user = await MalService.instance.fetchCurrentUserProfile();
      if (_selectedMedia == 'anime') {
        final list = await MalService.instance.getUserWatchlist(
          status: _selectedFilter == 'all' ? null : _selectedFilter,
        );
        if (mounted) {
          setState(() {
            _userProfile = user;
            _animeWatchlist = list;
            _isLoading = false;
          });
        }
      } else {
        final list = await MalService.instance.getUserMangaWatchlist(
          status: _selectedFilter == 'all' ? null : _selectedFilter,
        );
        if (mounted) {
          setState(() {
            _userProfile = user;
            _mangaWatchlist = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithOAuth() async {
    HapticFeedback.mediumImpact();
    final success = await MalOAuthWebView.show(context);
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil terhubung ke akun MyAnimeList! Otomatis menyinkronkan riwayat tontonan...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    }
  }

  Future<void> _triggerManualSync() async {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memulai sinkronisasi riwayat ke MyAnimeList...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final report = await MalService.instance.syncWithMal();
    if (mounted) {
      if (report.success) {
        final total = report.totalSynced;
        final msg = total > 0
            ? 'Sinkronisasi selesai! Berhasil menyinkronkan $total item (${report.animeUploaded} anime, ${report.mangaUploaded} komik) ke akun MAL.'
            : 'Sinkronisasi selesai! Semua progres tontonan & bacaan sudah mutakhir di MAL.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.errorMessage ?? 'Gagal melakukan sinkronisasi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Putuskan MyAnimeList?'),
        content: const Text('Sinkronisasi tontonan dan bacaan otomatis akan dihentikan.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MalService.instance.disconnect();
      if (mounted) {
        setState(() {
          _userProfile = null;
          _animeWatchlist = [];
          _mangaWatchlist = [];
        });
      }
    }
  }

  Future<void> _incrementEpisode(MalAnimeListEntry entry) async {
    if (!MalService.instance.hasOAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login dengan OAuth diperlukan untuk mengubah episode di MAL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final nextEp = entry.numWatchedEpisodes + 1;
    final isDone = entry.anime.numEpisodes != null && entry.anime.numEpisodes! > 0 && nextEp >= entry.anime.numEpisodes!;
    final ok = await MalService.instance.updateAnimeStatus(
      malId: entry.anime.id,
      status: isDone ? 'completed' : 'watching',
      episodesWatched: nextEp,
    );

    if (ok && mounted) {
      setState(() {
        final idx = _animeWatchlist.indexWhere((e) => e.anime.id == entry.anime.id);
        if (idx != -1) {
          _animeWatchlist[idx] = _animeWatchlist[idx].copyWith(
            numWatchedEpisodes: nextEp,
            status: isDone ? 'completed' : 'watching',
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Episode ${entry.anime.title} diupdate ke $nextEp!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _incrementChapter(MalMangaListEntry entry) async {
    if (!MalService.instance.hasOAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login dengan OAuth diperlukan untuk mengubah chapter di MAL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final nextChap = entry.numChaptersRead + 1;
    final isDone = entry.manga.numChapters != null && entry.manga.numChapters! > 0 && nextChap >= entry.manga.numChapters!;
    final ok = await MalService.instance.updateMangaStatus(
      malId: entry.manga.id,
      status: isDone ? 'completed' : 'reading',
      chaptersRead: nextChap,
    );

    if (ok && mounted) {
      setState(() {
        final idx = _mangaWatchlist.indexWhere((e) => e.manga.id == entry.manga.id);
        if (idx != -1) {
          _mangaWatchlist[idx] = _mangaWatchlist[idx].copyWith(
            numChaptersRead: nextChap,
            status: isDone ? 'completed' : 'reading',
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chapter ${entry.manga.title} diupdate ke $nextChap!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openInAnimeverse(MalAnimeListEntry entry) async {
    HapticFeedback.selectionClick();
    // 1. Cek apakah sudah ada pemetaan lokal sebelumnya
    if (MalService.instance.hasLocalMappingForMalId(entry.anime.id)) {
      final mappedId = MalService.instance.getLocalAnimeIdForMalId(entry.anime.id)!;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => AnimeDetailScreen(
            animeId: mappedId,
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final clean = MalService.cleanTitleForMatching(entry.anime.title);
      final searchRes = await AnimeRepository.instance.search(clean);
      if (mounted) {
        setState(() => _isLoading = false);
        if (searchRes.isNotEmpty) {
          final target = searchRes.first;
          unawaited(MalService.instance.setManualAnimeMapping(target.title, entry.anime.id, animeId: target.id));
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => AnimeDetailScreen(
                animeId: target.id,
                anime: target,
              ),
            ),
          );
        } else {
          // Buka sheet pencarian manual server jika belum ditemukan otomatis
          _showManualMatchServerSheet(entry);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showManualMatchServerSheet(entry);
      }
    }
  }

  void _openInComicverse(MalMangaListEntry entry) async {
    HapticFeedback.selectionClick();
    // 1. Cek apakah sudah ada pemetaan komik lokal sebelumnya
    if (MalService.instance.hasLocalMangaMappingForMalId(entry.manga.id)) {
      final mappedSlug = MalService.instance.getLocalMangaSlugForMalId(entry.manga.id)!;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ComicDetailScreen(
            slug: mappedSlug,
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final clean = MalService.cleanMangaTitleForMatching(entry.manga.title);
      final searchRes = await ComicRepository.instance.search(clean);
      if (mounted) {
        setState(() => _isLoading = false);
        if (searchRes.isNotEmpty) {
          final target = searchRes.first;
          unawaited(MalService.instance.setManualMangaMapping(target.title, entry.manga.id, comicSlug: target.slug));
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ComicDetailScreen(
                slug: target.slug,
                comic: target,
              ),
            ),
          );
        } else {
          // Buka sheet pencarian manual server jika belum ditemukan otomatis
          _showManualMatchServerMangaSheet(entry);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showManualMatchServerMangaSheet(entry);
      }
    }
  }

  void _showManualMatchServerSheet(MalAnimeListEntry entry) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ServerAnimeMatchModal(
        entry: entry,
        isDark: isDark,
        onMatched: (AnimeModel selected) {
          setState(() {
            final idx = _animeWatchlist.indexWhere((e) => e.anime.id == entry.anime.id);
            if (idx != -1) {
              _animeWatchlist[idx] = _animeWatchlist[idx].copyWith(isAvailableLocally: true);
            }
          });
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => AnimeDetailScreen(
                animeId: selected.id,
                anime: selected,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showManualMatchServerMangaSheet(MalMangaListEntry entry) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ServerComicMatchModal(
        entry: entry,
        isDark: isDark,
        onMatched: (ComicModel selected) {
          setState(() {
            final idx = _mangaWatchlist.indexWhere((e) => e.manga.id == entry.manga.id);
            if (idx != -1) {
              _mangaWatchlist[idx] = _mangaWatchlist[idx].copyWith(isAvailableLocally: true);
            }
          });
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ComicDetailScreen(
                slug: selected.slug,
                comic: selected,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = MalService.instance.isConnected;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.6,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  CupertinoIcons.chevron_back,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E51A2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E51A2).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'MAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'MyAnimeList Sync',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 0.6,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                    tooltip: 'Perbarui Data',
                    onPressed: _isLoading ? null : _loadData,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context)
                ? Responsive.maxProfileWidth
                : double.infinity,
          ),
          child: isConnected ? _buildConnectedView(isDark) : _buildUnconnectedView(isDark),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAMPILAN BELUM TERHUBUNG
  // ─────────────────────────────────────────────────────────────

  Widget _buildUnconnectedView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Hero Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF1B2A4A), Color(0xFF141418)]
                  : const [Color(0xFFE8EEF8), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2E51A2).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E51A2).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E51A2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E51A2).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'MAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sinkronkan Anime & Komik ke MyAnimeList',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lacak episode anime yang kamu tonton dan chapter manga/komik yang kamu baca secara otomatis langsung ke akun MyAnimeList!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Keunggulan Fitur
        _buildFeatureRow(
          icon: CupertinoIcons.sparkles,
          title: 'Auto-Scrobble Episode & Chapter',
          desc: 'Saat nonton anime atau baca komik di Animeverse, riwayat di MAL kamu otomatis bertambah.',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildFeatureRow(
          icon: CupertinoIcons.check_mark_circled_solid,
          title: 'Deteksi Katalog Server Cerdas',
          desc: 'Anime dan manga di daftar MAL kamu yang tersedia di server bisa langsung dibuka dalam 1 klik.',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildFeatureRow(
          icon: CupertinoIcons.shield_lefthalf_fill,
          title: 'Aman & Terverifikasi',
          desc: 'Menggunakan otorisasi OAuth 2.0 PKCE resmi dari MyAnimeList tanpa menyimpan kata sandimu.',
          isDark: isDark,
        ),

        const SizedBox(height: 32),

        // Tombol Login Akun MyAnimeList (OAuth PKCE)
        BouncyTap(
          onTap: _loginWithOAuth,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E51A2), Color(0xFF1D356A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E51A2).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.link, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Login Akun MyAnimeList',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2E51A2)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAMPILAN TERHUBUNG
  // ─────────────────────────────────────────────────────────────

  Widget _buildConnectedView(bool isDark) {
    final user = _userProfile;
    final userName = user?.name ?? MalService.instance.username ?? 'Pengguna MAL';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2E51A2),
                    backgroundImage: user?.picture != null
                        ? NetworkImage(user!.picture!)
                        : null,
                    child: user?.picture == null
                        ? const Text('MAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓ Terhubung',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.power, color: Colors.redAccent, size: 20),
                    tooltip: 'Putuskan Hubungan',
                    onPressed: _disconnect,
                  ),
                ],
              ),

              // Stats Row if available
              if (user?.stats != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Watching', user!.stats!.watching.toString(), isDark),
                    _statItem('Plan to Watch', user.stats!.planToWatch.toString(), isDark),
                    _statItem('Completed', user.stats!.completed.toString(), isDark),
                    _statItem('Rata-rata', user.stats!.meanScore > 0 ? user.stats!.meanScore.toStringAsFixed(1) : '-', isDark),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Auto-Scrobble Toggle
        ValueListenableBuilder<bool>(
          valueListenable: MalService.instance.autoScrobbleNotifier,
          builder: (context, autoScrobble, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.bolt_fill, color: Color(0xFF2E51A2), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Scrobble Tonton & Baca',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Otomatis catat episode anime & chapter komik di MAL',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: autoScrobble,
                    activeTrackColor: const Color(0xFF2E51A2),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      MalService.instance.setAutoScrobble(val);
                    },
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // ── KARTU SINKRONISASI MENYELURUH (SYNC LOCAL <-> MAL) ───────
        AnimatedBuilder(
          animation: Listenable.merge([
            MalService.instance.isSyncingNotifier,
            MalService.instance.syncStatusMessageNotifier,
            MalService.instance.lastSyncReportNotifier,
          ]),
          builder: (context, _) {
            final isSyncing = MalService.instance.isSyncing;
            final syncMsg = MalService.instance.syncStatusMessageNotifier.value;
            final lastReport = MalService.instance.lastSyncReportNotifier.value;
            final lastTime = MalService.instance.lastSyncTime;

            String syncSubtitle;
            if (isSyncing) {
              syncSubtitle = syncMsg ?? 'Menyinkronkan riwayat tontonan & bacaan ke MAL...';
            } else if (lastTime != null) {
              final diff = DateTime.now().difference(lastTime);
              String timeStr;
              if (diff.inSeconds < 60) {
                timeStr = 'Baru saja';
              } else if (diff.inMinutes < 60) {
                timeStr = '${diff.inMinutes} menit lalu';
              } else if (diff.inHours < 24) {
                timeStr = '${diff.inHours} jam lalu';
              } else {
                timeStr = '${diff.inDays} hari lalu';
              }
              final syncedCount = lastReport?.totalSynced ?? 0;
              syncSubtitle = 'Terakhir disinkronkan: $timeStr${syncedCount > 0 ? ' • $syncedCount item tersinkron' : ''}';
            } else {
              syncSubtitle = 'Sinkronkan riwayat tontonan anime & bacaan komik kamu ke akun MyAnimeList';
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF142038), AppColors.darkCard]
                      : const [Color(0xFFEFF5FD), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.35 : 0.20),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.12 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSyncing
                          ? const CupertinoActivityIndicator(radius: 10, color: Color(0xFF2E51A2))
                          : const Icon(
                              CupertinoIcons.arrow_2_circlepath,
                              color: Color(0xFF2E51A2),
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sinkronisasi Akun',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            if (isSyncing) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E51A2).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Proses',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E51A2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          syncSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncyTap(
                    scaleDown: 0.94,
                    onTap: isSyncing ? null : _triggerManualSync,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSyncing
                            ? Colors.grey.withValues(alpha: 0.2)
                            : const Color(0xFF2E51A2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isSyncing ? 'Sinkron...' : 'Sinkronkan',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSyncing
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── MEDIA SEGMENTED CONTROL: ANIME vs KOMIK ─────────────────
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _selectedMedia,
          backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          thumbColor: const Color(0xFF2E51A2),
          children: {
            'anime': _mediaSegment('Anime', CupertinoIcons.film, _selectedMedia == 'anime'),
            'manga': _mediaSegment('Komik (Manga)', CupertinoIcons.book, _selectedMedia == 'manga'),
          },
          onValueChanged: (val) {
            if (val != null && val != _selectedMedia) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMedia = val;
                _selectedFilter = 'all';
              });
              _loadData();
            }
          },
        ),

        const SizedBox(height: 12),

        // ── STATUS FILTER SEGMENTED CONTROL ────────────────────────
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _selectedFilter,
          backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          children: _selectedMedia == 'anime'
              ? {
                  'all': _segmentText('Semua', _selectedFilter == 'all', isDark),
                  'watching': _segmentText('Watching', _selectedFilter == 'watching', isDark),
                  'plan_to_watch': _segmentText('Plan', _selectedFilter == 'plan_to_watch', isDark),
                  'completed': _segmentText('Selesai', _selectedFilter == 'completed', isDark),
                }
              : {
                  'all': _segmentText('Semua', _selectedFilter == 'all', isDark),
                  'reading': _segmentText('Reading', _selectedFilter == 'reading', isDark),
                  'plan_to_read': _segmentText('Plan', _selectedFilter == 'plan_to_read', isDark),
                  'completed': _segmentText('Selesai', _selectedFilter == 'completed', isDark),
                },
          onValueChanged: (val) {
            if (val != null) {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = val);
              _loadData();
            }
          },
        ),

        const SizedBox(height: 14),

        // Watchlist Entries
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_selectedMedia == 'anime') ...[
          if (_animeWatchlist.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(CupertinoIcons.film, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada anime di kategori ini.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._animeWatchlist.map((entry) => _buildAnimeWatchCard(entry, isDark)),
        ] else ...[
          if (_mangaWatchlist.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(CupertinoIcons.book, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada komik di kategori ini.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._mangaWatchlist.map((entry) => _buildMangaWatchCard(entry, isDark)),
        ],
      ],
    );
  }

  Widget _mediaSegment(String label, IconData icon, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        CountUpText(
          text: value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _segmentText(String label, bool active, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white54 : Colors.black54),
        ),
      ),
    );
  }

  Widget _buildAnimeWatchCard(MalAnimeListEntry entry, bool isDark) {
    final anime = entry.anime;
    final totalEps = anime.numEpisodes != null && anime.numEpisodes! > 0
        ? anime.numEpisodes.toString()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 80,
              child: anime.mainPicture != null
                  ? Image.network(
                      anime.mainPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                    )
                  : Container(color: Colors.grey.shade800),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),

                // Episode & Score Pill
                Row(
                  children: [
                    Text(
                      'Ep: ${entry.numWatchedEpisodes} / $totalEps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (entry.score > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.star_fill, size: 9, color: Color(0xFFFF9500)),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.score}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF9500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Ketersediaan Server Badge & Action
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.isAvailableLocally || MalService.instance.hasLocalMappingForMalId(entry.anime.id)) ...[
                      GestureDetector(
                        onTap: () => _openInAnimeverse(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.play_circle_fill, size: 11, color: Color(0xFF34C759)),
                              SizedBox(width: 3),
                              Text(
                                'Tersedia',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showManualMatchServerSheet(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_2_squarepath,
                                size: 10,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Ganti',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await MalService.instance.removeManualAnimeMapping('', malId: entry.anime.id);
                          setState(() {
                            final idx = _animeWatchlist.indexWhere((e) => e.anime.id == entry.anime.id);
                            if (idx != -1) {
                              _animeWatchlist[idx] = _animeWatchlist[idx].copyWith(isAvailableLocally: false);
                            }
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sambungan server untuk "${entry.anime.title}" telah diputuskan.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link_off,
                                size: 10,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Putuskan',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Belum Ada',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showManualMatchServerSheet(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2E51A2).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.search, size: 10, color: Color(0xFF2E51A2)),
                              SizedBox(width: 3),
                              Text(
                                'Cocokkan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E51A2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action +1 Episode
          if (MalService.instance.hasOAuth)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton(
                icon: const Icon(CupertinoIcons.plus_circle, color: Color(0xFF2E51A2), size: 28),
                tooltip: '+1 Episode',
                onPressed: () => _incrementEpisode(entry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMangaWatchCard(MalMangaListEntry entry, bool isDark) {
    final manga = entry.manga;
    final totalChaps = manga.numChapters != null && manga.numChapters! > 0
        ? manga.numChapters.toString()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 80,
              child: manga.mainPicture != null
                  ? Image.network(
                      manga.mainPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                    )
                  : Container(color: Colors.grey.shade800),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manga.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),

                // Chapter & Score Pill
                Row(
                  children: [
                    Text(
                      'Ch: ${entry.numChaptersRead} / $totalChaps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (entry.score > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.star_fill, size: 9, color: Color(0xFFFF9500)),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.score}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF9500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Ketersediaan Server Badge & Action
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.isAvailableLocally || MalService.instance.hasLocalMangaMappingForMalId(entry.manga.id)) ...[
                      GestureDetector(
                        onTap: () => _openInComicverse(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.book_fill, size: 11, color: Color(0xFF34C759)),
                              SizedBox(width: 3),
                              Text(
                                'Tersedia',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showManualMatchServerMangaSheet(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_2_squarepath,
                                size: 10,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Ganti',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await MalService.instance.removeManualMangaMapping('', malId: entry.manga.id);
                          setState(() {
                            final idx = _mangaWatchlist.indexWhere((e) => e.manga.id == entry.manga.id);
                            if (idx != -1) {
                              _mangaWatchlist[idx] = _mangaWatchlist[idx].copyWith(isAvailableLocally: false);
                            }
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sambungan server untuk "${entry.manga.title}" telah diputuskan.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link_off,
                                size: 10,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Putuskan',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Belum Ada',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showManualMatchServerMangaSheet(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2E51A2).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.search, size: 10, color: Color(0xFF2E51A2)),
                              SizedBox(width: 3),
                              Text(
                                'Cocokkan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E51A2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action +1 Chapter
          if (MalService.instance.hasOAuth)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton(
                icon: const Icon(CupertinoIcons.plus_circle, color: Color(0xFF2E51A2), size: 28),
                tooltip: '+1 Chapter',
                onPressed: () => _incrementChapter(entry),
              ),
            ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet untuk mencari dan mencocokkan anime di katalog server Animeverse
class _ServerAnimeMatchModal extends StatefulWidget {
  final MalAnimeListEntry entry;
  final bool isDark;
  final ValueChanged<AnimeModel> onMatched;

  const _ServerAnimeMatchModal({
    required this.entry,
    required this.isDark,
    required this.onMatched,
  });

  @override
  State<_ServerAnimeMatchModal> createState() => _ServerAnimeMatchModalState();
}

class _ServerAnimeMatchModalState extends State<_ServerAnimeMatchModal> {
  late final TextEditingController _controller;
  List<AnimeModel> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final initialQuery = MalService.cleanTitleForMatching(widget.entry.anime.title);
    _controller = TextEditingController(text: initialQuery);
    _doSearch(initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final list = await AnimeRepository.instance.search(clean);
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cocokkan Anime di Server',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pilih judul di server untuk "${widget.entry.anime.title}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IosCapsuleTextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              onSubmitted: _doSearch,
              hintText: 'Ketik nama anime di server...',
              prefixIcon: CupertinoIcons.search,
            ),
          ),
          const SizedBox(height: 12),

          // Results list or loader
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.film,
                                size: 48,
                                color: widget.isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada anime server yang cocok dengan "${_controller.text}".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Coba ubah kata kunci pencarian judul di atas.',
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = _results[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 68,
                                    child: item.thumb != null && item.thumb!.isNotEmpty
                                        ? Image.network(
                                            item.thumb!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                                          )
                                        : Container(color: Colors.grey.shade800),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: widget.isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (item.type != null && item.type!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.type!,
                                                style: const TextStyle(
                                                  color: Color(0xFF2E51A2),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (item.status != null && item.status!.isNotEmpty)
                                            Text(
                                              item.status!,
                                              style: TextStyle(
                                                color: widget.isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    final messenger = ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    await MalService.instance.setManualAnimeMapping(
                                      item.title,
                                      widget.entry.anime.id,
                                      animeId: item.id,
                                    );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Berhasil menghubungkan "${item.title}" ke MyAnimeList!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    widget.onMatched(item);
                                  },
                                  icon: const Icon(CupertinoIcons.link, size: 14),
                                  label: const Text(
                                    'Hubungkan',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E51A2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet untuk mencari dan mencocokkan komik di katalog server Comicverse
class _ServerComicMatchModal extends StatefulWidget {
  final MalMangaListEntry entry;
  final bool isDark;
  final ValueChanged<ComicModel> onMatched;

  const _ServerComicMatchModal({
    required this.entry,
    required this.isDark,
    required this.onMatched,
  });

  @override
  State<_ServerComicMatchModal> createState() => _ServerComicMatchModalState();
}

class _ServerComicMatchModalState extends State<_ServerComicMatchModal> {
  late final TextEditingController _controller;
  List<ComicModel> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final initialQuery = MalService.cleanMangaTitleForMatching(widget.entry.manga.title);
    _controller = TextEditingController(text: initialQuery);
    _doSearch(initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final list = await ComicRepository.instance.search(clean);
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cocokkan Komik di Server',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pilih judul di server untuk "${widget.entry.manga.title}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IosCapsuleTextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              onSubmitted: _doSearch,
              hintText: 'Ketik nama komik di server...',
              prefixIcon: CupertinoIcons.search,
            ),
          ),
          const SizedBox(height: 12),

          // Results list or loader
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 48,
                                color: widget.isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada komik server yang cocok dengan "${_controller.text}".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Coba ubah kata kunci pencarian judul di atas.',
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = _results[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 68,
                                    child: item.thumb != null && item.thumb!.isNotEmpty
                                        ? Image.network(
                                            item.thumb!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                                          )
                                        : Container(color: Colors.grey.shade800),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: widget.isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (item.type != null && item.type!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2E51A2).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.type!,
                                                style: const TextStyle(
                                                  color: Color(0xFF2E51A2),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (item.rating != null && item.rating!.isNotEmpty)
                                            Text(
                                              '★ ${item.rating}',
                                              style: TextStyle(
                                                color: widget.isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    final messenger = ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    await MalService.instance.setManualMangaMapping(
                                      item.title,
                                      widget.entry.manga.id,
                                      comicSlug: item.slug,
                                    );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Berhasil menghubungkan "${item.title}" ke MyAnimeList!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    widget.onMatched(item);
                                  },
                                  icon: const Icon(CupertinoIcons.link, size: 14),
                                  label: const Text(
                                    'Hubungkan',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E51A2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
