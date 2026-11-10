import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../../core/utils/responsive.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/comic_read_progress_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../features/comic/data/comic_repository.dart';
import '../../../features/comic/data/models/comic_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../review/presentation/widgets/review_input_dialog.dart';

class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterLabel,
    required this.comicSlug,
    required this.comicTitle,
    this.comicThumb,
    this.chapters = const [],
    this.initialPage,
  });

  final String chapterId;
  final String chapterLabel;
  final String comicSlug;
  final String comicTitle;
  final String? comicThumb;
  final List<ChapterModel> chapters;
  final int? initialPage;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _repo = ComicRepository.instance;
  final _progressService = ComicReadProgressService.instance;
  ChapterImagesModel? _chapter;
  bool _loading = true;
  String? _error;
  int _current = 0;
  bool _showOverlay = true;
  List<ChapterModel> _chapters = [];
  late final ScrollController _scrollCtrl;
  late final TransformationController _transCtrl;
  late final FocusNode _focusNode;
  double? _targetScrollOffset;
  bool _isZoomed = false;
  double _zoomScale = 1.0;
  bool _isDoubleTapLocked = false;
  bool _isPinching = false;
  final Map<int, Offset> _pointerPositions = {};
  double _pinchStartDist = 0.0;
  Offset _pinchStartFocal = Offset.zero;
  Matrix4 _pinchStartMatrix = Matrix4.identity();
  Offset? _doubleTapPosition;
  AnimationController? _zoomAnimCtrl;
  DateTime _lastBackendSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.8;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    PipService.instance.disablePipNow();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _transCtrl = TransformationController();
    if (widget.chapters.isNotEmpty) {
      _chapters = List<ChapterModel>.from(widget.chapters);
    }
    _load();
    _fetchChaptersIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAutoScroll();
      _saveCurrentProgressLocally();
      _recordHistory();
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _zoomAnimCtrl?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentProgressLocally();
    _recordHistory();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _transCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (_isAutoScrolling) return;
    if (_isZoomed) _resetZoom();
    setState(() {
      _isAutoScrolling = true;
      _showOverlay = false;
    });
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_scrollCtrl.hasClients || !_isAutoScrolling) {
        timer.cancel();
        return;
      }
      final max = _scrollCtrl.position.maxScrollExtent;
      final current = _scrollCtrl.offset;
      if (current >= max) {
        _stopAutoScroll();
        return;
      }
      final next = (current + _autoScrollSpeed).clamp(0.0, max);
      _scrollCtrl.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (_isAutoScrolling && mounted) {
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  void _toggleAutoScroll() {
    HapticFeedback.selectionClick();
    if (_isAutoScrolling) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  void _cycleAutoScrollSpeed() {
    HapticFeedback.selectionClick();
    final nextSpeed = _autoScrollSpeed <= 1.2
        ? 1.8
        : _autoScrollSpeed <= 2.2
            ? 3.0
            : _autoScrollSpeed <= 3.5
                ? 4.5
                : 1.0;
    setState(() {
      _autoScrollSpeed = nextSpeed;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
          backgroundColor: const Color(0xFF1E293B),
          content: Text(
            'Kecepatan auto scroll: ${nextSpeed.toStringAsFixed(1)}x',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  void _saveCurrentProgressLocally() {
    if (_chapter == null || _chapter!.images.isEmpty) return;
    _progressService.saveProgress(
      comicSlug: ComicModel.extractCleanSlug(widget.comicSlug),
      chapterId: ChapterModel.extractCleanSlug(widget.chapterId),
      pageIndex: _current,
      totalPages: _chapter!.images.length,
      scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0,
      chapterLabel: widget.chapterLabel,
      comicTitle: widget.comicTitle,
      thumb: widget.comicThumb,
    );
  }

  void _resetZoom() {
    _isDoubleTapLocked = false;
    _isPinching = false;
    _animateMatrixTo(Matrix4.identity());
  }

  void _animateReset() {
    _isDoubleTapLocked = false;
    _isPinching = false;
    _animateMatrixTo(Matrix4.identity());
  }

  void _animateMatrixTo(Matrix4 target) {
    _zoomAnimCtrl?.dispose();
    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final Matrix4Tween tween = Matrix4Tween(
      begin: _transCtrl.value,
      end: target,
    );
    final animation = CurvedAnimation(
      parent: _zoomAnimCtrl!,
      curve: Curves.easeOutCubic,
    );
    _zoomAnimCtrl!.addListener(() {
      if (!mounted) return;
      _transCtrl.value = tween.evaluate(animation);
    });
    _zoomAnimCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final scale = _transCtrl.value.getMaxScaleOnAxis();
        final zoomed = scale > 1.05;
        setState(() {
          _zoomScale = scale;
          _isZoomed = zoomed;
        });
      }
    });
    _zoomAnimCtrl!.forward();
  }

  void _scrollBy(double offset) {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    final current = _targetScrollOffset ?? position.pixels;
    final target = (current + offset).clamp(0.0, position.maxScrollExtent);
    _targetScrollOffset = target;
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (_targetScrollOffset == target) {
        _targetScrollOffset = null;
      }
    });
  }

  void _scrollTo(double target) {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    final clamped = target.clamp(0.0, position.maxScrollExtent);
    _targetScrollOffset = clamped;
    _scrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (_targetScrollOffset == clamped) {
        _targetScrollOffset = null;
      }
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Arrow Down / Key J
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      _scrollBy(160.0);
      return KeyEventResult.handled;
    }

    // Arrow Up / Key K
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      _scrollBy(-160.0);
      return KeyEventResult.handled;
    }

    // Page Down or Space: scroll down by 75% of viewport
    if (key == LogicalKeyboardKey.pageDown ||
        (key == LogicalKeyboardKey.space &&
            !HardwareKeyboard.instance.isShiftPressed)) {
      final viewport = _scrollCtrl.hasClients
          ? _scrollCtrl.position.viewportDimension
          : 600.0;
      _scrollBy(viewport * 0.75);
      return KeyEventResult.handled;
    }

    // Page Up or Shift+Space: scroll up by 75% of viewport
    if (key == LogicalKeyboardKey.pageUp ||
        (key == LogicalKeyboardKey.space &&
            HardwareKeyboard.instance.isShiftPressed)) {
      final viewport = _scrollCtrl.hasClients
          ? _scrollCtrl.position.viewportDimension
          : 600.0;
      _scrollBy(-viewport * 0.75);
      return KeyEventResult.handled;
    }

    // Home: Top of chapter
    if (key == LogicalKeyboardKey.home) {
      _scrollTo(0.0);
      return KeyEventResult.handled;
    }

    // End: Bottom of chapter
    if (key == LogicalKeyboardKey.end) {
      if (_scrollCtrl.hasClients) {
        _scrollTo(_scrollCtrl.position.maxScrollExtent);
      }
      return KeyEventResult.handled;
    }

    // Arrow Left / Key A: Previous chapter
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      if (_prevChapter != null) {
        _goPrevChapter();
        return KeyEventResult.handled;
      }
    }

    // Arrow Right / Key D: Next chapter
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      if (_nextChapter != null) {
        _goNextChapter();
        return KeyEventResult.handled;
      }
    }

    // Escape: Reset Zoom
    if (key == LogicalKeyboardKey.escape) {
      if (_isZoomed) {
        _resetZoom();
        return KeyEventResult.handled;
      }
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (HardwareKeyboard.instance.isControlPressed) {
        final delta = -event.scrollDelta.dy * 0.002;
        final currentScale = _transCtrl.value.getMaxScaleOnAxis();
        final nextScale = (currentScale + delta).clamp(1.0, 4.0);
        final matrix = Matrix4.copy(_transCtrl.value);
        matrix.setEntry(0, 0, nextScale);
        matrix.setEntry(1, 1, nextScale);
        _transCtrl.value = matrix;
        setState(() {
          _zoomScale = nextScale;
          _isZoomed = nextScale > 1.05;
          _isDoubleTapLocked = nextScale > 1.05;
        });
      }
    }
  }

  void _handlePointerDown(PointerDownEvent e) {
    _pointerPositions[e.pointer] = e.position;
    if (_pointerPositions.length == 2) {
      _zoomAnimCtrl?.stop();
      final pts = _pointerPositions.values.toList();
      _pinchStartDist = (pts[0] - pts[1]).distance;
      _pinchStartFocal = (pts[0] + pts[1]) / 2.0;
      _pinchStartMatrix = Matrix4.copy(_transCtrl.value);
      _isPinching = true;
    }
  }

  void _handlePointerMove(PointerMoveEvent e) {
    if (_pointerPositions.containsKey(e.pointer)) {
      _pointerPositions[e.pointer] = e.position;
    }

    if (_isPinching && _pointerPositions.length >= 2) {
      final pts = _pointerPositions.values.toList();
      final currentDist = (pts[0] - pts[1]).distance;
      final currentFocal = (pts[0] + pts[1]) / 2.0;

      if (_pinchStartDist > 8.0) {
        final scaleFactor = currentDist / _pinchStartDist;
        final s0 = _pinchStartMatrix.getMaxScaleOnAxis();
        final sNew = (s0 * scaleFactor).clamp(1.0, 4.5);
        final k = sNew / (s0 <= 0 ? 1.0 : s0);
        final t0 = _pinchStartMatrix.getTranslation();

        final tNewX = currentFocal.dx - k * (_pinchStartFocal.dx - t0.x);
        final tNewY = currentFocal.dy - k * (_pinchStartFocal.dy - t0.y);

        final screenW = MediaQuery.sizeOf(context).width;
        final screenH = MediaQuery.sizeOf(context).height;
        final maxShiftX = screenW * (sNew - 1.0);
        final maxShiftY = screenH * (sNew - 1.0);

        final clampedX = tNewX.clamp(-maxShiftX - 40.0, 40.0);
        final clampedY = tNewY.clamp(-maxShiftY - 40.0, 40.0);

        _transCtrl.value = Matrix4.identity()
          ..setEntry(0, 0, sNew)
          ..setEntry(1, 1, sNew)
          ..setEntry(0, 3, clampedX)
          ..setEntry(1, 3, clampedY);

        _zoomScale = sNew;
        final zoomed = sNew > 1.05;
        if (zoomed != _isZoomed) {
          setState(() {
            _isZoomed = zoomed;
          });
        }
      }
    } else if (_isDoubleTapLocked && !_isPinching && _pointerPositions.length == 1) {
      final current = _transCtrl.value;
      final s = current.getMaxScaleOnAxis();
      final screenW = MediaQuery.sizeOf(context).width;
      final screenH = MediaQuery.sizeOf(context).height;
      final maxShiftX = screenW * (s - 1.0);
      final maxShiftY = screenH * (s - 1.0);

      final nextX = (current.getTranslation().x + e.delta.dx).clamp(-maxShiftX, 0.0);
      final nextY = (current.getTranslation().y + e.delta.dy).clamp(-maxShiftY, 0.0);

      _transCtrl.value = Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(0, 3, nextX)
        ..setEntry(1, 3, nextY);
    }
  }

  void _handlePointerUp(PointerUpEvent e) {
    _pointerPositions.remove(e.pointer);
    if (_pointerPositions.isEmpty) {
      _pointerPositions.clear();
    }
    if (_pointerPositions.length < 2 && _isPinching) {
      _isPinching = false;
      if (!_isDoubleTapLocked) {
        _animateReset();
      } else {
        final scale = _transCtrl.value.getMaxScaleOnAxis();
        if (scale <= 1.05) {
          _isDoubleTapLocked = false;
          _animateReset();
        }
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent e) {
    _pointerPositions.remove(e.pointer);
    if (_pointerPositions.isEmpty) {
      _pointerPositions.clear();
    }
    if (_pointerPositions.length < 2 && _isPinching) {
      _isPinching = false;
      if (!_isDoubleTapLocked) {
        _animateReset();
      } else {
        final scale = _transCtrl.value.getMaxScaleOnAxis();
        if (scale <= 1.05) {
          _isDoubleTapLocked = false;
          _animateReset();
        }
      }
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _chapter == null || _chapter!.images.isEmpty) return;
    final maxExtent = _scrollCtrl.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final progress = (_scrollCtrl.offset / maxExtent).clamp(0.0, 1.0);
    final newIndex = (progress * (_chapter!.images.length - 1)).round();
    if (newIndex != _current) {
      setState(() {
        _current = newIndex;
      });
      _saveCurrentProgressLocally();

      final now = DateTime.now();
      if (now.difference(_lastBackendSyncTime).inSeconds >= 10) {
        _lastBackendSyncTime = now;
        _recordHistory();
      }
    }
  }

  Future<void> _fetchChaptersIfNeeded() async {
    if (_chapters.isNotEmpty || widget.comicSlug.isEmpty) return;
    try {
      final detail = await _repo.detail(widget.comicSlug);
      if (!mounted) return;
      if (detail.chapters.isNotEmpty) {
        setState(() {
          _chapters = detail.chapters;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (widget.chapterId.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Chapter ID tidak valid. Silakan coba chapter lain.';
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      ChapterImagesModel ch;
      try {
        ch = await _repo.chapter(widget.chapterId);
      } catch (_) {
        ch = await _repo.chapterLegacy(widget.chapterId);
      }
      if (!mounted) return;
      setState(() {
        _chapter = ch;
        _loading = false;
      });
      _restoreReadingProgress(ch);
      _recordHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _repo.errorMessage(e);
        _loading = false;
      });
    }
  }

  void _jumpToPage(int page) {
    if (!_scrollCtrl.hasClients || _chapter == null || _chapter!.images.isEmpty) return;
    final total = _chapter!.images.length;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (total <= 1 || max <= 0) return;
    final ratio = (page - 1) / (total - 1);
    final target = (ratio * max).clamp(0.0, max);
    _scrollCtrl.jumpTo(target);
    setState(() {
      _current = page - 1;
    });
  }

  void _openChapterPickerSheet(BuildContext context, bool isDark) {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar chapter belum tersedia')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.90,
          builder: (sheetCtx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Chapter (${_chapters.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _chapters.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (itemCtx, index) {
                        final ch = _chapters[index];
                        final isCurrent = ch.id == widget.chapterId;
                        return ListTile(
                          dense: true,
                          title: Text(
                            ch.label,
                            style: TextStyle(
                              color: isCurrent
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white : AppColors.lightTextPrimary),
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isCurrent
                              ? Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : Colors.black, size: 20)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            if (!isCurrent) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComicReaderScreen(
                                    chapterId: ch.id,
                                    chapterLabel: ch.label,
                                    comicSlug: widget.comicSlug,
                                    comicTitle: widget.comicTitle,
                                    comicThumb: widget.comicThumb,
                                    chapters: _chapters,
                                  ),
                                ),
                              );
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

  Future<void> _restoreReadingProgress(ChapterImagesModel ch) async {
    if (ch.images.isEmpty) return;
    int targetPage = widget.initialPage ?? -1;
    double targetOffset = 0.0;

    if (targetPage < 0) {
      final saved = await _progressService.getSavedProgress(
        comicSlug: ComicModel.extractCleanSlug(widget.comicSlug),
        chapterId: ChapterModel.extractCleanSlug(widget.chapterId),
      );
      if (saved != null && saved.pageIndex > 0 && saved.pageIndex < ch.images.length) {
        targetPage = saved.pageIndex;
        targetOffset = saved.scrollOffset;
      }
    }

    if (targetPage > 0 && targetPage < ch.images.length) {
      if (mounted) {
        setState(() {
          _current = targetPage;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToProgress(targetPage, targetOffset, ch.images.length);
      });

      _showResumeToast(targetPage + 1, ch.images.length);
    }
  }

  void _jumpToProgress(int page, double savedOffset, int totalImages) {
    if (!_scrollCtrl.hasClients || _scrollCtrl.offset > 80.0) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max > 0) {
      if (savedOffset > 0 && savedOffset <= max) {
        _scrollCtrl.jumpTo(savedOffset);
      } else {
        final ratio = page / (totalImages - 1);
        _scrollCtrl.jumpTo((ratio * max).clamp(0.0, max));
      }
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollCtrl.hasClients && _scrollCtrl.offset <= 80.0) {
          final maxRetry = _scrollCtrl.position.maxScrollExtent;
          if (maxRetry > 0) {
            if (savedOffset > 0 && savedOffset <= maxRetry) {
              _scrollCtrl.jumpTo(savedOffset);
            } else {
              final ratio = page / (totalImages - 1);
              _scrollCtrl.jumpTo((ratio * maxRetry).clamp(0.0, maxRetry));
            }
          }
        }
      });
    }
  }

  void _showResumeToast(int page, int total) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Melanjutkan halaman $page dari $total',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(0);
                }
                setState(() => _current = 0);
                _saveCurrentProgressLocally();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text('Awal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordHistory() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    try {
      await _repo.addToHistory(
        comicSlug: ComicModel.extractCleanSlug(widget.comicSlug),
        chapterId: ChapterModel.extractCleanSlug(widget.chapterId),
        title: widget.comicTitle,
        chapterLabel: widget.chapterLabel,
        thumb: widget.comicThumb,
        lastPage: _current + 1,
        totalPages: _chapter?.images.length,
      );
    } catch (_) {}
  }

  int get _currentIndex {
    final cleanCurrent =
        ChapterModel.extractCleanSlug(widget.chapterId).toLowerCase();
    final idx = _chapters.indexWhere(
      (c) =>
          ChapterModel.extractCleanSlug(c.id).toLowerCase() == cleanCurrent ||
          c.label.trim().toLowerCase() ==
              widget.chapterLabel.trim().toLowerCase(),
    );
    return idx;
  }

  /// Extracts the chapter number from a label/slug (e.g. "Chapter 12.5" -> 12.5).
  double? _extractChapterNumber(String text) {
    if (text.trim().isEmpty) return null;
    final reg = RegExp(
      r'(?:chapter|ch|ep|episode)?\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final match = reg.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// True when the chapter list is ordered newest-first (descending).
  /// Most comic sources (e.g. Komiku) list chapters from latest to oldest,
  /// so index-1 = newer/next chapter and index+1 = older/previous chapter.
  bool get _isDescending {
    if (_chapters.length < 2) return true;
    final firstNum = _extractChapterNumber(_chapters.first.label) ??
        _extractChapterNumber(_chapters.first.id);
    final lastNum = _extractChapterNumber(_chapters.last.label) ??
        _extractChapterNumber(_chapters.last.id);
    if (firstNum != null && lastNum != null && firstNum != lastNum) {
      return firstNum > lastNum;
    }
    return true;
  }

  /// Index of the previous chapter (the older one) in the list, or -1.
  int get _prevIndex {
    final idx = _currentIndex;
    if (idx < 0) return -1;
    final target = _isDescending ? idx + 1 : idx - 1;
    return (target >= 0 && target < _chapters.length) ? target : -1;
  }

  /// Index of the next chapter (the newer one) in the list, or -1.
  int get _nextIndex {
    final idx = _currentIndex;
    if (idx < 0) return -1;
    final target = _isDescending ? idx - 1 : idx + 1;
    return (target >= 0 && target < _chapters.length) ? target : -1;
  }

  ChapterModel? get _prevChapter =>
      _prevIndex >= 0 ? _chapters[_prevIndex] : null;

  ChapterModel? get _nextChapter =>
      _nextIndex >= 0 ? _chapters[_nextIndex] : null;

  void _goToChapterIndex(int idx, {required bool isNext}) {
    _stopAutoScroll();
    if (idx < 0 || idx >= _chapters.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNext ? 'Sudah chapter terakhir' : 'Sudah chapter pertama'),
        ),
      );
      return;
    }
    final ch = _chapters[idx];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ComicReaderScreen(
          chapterId: ch.id,
          chapterLabel: ch.label,
          comicSlug: widget.comicSlug,
          comicTitle: widget.comicTitle,
          comicThumb: widget.comicThumb,
          chapters: _chapters,
        ),
      ),
    );
  }

  void _goPrevChapter() => _goToChapterIndex(_prevIndex, isNext: false);

  void _goNextChapter() => _goToChapterIndex(_nextIndex, isNext: true);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: Stack(
            children: [
              // Reader
              if (_loading)
                Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
              else if (_error != null)
                Center(
                  child: ErrorState(message: _error!, onRetry: _load),
                )
              else if (_chapter != null && _chapter!.images.isNotEmpty)
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onPointerSignal: _handlePointerSignal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTapDown: (details) {
                      _doubleTapPosition = details.localPosition;
                    },
                    onDoubleTap: () {
                      if (_isZoomed || _isDoubleTapLocked) {
                        _resetZoom();
                      } else {
                        _isDoubleTapLocked = true;
                        final pos = _doubleTapPosition ?? Offset.zero;
                        final screenW = MediaQuery.sizeOf(context).width;
                        final screenH = MediaQuery.sizeOf(context).height;
                        const targetScale = 2.4;
                        final x = -(pos.dx * (targetScale - 1.0)).clamp(-screenW * (targetScale - 1.0), 0.0);
                        final y = -(pos.dy * (targetScale - 1.0)).clamp(-screenH * (targetScale - 1.0), 0.0);
                        _animateMatrixTo(
                          Matrix4.identity()
                            ..setEntry(0, 0, targetScale)
                            ..setEntry(1, 1, targetScale)
                            ..setEntry(0, 3, x)
                            ..setEntry(1, 3, y),
                        );
                        setState(() {
                          _zoomScale = targetScale;
                          _isZoomed = true;
                        });
                      }
                    },
                    onTap: () {
                      _focusNode.requestFocus();
                      if (_isAutoScrolling) {
                        _stopAutoScroll();
                      } else {
                        setState(() => _showOverlay = !_showOverlay);
                      }
                    },
                    child: ClipRect(
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: _transCtrl,
                        builder: (context, matrix, child) {
                          return Transform(
                            transform: matrix,
                            alignment: Alignment.topLeft,
                            child: child,
                          );
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is UserScrollNotification) {
                              _targetScrollOffset = null;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            physics: _LockableScrollPhysics(
                              isLocked: () => _isPinching || _isDoubleTapLocked,
                            ),
                            padding: EdgeInsets.zero,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                            scrollCacheExtent: const ScrollCacheExtent.pixels(1800.0),
                            itemCount: _chapter!.images.length + 1,
                            itemBuilder: (ctx, i) {
                              if (i == _chapter!.images.length) {
                                return _buildEndOfChapterFooter(isDark);
                              }
                              final screenW = MediaQuery.sizeOf(context).width;
                              final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
                              final readerCacheW = (screenW * pixelRatio * 1.5).toInt().clamp(400, 2160);

                              return _KeepAliveComicPage(
                                key: ValueKey('page_${widget.chapterId}_$i'),
                                imageUrl: _chapter!.images[i],
                                pageIndex: i,
                                isDark: isDark,
                                cacheWidth: readerCacheW,
                              );
                            },
                          ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const EmptyState(
                icon: Icons.image_not_supported_outlined,
                title: 'Tidak ada gambar',
                subtitle: 'Chapter ini tidak memiliki halaman.',
              ),

            // Floating reset zoom pill
            if (_isZoomed)
              Positioned(
                bottom: _showOverlay
                    ? (90 + MediaQuery.paddingOf(context).bottom)
                    : (24 + MediaQuery.paddingOf(context).bottom),
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${_zoomScale.toStringAsFixed(1)}x • Reset',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Floating Auto Scroll Controller Pill
            if (_isAutoScrolling)
              Positioned(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                left: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _stopAutoScroll,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.pause_circle_filled, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Auto Scroll',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _cycleAutoScrollSpeed,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_autoScrollSpeed.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top bar overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: _showOverlay ? (12 + MediaQuery.paddingOf(context).top) : -100,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isDesktop(context) ? 800 : double.infinity,
                  ),
                  child: _topBar(isDark),
                ),
              ),
            ),

            // Bottom bar overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              bottom: _showOverlay ? (16 + MediaQuery.paddingOf(context).bottom) : -140,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isDesktop(context) ? 800 : double.infinity,
                  ),
                  child: _bottomBar(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _topBar(bool isDark) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.comicTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.chapterLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ulas / Tandai Chapter',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    if (!auth.isAuthenticated) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Login untuk menulis ulasan')),
                      );
                      return;
                    }
                    final res = await ReviewInputDialog.show(
                      context,
                      itemType: 'comic',
                      targetId: widget.comicSlug,
                      targetTitle: widget.comicTitle,
                      targetCover: widget.comicThumb,
                      subId: widget.chapterId,
                      subTitle: widget.chapterLabel,
                    );
                    if (res != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ulasan berhasil disimpan!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(CupertinoIcons.square_pencil, color: Colors.white, size: 20),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(bool isDark) {
    final totalPages = _chapter?.images.length ?? 0;
    final curPage = _current + 1;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 0.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Slider for direct page jumping
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: curPage.toDouble().clamp(1.0, totalPages.toDouble()),
                      min: 1.0,
                      max: totalPages.toDouble(),
                      onChanged: (val) {
                        _jumpToPage(val.round());
                      },
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    onPressed: _prevChapter != null ? _goPrevChapter : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: _prevChapter != null ? Colors.white : Colors.white30,
                    tooltip: 'Chapter Sebelumnya (←)',
                  ),
                  IconButton(
                    onPressed: () => _openChapterPickerSheet(context, isDark),
                    icon: const Icon(CupertinoIcons.list_bullet, color: Colors.white, size: 18),
                    tooltip: 'Daftar Chapter',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Hal $curPage/${totalPages > 0 ? totalPages : 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleAutoScroll,
                    icon: Icon(
                      _isAutoScrolling ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle,
                      color: _isAutoScrolling ? const Color(0xFFFF3B30) : Colors.white,
                      size: 20,
                    ),
                    tooltip: _isAutoScrolling ? 'Hentikan Auto Scroll' : 'Mulai Auto Scroll',
                  ),
                  IconButton(
                    onPressed: () {
                      _showResumeToast(curPage, totalPages);
                    },
                    icon: const Icon(CupertinoIcons.bookmark, color: Colors.white70, size: 17),
                    tooltip: 'Status Baca',
                  ),
                  IconButton(
                    onPressed: _nextChapter != null ? _goNextChapter : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: _nextChapter != null ? Colors.white : Colors.white30,
                    tooltip: 'Chapter Selanjutnya (→)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildEndOfChapterFooter(bool isDark) {
    final prev = _prevChapter;
    final next = _nextChapter;
    final hasPrev = prev != null;
    final hasNext = next != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 32, 16, 120 + bottomInset),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : Colors.black, size: 40),
          const SizedBox(height: 8),
          Text(
            'Akhir Chapter ${widget.chapterLabel}',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // Banner Ad
          const AdBannerWidget(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            fallbackToSmartlink: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasPrev)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onPressed: _goPrevChapter,
                  icon: const Icon(Icons.skip_previous_rounded, size: 18),
                  label: Text(
                    prev.label.isNotEmpty
                        ? prev.label
                        : 'Chapter Sebelumnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              if (hasPrev && hasNext) const SizedBox(width: 12),
              if (hasNext)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 4,
                    shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: _goNextChapter,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    next.label.isNotEmpty
                        ? next.label
                        : 'Chapter Berikutnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockableScrollPhysics extends BouncingScrollPhysics {
  final bool Function() isLocked;
  const _LockableScrollPhysics({required this.isLocked, super.parent});

  @override
  _LockableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _LockableScrollPhysics(isLocked: isLocked, parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isLocked()) return 0.0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (isLocked()) return false;
    return super.shouldAcceptUserOffset(position);
  }
}

class _KeepAliveComicPage extends StatefulWidget {
  final String imageUrl;
  final int pageIndex;
  final bool isDark;
  final int cacheWidth;

  const _KeepAliveComicPage({
    super.key,
    required this.imageUrl,
    required this.pageIndex,
    required this.isDark,
    required this.cacheWidth,
  });

  @override
  State<_KeepAliveComicPage> createState() => _KeepAliveComicPageState();
}

class _KeepAliveComicPageState extends State<_KeepAliveComicPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;

    return Center(
      child: Container(
        width: Responsive.isDesktop(context) ? 800 : double.infinity,
        color: isDark ? Colors.black : Colors.white,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          memCacheWidth: widget.cacheWidth,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Container(
            height: 480,
            color: isDark ? const Color(0xFF141416) : const Color(0xFFF2F2F7),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white70 : Colors.black54,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 220,
            color: isDark ? const Color(0xFF141416) : const Color(0xFFF2F2F7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                  const SizedBox(height: 6),
                  Text(
                    'Gagal memuat halaman ${widget.pageIndex + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}