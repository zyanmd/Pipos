import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/adult_content_service.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../anime/presentation/widgets/anime_player_custom_controls.dart';
import '../data/models/jav_model.dart';
import '../data/jav_repository.dart';
import 'jav_search_screen.dart';
import 'jav_actress_screen.dart';

class JavPlayerScreen extends StatefulWidget {
  final JavVideoModel video;

  const JavPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<JavPlayerScreen> createState() => _JavPlayerScreenState();
}

class _JavPlayerScreenState extends State<JavPlayerScreen>
    with WidgetsBindingObserver, RouteAware {
  final _repo = JavRepository.instance;

  late JavVideoModel _currentVideo;
  JavDetailModel? _detail;
  VideoPlayerController? _videoPlayerController;

  bool _isLoadingDetail = true;
  bool _isPlayerInitializing = true;
  String? _errorMessage;

  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto';
  bool _isUsingProxy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentVideo = widget.video;
    WakelockPlus.enable().catchError((_) {});
    _loadVideoDetailAndPlay();
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
  void didPushNext() => _onPausePlayer();

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

  void _toggleFullscreen() {
    HapticFeedback.selectionClick();


    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterPip() {
    PipService.instance.enterPip();
  }

  void _shareJav() {
    HapticFeedback.selectionClick();
    final title = _detail?.title ?? _currentVideo.title;
    final code = _detail?.code ?? _currentVideo.code;
    final link = DeepLinkService.buildJavLink(
      id: _currentVideo.id,
      code: code,
      title: title,
      url: _currentVideo.url,
    );
    final label = code.isNotEmpty ? '[$code] $title' : title;
    Clipboard.setData(ClipboardData(text: 'Tonton $label di MOKO!\n$link'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan video berhasil disalin untuk dibagikan!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadVideoDetailAndPlay() async {
    if (!AdultContentService.instance.is18Unlocked) {
      setState(() {
        _isLoadingDetail = false;
        _isPlayerInitializing = false;
      });
      return;
    }
    setState(() {
      _isLoadingDetail = true;
      _errorMessage = null;
    });

    try {
      final detail = await _repo.getDetail(_currentVideo.id);
      if (!mounted) return;

      if (detail != null) {
        setState(() {
          _detail = detail;
          _isLoadingDetail = false;
        });

        final targetUrl = detail.videoUrl.isNotEmpty
            ? detail.videoUrl
            : detail.streamUrl;

        if (targetUrl.isNotEmpty) {
          await _startPlayer(targetUrl, useProxyFallback: true);
        } else {
          setState(() {
            _isPlayerInitializing = false;
            _errorMessage = 'URL video stream tidak ditemukan.';
          });
        }
      } else {
        setState(() {
          _isLoadingDetail = false;
          _isPlayerInitializing = false;
          _errorMessage = 'Gagal memuat detail film JAV.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _isPlayerInitializing = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _startPlayer(String url, {bool useProxyFallback = true, Duration? seekToPos}) async {
    setState(() {
      _isPlayerInitializing = true;
      _errorMessage = null;
    });

    try {
      final old = _videoPlayerController;
      _videoPlayerController = null;
      await old?.dispose();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://javtiful.com/',
          'Accept': '*/*',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await controller.initialize();
      controller.setLooping(false);
      controller.setPlaybackSpeed(_playbackSpeed);

      if (seekToPos != null) {
        await controller.seekTo(seekToPos);
      }
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      PipService.instance.registerActivePlayer(
        onPause: _onPausePlayer,
      );

      setState(() {
        _videoPlayerController = controller;
        _isPlayerInitializing = false;
      });

      controller.addListener(() {
        if (mounted) {
          _syncPipState();
          setState(() {});
        }
      });
      _syncPipState();
    } catch (e) {
      if (useProxyFallback && !_isUsingProxy && _detail != null) {
        _isUsingProxy = true;
        final rawUrl = _detail!.videoUrl.isNotEmpty ? _detail!.videoUrl : _detail!.streamUrl;
        final proxyUrl = _repo.getStreamProxyUrl(rawUrl);
        await _startPlayer(proxyUrl, useProxyFallback: false, seekToPos: seekToPos);
      } else {
        if (!mounted) return;
        setState(() {
          _isPlayerInitializing = false;
          _errorMessage = 'Gagal memutar video ($e).';
        });
      }
    }
  }

  void _playDifferentVideo(JavVideoModel newVideo) {
    HapticFeedback.mediumImpact();
    _onPausePlayer();
    setState(() {
      _currentVideo = newVideo;
      _detail = null;
      _isUsingProxy = false;
    });
    _loadVideoDetailAndPlay();
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
            onPressed: () => Navigator.of(context).pop(),
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
                const Text('Aktifkan Mode 18+ di Profil untuk memutar konten ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  child: const Text('Tutup'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        final bg = isDark ? const Color(0xFF0D0D12) : const Color(0xFFF2F2F7);

        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final isFullscreenActive = isLandscape || _isFullscreen;

        if (isFullscreenActive) {
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_isFullscreen) _exitFullscreen();
              },
              const SingleActivator(LogicalKeyboardKey.keyF): () {
                _toggleFullscreen();
              },
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) async {
                    if (didPop) return;
                    await _exitFullscreen();
                  },
                  child: _buildPlayerContent(isDark, isFs: true),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                // Video Player Box (Anime Style Controls, Adaptive Portrait/Landscape Aspect Ratio)
                AspectRatio(
                  aspectRatio: _isPortraitVideo
                      ? (_videoPlayerController?.value.aspectRatio ?? 9 / 16).clamp(0.5, 0.95)
                      : 16 / 9,
                  child: _buildPlayerContent(isDark, isFs: false),
                ),

                // Video Details, Meta & Related
                Expanded(
                  child: _buildDetailsList(isDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerContent(bool isDark, {required bool isFs}) {
    final c = _videoPlayerController;
    final initialized = c != null && c.value.isInitialized;

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Color(0xFFFF453A),
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 14),
              BouncyTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _loadVideoDetailAndPlay();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (initialized && !_isPlayerInitializing && !_isLoadingDetail) {
      final qualities = ['720p HD', 'Auto'];
      if (!qualities.contains(_selectedQuality)) {
        _selectedQuality = qualities.first;
      }

      return Container(
        key: ValueKey('jav_player_${_currentVideo.id}'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
                child: VideoPlayer(c),
              ),
            ),
            if (!PipService.instance.isInPip.value)
              AnimePlayerCustomControls(
                player: c,
                title: _detail?.title ?? _currentVideo.title,
                episodeLabel: _selectedQuality,
                qualities: qualities,
                selectedQuality: _selectedQuality,
                onSelectQuality: (q) {
                  setState(() => _selectedQuality = q);
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
                    Navigator.of(context).pop();
                  }
                },
                isFullScreen: _isFullscreen,
                onToggleFullScreen: _toggleFullscreen,
              ),
          ],
        ),
      );
    }

    // Loading / Initializing State with Thumbnail Poster Background
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_currentVideo.thumbnail.isNotEmpty)
            CachedNetworkImage(
              imageUrl: _currentVideo.thumbnail,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Center(
                child: Icon(CupertinoIcons.film, color: Colors.white24, size: 48),
              ),
            ),
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: const Center(
              child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
            ),
          ),
          Positioned(
            top: isFs ? 20 : 12,
            left: 12,
            child: BouncyTap(
              onTap: () {
            

    if (_isFullscreen) {
                  _exitFullscreen();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsList(bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1F);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF15151D) : Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Title
        Text(
          _detail?.title ?? _currentVideo.title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),

        // Badges: Code, Quality, Duration, Views, Channel, Type
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if ((_detail?.code ?? _currentVideo.code).isNotEmpty)
              _buildBadge(
                _detail?.code ?? _currentVideo.code,
                const Color(0xFFFF2D55),
              ),
            if (_currentVideo.quality.isNotEmpty)
              _buildBadge(_currentVideo.quality, const Color(0xFF5856D6)),
            if ((_detail?.duration ?? _currentVideo.duration).isNotEmpty)
              _buildBadge(_detail?.duration ?? _currentVideo.duration, const Color(0xFF007AFF)),
            if ((_detail?.views ?? _currentVideo.views).isNotEmpty)
              _buildBadge(
                _detail?.views ?? _currentVideo.views,
                isDark ? Colors.white24 : Colors.black12,
                textColor: textPrimary,
              ),
            if ((_detail?.channel ?? '').isNotEmpty)
              _buildBadge(_detail!.channel, const Color(0xFFFF9500)),
            if (_currentVideo.type.isNotEmpty)
              _buildBadge(_currentVideo.type, const Color(0xFF34C759)),
          ],
        ),

        const SizedBox(height: 14),
        BouncyTap(
          onTap: _shareJav,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.share, size: 17, color: Color(0xFFFF2D55)),
                const SizedBox(width: 8),
                Text(
                  'Bagikan Tautan',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Actresses Section (if available)
        if (_detail != null && _detail!.actresses.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'AKTRIS JAV',
            style: TextStyle(
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _detail!.actresses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final act = _detail!.actresses[i];
                return BouncyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => JavActressScreen(
                          actressSlug: act.slug,
                          initialName: act.name,
                          initialAvatar: act.image,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: act.image,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Icon(CupertinoIcons.person_fill, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              act.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (act.videoCount.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                act.videoCount,
                                style: TextStyle(color: textMuted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Categories & Tags
        if (_detail != null && (_detail!.categories.isNotEmpty || _detail!.tags.isNotEmpty)) ...[
          const SizedBox(height: 20),
          Text(
            'KATEGORI & TAG',
            style: TextStyle(
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._detail!.categories.map((c) => _buildTagChip(c.name, isDark, textPrimary)),
              ..._detail!.tags.map((t) => _buildTagChip(t, isDark, textPrimary)),
            ],
          ),
        ],

        // Related Videos Section
        if (_detail != null && _detail!.relatedVideos.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF2D55), size: 18),
              const SizedBox(width: 6),
              Text(
                'Video Terkait',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _detail!.relatedVideos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (ctx, i) {
              final rel = _detail!.relatedVideos[i];
              return _buildRelatedCard(rel, isDark, cardBg, textPrimary, textMuted);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String text, Color bg, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTagChip(String text, bool isDark, Color textPrimary) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => JavSearchScreen(initialQuery: text),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '# $text',
          style: TextStyle(
            color: textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedCard(
    JavVideoModel item,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
  ) {
    return BouncyTap(
      onTap: () => _playDifferentVideo(item),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFE5E5EA),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(CupertinoIcons.film, color: Colors.white24),
                    ),
                  ),
                  if (item.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.views.isNotEmpty)
                    Text(
                      item.views,
                      style: TextStyle(color: textMuted, fontSize: 10),
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
