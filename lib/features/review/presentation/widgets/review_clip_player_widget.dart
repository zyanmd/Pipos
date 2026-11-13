import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../anime/data/anime_repository.dart';
import '../../data/models/user_review_model.dart';

/// Widget pemutar klip anime inline yang modern bergaya Apple iOS HIG.
/// Memutar cuplikan anime tepat pada rentang waktu yang ditentukan (clip_start s/d clip_end)
/// secara looping dengan opsi mute/unmute serta tombol tonton full episode.
class ReviewClipPlayerWidget extends StatefulWidget {
  final UserReviewModel review;
  final VoidCallback? onOpenFullPlayer;

  const ReviewClipPlayerWidget({
    super.key,
    required this.review,
    this.onOpenFullPlayer,
  });

  @override
  State<ReviewClipPlayerWidget> createState() => _ReviewClipPlayerWidgetState();
}

class _ReviewClipPlayerWidgetState extends State<ReviewClipPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _hasError = false;

  double get _startSec => widget.review.clipStart ?? 0.0;
  double get _endSec => widget.review.clipEnd ?? (_startSec + 30.0);

  @override
  void dispose() {
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
    HapticFeedback.selectionClick();

    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
        setState(() => _isPlaying = false);
      } else {
        await _controller!.play();
        setState(() => _isPlaying = true);
      }
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      String? streamUrl = widget.review.mediaUrl;

      // Jika mediaUrl kosong tapi ada subId (episode id), resolve dari repository
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

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize();
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
      await controller.play();

      controller.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
          _isPlaying = true;
        });
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

    // Looping rentang klip
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

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cover = widget.review.targetCover;
    final hasActivePlayer = _controller != null && _controller!.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 195,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background Thumbnail / Active Video ──
            if (hasActivePlayer)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
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
              Container(color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFD1D1D6)),

            // Dark Vignette / Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: hasActivePlayer ? 0.45 : 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // ── Top Bar: Clip Badge & Mute Toggle ──
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  // Badge Rentang Klip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24, width: 0.6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.scissors,
                          size: 11,
                          color: Color(0xFFFF2D55),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.review.clipTimeRangeFormatted.isNotEmpty
                              ? widget.review.clipTimeRangeFormatted
                              : 'Klip Anime',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.review.clipDurationFormatted.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.review.clipDurationFormatted})',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Mute / Unmute Toggle Button (Hanya jika player aktif)
                  if (hasActivePlayer)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.6),
                        ),
                        child: Icon(
                          _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Center Action Button (Play / Pause / Loading) ──
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _startPlayback,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isInitializing
                        ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                        : Icon(
                            hasActivePlayer && _isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_arrow_solid,
                            size: 24,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),

            // ── Error Banner (jika stream tidak dapat dimuat) ──
            if (_hasError)
              Positioned(
                bottom: 40,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Klip streaming belum tersedia di server. Ketuk untuk coba tonton full episode.',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ── Bottom Controls & Open Full Player Button ──
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  // Info Episode / Durasi Klip
                  Expanded(
                    child: Text(
                      widget.review.subTitle != null && widget.review.subTitle!.isNotEmpty
                          ? '${widget.review.targetTitle} • ${widget.review.subTitle}'
                          : widget.review.targetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Tonton Full Episode di Player
                  if (widget.onOpenFullPlayer != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onOpenFullPlayer!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30, width: 0.6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.play_circle_fill, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Buka Full',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
      ),
    );
  }
}
