import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/widgets/cinematic_fullscreen_hud.dart';

class AnimePlayerCustomControls extends StatefulWidget {
  final VideoPlayerController controller;
  VideoPlayerController get player => controller;
  final void Function(bool visibility)? onControlsVisibilityChanged;
  final String title;
  final String episodeLabel;
  final List<String> qualities;
  final String selectedQuality;
  final ValueChanged<String> onSelectQuality;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChange;
  final VoidCallback? onPip;
  final VoidCallback? onBack;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final bool hasPreviousEpisode;
  final bool hasNextEpisode;

  AnimePlayerCustomControls({
    super.key,
    VideoPlayerController? player,
    VideoPlayerController? controller,
    this.onControlsVisibilityChanged,
    required this.title,
    required this.episodeLabel,
    required this.qualities,
    required this.selectedQuality,
    required this.onSelectQuality,
    required this.playbackSpeed,
    required this.onSpeedChange,
    this.onPip,
    this.onBack,
    this.isFullScreen = false,
    this.onToggleFullScreen,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.hasPreviousEpisode = false,
    this.hasNextEpisode = false,
  }) : controller = controller ?? player!;

  @override
  State<AnimePlayerCustomControls> createState() => _AnimePlayerCustomControlsState();
}

class _AnimePlayerCustomControlsState extends State<AnimePlayerCustomControls> {
  bool _isVisible = true;
  Timer? _hideTimer;

  // Double tap skip feedback state
  bool _showLeftSkip = false;
  bool _showRightSkip = false;
  Timer? _leftSkipTimer;
  Timer? _rightSkipTimer;

  // Long press 2x state
  bool _isHolding2x = false;
  double _speedBefore2x = 1.0;

  // Dragging slider state
  bool _isDragging = false;
  double _dragValue = 0.0;

  late String _currentSelectedQuality;
  late double _currentPlaybackSpeed;

  @override
  void initState() {
    super.initState();
    _currentSelectedQuality = widget.selectedQuality;
    _currentPlaybackSpeed = widget.playbackSpeed;

    widget.player.addListener(_onPlayerUpdate);
    _resetHideTimer();
  }

