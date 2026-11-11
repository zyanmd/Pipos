import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../shared/widgets/cinematic_fullscreen_hud.dart';
import '../../anime/presentation/widgets/anime_player_custom_controls.dart';
import '../data/models/zpic_model.dart';
import '../data/zpic_repository.dart';

class ZpicPlayerScreen extends StatefulWidget {
  final ZpicVideoModel video;

  const ZpicPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<ZpicPlayerScreen> createState() => _ZpicPlayerScreenState();
}

class _ZpicPlayerScreenState extends State<ZpicPlayerScreen>
    with WidgetsBindingObserver, RouteAware {
  final _repo = ZpicRepository.instance;

  late ZpicVideoModel _currentVideo;
  VideoPlayerController? _videoPlayerController;

  bool _loadingDetail = false;
  bool _playerInitializing = true;
  String? _errorMessage;
  List<ZpicVideoModel> _recommendations = [];

  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentVideo = widget.video;
    WakelockPlus.enable().catchError((_) {});
    _initVideo();
    _loadRecommendations();
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
    // Tidak perlu mem-pause video hanya karena modal/sheet dibuka di atas player
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _onPausePlayer();
    }
  }

  bool get _isPortraitVideo {
    final c = _videoPlayerController;
    if (c == null || !c.value.isInitialized) return false;
    final size = c.value.size;
    return (size.height > size.width) || (c.value.aspectRatio > 0 && c.value.aspectRatio < 0.95);
  }

  void _syncPipState() {
    final isPlaying = _videoPlayerController?.value.isPlaying ?? false;
    PipService.instance.updateVideoPlaybackState(
      isVideoScreen: true,
      isPlaying: isPlaying,
    );
  }

  void _onPausePlayer() {
    try {
      _videoPlayerController?.pause();
      _syncPipState();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      PipService.routeObserver.unsubscribe(this);
    } catch (_) {}
    _onPausePlayer();
    WakelockPlus.disable().catchError((_) {});
    PipService.instance.unregisterActivePlayer(onPause: _onPausePlayer);
    PipService.instance.disablePipNow();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    setState(() => _isFullscreen = true);
    await PipService.instance.enterFullscreen(isPortrait: _isPortraitVideo);
  }

  Future<void> _exitFullscreen() async {
    setState(() => _isFullscreen = false);
    await PipService.instance.exitFullscreen();
  }

  void _toggleFullScreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterPip() {
    PipService.instance.enterPip();
  }

  Future<void> _loadRecommendations() async {
    try {
      final list = await _repo.getHome(page: 1);
      if (mounted) {
        setState(() {
          _recommendations = list
              .where((v) => v.url != _currentVideo.url && v.videoId != _currentVideo.videoId)
              .take(10)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _initVideo({String? overrideUrl, Duration? seekToPos}) async {
    setState(() {
      _playerInitializing = true;
      _errorMessage = null;
    });

    String? streamUrl = overrideUrl ?? _currentVideo.videoSrc;

    // If videoSrc is missing, fetch from detail endpoint
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() => _loadingDetail = true);
      try {
        final detail = await _repo.getDetail(_currentVideo.videoId);
        if (detail != null) {
          _currentVideo = detail;
          streamUrl = detail.videoSrc;
          if ((streamUrl == null || streamUrl.isEmpty) && detail.videoSources.isNotEmpty) {
            streamUrl = detail.videoSources.first.url;
          }
        }
      } catch (e) {
        // Continue with fallback
      } finally {
        if (mounted) setState(() => _loadingDetail = false);
      }
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _playerInitializing = false;
          _errorMessage = 'URL video stream tidak ditemukan.';
        });
      }
      return;
    }

    try {
      final oldVp = _videoPlayerController;
      _videoPlayerController = null;
      oldVp?.dispose();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await controller.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('Koneksi timeout saat memuat video');
        },
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      if (_playbackSpeed != 1.0) {
        try {
          await controller.setPlaybackSpeed(_playbackSpeed);
        } catch (_) {}
      }

      if (seekToPos != null && seekToPos > Duration.zero) {
        try {
          await controller.seekTo(seekToPos);
        } catch (_) {}
      }

      PipService.instance.registerActivePlayer(onPause: _onPausePlayer);

      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.addListener(() {
        if (mounted) {
          _syncPipState();
          setState(() {});
        }
      });
      _syncPipState();

      setState(() {
        _videoPlayerController = controller;
        _playerInitializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _playerInitializing = false;
          _errorMessage = 'Terjadi kesalahan saat memuat pemutar: ';
        });
      }
    }
  }

  Future<void> _playRandomVideo() async {
    HapticFeedback.mediumImpact();
    setState(() => _loadingDetail = true);
    try {
      final video = await _repo.getRandom();
      if (video != null && mounted) {
        setState(() {
          _currentVideo = video;
          _loadingDetail = false;
        });
        _initVideo();
        _loadRecommendations();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mendapatkan video acak.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _selectVideo(ZpicVideoModel video) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentVideo = video;
      _playerInitializing = true;
      _errorMessage = null;
    });
    _initVideo();
    _loadRecommendations();
  }

  void _copyTitle() {
    Clipboard.setData(ClipboardData(text: _currentVideo.title));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Judul video disalin!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareVideo() {
    HapticFeedback.selectionClick();
    final link = DeepLinkService.buildZpicLink(
      videoId: _currentVideo.videoId,
      title: _currentVideo.title,
      url: _currentVideo.url,
    );
    final text = 'Tonton ${_currentVideo.title} di MOKO!\n$link';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan video disalin untuk dibagikan!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PipService.instance.isInPip,
      builder: (context, inPip, child) {
        if (inPip) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoPlayerController!.value.aspectRatio > 0
                          ? _videoPlayerController!.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(_videoPlayerController!),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
        final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
        final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final isFullscreenActive = isLandscape || _isFullscreen;

        if (isFullscreenActive) {
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_isFullscreen) _exitFullscreen();
              },
              const SingleActivator(LogicalKeyboardKey.keyF): () {
                _toggleFullScreen();
              },
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) async {
                    if (didPop) return;
                    await _exitFullscreen();
                  },
                  child: _buildPlayerContent(isDark),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: Text(
              _currentVideo.title.isNotEmpty ? _currentVideo.title : 'zPic Video Player',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            backgroundColor: bg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildIosActionButton(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: 'Kembali',
                  isDark: isDark,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Video Player Container (Dynamic Aspect Ratio for Portrait/Landscape)
                AspectRatio(
                  aspectRatio: _isPortraitVideo
                      ? (_videoPlayerController?.value.aspectRatio ?? 9 / 16).clamp(0.5, 0.95)
                      : 16 / 9,
                  child: _buildPlayerContent(isDark),
                ),

                // Video Details & Controls
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                  // Title & Meta
                  Text(
                    _currentVideo.title.isNotEmpty ? _currentVideo.title : 'Untitled Video',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tags / Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_currentVideo.isNsfw)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '18+ NSFW',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (_currentVideo.views.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.eye, size: 12, color: textMuted),
                              const SizedBox(width: 4),
                              Text(
                                _currentVideo.views,
                                style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Full HD',
                          style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Card (Glass Container)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: CupertinoIcons.shuffle,
                          label: 'Acak',
                          isDark: isDark,
                          onTap: _loadingDetail ? null : _playRandomVideo,
                        ),
                        _buildActionButton(
                          icon: CupertinoIcons.doc_on_clipboard,
                          label: 'Salin Judul',
                          isDark: isDark,
                          onTap: _copyTitle,
                        ),
                        _buildActionButton(
                          icon: CupertinoIcons.share,
                          label: 'Bagikan',
                          isDark: isDark,
                          onTap: _shareVideo,
                        ),
                        _buildActionButton(
                          icon: CupertinoIcons.arrow_clockwise,
                          label: 'Muat Ulang',
                          isDark: isDark,
                          onTap: _initVideo,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recommendations Section Header
                  Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Video Rekomendasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      if (_recommendations.isNotEmpty)
                        Text(
                          '${_recommendations.length} video',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recommendations List / Grid
                  if (_recommendations.isNotEmpty)
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final item = _recommendations[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            child: _buildSmallVideoCard(item, isDark),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Memuat rekomendasi video...',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle_fill,
                              size: 16,
                              color: textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Informasi Video',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mode 18+ NSFW aktif otomatis untuk memuat seluruh tayangan video lengkap tanpa sensor.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildSmallVideoCard(ZpicVideoModel item, bool isDark) {
    return GestureDetector(
      onTap: () => _selectVideo(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
          border: Border.all(
            color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.thumbnail,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  child: const Icon(CupertinoIcons.play_rectangle, color: Colors.grey, size: 24),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x33000000),
                      Color(0xDD000000),
                    ],
                    stops: [0.4, 0.7, 1.0],
                  ),
                ),
              ),
              if (item.views.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.views,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerContent(bool isDark) {
    return CinematicFullscreenWrapper(
      isFullscreen: _isFullscreen,
      onToggleFullscreen: _toggleFullScreen,
      child: _buildPlayerContentInner(isDark),
    );
  }

  Widget _buildPlayerContentInner(bool isDark) {
    if (_playerInitializing || _loadingDetail) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 3.5, color: Colors.white),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle, color: Color(0xFFFF3B30), size: 36),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white24,
                  onPressed: () => _initVideo(),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      List<String> qualities = [];
      if (_currentVideo.videoSources.isNotEmpty) {
        for (int i = 0; i < _currentVideo.videoSources.length; i++) {
          qualities.add('Server ');
        }
      }
      if (qualities.isEmpty) {
        qualities.add('Full HD');
      }
      if (!qualities.contains(_selectedQuality)) {
        _selectedQuality = qualities.first;
      }

      return Container(
        key: ValueKey('zpic_player_'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio > 0
                    ? _videoPlayerController!.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(_videoPlayerController!),
              ),
            ),
            if (!PipService.instance.isInPip.value)
              AnimePlayerCustomControls(
                player: _videoPlayerController!,
                title: _currentVideo.title.isNotEmpty ? _currentVideo.title : 'zPic Video',
                episodeLabel: _selectedQuality,
                qualities: qualities,
                selectedQuality: _selectedQuality,
                onSelectQuality: (q) {
                  final idx = qualities.indexOf(q);
                  if (idx >= 0 && idx < _currentVideo.videoSources.length) {
                    setState(() => _selectedQuality = q);
                    final pos = _videoPlayerController?.value.position;
                    _initVideo(
                      overrideUrl: _currentVideo.videoSources[idx].url,
                      seekToPos: pos,
                    );
                  }
                },
                playbackSpeed: _playbackSpeed,
                onSpeedChange: (speed) {
                  setState(() => _playbackSpeed = speed);
                  _videoPlayerController?.setPlaybackSpeed(speed);
                },
                onPip: _enterPip,
                onBack: () {
                  if (_isFullscreen) {
                    _exitFullscreen();
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                isFullScreen: _isFullscreen,
                onToggleFullScreen: _toggleFullScreen,
              ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 3.5, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final color = isDark ? Colors.white : Colors.black;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onTap != null ? color : color.withValues(alpha: 0.3), size: 21),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: onTap != null
                  ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                  : color.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
