import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/widgets/app_network_image.dart';

/// Pemutar video forum yang bersih, modern, dan responsif.
/// Mendukung play/pause, volume mute/unmute, progress bar, dan full screen view.
class ForumVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? coverUrl;
  final bool autoPlay;
  final double aspectRatio;

  const ForumVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.coverUrl,
    this.autoPlay = false,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<ForumVideoPlayerWidget> createState() => _ForumVideoPlayerWidgetState();
}

class _ForumVideoPlayerWidgetState extends State<ForumVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant ForumVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _cleanup();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    try {
      _controller?.removeListener(_onPlayerUpdate);
      _controller?.pause();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _isInitialized = false;
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl.trim().isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uri = Uri.parse(widget.videoUrl.trim());
      final ctrl = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = ctrl;
      await ctrl.initialize();
      ctrl.addListener(_onPlayerUpdate);
      ctrl.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        if (widget.autoPlay) {
          ctrl.play();
          setState(() => _isPlaying = true);
          _startHideTimer();
        }
      }
    } catch (e) {
      debugPrint('[ForumVideoPlayer] Init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    if (val.isPlaying != _isPlaying) {
      setState(() => _isPlaying = val.isPlaying);
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _controller!.pause();
      _showControlsTemporarily();
    } else {
      _controller!.play();
      _startHideTimer();
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);
  }

  void _onTapVideo() {
    if (!_showControls) {
      _showControlsTemporarily();
      _startHideTimer();
    } else {
      _togglePlayPause();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Video Layer / Cover Image Fallback
              if (_isInitialized && _controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio > 0
                        ? _controller!.value.aspectRatio
                        : widget.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
                AppNetworkImage(
                  url: widget.coverUrl!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: const Color(0xFF14141E),
                  child: const Center(
                    child: Icon(CupertinoIcons.play_circle, size: 48, color: Colors.white24),
                  ),
                ),

              // 2. Gesture Area
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTapVideo,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // 3. Loading Indicator
              if (_isLoading)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
                  ),
                ),

              // 4. Error Display
              if (_hasError)
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.orangeAccent, size: 28),
                        const SizedBox(height: 8),
                        const Text(
                          'Video tidak dapat dimuat',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _initPlayer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Controls Overlay
              if (_isInitialized && _showControls && !_hasError)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Center Play / Pause Button
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                      // Top Controls (Badge & Mute)
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.play_rectangle_fill, size: 11, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reels Video',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom Timeline Scrubber & Time
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 8,
                        child: ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _controller!,
                          builder: (context, value, _) {
                            final pos = value.position;
                            final dur = value.duration;
                            final posSec = pos.inMilliseconds.toDouble();
                            final durSec = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: SizedBox(
                                    height: 5,
                                    child: LinearProgressIndicator(
                                      value: (posSec / durSec).clamp(0.0, 1.0),
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
