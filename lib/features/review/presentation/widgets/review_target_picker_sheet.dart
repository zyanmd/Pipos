import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/anime_watch_progress_service.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../anime/data/anime_repository.dart';
import '../../../comic/data/comic_repository.dart';
import '../../data/models/user_review_model.dart';
import 'review_input_dialog.dart';

class _PickerItem {
  final String itemType;
  final String id;
  final String title;
  final String? thumb;
  final String? subtitle;

  const _PickerItem({
    required this.itemType,
    required this.id,
    required this.title,
    this.thumb,
    this.subtitle,
  });
}

/// Sheet modal modern berdesain Apple iOS untuk memilih judul Anime / Komik yang ingin diulas
class ReviewTargetPickerSheet extends StatefulWidget {
  const ReviewTargetPickerSheet({super.key});

  static Future<UserReviewModel?> show(BuildContext context) {
    return showModalBottomSheet<UserReviewModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ReviewTargetPickerSheet(),
    );
  }

  @override
  State<ReviewTargetPickerSheet> createState() => _ReviewTargetPickerSheetState();
}

class _ReviewTargetPickerSheetState extends State<ReviewTargetPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AnimeRepository _animeRepo = AnimeRepository.instance;
  final ComicRepository _comicRepo = ComicRepository.instance;

  String _selectedTab = 'anime'; // 'anime' or 'comic'
  bool _isLoading = false;
  List<_PickerItem> _items = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadDefaultItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultItems() async {
    setState(() => _isLoading = true);
    final results = <_PickerItem>[];

    try {
      if (_selectedTab == 'anime') {
        // Ambil riwayat tonton terlebih dahulu
        final history = await AnimeWatchProgressService.instance.getRecentAnimeHistoryMaps(limit: 15);
        if (history.isNotEmpty) {
          for (final h in history) {
            final id = (h['animeId'] ?? '').toString();
            final title = (h['animeTitle'] ?? h['title'] ?? '').toString();
            final thumb = (h['thumb'] ?? '').toString();
            if (id.isNotEmpty && title.isNotEmpty) {
              results.add(
                _PickerItem(
                  itemType: 'anime',
                  id: id,
                  title: title,
                  thumb: thumb.isNotEmpty ? thumb : null,
                  subtitle: 'Terakhir ditonton',
                ),
              );
            }
          }
        }

        // Jika riwayat sedikit, tambahkan dari anime ongoing
        if (results.length < 10) {
          final ongoing = await _animeRepo.ongoing(page: 1);
          final seen = results.map((e) => e.id).toSet();
          for (final a in ongoing) {
            if (!seen.contains(a.id)) {
              results.add(
                _PickerItem(
                  itemType: 'anime',
                  id: a.id,
                  title: a.title,
                  thumb: a.thumb,
                  subtitle: (a.status != null && a.status!.isNotEmpty) ? a.status! : 'Ongoing',
                ),
              );
            }
          }
        }
      } else {
        // Tab Komik: Ambil komik terbaru / populer
        final comics = await _comicRepo.terbaru(page: 1);
        for (final c in comics) {
          results.add(
            _PickerItem(
              itemType: 'comic',
              id: c.slug,
              title: c.title,
              thumb: c.thumb,
              subtitle: (c.type != null && c.type!.isNotEmpty) ? c.type! : 'Komik',
            ),
          );
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      _loadDefaultItems();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final results = <_PickerItem>[];
      try {
        if (_selectedTab == 'anime') {
          final list = await _animeRepo.search(q);
          for (final a in list) {
            results.add(
              _PickerItem(
                itemType: 'anime',
                id: a.id,
                title: a.title,
                thumb: a.thumb,
                subtitle: (a.status != null && a.status!.isNotEmpty) ? a.status! : 'Anime',
              ),
            );
          }
        } else {
          final list = await _comicRepo.search(q);
          for (final c in list) {
            results.add(
              _PickerItem(
                itemType: 'comic',
                id: c.slug,
                title: c.title,
                thumb: c.thumb,
                subtitle: (c.type != null && c.type!.isNotEmpty) ? c.type! : 'Komik',
              ),
            );
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    });
  }

  void _switchTab(String tab) {
    if (_selectedTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTab = tab;
      _searchCtrl.clear();
    });
    _loadDefaultItems();
  }

  Future<void> _selectItem(_PickerItem item) async {
    HapticFeedback.lightImpact();
    final result = await ReviewInputDialog.show(
      context,
      itemType: item.itemType,
      targetId: item.id,
      targetTitle: item.title,
      targetCover: item.thumb,
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final sheetBg = isDark ? const Color(0xEB16161A) : const Color(0xF5FFFFFF);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: sheetHeight,
          margin: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Apple Grabber Pill
              Center(
                child: Container(
                  width: 38,
                  height: 4.8,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.4),
                  ),
                ),
              ),

              // Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Judul untuk Diulas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pilih anime atau komik yang ingin kamu berikan rating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Apple Segmented Control [ Anime | Komik ]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222228) : const Color(0xFFEBEBF0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSegmentButton('anime', 'Anime', CupertinoIcons.play_rectangle_fill, isDark),
                      ),
                      Expanded(
                        child: _buildSegmentButton('comic', 'Komik', CupertinoIcons.book_fill, isDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cupertino Search TextField
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CupertinoSearchTextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  placeholder: _selectedTab == 'anime' ? 'Cari judul anime...' : 'Cari judul komik...',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  placeholderStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222228) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: dividerColor, thickness: 0.6),

              // Results List (Apple Store / Music Style)
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 40,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tidak ada hasil ditemukan',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: dividerColor,
                              thickness: 0.6,
                            ),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                onPressed: () => _selectItem(item),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: item.thumb != null && item.thumb!.isNotEmpty
                                          ? AppNetworkImage(
                                              url: item.thumb!,
                                              width: 48,
                                              height: 66,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 48,
                                              height: 66,
                                              color: isDark ? Colors.white12 : Colors.black12,
                                              child: Icon(
                                                _selectedTab == 'anime'
                                                    ? CupertinoIcons.play_circle
                                                    : CupertinoIcons.book,
                                                size: 22,
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (item.subtitle != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(alpha: 0.08)
                                                    : Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.subtitle!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Apple iOS Glass Action Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isDark ? Colors.white12 : Colors.black12,
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.square_pencil,
                                            size: 13,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ulas',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ],
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
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String tab, String label, IconData icon, bool isDark) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTab(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF323238) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 5,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
