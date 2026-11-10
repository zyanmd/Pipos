import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/announcement_model.dart';
import '../../data/announcement_repository.dart';
import '../app_features_screen.dart';

/// Clean Apple iOS HIG announcement banner widget and detail modal.
/// Fetches active announcements from `/api/announcements` and displays them
/// on Anime, Komik, Anime 18, and Komik 18 screens.
class AnnouncementBanner extends StatefulWidget {
  final EdgeInsetsGeometry? margin;

  const AnnouncementBanner({
    super.key,
    this.margin,
  });

  /// Push-alert fallback announcement if any.
  static AnnouncementModel? latestAnnouncement;

  /// Memeriksa apakah ada pengumuman baru yang belum pernah muncul di popup dialog,
  /// jika ada maka otomatis tampilkan popup dialog iOS yang elegan.
  static Future<void> checkAndShowNewAnnouncementPopup(BuildContext context) async {
    try {
      final repo = AnnouncementRepository.instance;
      // Pastikan data pengumuman aktif sudah termuat
      if (repo.announcements.value.isEmpty) {
        await repo.fetchActiveAnnouncements();
      }
      final item = await repo.getUnseenPopupAnnouncement();
      if (item != null && context.mounted) {
        showNewAnnouncementPopup(context, item);
      }
    } catch (e) {
      debugPrint('[Announcement] Gagal checkAndShowNewAnnouncementPopup: $e');
    }
  }

  /// Menampilkan popup dialog pengumuman baru bergaya Apple iOS Frosted Card
  static void showNewAnnouncementPopup(BuildContext context, AnnouncementModel item) {
    AnnouncementRepository.instance.markPopupAsSeen(item.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.88,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header Glowing Circle
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.speaker_2_fill,
                        size: 28,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Badge Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.badge.isNotEmpty ? item.badge.toUpperCase() : 'PENGUMUMAN BARU',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Content (Scrollable if long)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        item.content,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button 1: External URL (if any)
                  if (item.actionUrl != null && item.actionUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          final uri = Uri.tryParse(item.actionUrl!);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          item.actionLabel ?? 'Buka Tautan',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Action Button 2: Jelajahi Semua Fitur Aplikasi
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const AppFeaturesScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 15,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Jelajahi Semua Fitur',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action Button 3: Dismiss "Mengerti"
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Mengerti, Tutup',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
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
  }

  /// Shows the full announcement detail modal sheet.
  static void showDetail(BuildContext context, AnnouncementModel item) {
    latestAnnouncement = item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // iOS Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Badge & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Content
              Text(
                item.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),

              if (item.actionUrl != null && item.actionUrl!.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final uri = Uri.tryParse(item.actionUrl!);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      item.actionLabel ?? 'Buka Tautan',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              // Tombol Lihat Semua Fitur Aplikasi
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AppFeaturesScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.sparkles,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Semua Fitur Aplikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  final _repo = AnnouncementRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.fetchActiveAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<List<AnnouncementModel>>(
      valueListenable: _repo.announcements,
      builder: (context, _, __) {
        final visible = _repo.visibleAnnouncements;
        final item = visible.isNotEmpty ? visible.first : AnnouncementBanner.latestAnnouncement;
        if (item == null) return const SizedBox.shrink();

        return Padding(
          padding: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.lightImpact();
                  AnnouncementBanner.showDetail(context, item);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Megaphone Icon Badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.speaker_2_fill,
                          size: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Badge Chip (e.g. "INFO", "BARU")
                      if (item.badge.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.badge.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Title
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Dismiss button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _repo.dismissAnnouncement(item.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

