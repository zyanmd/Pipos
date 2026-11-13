import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/user_review_model.dart';
import '../../data/review_repository.dart';

/// Modal dialog modern berdesain Apple iOS HIG untuk menulis / mengedit ulasan
class ReviewInputDialog extends StatefulWidget {
  final String itemType; // 'anime' atau 'comic'
  final String targetId;
  final String targetTitle;
  final String? targetCover;
  final String? subId;
  final String? subTitle;
  final UserReviewModel? initialReview;
  final double? initialClipStart;
  final double? initialClipEnd;
  final String? initialMediaUrl;
  final String? initialMediaType;
  final double? playbackPosition;

  const ReviewInputDialog({
    super.key,
    required this.itemType,
    required this.targetId,
    required this.targetTitle,
    this.targetCover,
    this.subId,
    this.subTitle,
    this.initialReview,
    this.initialClipStart,
    this.initialClipEnd,
    this.initialMediaUrl,
    this.initialMediaType,
    this.playbackPosition,
  });

  static Future<UserReviewModel?> show(
    BuildContext context, {
    required String itemType,
    required String targetId,
    required String targetTitle,
    String? targetCover,
    String? subId,
    String? subTitle,
    String? subItemTitle,
    UserReviewModel? initialReview,
    double? initialClipStart,
    double? initialClipEnd,
    String? initialMediaUrl,
    String? initialMediaType,
    double? playbackPosition,
  }) {
    return showModalBottomSheet<UserReviewModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewInputDialog(
        itemType: itemType,
        targetId: targetId,
        targetTitle: targetTitle,
        targetCover: targetCover,
        subId: subId,
        subTitle: subTitle ?? subItemTitle,
        initialReview: initialReview,
        initialClipStart: initialClipStart,
        initialClipEnd: initialClipEnd,
        initialMediaUrl: initialMediaUrl,
        initialMediaType: initialMediaType,
        playbackPosition: playbackPosition,
      ),
    );
  }

  @override
  State<ReviewInputDialog> createState() => _ReviewInputDialogState();
}

