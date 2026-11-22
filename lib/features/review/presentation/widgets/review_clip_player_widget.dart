import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../anime/data/anime_repository.dart';
import '../../data/models/user_review_model.dart';

/// Widget pemutar video & klip anime bergaya media sosial (Instagram & Facebook Reels / Feed).
/// Dilengkapi aspect ratio adaptif, tap to play/pause dengan animasi pop-up, double-tap to like,
/// tombol mute/unmute di pojok, serta progress bar scrubber modern.
class ReviewClipPlayerWidget extends StatefulWidget {
  final UserReviewModel review;
  final VoidCallback? onOpenFullPlayer;
  final VoidCallback? onLike;

  const ReviewClipPlayerWidget({
    super.key,
    required this.review,
    this.onOpenFullPlayer,
    this.onLike,
  });

  @override
  State<ReviewClipPlayerWidget> createState() => _ReviewClipPlayerWidgetState();
}

class _ReviewClipPlayerWidgetState extends State<ReviewClipPlayerWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _hasError = false;

  // Animasi tap feedback (Play / Pause pop-up ala Instagram)
  IconData? _feedbackIcon;
  bool _showFeedbackIcon = false;
  Timer? _feedbackTimer;

  // Animasi double tap Like (Heart pop ala Instagram)
  bool _showHeartAnimation = false;
  Timer? _heartTimer;

  double get _startSec => widget.review.clipStart ?? 0.0;
  double get _endSec {
    if (widget.review.clipEnd != null && widget.review.clipEnd! > _startSec) {
      return widget.review.clipEnd!;
    }
    if (_controller != null && _controller!.value.isInitialized) {
      final dur = _controller!.value.duration.inMilliseconds / 1000.0;
      if (dur > 0) return dur;
    }
    return _startSec + 30.0;
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _heartTimer?.cancel();
    _cleanupController();
    super.dispose();
  }

  void _cleanupController() {
    try {
      _controller?.removeListener(_onControllerUpdate);
      _controller?.pause();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  Future<void> _startPlayback() async {
    if (_isInitializing) return;

    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
        _triggerFeedback(CupertinoIcons.pause_fill);
      } else {
        await _controller!.play();
        _triggerFeedback(CupertinoIcons.play_fill);
      }
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      String? streamUrl = widget.review.fullMediaUrl ?? widget.review.mediaUrl;

      // Jika mediaUrl kosong tapi ada subId (episode id), resolve dari AnimeRepository
      if ((streamUrl == null || streamUrl.isEmpty) &&
          widget.review.subId != null &&
          widget.review.subId!.isNotEmpty) {
        try {
          final epData = await AnimeRepository.instance.episode(widget.review.subId!);
          if (epData.defaultStreamingUrl != null && epData.defaultStreamingUrl!.isNotEmpty) {
            streamUrl = epData.defaultStreamingUrl;
          } else if (epData.streams.isNotEmpty) {
            streamUrl = epData.streams.first.url;
          }
        } catch (_) {}
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _hasError = true;
          });
        }
        return;
      }

      final lower = streamUrl.toLowerCase();
      final Map<String, String> headers = {};
      if (lower.contains('s3.animeverse.id') ||
          lower.contains('animeverse.id') ||
          lower.contains('animeverse.') ||
          lower.contains('ylnime.')) {
        headers['Referer'] = 'https://ylnime.com/';
        headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: headers.isNotEmpty ? headers : const {},
      );

      await controller.initialize();
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      if (_startSec > 0) {
        await controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
      }
      await controller.play();

      controller.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
          _isPlaying = true;
        });
        _triggerFeedback(CupertinoIcons.play_fill);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final curSec = c.value.position.inMilliseconds / 1000.0;

    // Looping video atau klip secara mulus ala Instagram
    if (curSec >= _endSec || curSec < (_startSec - 1.0)) {
      c.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
      if (!c.value.isPlaying) {
        c.play();
      }
    }

    final playing = c.value.isPlaying;
    if (playing != _isPlaying && mounted) {
      setState(() => _isPlaying = playing);
    }
  }

  void _triggerFeedback(IconData icon) {
    HapticFeedback.lightImpact();
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackIcon = icon;
      _showFeedbackIcon = true;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _showFeedbackIcon = false);
      }
    });
  }

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();
    _heartTimer?.cancel();
    setState(() => _showHeartAnimation = true);
    widget.onLike?.call();
    _heartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showHeartAnimation = false);
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  double get _currentPositionSec {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return _startSec;
    return c.value.position.inMilliseconds / 1000.0;
  }

  double get _progressFraction {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return 0.0;
    final total = _endSec - _startSec;
    if (total <= 0) return 0.0;
    final cur = (_currentPositionSec - _startSec).clamp(0.0, total);
    return cur / total;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cover = widget.review.targetCover;
    final hasActivePlayer = _controller != null && _controller!.value.isInitialized;

    // Aspect ratio adaptif: natural aspect ratio clamped to modern feed range (0.56 to 2.39)
    double targetAspectRatio = 16 / 9;
    if (hasActivePlayer) {
      final vRatio = _controller!.value.aspectRatio;
      targetAspectRatio = vRatio > 0 ? vRatio.clamp(0.56, 2.39) : (16 / 9);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: targetAspectRatio,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startPlayback,
            onDoubleTap: _triggerDoubleTapLike,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Video Layer / Cover Thumbnail (Clean, Full, Tanpa UI) ──
                if (hasActivePlayer)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio > 0
                          ? _controller!.value.aspectRatio
                          : targetAspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                else if (cover != null && cover.isNotEmpty)
                  AppNetworkImage(
                    url: cover,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(color: const Color(0xFF141418)),

                // ── 2. Center Action: Play / Pause Button & Pop Animations ──
                if (!hasActivePlayer && !_isInitializing)
                  Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.play_arrow_solid,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (_isInitializing)
                  const Center(
                    child: CupertinoActivityIndicator(color: Colors.white, radius: 13),
                  ),

                // Pop Feedback Icon (Play / Pause toggle feedback)
                if (_showFeedbackIcon && _feedbackIcon != null)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 250),
                      tween: Tween(begin: 0.6, end: 1.0),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 1),
                            ),
                            child: Icon(_feedbackIcon, size: 26, color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),

                // Double Tap Heart Animation (Like pop)
                if (_showHeartAnimation)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 400),
                      tween: Tween(begin: 0.3, end: 1.2),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: const Icon(
                            CupertinoIcons.heart_fill,
                            size: 80,
                            color: Color(0xFFFF2D55),
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // ── 3. Error Banner ──
                if (_hasError)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle_fill,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Klip video belum dapat dimuat',
                              style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _startPlayback,
                            child: const Text(
                              'Coba Lagi',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFFF2D55),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 4. Floating Discreet Corner Controls (Tanpa Menutupi Video) ──
                if (hasActivePlayer) ...[
                  // Tombol Tonton Full Episode di pojok kiri bawah (jika tersedia)
                  if (widget.onOpenFullPlayer != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenFullPlayer!();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 0.6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.fullscreen, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Full',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Tombol Mute / Unmute di pojok kanan bawah
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.6),
                        ),
                        child: Icon(
                          _isMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // ── 5. Hairline Progress Bar di Garis Bawah Layar Video ──
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 2.0,
                      color: Colors.white.withValues(alpha: 0.15),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressFraction.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
