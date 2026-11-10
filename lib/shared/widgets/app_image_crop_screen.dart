import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum CropType {
  avatar,
  cover,
}

class AppImageCropScreen extends StatefulWidget {
  final File imageFile;
  final CropType cropType;

  const AppImageCropScreen({
    super.key,
    required this.imageFile,
    required this.cropType,
  });

  /// Helper static method to open the crop screen and return the cropped File.
  static Future<File?> open({
    required BuildContext context,
    required File imageFile,
    required CropType cropType,
  }) {
    return Navigator.push<File>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AppImageCropScreen(
          imageFile: imageFile,
          cropType: cropType,
        ),
      ),
    );
  }

  @override
  State<AppImageCropScreen> createState() => _AppImageCropScreenState();
}

class _AppImageCropScreenState extends State<AppImageCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transCtrl = TransformationController();

  int _quarterTurns = 0;
  bool _isProcessing = false;
  bool _circularAvatarPreview = true;

  // Cover aspect ratio options: 16/9, 2.5/1, 4/3
  double _coverAspectRatio = 16 / 9;

  @override
  void dispose() {
    _transCtrl.dispose();
    super.dispose();
  }

  void _resetTransform() {
    HapticFeedback.lightImpact();
    setState(() {
      _transCtrl.value = Matrix4.identity();
      _quarterTurns = 0;
    });
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transCtrl.value = Matrix4.identity();
    });
  }

  Future<void> _applyCrop() async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Crop view tidak ditemukan');
      }

      // Render boundary at 3.0 pixel ratio for crystal-clear output
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal mengekstrak data gambar');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final fileName = 'crop_${widget.cropType.name}_${DateTime.now().millisecondsSinceEpoch}.png';
      final croppedFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await croppedFile.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context, croppedFile);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal memotong gambar: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvatar = widget.cropType == CropType.avatar;
    final title = isAvatar ? 'Sesuaikan Foto Profil' : 'Sesuaikan Foto Sampul';
    final screenSize = MediaQuery.of(context).size;

    // Calculate crop viewport dimensions
    final maxAvailableWidth = screenSize.width - 36;
    final maxAvailableHeight = screenSize.height * 0.52;

    double cropWidth;
    double cropHeight;

    if (isAvatar) {
      final size = math.min(maxAvailableWidth, maxAvailableHeight).clamp(240.0, 320.0);
      cropWidth = size;
      cropHeight = size;
    } else {
      cropWidth = maxAvailableWidth;
      cropHeight = cropWidth / _coverAspectRatio;
      if (cropHeight > maxAvailableHeight) {
        cropHeight = maxAvailableHeight;
        cropWidth = cropHeight * _coverAspectRatio;
      }
    }

    final cornerRadius = isAvatar
        ? (_circularAvatarPreview ? cropWidth / 2 : 20.0)
        : 14.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resetTransform,
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _applyCrop,
              icon: _isProcessing
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 20),
              label: Text(
                _isProcessing ? 'Memproses...' : 'Selesai',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Center crop stage
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Crop container
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. The Capturable Image Viewport
                          ClipRRect(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            child: RepaintBoundary(
                              key: _cropKey,
                              child: Container(
                                width: cropWidth,
                                height: cropHeight,
                                color: Colors.black,
                                child: InteractiveViewer(
                                  transformationController: _transCtrl,
                                  minScale: 0.5,
                                  maxScale: 6.0,
                                  boundaryMargin: EdgeInsets.all(math.max(cropWidth, cropHeight) * 2),
                                  child: Center(
                                    child: RotatedBox(
                                      quarterTurns: _quarterTurns,
                                      child: Image.file(
                                        widget.imageFile,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 2. Visual Guide & Grid (Not captured in output image)
                          IgnorePointer(
                            child: Container(
                              width: cropWidth,
                              height: cropHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(cornerRadius),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _CropGridPainter(
                                  isCircle: isAvatar && _circularAvatarPreview,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Hint indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.hand_draw_fill, color: Colors.white70, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Geser untuk posisi • Cubit untuk zoom',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF16161A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode / Aspect ratio selector
                  if (isAvatar) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildChoiceChip(
                          label: 'Lingkaran',
                          icon: CupertinoIcons.circle,
                          isSelected: _circularAvatarPreview,
                          onTap: () => setState(() => _circularAvatarPreview = true),
                        ),
                        const SizedBox(width: 12),
                        _buildChoiceChip(
                          label: 'Kotak (1:1)',
                          icon: CupertinoIcons.square,
                          isSelected: !_circularAvatarPreview,
                          onTap: () => setState(() => _circularAvatarPreview = false),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Putar 90°',
                          onPressed: _rotateClockwise,
                          icon: const Icon(CupertinoIcons.rotate_right, color: Colors.white),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildChoiceChip(
                          label: '16:9 (Standar)',
                          icon: CupertinoIcons.rectangle,
                          isSelected: (_coverAspectRatio - 16 / 9).abs() < 0.05,
                          onTap: () => setState(() => _coverAspectRatio = 16 / 9),
                        ),
                        const SizedBox(width: 8),
                        _buildChoiceChip(
                          label: '2.5:1 (Banner)',
                          icon: CupertinoIcons.rectangle_split_3x1,
                          isSelected: (_coverAspectRatio - 2.5).abs() < 0.05,
                          onTap: () => setState(() => _coverAspectRatio = 2.5),
                        ),
                        const SizedBox(width: 8),
                        _buildChoiceChip(
                          label: '4:3',
                          icon: CupertinoIcons.rectangle,
                          isSelected: (_coverAspectRatio - 4 / 3).abs() < 0.05,
                          onTap: () => setState(() => _coverAspectRatio = 4 / 3),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Putar 90°',
                          onPressed: _rotateClockwise,
                          icon: const Icon(CupertinoIcons.rotate_right, color: Colors.white),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Big apply button (Welcome Screen Pill Style)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shadowColor: Colors.white.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _isProcessing ? null : _applyCrop,
                      icon: _isProcessing
                          ? const CupertinoActivityIndicator(color: Colors.black)
                          : const Icon(CupertinoIcons.checkmark_circle_fill, size: 20, color: Colors.black),
                      label: Text(
                        _isProcessing ? 'Memotong...' : 'Terapkan Hasil Crop',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Colors.black,
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

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for rule-of-thirds grid lines on the crop viewport
class _CropGridPainter extends CustomPainter {
  final bool isCircle;

  _CropGridPainter({required this.isCircle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Horizontal lines
    final rowH = size.height / 3;
    canvas.drawLine(Offset(0, rowH), Offset(size.width, rowH), paint);
    canvas.drawLine(Offset(0, rowH * 2), Offset(size.width, rowH * 2), paint);

    // Vertical lines
    final colW = size.width / 3;
    canvas.drawLine(Offset(colW, 0), Offset(colW, size.height), paint);
    canvas.drawLine(Offset(colW * 2, 0), Offset(colW * 2, size.height), paint);

    // If circle guide, draw inner circle outline
    if (isCircle) {
      final circlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        circlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) {
    return oldDelegate.isCircle != isCircle;
  }
}