class _ReviewInputDialogState extends State<ReviewInputDialog> {
  late final TextEditingController _textCtrl;
  late double _rating;
  late String _status;
  File? _selectedMedia;
  String? _existingMediaUrl;
  double? _clipStart;
  double? _clipEnd;
  String? _mediaType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialReview?.content ?? '');
    _rating = widget.initialReview?.rating ?? 5.0;
    _status = widget.initialReview?.status ?? 'completed';
    _existingMediaUrl = widget.initialMediaUrl ?? widget.initialReview?.mediaUrl;
    _mediaType = widget.initialMediaType ?? widget.initialReview?.mediaType;
    _clipStart = widget.initialClipStart ?? widget.initialReview?.clipStart;
    _clipEnd = widget.initialClipEnd ?? widget.initialReview?.clipEnd;
    if (_clipStart != null && _clipEnd != null) {
      _mediaType ??= 'clip';
    }

    if (widget.initialReview == null && widget.targetId.isNotEmpty) {
      _fetchExistingReview();
    }
  }

  Future<void> _fetchExistingReview() async {
    try {
      final existing = await ReviewRepository.instance.checkReview(
        targetId: widget.targetId,
        subId: widget.subId,
      );
      if (existing != null && mounted) {
        setState(() {
          if (_textCtrl.text.isEmpty && (existing.content != null && existing.content!.isNotEmpty)) {
            _textCtrl.text = existing.content!;
          }
          if (existing.rating > 0) {
            _rating = existing.rating;
          }
          if (existing.status.isNotEmpty) {
            _status = existing.status;
          }
          if (existing.mediaUrl != null && existing.mediaUrl!.isNotEmpty && _existingMediaUrl == null) {
            _existingMediaUrl = existing.mediaUrl;
          }
          if (existing.mediaType != null && _mediaType == null) {
            _mediaType = existing.mediaType;
          }
          if (existing.clipStart != null && _clipStart == null) {
            _clipStart = existing.clipStart;
          }
          if (existing.clipEnd != null && _clipEnd == null) {
            _clipEnd = existing.clipEnd;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.lightImpact();
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedMedia = File(picked.path);
          _existingMediaUrl = null;
        });
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final tid = widget.targetId.trim();
    final ttitle = widget.targetTitle.trim();
    if (tid.isEmpty || ttitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID atau judul tidak valid untuk menulis ulasan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final res = await ReviewRepository.instance.saveReview(
      itemType: widget.itemType,
      targetId: tid,
      targetTitle: ttitle,
      targetCover: widget.targetCover,
      subId: widget.subId,
      subTitle: widget.subTitle,
      content: _textCtrl.text.trim(),
      rating: _rating,
      status: _status,
      mediaFile: _selectedMedia,
      mediaUrl: _existingMediaUrl,
      mediaType: _mediaType,
      clipStart: _clipStart,
      clipEnd: _clipEnd,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null) {
        Navigator.of(context).pop(res);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan ulasan. Periksa koneksi atau coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showClipTrimmerSheet() {
    HapticFeedback.lightImpact();
    final defaultPos = widget.playbackPosition ?? 0.0;
    double start = _clipStart ?? (defaultPos > 0 ? (defaultPos - 10.0).clamp(0.0, 7200.0) : 0.0);
    double end = _clipEnd ?? (start + 30.0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1C1C22) : const Color(0xFFFFFFFF);
            final durSec = (end - start).clamp(1.0, 3600.0).round().abs();

            void adjustStart(double delta) {
              HapticFeedback.selectionClick();
              setSheetState(() {
                start = (start + delta).clamp(0.0, 7200.0);
                if (end <= start) {
                  end = start + 5.0;
                }
              });
            }

            void adjustEnd(double delta) {
              HapticFeedback.selectionClick();
              setSheetState(() {
                end = (end + delta).clamp(start + 1.0, 7200.0);
              });
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grabber
                      Center(
                        child: Container(
                          width: 36,
                          height: 4.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2.2),
                          ),
                        ),
                      ),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.scissors,
                                  size: 16,
                                  color: Color(0xFFFF2D55),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Atur Waktu Klip Anime',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Tutup', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tentukan menit dan detik awal serta akhir cuplikan yang ingin kamu bagikan.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Waktu Mulai (Start Time Card)
                      _buildTimeAdjustCard(
                        title: 'WAKTU MULAI (START)',
                        timeText: UserReviewModel.formatSeconds(start),
                        isDark: isDark,
                        onMinus30: () => adjustStart(-30),
                        onMinus5: () => adjustStart(-5),
                        onPlus5: () => adjustStart(5),
                        onPlus30: () => adjustStart(30),
                      ),

                      const SizedBox(height: 12),

                      // Waktu Selesai (End Time Card)
                      _buildTimeAdjustCard(
                        title: 'WAKTU SELESAI (END)',
                        timeText: UserReviewModel.formatSeconds(end),
                        isDark: isDark,
                        onMinus30: () => adjustEnd(-30),
                        onMinus5: () => adjustEnd(-5),
                        onPlus5: () => adjustEnd(5),
                        onPlus30: () => adjustEnd(30),
                      ),

                      const SizedBox(height: 14),

                      // Summary Badge Durasi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Durasi Klip:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$durSec detik (${UserReviewModel.formatSeconds(start)} - ${UserReviewModel.formatSeconds(end)})',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF2D55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tombol Terapkan Klip
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: CupertinoButton(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(14),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _clipStart = start;
                              _clipEnd = end;
                              _mediaType = 'clip';
                              _selectedMedia = null;
                              if ((_existingMediaUrl == null || _existingMediaUrl!.isEmpty) &&
                                  widget.initialMediaUrl != null &&
                                  widget.initialMediaUrl!.isNotEmpty) {
                                _existingMediaUrl = widget.initialMediaUrl;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Terapkan Klip ke Ulasan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeAdjustCard({
    required String title,
    required String timeText,
    required bool isDark,
    required VoidCallback onMinus30,
    required VoidCallback onMinus5,
    required VoidCallback onPlus5,
    required VoidCallback onPlus30,
  }) {
    final btnBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24242C) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _buildStepBtn('-30s', onMinus30, btnBg, isDark),
              const SizedBox(width: 5),
              _buildStepBtn('-5s', onMinus5, btnBg, isDark),
              const SizedBox(width: 5),
              _buildStepBtn('+5s', onPlus5, btnBg, isDark),
              const SizedBox(width: 5),
              _buildStepBtn('+30s', onPlus30, btnBg, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBtn(String label, VoidCallback onTap, Color bg, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = isDark ? const Color(0xEB16161A) : const Color(0xF5FFFFFF);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return PopScope(
      canPop: !_isLoading,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 20),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apple Grabber Pill
                  Center(
                    child: Container(
                      width: 38,
                      height: 4.8,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2.4),
                      ),
                    ),
                  ),

                  // Apple Modal Header: [ Batal | Judul | Simpan ]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        widget.initialReview != null ? 'Edit Ulasan' : 'Beri Ulasan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CupertinoActivityIndicator(radius: 9)
                            : Text(
                                'Simpan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: dividerColor, thickness: 0.6),
                  const SizedBox(height: 14),

                  // Target Preview Card (Cover + Title + Subtitle)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: widget.targetCover != null && widget.targetCover!.isNotEmpty
                              ? AppNetworkImage(
                                  url: widget.targetCover!,
                                  width: 44,
                                  height: 58,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 44,
                                  height: 58,
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  child: Icon(
                                    widget.itemType == 'anime'
                                        ? CupertinoIcons.play_circle_fill
                                        : CupertinoIcons.book_fill,
                                    size: 20,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  widget.itemType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.targetTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (widget.subTitle != null && widget.subTitle!.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  widget.subTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rating Bintang Apple Style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Rating',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(5, (index) {
                            final starVal = (index + 1).toDouble();
                            final isFilled = _rating >= starVal;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _rating = starVal);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(
                                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Status Pilihan (Apple Segmented Style)
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard(
                          'completed',
                          'Selesai',
                          CupertinoIcons.checkmark_seal_fill,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusCard(
                          'planned',
                          widget.itemType == 'anime' ? 'Mau Nonton' : 'Mau Baca',
                          CupertinoIcons.clock_fill,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusCard(
                          'replaying',
                          'Diulang',
                          CupertinoIcons.arrow_2_circlepath,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input Teks Ulasan
                  Text(
                    'Catatan / Ulasan',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _textCtrl,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    placeholder: 'Tulis kesan, review, atau momen favoritmu...',
                    placeholderStyle: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF202026) : const Color(0xFFF4F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Lampiran Media Gambar / GIF & Klip Anime (Apple Style)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Tombol Tambah / Ganti Foto
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.photo_fill_on_rectangle_fill,
                                size: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedMedia != null || (_existingMediaUrl != null && _mediaType != 'clip')
                                    ? 'Ganti Foto'
                                    : 'Tambah Foto/GIF',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tombol Klip Anime (Hanya untuk Anime)
                      if (widget.itemType == 'anime')
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showClipTrimmerSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _clipStart != null
                                  ? const Color(0xFFFF2D55).withValues(alpha: 0.16)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _clipStart != null
                                    ? const Color(0xFFFF2D55).withValues(alpha: 0.5)
                                    : (isDark ? Colors.white12 : Colors.black12),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.scissors,
                                  size: 15,
                                  color: _clipStart != null ? const Color(0xFFFF2D55) : (isDark ? Colors.white : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _clipStart != null ? 'Edit Waktu Klip' : 'Klip Anime',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _clipStart != null ? const Color(0xFFFF2D55) : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_selectedMedia != null || (_existingMediaUrl != null && _mediaType != 'clip')) ...[
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedMedia = null;
                              if (_mediaType != 'clip') {
                                _existingMediaUrl = null;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Hapus Foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // ── Preview Klip Anime Terpasang ──
                  if (_clipStart != null && _clipEnd != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.scissors, size: 18, color: Color(0xFFFF2D55)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Klip Anime Terpasang',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${UserReviewModel.formatSeconds(_clipStart!)} - ${UserReviewModel.formatSeconds(_clipEnd!)} (${(_clipEnd! - _clipStart!).round().abs()} dtk)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF2D55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            onPressed: _showClipTrimmerSheet,
                            child: const Text('Ubah', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _clipStart = null;
                                _clipEnd = null;
                                if (_mediaType == 'clip') {
                                  _mediaType = null;
                                }
                              });
                            },
                            child: const Icon(CupertinoIcons.trash, size: 16, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Preview Media
                  if (_selectedMedia != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_selectedMedia!, height: 130, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ] else if (_existingMediaUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(_existingMediaUrl!, height: 130, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String value, String label, IconData icon, bool isDark) {
    final isSelected = _status == value;
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeFg = isDark ? Colors.black : Colors.white;
    final inactiveBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final inactiveFg = isDark ? Colors.white70 : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _status = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white10 : Colors.black12),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeFg : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeFg : inactiveFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
