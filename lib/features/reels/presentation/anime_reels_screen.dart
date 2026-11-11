import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/services/pip_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../anime/presentation/anime_episode_player.dart';
import '../data/models/reel_model.dart';
import '../data/reels_repository.dart';

/// Fullscreen vertical anime reels player matching Instagram Reels / TikTok.
class AnimeReelsScreen extends StatefulWidget {
  final List<ReelModel> initialReels;
  final int initialIndex;

  const AnimeReelsScreen({
    super.key,
    this.initialReels = const [],
    this.initialIndex = 0,
  });

  @override
  State<AnimeReelsScreen> createState() => _AnimeReelsScreenState();
}

class _AnimeReelsScreenState extends State<AnimeReelsScreen>
    with WidgetsBindingObserver, RouteAware {
  final _repo = ReelsRepository.instance;
  late final PageController _pageController;

  List<ReelModel> _reels = [];
  int _currentIndex = 0;
  bool _loading = false;
  bool _loadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isMuted = false;
  bool _isAppInBackground = false;
  bool _isScreenCovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().catchError((_) {});
    PipService.instance.pauseAllPlayers();
    PipService.instance.disablePipNow();

    _reels = List<ReelModel>.from(widget.initialReels);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    if (_reels.isEmpty) {
      _loadReels();
    } else {
      // Pre-load the next batch immediately so user never hits the end
      _loadMore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      PipService.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // Layar lain dibuka di atas Reels (Detail Anime, Profil, Komentar, dll.)
    if (mounted) {
      setState(() => _isScreenCovered = true);
    }
  }

  @override
  void didPopNext() {
    // Kembali fokus ke Reels
    if (mounted) {
      setState(() => _isScreenCovered = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (mounted && !_isAppInBackground) {
        setState(() => _isAppInBackground = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && _isAppInBackground) {
        setState(() => _isAppInBackground = false);
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    WidgetsBinding.instance.removeObserver(this);
    try {
      PipService.routeObserver.unsubscribe(this);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels() async {
    setState(() => _loading = true);
    final pagination = await _repo.getReels(page: 1);
    if (!mounted) return;
    setState(() {
      _reels = pagination.items;
      _hasMore = true;
      _currentPage = 1;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    final nextPage = _currentPage + 1;
    final pagination = await _repo.getReels(page: nextPage);
    if (!mounted) return;
    if (pagination.items.isNotEmpty) {
      final existingIds = _reels.map((r) => r.id).toSet();
      final toAdd = <ReelModel>[];
      for (final it in pagination.items) {
        if (!existingIds.contains(it.id)) {
          toAdd.add(it);
          existingIds.add(it.id);
        } else {
          // Add unique instance key for endless scroll
          toAdd.add(it.copyWith(id: '${it.id}_p${nextPage}_${toAdd.length}'));
        }
      }
      setState(() {
        _reels.addAll(toAdd);
        _hasMore = true;
        _currentPage = nextPage;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _hasMore = true;
        _loadingMore = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index >= _reels.length - 4) {
      _loadMore();
    }
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── 1. VERTICAL PAGE VIEW ──
            if (_loading && _reels.isEmpty)
              const Center(
                child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
              )
            else if (_reels.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak ada reels tersedia saat ini',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _loadReels,
                      child: const Text('Muat Ulang', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _reels.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (ctx, index) {
                  return _ReelPageItem(
                    key: ValueKey(_reels[index].id),
                    reel: _reels[index],
                    isActive: index == _currentIndex && !_isAppInBackground && !_isScreenCovered,
                    isMuted: _isMuted,
                    onToggleMute: _toggleMute,
                  );
                },
              ),

            // ── 2. TOP BAR OVERLAY ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  RepaintBoundary(
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.6),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2E93), Color(0xFFFF8E3C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E93).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.flame_fill, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'ANIME REELS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  RepaintBoundary(
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.6),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _toggleMute,
                          ),
                        ),
                      ),
                    ),
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

class _ReelPageItem extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const _ReelPageItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<_ReelPageItem> createState() => _ReelPageItemState();
}

class _ReelPageItemState extends State<_ReelPageItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPlaying = true;
  late bool _isLiked = widget.reel.isLiked;
  late int _likeCount = widget.reel.likes;
  int _lastSeekLoopTime = 0;
  bool _isPhysicalCut = false;
  int _playerGeneration = 0;

  // Clip timing helpers
  int get _startMs {
    if (_isPhysicalCut) return 0;
    if (widget.reel.clip.startTime > 0) {
      return widget.reel.clip.startTime * 1000;
    }
    if (widget.reel.ui.clipStart > 0) {
      return widget.reel.ui.clipStart * 1000;
    }
    return 0;
  }

  int get _clipDurMs {
    if (_isPhysicalCut && _controller != null && _controller!.value.isInitialized) {
      final d = _controller!.value.duration.inMilliseconds;
      if (d > 0) return d;
    }
    final clipDur = widget.reel.clip.duration > 0
        ? widget.reel.clip.duration
        : (widget.reel.duration > 0 ? widget.reel.duration : 30);
    return clipDur * 1000;
  }

  int get _endMs {
    if (_isPhysicalCut) return _clipDurMs;
    final s = _startMs;
    final endSec = widget.reel.clip.endTime > 0
        ? widget.reel.clip.endTime
        : widget.reel.ui.clipEnd;
    final e = endSec * 1000;
    return e > s ? e : (s + _clipDurMs);
  }

  // Heart pop animation on double tap
  bool _showHeart = false;
  Offset _heartPosition = Offset.zero;

  String get _formattedLikes {
    if (_likeCount >= 1000000) {
      return '${(_likeCount / 1000000).toStringAsFixed(1)}M';
    } else if (_likeCount >= 1000) {
      return '${(_likeCount / 1000).toStringAsFixed(1)}k';
    }
    return '$_likeCount';
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLiked;
    _likeCount = widget.reel.likes;
    if (widget.isActive) {
      _initPlayer(autoPlay: true);
    }
  }

  void _disposePlayer() {
    _playerGeneration++;
    final ctrl = _controller;
    _controller = null;
    _initialized = false;
    if (ctrl != null) {
      try {
        ctrl.removeListener(_onVideoTick);
      } catch (_) {}
      try {
        ctrl.pause();
      } catch (_) {}
      Future.microtask(() {
        try {
          ctrl.dispose();
        } catch (_) {}
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reel.id != oldWidget.reel.id) {
      _isLiked = widget.reel.isLiked;
      _likeCount = widget.reel.likes;
      _disposePlayer();
      if (widget.isActive) {
        _initPlayer(autoPlay: true);
      }
      return;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_controller == null) {
          _initPlayer(autoPlay: true);
        } else if (_initialized) {
          if (!_isPhysicalCut) {
            final pos = _controller!.value.position.inMilliseconds;
            if (pos >= _endMs || (_startMs > 0 && pos < _startMs - 1000)) {
              _controller?.seekTo(Duration(milliseconds: _startMs));
            }
          }
          _controller?.play();
          setState(() => _isPlaying = true);
        } else {
          _isPlaying = true;
        }
      } else {
        // Immediate full dispose when scrolled away to completely free MediaCodec and RAM
        _disposePlayer();
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
    }

    if (widget.isMuted != oldWidget.isMuted) {
      _controller?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _onVideoTick() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (ctrl.value.hasError) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    if (_isPhysicalCut) {
      return;
    }

    final pos = ctrl.value.position.inMilliseconds;
    final startMs = _startMs;
    final endMs = _endMs;
    final dur = ctrl.value.duration.inMilliseconds;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSeekLoopTime < 1500) {
      return;
    }

    // If pos reached or exceeded endMs (or end of stream), loop back to startMs smoothly
    if (pos >= endMs || (dur > 0 && pos >= dur - 300)) {
      _lastSeekLoopTime = now;
      ctrl.seekTo(Duration(milliseconds: startMs)).then((_) {
        if (mounted && widget.isActive && _isPlaying) {
          ctrl.play();
        }
      }).catchError((_) {});
    }
  }

  Future<void> _initPlayer({bool autoPlay = true}) async {
    final currentGen = ++_playerGeneration;
    final videoUrl = widget.reel.effectiveVideoUrl;
    if (videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    if (_controller != null) {
      final old = _controller;
      _controller = null;
      try {
        old?.removeListener(_onVideoTick);
        old?.pause();
        old?.dispose();
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(videoUrl);
      final ctrl = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      _controller = ctrl;
      await ctrl.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Reels timeout'),
      );

      // Guard: Check if player was superseded or disposed while initializing
      if (!mounted || _playerGeneration != currentGen || _controller != ctrl) {
        try {
          ctrl.dispose();
        } catch (_) {}
        return;
      }

      final totalSec = ctrl.value.duration.inSeconds;
      final isPhysicalCut = widget.reel.isPhysicalCut || totalSec <= 45;
      _isPhysicalCut = isPhysicalCut;

      await ctrl.setVolume(widget.isMuted ? 0.0 : 1.0);

      if (isPhysicalCut) {
        await ctrl.setLooping(true);
      } else {
        await ctrl.setLooping(false);
        if (_startMs > 0) {
          await ctrl.seekTo(Duration(milliseconds: _startMs));
        }
      }

      // Guard: Re-check after async seek
      if (!mounted || _playerGeneration != currentGen || _controller != ctrl) {
        try {
          ctrl.dispose();
        } catch (_) {}
        return;
      }

      ctrl.addListener(_onVideoTick);

      if (widget.isActive && (autoPlay || _isPlaying)) {
        await ctrl.play();
        if (mounted && _playerGeneration == currentGen) {
          setState(() {
            _initialized = true;
            _isPlaying = true;
          });
        }
      } else if (mounted && _playerGeneration == currentGen) {
        setState(() {
          _initialized = true;
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('[ReelPageItem] Init error: $e');
      if (mounted && _playerGeneration == currentGen) {
        setState(() => _hasError = true);
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_initialized) return;
    HapticFeedback.selectionClick();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _handleToggleLike() async {
    HapticFeedback.selectionClick();
    final prevLiked = _isLiked;
    final prevCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = (_likeCount + (_isLiked ? 1 : -1)).clamp(0, 9999999);
    });

    final res = await ReelsRepository.instance.toggleLike(widget.reel.id);
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _isLiked = res.isLiked;
        if (res.likes > 0 || !res.isLiked) {
          _likeCount = res.likes;
        }
      });
    } else {
      setState(() {
        _isLiked = prevLiked;
        _likeCount = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk menyukai reel.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showHeart = true;
      _heartPosition = details.localPosition;
    });

    if (!_isLiked) {
      _handleToggleLike();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  void _openDetail() {
    final animeId = widget.reel.anime.animeId.isNotEmpty
        ? widget.reel.anime.animeId
        : widget.reel.seriesKey;
    if (animeId.isEmpty) return;

    _controller?.pause();
    setState(() => _isPlaying = false);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => AnimeDetailScreen(
          animeId: animeId,
          anime: AnimeModel(
            id: animeId,
            title: widget.reel.anime.title.isNotEmpty
                ? widget.reel.anime.title
                : widget.reel.displayTitle,
            thumb: widget.reel.effectiveCoverUrl,
          ),
        ),
      ),
    );
  }

  void _watchFullEpisode() {
    _controller?.pause();
    setState(() => _isPlaying = false);

    final ep = widget.reel.episode;
    final anime = widget.reel.anime;
    final startTimeSeconds = widget.reel.clip.startTime;

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AnimeEpisodePlayerScreen(
          episodeId: ep.episodeId.isNotEmpty ? ep.episodeId : ep.episodeKey,
          episodeLabel: ep.displayEpisodeTitle.isNotEmpty ? ep.displayEpisodeTitle : 'Episode',
          episodeUrl: ep.episodeUrl,
          animeId: anime.animeId.isNotEmpty ? anime.animeId : widget.reel.seriesKey,
          animeTitle: anime.title.isNotEmpty ? anime.title : widget.reel.title,
          animeThumb: widget.reel.effectiveCoverUrl,
          startAt: startTimeSeconds > 0 ? Duration(seconds: startTimeSeconds) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.reel.effectiveCoverUrl;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: _onDoubleTapDown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── BACKGROUND POSTER (FALLBACK) ──
          if (cover.isNotEmpty)
            AppNetworkImage(
              url: cover,
              fit: BoxFit.cover,
            ),

          // ── VIDEO PLAYER ──
          if (_initialized && _controller != null && !_hasError)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (!_hasError)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
              ),
            ),

          // ── GRADIENT OVERLAYS ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.25, 0.6, 1.0],
              ),
            ),
          ),

          // ── PLAY / PAUSE CENTER ICON ──
          if (!_isPlaying && _initialized)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.play_arrow_solid,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

          // ── HEART POP ANIMATION ──
          if (_showHeart)
            Positioned(
              left: _heartPosition.dx - 45,
              top: _heartPosition.dy - 45,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (ctx, val, child) {
                  return Transform.scale(
                    scale: val * 1.3,
                    child: Opacity(
                      opacity: (1.0 - val).clamp(0.0, 1.0),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        color: Color(0xFFFF2E93),
                        size: 90,
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── RIGHT SIDE ACTION COLUMN ──
          Positioned(
            right: 14,
            bottom: bottomInset + 76,
            child: Column(
              children: [
                // Anime Poster Avatar
                GestureDetector(
                  onTap: _openDetail,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: cover.isNotEmpty
                          ? AppNetworkImage(url: cover, fit: BoxFit.cover)
                          : const Icon(CupertinoIcons.film, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Like Button
                _buildSideAction(
                  icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  label: _formattedLikes,
                  iconColor: _isLiked ? const Color(0xFFFF2E93) : Colors.white,
                  onTap: _handleToggleLike,
                ),
                const SizedBox(height: 18),

                // Full Episode Button
                _buildSideAction(
                  icon: CupertinoIcons.play_circle_fill,
                  label: 'Full Ep',
                  iconColor: const Color(0xFF0A84FF),
                  onTap: _watchFullEpisode,
                ),
              ],
            ),
          ),

          // ── BOTTOM INFO OVERLAY ──
          Positioned(
            left: 16,
            right: 80,
            bottom: bottomInset + 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Anime Title (Tappable)
                GestureDetector(
                  onTap: _openDetail,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ANIME',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.reel.anime.title.isNotEmpty
                              ? widget.reel.anime.title
                              : widget.reel.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Episode Info & Time Tag
                Text(
                  widget.reel.episode.displayEpisodeTitle.isNotEmpty
                      ? widget.reel.episode.displayEpisodeTitle
                      : widget.reel.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // CTA Button: Tonton Episode Penuh
                GestureDetector(
                  onTap: _watchFullEpisode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A84FF).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.play_fill, size: 13, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          'Tonton Episode Penuh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.reel.clip.startTimeFormatted.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${widget.reel.clip.startTimeFormatted})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM SCRUBBER PROGRESS BAR (30s clip) ──
          if (_initialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset > 0 ? bottomInset : 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (ctx, val, _) {
                  final dur = _clipDurMs;
                  final pos = val.position.inMilliseconds;
                  final relPos = (pos - _startMs).clamp(0, dur);
                  final progress = dur > 0 ? (relPos / dur).clamp(0.0, 1.0) : 0.0;

                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideAction({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 0.6),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

