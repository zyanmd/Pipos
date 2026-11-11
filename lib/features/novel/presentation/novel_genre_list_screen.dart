import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/bouncy_tap.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';
import 'novel_genre_detail_screen.dart';

/// Full screen list of all Sakuranovel Genres
/// Matching https://sakuranovel.id/genre/
class NovelGenreListScreen extends StatefulWidget {
  const NovelGenreListScreen({super.key});

  @override
  State<NovelGenreListScreen> createState() => _NovelGenreListScreenState();
}

class _NovelGenreListScreenState extends State<NovelGenreListScreen> {
  final _repo = NovelRepository.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  List<NovelGenreModel> _genres = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    setState(() => _loading = true);
    final list = await _repo.getNovelGenres();
    if (mounted) {
      setState(() {
        _genres = list;
        _loading = false;
      });
    }
  }

  void _openGenre(NovelGenreModel genre) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NovelGenreDetailScreen(genre: genre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D10) : const Color(0xFFF6F6F9);

    final filtered = _searchQuery.isEmpty
        ? _genres
        : _genres.where((g) {
            return g.name.toLowerCase().contains(_searchQuery) ||
                g.slug.toLowerCase().contains(_searchQuery);
          }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  BouncyTap(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E22)
                            : const Color(0xFFEBEBF0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_back,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Genre Novel',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                          ),
                        ),
                        Text(
                          'Sakuranovel Official Catalog',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search filter field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1E)
                      : const Color(0xFFEDEDF2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 0.6,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari genre (Action, Romance, dll)...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Genre Grid
            Expanded(
              child: _loading
                  ? Center(
                      child: CupertinoActivityIndicator(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Genre tidak ditemukan',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final g = filtered[i];
                            return BouncyTap(
                              onTap: () => _openGenre(g),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF16161A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.09)
                                        : Colors.black.withValues(alpha: 0.06),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            g.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.2,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1D1D1F),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${g.count} Novel',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 13,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black26,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
