import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/pip_service.dart';

/// Overlay interaktif khusus untuk floating window PiP di Desktop (Windows).
/// Menyediakan kontrol drag window, play/pause, seek, expand, dan close.
class DesktopPipOverlay extends StatefulWidget {
  final dynamic player;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const DesktopPipOverlay({
    super.key,
    required this.player,
    required this.onExpand,
    required this.onClose,
  });

  @override
  State<DesktopPipOverlay> createState() => _DesktopPipOverlayState();
}

class _DesktopPipOverlayState extends State<DesktopPipOverlay> {
  bool _isHovered = false;
  Timer? _hideTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = true;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    if (p is VideoPlayerController) {
      _position = p.value.position;
      _duration = p.value.duration;
      _isPlaying = p.value.isPlaying;
      p.addListener(_onPlayerUpdate);
    } else if (p != null) {
      try {
        _position = (p.state.position as Duration?) ?? Duration.zero;
        _duration = (p.state.duration as Duration?) ?? Duration.zero;
        _isPlaying = (p.state.playing as bool?) ?? true;
        _posSub = (p.stream.position as Stream<Duration>).listen((pos) {
          if (mounted) setState(() => _position = pos);
        });
        _durSub = (p.stream.duration as Stream<Duration>).listen((dur) {
          if (mounted) setState(() => _duration = dur);
        });
        _playSub = (p.stream.playing as Stream<bool>).listen((playing) {
          if (mounted) setState(() => _isPlaying = playing);
        });
      } catch (_) {}
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || widget.player == null) return;
    final p = widget.player;
    if (p is VideoPlayerController) {
      final val = p.value;
      setState(() {
        _position = val.position;
        _duration = val.duration;
        _isPlaying = val.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    final p = widget.player;
    if (p is VideoPlayerController) {
      p.removeListener(_onPlayerUpdate);
    }
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    super.dispose();
  }

  void _onHoverChanged(bool hovered) {
    if (hovered) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
      if (mounted) setState(() => _isHovered = false);
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted && !_isHovered) {
      setState(() => _isHovered = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isHovered = false);
    });
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration && _duration > Duration.zero ? _duration : target);
    final p = widget.player;
    if (p is VideoPlayerController) {
      p.seekTo(clamped);
    } else if (p != null) {
      try {
        p.seek(clamped);
      } catch (_) {}
    }
    _resetHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onHover: (_) => _resetHideTimer(),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => PipService.instance.startDragging(),
        onDoubleTap: widget.onExpand,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark vignette when hovered
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: _isHovered ? Colors.black.withValues(alpha: 0.45) : Colors.transparent,
            ),

            // Top bar controls (Drag area, Expand, Close)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              top: _isHovered ? 8 : -50,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  // Drag indicator & Title
                  GestureDetector(
                    onPanStart: (_) => PipService.instance.startDragging(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.move, color: Colors.white70, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            'Moko PiP',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Expand to main window button
                  _buildIconButton(
                    icon: CupertinoIcons.arrow_up_right_square,
                    tooltip: 'Kembali ke Layar Penuh / Normal',
                    onTap: widget.onExpand,
                  ),
                  const SizedBox(width: 6),

                  // Close PiP button
                  _buildIconButton(
                    icon: CupertinoIcons.xmark,
                    tooltip: 'Tutup PiP',
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),

            // Center playback controls (Skip -10s, Play/Pause, Skip +10s)
            if (_isHovered)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Skip -10s
                    _buildRoundButton(
                      icon: CupertinoIcons.gobackward_10,
                      size: 32,
                      iconSize: 18,
                      onTap: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 16),

                    // Play/Pause
                    _buildRoundButton(
                      icon: _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                      size: 42,
                      iconSize: 22,
                      backgroundColor: Colors.white,
                      iconColor: Colors.black,
                      onTap: () {
                        final p = widget.player;
                        if (p is VideoPlayerController) {
                          if (p.value.isPlaying) {
                            p.pause();
                          } else {
                            p.play();
                          }
                        } else if (p != null) {
                          try {
                            p.playOrPause();
                          } catch (_) {}
                        }
                        _resetHideTimer();
                      },
                    ),
                    const SizedBox(width: 16),

                    // Skip +10s
                    _buildRoundButton(
                      icon: CupertinoIcons.goforward_10,
                      size: 32,
                      iconSize: 18,
                      onTap: () => _seekRelative(10),
                    ),
                  ],
                ),
              ),

            // Bottom slim progress bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3.5,
                color: Colors.white12,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required double size,
    required double iconSize,
    Color? backgroundColor,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}