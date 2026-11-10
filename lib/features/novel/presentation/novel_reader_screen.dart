import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/novel_model.dart';
import '../data/novel_repository.dart';

enum ReaderThemeMode {
  oled,
  dark,
  sepia,
  light,
}

class NovelReaderScreen extends StatefulWidget {
  final String chapterSlug;
  final String novelSlug;
  final String novelTitle;
  final String novelPoster;
  final List<NovelChapterModel> chapters;

  const NovelReaderScreen({
    super.key,
    required this.chapterSlug,
    required this.novelSlug,
    required this.novelTitle,
    required this.novelPoster,
    this.chapters = const [],
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final _repo = NovelRepository.instance;
  final _scrollController = ScrollController();

  late String _currentChapterSlug;
  late List<NovelChapterModel> _chapters;
  NovelReaderModel? _chapterData;
  bool _loading = true;
  String? _error;

  bool _showControls = true;
  Timer? _controlsTimer;

  // Reader Preferences
  double _fontSize = 17.0;
  final double _lineHeight = 1.8;
  String _fontFamily = 'System';
  ReaderThemeMode _themeMode = ReaderThemeMode.oled;

  static const String _kPrefFontSize = 'novel_reader_font_size';
  static const String _kPrefFontFamily = 'novel_reader_font_family';
  static const String _kPrefThemeMode = 'novel_reader_theme_mode';

  @override
  void initState() {
    super.initState();
    _currentChapterSlug = widget.chapterSlug;
    _chapters = widget.chapters.toList();
    _loadPreferences();
    _loadChapter(_currentChapterSlug);
    _scrollController.addListener(_onScroll);
    if (_chapters.isEmpty && widget.novelSlug.isNotEmpty) {
      _loadChapterList();
    }
  }

  Future<void> _loadChapterList() async {
    try {
      final detail = await _repo.getNovelDetail(widget.novelSlug);
      if (mounted && detail.chapters.isNotEmpty) {
        setState(() {
          _chapters = detail.chapters;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_chapterData == null) return;
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final progress = (_scrollController.position.pixels / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
      _repo.saveReadingHistory(
        novelSlug: widget.novelSlug,
        novelTitle: widget.novelTitle,
        novelPoster: widget.novelPoster,
        chapterSlug: _currentChapterSlug,
        chapterTitle: _chapterData!.title,
        progress: progress,
      );
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fontSize = prefs.getDouble(_kPrefFontSize) ?? 17.0;
        _fontFamily = prefs.getString(_kPrefFontFamily) ?? 'System';
        final themeIdx = prefs.getInt(_kPrefThemeMode);
        if (themeIdx != null && themeIdx >= 0 && themeIdx < ReaderThemeMode.values.length) {
          _themeMode = ReaderThemeMode.values[themeIdx];
        }
      });
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPrefFontSize, _fontSize);
      await prefs.setString(_kPrefFontFamily, _fontFamily);
      await prefs.setInt(_kPrefThemeMode, _themeMode.index);
    } catch (_) {}
  }

  Future<void> _loadChapter(String slug) async {
    setState(() {
      _currentChapterSlug = slug;
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repo.readChapter(slug);
      if (!mounted) return;
      setState(() {
        _chapterData = data;
        _loading = false;
      });

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }

      _repo.saveReadingHistory(
        novelSlug: widget.novelSlug,
        novelTitle: widget.novelTitle,
        novelPoster: widget.novelPoster,
        chapterSlug: slug,
        chapterTitle: data.title,
        progress: 0.0,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat isi chapter: $e';
        _loading = false;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Color get _backgroundColor {
    switch (_themeMode) {
      case ReaderThemeMode.oled:
        return const Color(0xFF000000);
      case ReaderThemeMode.dark:
        return const Color(0xFF141416);
      case ReaderThemeMode.sepia:
        return const Color(0xFFF7EED6);
      case ReaderThemeMode.light:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get _textColor {
    switch (_themeMode) {
      case ReaderThemeMode.oled:
        return const Color(0xFFE2E2E8);
      case ReaderThemeMode.dark:
        return const Color(0xFFD6D6DE);
      case ReaderThemeMode.sepia:
        return const Color(0xFF4A3A25);
      case ReaderThemeMode.light:
        return const Color(0xFF1F1F24);
    }
  }

  Color get _subtextColor {
    switch (_themeMode) {
      case ReaderThemeMode.oled:
      case ReaderThemeMode.dark:
        return const Color(0xFF888894);
      case ReaderThemeMode.sepia:
        return const Color(0xFF826E54);
      case ReaderThemeMode.light:
        return const Color(0xFF6B6B76);
    }
  }

  Color get _appBarBg {
    return _themeMode == ReaderThemeMode.light || _themeMode == ReaderThemeMode.sepia
        ? _backgroundColor.withValues(alpha: 0.95)
        : const Color(0xFF0D0D11).withValues(alpha: 0.95);
  }

  Color get _appBarTextColor {
    return _themeMode == ReaderThemeMode.light || _themeMode == ReaderThemeMode.sepia
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }

  TextStyle get _bodyTextStyle {
    TextStyle base;
    switch (_fontFamily) {
      case 'Serif':
        base = const TextStyle(fontFamily: 'serif');
        break;
      case 'Monospace':
        base = const TextStyle(fontFamily: 'monospace');
        break;
      default:
        base = const TextStyle();
    }
    return base.copyWith(
      fontSize: _fontSize,
      height: _lineHeight,
      color: _textColor,
      letterSpacing: 0.2,
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDarkSheet = _themeMode == ReaderThemeMode.oled || _themeMode == ReaderThemeMode.dark;
            final sheetBg = isDarkSheet ? const Color(0xFF16161C) : const Color(0xFFFBFBFB);
            final sheetFg = isDarkSheet ? Colors.white : Colors.black87;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDarkSheet ? Colors.white12 : Colors.black12,
                    width: 0.5,
                  ),
                ),
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
                        color: isDarkSheet ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pengaturan Membaca',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: sheetFg,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Font Size
                  Row(
                    children: [
                      Text('Ukuran Teks', style: TextStyle(color: sheetFg, fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        onPressed: _fontSize > 12.0
                            ? () {
                                setState(() => _fontSize -= 1.0);
                                setModalState(() {});
                                _savePreferences();
                              }
                            : null,
                        icon: const Icon(CupertinoIcons.minus_circle),
                        color: sheetFg,
                      ),
                      Text(
                        '${_fontSize.toInt()} px',
                        style: TextStyle(color: sheetFg, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: _fontSize < 32.0
                            ? () {
                                setState(() => _fontSize += 1.0);
                                setModalState(() {});
                                _savePreferences();
                              }
                            : null,
                        icon: const Icon(CupertinoIcons.plus_circle),
                        color: sheetFg,
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.5),

                  // 2. Theme selector
                  Text('Warna Latar', style: TextStyle(color: sheetFg, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildThemeCircle(ReaderThemeMode.oled, 'OLED', const Color(0xFF000000), setModalState),
                      _buildThemeCircle(ReaderThemeMode.dark, 'Malam', const Color(0xFF1E1E26), setModalState),
                      _buildThemeCircle(ReaderThemeMode.sepia, 'Sepia', const Color(0xFFF7EED6), setModalState),
                      _buildThemeCircle(ReaderThemeMode.light, 'Terang', const Color(0xFFFFFFFF), setModalState),
                    ],
                  ),
                  const Divider(height: 28, thickness: 0.5),

                  // 3. Font Family
                  Text('Jenis Font', style: TextStyle(color: sheetFg, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFontOption('System', 'Sans', setModalState),
                      const SizedBox(width: 8),
                      _buildFontOption('Serif', 'Serif', setModalState),
                      const SizedBox(width: 8),
                      _buildFontOption('Monospace', 'Mono', setModalState),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeCircle(ReaderThemeMode mode, String label, Color color, StateSetter setModalState) {
    final isSelected = _themeMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _themeMode = mode);
        setModalState(() {});
        _savePreferences();
      },
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: mode == ReaderThemeMode.light || mode == ReaderThemeMode.sepia
                        ? Colors.black87
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFontOption(String familyKey, String display, StateSetter setModalState) {
    final isSelected = _fontFamily == familyKey;
    final isDarkSheet = _themeMode == ReaderThemeMode.oled || _themeMode == ReaderThemeMode.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _fontFamily = familyKey);
          setModalState(() {});
          _savePreferences();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkSheet ? Colors.white : Colors.black)
                : (isDarkSheet ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            display,
            style: TextStyle(
              color: isSelected
                  ? (isDarkSheet ? Colors.black : Colors.white)
                  : (isDarkSheet ? Colors.white : Colors.black),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _showChapterListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkSheet = _themeMode == ReaderThemeMode.oled || _themeMode == ReaderThemeMode.dark;
        final sheetBg = isDarkSheet ? const Color(0xFF14141A) : const Color(0xFFFFFFFF);
        final sheetFg = isDarkSheet ? Colors.white : Colors.black87;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkSheet ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Daftar Chapter (${_chapters.length})',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: sheetFg,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          color: isDarkSheet ? Colors.white38 : Colors.black38,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  Expanded(
                    child: _chapters.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada daftar chapter tersimpan',
                              style: TextStyle(color: isDarkSheet ? Colors.white54 : Colors.black54),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: _chapters.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color: isDarkSheet ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (ctx, idx) {
                              final ch = _chapters[idx];
                              final isCurrent = ch.slug == _currentChapterSlug;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  ch.title,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.blueAccent : sheetFg,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: ch.date.isNotEmpty
                                    ? Text(
                                        ch.date,
                                        style: TextStyle(
                                          color: isDarkSheet ? Colors.white38 : Colors.black38,
                                          fontSize: 11,
                                        ),
                                      )
                                    : null,
                                trailing: isCurrent
                                    ? const Icon(Icons.check, color: Colors.blueAccent, size: 18)
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  if (!isCurrent) {
                                    _loadChapter(ch.slug);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _nextChapter() {
    if (_chapterData?.nextSlug != null && _chapterData!.nextSlug!.isNotEmpty) {
      _loadChapter(_chapterData!.nextSlug!);
    } else {
      // Find index in _chapters
      final idx = _chapters.indexWhere((c) => c.slug == _currentChapterSlug);
      // chapters usually in descending order (latest first): previous index is newer chapter
      if (idx > 0) {
        _loadChapter(_chapters[idx - 1].slug);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ini adalah chapter paling baru')),
        );
      }
    }
  }

  void _prevChapter() {
    if (_chapterData?.prevSlug != null && _chapterData!.prevSlug!.isNotEmpty) {
      _loadChapter(_chapterData!.prevSlug!);
    } else {
      final idx = _chapters.indexWhere((c) => c.slug == _currentChapterSlug);
      if (idx >= 0 && idx + 1 < _chapters.length) {
        _loadChapter(_chapters[idx + 1].slug);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ini adalah chapter paling awal')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // ── MAIN CONTENT ──
          GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.translucent,
            child: _buildReaderBody(),
          ),

          // ── FLOATING TOP APP BAR ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            top: _showControls ? 0 : -(topPadding + 60),
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 8),
              decoration: BoxDecoration(
                color: _appBarBg,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.back, color: _appBarTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _chapterData?.title ?? widget.novelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _appBarTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.novelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _subtextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.textformat_size, color: _appBarTextColor),
                    onPressed: _showSettingsModal,
                    tooltip: 'Pengaturan Teks',
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.list_bullet, color: _appBarTextColor),
                    onPressed: _showChapterListModal,
                    tooltip: 'Daftar Chapter',
                  ),
                ],
              ),
            ),
          ),

          // ── FLOATING BOTTOM BAR (CHAPTER NAVIGATION) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            bottom: _showControls ? 0 : -(bottomPadding + 70),
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding > 0 ? bottomPadding : 12),
              decoration: BoxDecoration(
                color: _appBarBg,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _prevChapter,
                    icon: Icon(CupertinoIcons.chevron_left, size: 16, color: _appBarTextColor),
                    label: Text('Prev', style: TextStyle(color: _appBarTextColor, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: _showChapterListModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.book, size: 14, color: _subtextColor),
                          const SizedBox(width: 6),
                          Text(
                            'Chapters',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _subtextColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _nextChapter,
                    label: Text('Next', style: TextStyle(color: _appBarTextColor, fontSize: 13)),
                    icon: Icon(CupertinoIcons.chevron_right, size: 16, color: _appBarTextColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 14, color: _textColor),
            const SizedBox(height: 16),
            Text(
              'Memuat chapter novel...',
              style: TextStyle(color: _subtextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textColor, fontSize: 14),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _loadChapter(_currentChapterSlug),
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final chapter = _chapterData!;
    final topInset = MediaQuery.of(context).padding.top + 70;
    final bottomInset = MediaQuery.of(context).padding.bottom + 80;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, topInset, 20, bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter Title
              Text(
                chapter.title,
                style: TextStyle(
                  fontSize: _fontSize + 6,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.novelTitle,
                style: TextStyle(
                  fontSize: _fontSize - 2,
                  color: _subtextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: _subtextColor.withValues(alpha: 0.2), thickness: 0.5),
              const SizedBox(height: 24),

              // Paragraphs
              ...chapter.paragraphs.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    p,
                    style: _bodyTextStyle,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Divider(color: _subtextColor.withValues(alpha: 0.2), thickness: 0.5),
              const SizedBox(height: 24),

              // Bottom Chapter Next/Prev CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _prevChapter,
                    icon: const Icon(CupertinoIcons.arrow_left, size: 16),
                    label: const Text('Chapter Sebelumnya'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textColor,
                      side: BorderSide(color: _subtextColor.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nextChapter,
                    icon: const Icon(CupertinoIcons.arrow_right, size: 16),
                    label: const Text('Chapter Selanjutnya'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

