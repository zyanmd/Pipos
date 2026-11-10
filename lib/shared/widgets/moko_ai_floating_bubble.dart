import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/pip_service.dart';
import 'moko_ai_universal_modal.dart';

/// Floating, draggable AI bubble widget ("Moko AI Pop-Up").
/// Floats gracefully above app content and pops up Moko AI modal on tap.
class MokoAiFloatingBubble extends StatefulWidget {
  const MokoAiFloatingBubble({super.key});

  @override
  State<MokoAiFloatingBubble> createState() => _MokoAiFloatingBubbleState();
}

class _MokoAiFloatingBubbleState extends State<MokoAiFloatingBubble>
    with SingleTickerProviderStateMixin {
  Offset? _position;
  bool _isDragging = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PipService.instance.isFullscreen,
      builder: (context, isFullscreen, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: PipService.instance.isInPip,
          builder: (context, isInPip, _) {
            // Sembunyikan saat sedang menonton video full-screen / PiP
            if (isFullscreen || isInPip) {
              return const SizedBox.shrink();
            }

            final media = MediaQuery.of(context);
            final screenSize = media.size;
            final bottomPadding = media.padding.bottom + 88.0; // Mengambang di atas bottom navbar
            const bubbleSize = 52.0;

            // Inisialisasi posisi awal di kanan bawah
            _position ??= Offset(
              screenSize.width - bubbleSize - 16.0,
              screenSize.height - bottomPadding - bubbleSize,
            );

            // Batasi posisi agar tidak keluar layar
            final clampedX = _position!.dx.clamp(
              8.0,
              screenSize.width - bubbleSize - 8.0,
            );
            final clampedY = _position!.dy.clamp(
              media.padding.top + 8.0,
              screenSize.height - media.padding.bottom - bubbleSize - 16.0,
            );

            return Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() => _isDragging = true);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      _position!.dx + details.delta.dx,
                      _position!.dy + details.delta.dy,
                    );
                  });
                },
                onPanEnd: (details) {
                  setState(() => _isDragging = false);
                  // Snap ke sisi kiri atau kanan layar terdekat
                  final midX = screenSize.width / 2;
                  final targetX = (_position!.dx + bubbleSize / 2 < midX)
                      ? 14.0
                      : screenSize.width - bubbleSize - 14.0;
                  setState(() {
                    _position = Offset(targetX, clampedY);
                  });
                },
                onTap: () {
                  if (!_isDragging) {
                    HapticFeedback.mediumImpact();
                    MokoAiUniversalModal.show(context);
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final glow = 0.35 + (_pulseCtrl.value * 0.35);
                    return Container(
                      width: bubbleSize,
                      height: bubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA855F7).withValues(alpha: glow),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFFA855F7),
                                  Color(0xFFEC4899),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.sparkles,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

