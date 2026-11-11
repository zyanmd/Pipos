import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../data/models/jav_model.dart';
import '../data/jav_repository.dart';
import 'jav_player_screen.dart';

/// Fullscreen vertical reels for JAV short preview clips (TikTok / IG Reels style)
class JavReelsScreen extends StatefulWidget {
  final List<JavVideoModel> initialVideos;
  final int initialIndex;

  const JavReelsScreen({
    super.key,
    this.initialVideos = const [],
    this.initialIndex = 0,
  });

  @override
  State<JavReelsScreen> createState() => _JavReelsScreenState();
}

class _JavReelsScreenState extends State<JavReelsScreen>
    with WidgetsBindingObserver, RouteAware {
  final _repo = JavRepository.instance;
  late final PageController _pageController;

  List<JavVideoModel> _videos = [];
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
    PipService.instance.pauseAllPlayers();
    PipService.instance.disablePipNow();

    _videos = List<JavVideoModel>.from(widget.initialVideos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    if (_videos.isEmpty) {
      _loadReels();
    } else {
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
    if (mounted) setState(() => _isScreenCovered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _isScreenCovered = false);
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
    WidgetsBinding.instance.removeObserver(this);
    try {
      PipService.routeObserver.unsubscribe(this);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels() async {
    if (!AdultContentService.instance.is18Unlocked) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final list = await _repo.getReels(page: 1);
    if (!mounted) return;
    setState(() {
      _videos = list;
      _hasMore = list.isNotEmpty;
      _currentPage = 1;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    final nextPage = _currentPage + 1;
    final list = await _repo.getReels(page: nextPage);
    if (!mounted) return;
    if (list.isNotEmpty) {
      final existingIds = _videos.map((v) => v.id).toSet();
      final toAdd = <JavVideoModel>[];
      for (final it in list) {
        if (!existingIds.contains(it.id)) {
          toAdd.add(it);
          existingIds.add(it.id);
        }
      }
      setState(() {
        _videos.addAll(toAdd);
        _hasMore = toAdd.isNotEmpty;
        _currentPage = nextPage;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index >= _videos.length - 3) {
      _loadMore();
    }
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    if (!AdultContentService.instance.is18Unlocked) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.back, color: Colors.white),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock_shield_fill, color: Color(0xFFFF2D55), size: 54),
                const SizedBox(height: 16),
                const Text('Mode 18+ Terkunci', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Aktifkan Mode 18+ di Profil untuk menonton reels ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  child: const Text('Tutup'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── 1. VERTICAL PAGE VIEW ──
            if (_loading && _videos.isEmpty)
              const Center(
                child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
              )
            else if (_videos.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak ada klip reels JAV saat ini',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _loadReels,
                      child: const Text('Muat Ulang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (ctx, index) {
                  return _JavReelPageItem(
                    key: ValueKey('jav_reel_${_videos[index].id}_$index'),
                    video: _videos[index],
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
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.flame_fill, size: 12, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'JAV REELS',
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
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                            color: Colors.white,
                            size: 19,
                          ),
                          onPressed: _toggleMute,
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

class _JavReelPageItem extends StatefulWidget {
  final JavVideoModel video;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const _JavReelPageItem({
    super.key,
    required this.video,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<_JavReelPageItem> createState() => _JavReelPageItemState();
}

class _JavReelPageItemState extends State<_JavReelPageItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPlaying = true;
  bool _isLiked = false;
  bool _showHeartAnim = false;
  late final AnimationController _heartAnimCtrl;

  @override
  void initState() {
    super.initState();
    _heartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isActive) {
      _initPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant _JavReelPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_controller == null) {
          _initPlayer();
        } else if (_initialized) {
          _controller!.play();
          setState(() => _isPlaying = true);
        }
      } else {
        _controller?.pause();
        setState(() => _isPlaying = false);
      }
    }

    if (widget.isMuted != oldWidget.isMuted && _controller != null) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _heartAnimCtrl.dispose();
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final streamUrl = widget.video.previewVideo.isNotEmpty
        ? widget.video.previewVideo
        : widget.video.url;

    if (streamUrl.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _controller = ctrl;
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }

      await ctrl.setLooping(true);
      await ctrl.setVolume(widget.isMuted ? 0.0 : 1.0);

      if (widget.isActive) {
        await ctrl.play();
      }

      setState(() {
        _initialized = true;
        _isPlaying = widget.isActive;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _isLiked = true;
      _showHeartAnim = true;
    });
    _heartAnimCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeartAnim = false);
    });
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

  void _openFullVideo() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => JavPlayerScreen(video: widget.video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidThumb = widget.video.thumbnail.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. BACKGROUND THUMBNAIL (FALLBACK & PREVIEW) ──
          if (hasValidThumb)
            AppNetworkImage(
              url: widget.video.thumbnail,
              fit: BoxFit.cover,
              memCacheWidth: 600,
            ),

          // ── 2. VIDEO LAYER ──
          if (_initialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio > 0
                    ? _controller!.value.aspectRatio
                    : 9 / 16,
                child: VideoPlayer(_controller!),
              ),
            ),

          // ── 3. GRADIENT SHADE OVERLAY ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.22, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // ── 4. BUFFERING / LOADING INDICATOR ──
          if (!_initialized && !_hasError)
            const Center(
              child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
            ),

          // ── 5. PAUSE OVERLAY ICON ──
          if (_initialized && !_isPlaying)
            Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: const Icon(CupertinoIcons.play_fill, size: 34, color: Colors.white),
                  ),
                ),
              ),
            ),

          // ── 6. DOUBLE TAP HEART ANIMATION ──
          if (_showHeartAnim)
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.4, end: 1.3).animate(
                  CurvedAnimation(parent: _heartAnimCtrl, curve: Curves.elasticOut),
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  size: 96,
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),

          // ── 7. RIGHT SIDE ACTION BUTTONS ──
          Positioned(
            right: 14,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like Button
                BouncyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isLiked = !_isLiked);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Icon(
                          _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          color: _isLiked ? const Color(0xFFFF2D55) : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Suka',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Share Button
                BouncyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: widget.video.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tautan video disalin'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(CupertinoIcons.share, color: Colors.white, size: 21),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bagikan',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 8. BOTTOM CONTENT METADATA ──
          Positioned(
            left: 16,
            right: 76,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quality & Duration Badges
                Row(
                  children: [
                    if (widget.video.quality.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          widget.video.quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (widget.video.duration.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24, width: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.clock, size: 10, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(
                              widget.video.duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (widget.video.views.isNotEmpty)
                      Text(
                        '${widget.video.views} tayangan',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Video Title
                Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // "Tonton Full Video" Modern Action Button
                BouncyTap(
                  onTap: _openFullVideo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.play_fill, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Tonton Full Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
