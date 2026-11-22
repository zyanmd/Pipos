import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mal_models.dart';
import '../../../../core/services/mal_service.dart';
import '../../../../shared/widgets/ios_capsule_text_field.dart';
import '../mal_integration_screen.dart';

/// Card interaktif MyAnimeList di halaman detail komik (Manga)
/// Mendukung pencarian manual jika judul tidak otomatis cocok di MAL,
/// serta penambahan chapter manual (+1, +5, input angka langsung).
class MalMangaDetailCard extends StatefulWidget {
  final String comicTitle;
  final String comicSlug;

  const MalMangaDetailCard({
    super.key,
    required this.comicTitle,
    required this.comicSlug,
  });

  @override
  State<MalMangaDetailCard> createState() => _MalMangaDetailCardState();
}

class _MalMangaDetailCardState extends State<MalMangaDetailCard> {
  MalMangaItem? _malManga;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadMalInfo();
  }

  Future<void> _loadMalInfo() async {
    try {
      final item = await MalService.instance.findMalManga(
        widget.comicTitle,
        comicSlug: widget.comicSlug,
      );
      if (mounted) {
        setState(() {
          _malManga = item;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Membuka modal pencarian manual MyAnimeList Manga
  void _showManualSearchSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MalMangaSearchModal(
        initialQuery: MalService.cleanMangaTitleForMatching(widget.comicTitle),
        isDark: isDark,
        onSelected: (selectedManga) async {
          Navigator.pop(ctx);
          setState(() {
            _malManga = selectedManga;
            _isLoading = false;
          });
          await MalService.instance.setManualMangaMapping(
            widget.comicTitle,
            selectedManga.id,
            comicSlug: widget.comicSlug,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Berhasil menghubungkan ke "${selectedManga.title}"!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showUpdateSheet(this.context, isDark);
            }
          });
        },
      ),
    );
  }

  /// Menambah 1 chapter secara instan langsung dari card
  Future<void> _quickIncrementChapter() async {
    if (_malManga == null || _isUpdating) return;
    HapticFeedback.lightImpact();

    final current = _malManga?.myListStatus?.numChaptersRead ?? 0;
    final rawMax = _malManga?.numChapters;
    final hasKnownMax = rawMax != null && rawMax > 0;
    final maxCh = hasKnownMax ? rawMax : 9999;
    final next = (current + 1).clamp(0, maxCh);
    final status = (hasKnownMax && next >= maxCh) ? 'completed' : 'reading';

    setState(() => _isUpdating = true);
    final ok = await MalService.instance.updateMangaStatus(
      malId: _malManga!.id,
      status: status,
      chaptersRead: next,
    );

    if (ok) {
      await _loadMalInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MyAnimeList: Chapter diperbarui ke $next!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  void _showUpdateSheet(BuildContext context, bool isDark) {
    if (_malManga == null) {
      _showManualSearchSheet(context, isDark);
      return;
    }
    if (!MalService.instance.hasOAuth) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const MalIntegrationScreen(initialMedia: 'manga')),
      );
      return;
    }

    final currentStatus = _malManga?.myListStatus;
    String selectedStatus = currentStatus?.status ?? 'reading';
    int selectedChapters = (currentStatus != null && currentStatus.numChaptersRead > 0)
        ? currentStatus.numChaptersRead
        : 1;
    int selectedScore = (currentStatus != null && currentStatus.score > 0)
        ? currentStatus.score
        : 8;
    final rawMax = _malManga!.numChapters;
    final hasKnownMax = rawMax != null && rawMax > 0;
    final maxChapters = hasKnownMax ? rawMax : 9999;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: MAL Title & Ganti/Cari Manual Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E51A2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MAL',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _malManga!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) {
                              _showManualSearchSheet(this.context, isDark);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.search, size: 13, color: isDark ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 4),
                              Text(
                                'Ganti',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(this.context);
                          Navigator.pop(ctx);
                          await MalService.instance.removeManualMangaMapping(
                            widget.comicTitle,
                            comicSlug: widget.comicSlug,
                            malId: _malManga?.id,
                          );
                          if (mounted) {
                            setState(() {
                              _malManga = null;
                              _isLoading = false;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Sambungan komik ke MyAnimeList telah diputuskan.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link_off, size: 13, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Putuskan',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Baca
              Text(
                'Status Membaca',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip('reading', 'Sedang Membaca', selectedStatus, isDark, (val) => setModalState(() => selectedStatus = val)),
                  _statusChip('plan_to_read', 'Rencana Baca', selectedStatus, isDark, (val) => setModalState(() => selectedStatus = val)),
                  _statusChip('completed', 'Selesai', selectedStatus, isDark, (val) => setModalState(() => selectedStatus = val)),
                  _statusChip('on_hold', 'Ditunda', selectedStatus, isDark, (val) => setModalState(() => selectedStatus = val)),
                  _statusChip('dropped', 'Dibatalkan', selectedStatus, isDark, (val) => setModalState(() => selectedStatus = val)),
                ],
              ),
              const SizedBox(height: 16),

              // Chapter Row (Minus, Counter/Tap to Type, Plus)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chapter Dibaca:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.minus_circle),
                        onPressed: selectedChapters > 0 ? () => setModalState(() => selectedChapters--) : null,
                      ),
                      GestureDetector(
                        onTap: () async {
                          final ctrl = TextEditingController(text: '$selectedChapters');
                          final newCh = await showDialog<int>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              title: Text(
                                'Input Chapter Manual',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              content: TextField(
                                controller: ctrl,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 50',
                                  labelText: 'Jumlah Chapter Dibaca',
                                  labelStyle: GoogleFonts.inter(fontSize: 13),
                                  hintStyle: GoogleFonts.inter(fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx),
                                  child: Text('Batal', style: GoogleFonts.inter()),
                                ),
                                CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  borderRadius: BorderRadius.circular(10),
                                  onPressed: () {
                                    final val = int.tryParse(ctrl.text.trim());
                                    if (val != null && val >= 0) {
                                      Navigator.pop(dCtx, val.clamp(0, maxChapters));
                                    } else {
                                      Navigator.pop(dCtx);
                                    }
                                  },
                                  child: Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                          if (newCh != null) {
                            setModalState(() {
                              selectedChapters = newCh;
                              if (hasKnownMax && selectedChapters >= maxChapters) {
                                selectedStatus = 'completed';
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$selectedChapters ${hasKnownMax ? '/ $maxChapters' : '/ ?'}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(CupertinoIcons.pencil, size: 13, color: isDark ? Colors.white60 : Colors.black54),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.plus_circle),
                        onPressed: selectedChapters < maxChapters ? () => setModalState(() => selectedChapters++) : null,
                      ),
                    ],
                  ),
                ],
              ),

              // Quick Preset Chapter Pills
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _quickPill('+1 Ch', isDark, () {
                      if (selectedChapters < maxChapters) {
                        setModalState(() {
                          selectedChapters++;
                          if (hasKnownMax && selectedChapters >= maxChapters) {
                            selectedStatus = 'completed';
                          }
                        });
                      }
                    }),
                    _quickPill('+5 Ch', isDark, () {
                      setModalState(() {
                        selectedChapters = (selectedChapters + 5).clamp(0, maxChapters);
                        if (hasKnownMax && selectedChapters >= maxChapters) {
                          selectedStatus = 'completed';
                        }
                      });
                    }),
                    _quickPill('+10 Ch', isDark, () {
                      setModalState(() {
                        selectedChapters = (selectedChapters + 10).clamp(0, maxChapters);
                        if (hasKnownMax && selectedChapters >= maxChapters) {
                          selectedStatus = 'completed';
                        }
                      });
                    }),
                    if (hasKnownMax)
                      _quickPill('Tamat ($maxChapters)', isDark, () {
                        setModalState(() {
                          selectedChapters = maxChapters;
                          selectedStatus = 'completed';
                        });
                      }),
                  ],
                ),
              ),

              // Rating Skor
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rating Skor (1 - 10):',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.star_fill, size: 16, color: Color(0xFFFF9500)),
                      const SizedBox(width: 4),
                      Text(
                        '$selectedScore / 10',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Slider(
                value: selectedScore.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                activeColor: const Color(0xFF2E51A2),
                onChanged: (val) => setModalState(() => selectedScore = val.round()),
              ),
              const SizedBox(height: 14),

              // Simpan Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  padding: EdgeInsets.zero,
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          setState(() => _isUpdating = true);
                          final ok = await MalService.instance.updateMangaStatus(
                            malId: _malManga!.id,
                            status: selectedStatus,
                            chaptersRead: selectedChapters,
                            score: selectedScore,
                          );
                          if (ok) {
                            _loadMalInfo();
                          }
                          if (mounted) {
                            setState(() => _isUpdating = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Status Manga di MAL berhasil diperbarui!'
                                      : 'Gagal memperbarui status di MyAnimeList',
                                  style: GoogleFonts.inter(),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: Text(
                    'Simpan ke MyAnimeList',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickPill(String label, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String val, String label, String current, bool isDark, void Function(String) onSelect) {
    final active = val == current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(val);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2E51A2)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF2E51A2) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scoreStr = _malManga?.meanScore != null && _malManga!.meanScore! > 0
        ? _malManga!.meanScore!.toStringAsFixed(2)
        : null;

    return ValueListenableBuilder<bool>(
      valueListenable: MalService.instance.isConnectedNotifier,
      builder: (context, isConnected, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                if (!isConnected) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const MalIntegrationScreen(initialMedia: 'manga')),
                  );
                } else if (_malManga == null) {
                  _showManualSearchSheet(context, isDark);
                } else {
                  _showUpdateSheet(context, isDark);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // MAL Squircle Icon Badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E51A2),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.35 : 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'MAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'MyAnimeList',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (_isLoading) ...[
                                const SizedBox(width: 8),
                                const CupertinoActivityIndicator(radius: 6),
                              ] else if (_malManga == null && isConnected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Cari Manual',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFF9500),
                                    ),
                                  ),
                                ),
                              ] else if (scoreStr != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.star_fill, size: 9.5, color: Color(0xFFFF9500)),
                                      const SizedBox(width: 3),
                                      Text(
                                        scoreStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFF9500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            !isConnected
                                ? 'Hubungkan akun untuk auto-sync bacaan'
                                : (_malManga == null
                                    ? 'Belum cocok otomatis • Ketuk untuk cari'
                                    : (_malManga?.myListStatus != null
                                        ? '${_malManga!.myListStatus!.localizedStatus} • Ch ${_malManga!.myListStatus!.numChaptersRead}${_malManga!.numChapters != null && _malManga!.numChapters! > 0 ? ' / ${_malManga!.numChapters}' : ''}'
                                        : 'Ketuk untuk sinkronkan atau ubah status')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: _malManga?.myListStatus != null ? FontWeight.w600 : FontWeight.w400,
                              color: _malManga?.myListStatus != null
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669))
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Increment Chapter Button or Search/Chevron
                    if (isConnected && _malManga != null) ...[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _quickIncrementChapter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.20 : 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2E51A2).withValues(alpha: isDark ? 0.35 : 0.20),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.plus, size: 11, color: Color(0xFF2E51A2)),
                              const SizedBox(width: 3),
                              Text(
                                '1 Ch',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF7A9EFF) : const Color(0xFF2E51A2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    Icon(
                      _malManga == null && isConnected
                          ? CupertinoIcons.search
                          : CupertinoIcons.chevron_right,
                      size: 13,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modal Sheet pencarian manual manga di MyAnimeList
class _MalMangaSearchModal extends StatefulWidget {
  final String initialQuery;
  final bool isDark;
  final ValueChanged<MalMangaItem> onSelected;

  const _MalMangaSearchModal({
    required this.initialQuery,
    required this.isDark,
    required this.onSelected,
  });

  @override
  State<_MalMangaSearchModal> createState() => _MalMangaSearchModalState();
}

class _MalMangaSearchModalState extends State<_MalMangaSearchModal> {
  late TextEditingController _searchCtrl;
  Timer? _debounce;
  bool _isLoading = false;
  List<MalMangaItem> _results = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _performSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    final list = await MalService.instance.searchMalManga(clean);
    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.85,
      padding: EdgeInsets.fromLTRB(16, 14, 16, media.viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E51A2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.search, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cari Manual MyAnimeList (Manga)',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(CupertinoIcons.xmark, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          IosCapsuleTextField(
            controller: _searchCtrl,
            onChanged: _onQueryChanged,
            hintText: 'Cari judul, ID MAL (cth: 1234), atau link...',
            prefixIcon: CupertinoIcons.search,
          ),
          const SizedBox(height: 12),

          // Results or Loading
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.tray, size: 36, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak ada komik ditemukan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coba gunakan nama Romaji atau judul alternatif lain',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        ),
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          final chStr = item.numChapters != null && item.numChapters! > 0
                              ? '${item.numChapters} Ch'
                              : 'Ongoing';
                          final scoreStr = item.meanScore != null && item.meanScore! > 0
                              ? '★ ${item.meanScore!.toStringAsFixed(2)}'
                              : null;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.mainPicture != null
                                  ? Image.network(
                                      item.mainPicture!,
                                      width: 44,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44,
                                        height: 60,
                                        color: isDark ? Colors.white12 : Colors.black12,
                                        child: const Icon(CupertinoIcons.book, size: 20),
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 60,
                                      color: isDark ? Colors.white12 : Colors.black12,
                                      child: const Icon(CupertinoIcons.book, size: 20),
                                    ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      chStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (scoreStr != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        scoreStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFF9500),
                                        ),
                                      ),
                                    ],
                                    if (item.myListStatus != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34C759).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Ch ${item.myListStatus!.numChaptersRead}',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF34C759),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: const Color(0xFF2E51A2),
                              borderRadius: BorderRadius.circular(10),
                              minimumSize: const Size(0, 30),
                              onPressed: () => widget.onSelected(item),
                              child: Text(
                                'Pilih',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            onTap: () => widget.onSelected(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