  void _onPlayerUpdate() {
    if (mounted && !_isDragging) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant AnimePlayerCustomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player) {
      oldWidget.player.removeListener(_onPlayerUpdate);
      widget.player.addListener(_onPlayerUpdate);
    }
    if (widget.selectedQuality != oldWidget.selectedQuality) {
      _currentSelectedQuality = widget.selectedQuality;
    }
    if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      _currentPlaybackSpeed = widget.playbackSpeed;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _leftSkipTimer?.cancel();
    _rightSkipTimer?.cancel();
    widget.player.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isVisible && !_isDragging && !_isHolding2x) {
        setState(() {
          _isVisible = false;
        });
        widget.onControlsVisibilityChanged?.call(false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _isVisible = !_isVisible;
    });
    widget.onControlsVisibilityChanged?.call(_isVisible);
    if (_isVisible) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _triggerSkip({required bool isForward}) {
    HapticFeedback.lightImpact();
    final current = widget.player.value.position;
    final duration = widget.player.value.duration;

    if (isForward) {
      final target = current + const Duration(seconds: 10);
      widget.player.seekTo(target > duration ? duration : target);
      setState(() {
        _showRightSkip = true;
      });
      _rightSkipTimer?.cancel();
      _rightSkipTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showRightSkip = false);
      });
    } else {
      final target = current - const Duration(seconds: 10);
      widget.player.seekTo(target < Duration.zero ? Duration.zero : target);
      setState(() {
        _showLeftSkip = true;
      });
      _leftSkipTimer?.cancel();
      _leftSkipTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showLeftSkip = false);
      });
    }

    _resetHideTimer();
  }

  void _start2xSpeed() {
    _speedBefore2x = _currentPlaybackSpeed;
    _isHolding2x = true;
    try {
      widget.player.setPlaybackSpeed(2.0);
    } catch (_) {}
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _stop2xSpeed() {
    if (_isHolding2x) {
      _isHolding2x = false;
      try {
        widget.player.setPlaybackSpeed(_speedBefore2x);
      } catch (_) {}
      HapticFeedback.selectionClick();
      setState(() {});
      _resetHideTimer();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showQualityModal(BuildContext context) {
    _hideTimer?.cancel();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(CupertinoIcons.slider_horizontal_3, color: isDark ? Colors.white : Colors.black, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Kualitas Video',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000)),
                  ...widget.qualities.map((quality) {
                    final active = (_currentSelectedQuality.isNotEmpty ? _currentSelectedQuality : widget.selectedQuality)
                            .toLowerCase()
                            .replaceAll('p', '') ==
                        quality.toLowerCase().replaceAll('p', '');
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentSelectedQuality = quality;
                        });
                        widget.onSelectQuality(quality);
                        if (widget.isFullScreen) {
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                quality,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                                ),
                              ),
                            ),
                            if (active)
                              Icon(CupertinoIcons.checkmark_alt, color: isDark ? Colors.white : Colors.black, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (widget.isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      _resetHideTimer();
    });
  }

  void _showSpeedModal(BuildContext context) {
    _hideTimer?.cancel();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(CupertinoIcons.speedometer, color: isDark ? Colors.white : Colors.black, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Kecepatan Pemutaran',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000)),
                  ...speeds.map((s) {
                    final active = (_currentPlaybackSpeed - s).abs() < 0.05;
                    return InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentPlaybackSpeed = s;
                        });
                        try {
                          await widget.player.setPlaybackSpeed(s);
                        } catch (e) {
                          debugPrint('[Speed] player.setPlaybackSpeed failed: $e');
                        }
                        widget.onSpeedChange(s);
                        if (widget.isFullScreen) {
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s == 1.0 ? '1.0x (Normal)' : '${s}x',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                                ),
                              ),
                            ),
                            if (active)
                              Icon(CupertinoIcons.checkmark_alt, color: isDark ? Colors.white : Colors.black, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (widget.isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      _resetHideTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final val = widget.player.value;
    final isInitialized = val.isInitialized;
    final isPlaying = val.isPlaying;
    final isBuffering = val.isBuffering;
    final position = _isDragging
        ? Duration(milliseconds: _dragValue.toInt())
        : val.position;
    final duration = val.duration;
    final isFullScreen = widget.isFullScreen;

    double maxBufferedMs = 0.0;
    if (val.buffered.isNotEmpty) {
      for (final range in val.buffered) {
        final endMs = range.end.inMilliseconds.toDouble();
        if (endMs > maxBufferedMs) {
          maxBufferedMs = endMs;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final x = details.localPosition.dx;
            if (x >= screenWidth * 0.35 && x <= screenWidth * 0.65) {
              if (widget.onToggleFullScreen != null) {
                HapticFeedback.selectionClick();
                widget.onToggleFullScreen?.call();
                _resetHideTimer();
                return;
              }
            }
            if (x < screenWidth / 2) {
              _triggerSkip(isForward: false);
            } else {
              _triggerSkip(isForward: true);
            }
          },
          onLongPressStart: (_) => _start2xSpeed(),
          onLongPressEnd: (_) => _stop2xSpeed(),
          onLongPressCancel: () => _stop2xSpeed(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 2X SPEED FLOATING CAPSULE (Top Center)
              if (_isHolding2x)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '2.0x Kecepatan Cepat',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. DOUBLE TAP SKIP RIPPLE INDICATORS
              if (_showLeftSkip)
                Positioned(
                  left: 36,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.70),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.gobackward_10, color: Colors.white, size: 28),
                          const SizedBox(height: 2),
                          Text(
                            '-10s',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_showRightSkip)
                Positioned(
                  right: 36,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.70),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.goforward_10, color: Colors.white, size: 28),
                          const SizedBox(height: 2),
                          Text(
                            '+10s',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. BUFFERING INDICATOR
              if (isBuffering && !isPlaying)
                const Center(
                  child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
                ),

              // 4. MAIN CONTROLS OVERLAY (Smooth Fade)
              IgnorePointer(
                ignoring: !_isVisible,
                child: AnimatedOpacity(
                  opacity: _isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xB3000000), // Black 70%
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xCC000000), // Black 80%
                        ],
                        stops: [0.0, 0.28, 0.68, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      bottom: isFullScreen,
                      top: isFullScreen,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // â”€â”€â”€ TOP BAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 12, 0),
                            child: Row(
                              children: [
                                // Back button
                                GestureDetector(
                                  onTap: () {
                                    if (isFullScreen) {
                                      widget.onToggleFullScreen?.call();
                                    } else {
                                      widget.onBack?.call();
                                    }
                                  },
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24, width: 0.5),
                                    ),
                                    child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Title & Episode
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        widget.episodeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Resolution Button
                                if (widget.qualities.isNotEmpty)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showQualityModal(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(CupertinoIcons.slider_horizontal_3, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            _currentSelectedQuality.isNotEmpty
                                                ? _currentSelectedQuality
                                                : widget.selectedQuality,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),

                                // Speed Button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showSpeedModal(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(CupertinoIcons.speedometer, size: 12, color: Colors.white70),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${_currentPlaybackSpeed}x',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // PiP Button (only in non-fullscreen)
                                if (!isFullScreen && widget.onPip != null) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: widget.onPip,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white24, width: 0.5),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.rectangle_on_rectangle_angled,
                                        size: 15,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // â”€â”€â”€ CENTER CONTROLS (Skip 10s, Play/Pause) â”€â”€â”€â”€â”€â”€â”€â”€â”€
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Previous Episode
                              if (widget.onPreviousEpisode != null) ...[
                                CupertinoButton(
                                  padding: const EdgeInsets.all(10),
                                  onPressed: widget.hasPreviousEpisode
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          widget.onPreviousEpisode!();
                                          _resetHideTimer();
                                        }
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.backward_end_fill,
                                    color: widget.hasPreviousEpisode ? Colors.white : Colors.white24,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Skip Back 10s
                              CupertinoButton(
                                padding: const EdgeInsets.all(12),
                                onPressed: () => _triggerSkip(isForward: false),
                                child: const Icon(CupertinoIcons.gobackward_10, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),

                              // Play / Pause Circle
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  if (widget.player.value.isPlaying) {
                                    widget.player.pause();
                                  } else {
                                    widget.player.play();
                                  }
                                  _resetHideTimer();
                                },
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                                      color: Colors.black,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Skip Forward 10s
                              CupertinoButton(
                                padding: const EdgeInsets.all(12),
                                onPressed: () => _triggerSkip(isForward: true),
                                child: const Icon(CupertinoIcons.goforward_10, color: Colors.white, size: 28),
                              ),

                              // Next Episode
                              if (widget.onNextEpisode != null) ...[
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: const EdgeInsets.all(10),
                                  onPressed: widget.hasNextEpisode
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          widget.onNextEpisode!();
                                          _resetHideTimer();
                                        }
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.forward_end_fill,
                                    color: widget.hasNextEpisode ? Colors.white : Colors.white24,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // â”€â”€â”€ BOTTOM BAR (Timeline, Duration, Fullscreen) â”€â”€â”€â”€
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    // Current Position
                                    Text(
                                      _formatDuration(position),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),

                                    // Timeline Slider
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3.5,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                            elevation: 2,
                                          ),
                                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                          activeTrackColor: Colors.white,
                                          secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.45),
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                          overlayColor: Colors.white.withValues(alpha: 0.25),
                                        ),
                                        child: Slider(
                                          value: isInitialized
                                              ? position.inMilliseconds
                                                  .toDouble()
                                                  .clamp(0.0, duration.inMilliseconds.toDouble())
                                              : 0.0,
                                          secondaryTrackValue: isInitialized && duration.inMilliseconds > 0
                                              ? maxBufferedMs.clamp(0.0, duration.inMilliseconds.toDouble())
                                              : null,
                                          min: 0.0,
                                          max: isInitialized && duration.inMilliseconds > 0
                                              ? duration.inMilliseconds.toDouble()
                                              : 1.0,
                                          onChangeStart: (val) {
                                            _isDragging = true;
                                            _dragValue = val;
                                            _hideTimer?.cancel();
                                          },
                                          onChanged: (val) {
                                            setState(() {
                                              _dragValue = val;
                                            });
                                          },
                                          onChangeEnd: (val) {
                                            _isDragging = false;
                                            widget.player.seekTo(Duration(milliseconds: val.toInt()));
                                            _resetHideTimer();
                                          },
                                        ),
                                      ),
                                    ),

                                    // Total Duration
                                    Text(
                                      _formatDuration(duration),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white60,
                                      ),
                                    ),
                                    const SizedBox(width: 8),


                                    // Fullscreen Button
                                    if (widget.onToggleFullScreen != null)
                                      AnimatedFullscreenButton(
                                        isFullscreen: isFullScreen,
                                        onTap: () {
                                          widget.onToggleFullScreen?.call();
                                          _resetHideTimer();
                                        },
                                        size: 32,
                                        iconSize: 18,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
