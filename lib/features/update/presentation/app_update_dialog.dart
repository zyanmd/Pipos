import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../data/models/app_update_model.dart';
import '../services/app_apk_installer.dart';
import '../services/app_update_service.dart';

/// Apple iOS HIG In-App OTA Update Modal Dialog.
/// 
/// Features:
/// - One-tap in-app background download with live progress bar and speed/size tracking.
/// - Automatic resolution of direct APK asset from GitHub Releases or custom URLs.
/// - Direct native Android PackageInstaller invocation upon download completion.
/// - Permission guard for unknown app installations (Android 8.0+).
/// - Fallback to external browser if needed.
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.update,
    this.currentVersion = AppUpdateService.currentVersion,
    this.isManual = false,
  });

  final AppUpdateModel update;
  final String currentVersion;
  final bool isManual;

  static Future<void> show(
    BuildContext context, {
    required AppUpdateModel update,
    String currentVersion = AppUpdateService.currentVersion,
    bool isManual = false,
  }) {
    final isMandatory = AppUpdateService.isUpdateMandatory(
      update,
      isManual: isManual,
    );
    return showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: AppUpdateDialog(
          update: update,
          currentVersion: currentVersion,
          isManual: isManual,
        ),
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusText = '';
  String? _downloadedFilePath;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog disposed');
    super.dispose();
  }

  Future<void> _launchUpdateUrl(BuildContext context) async {
    HapticFeedback.lightImpact();
    final uri = Uri.tryParse(widget.update.updateUrl);
    if (uri != null) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Gagal membuka tautan pembaruan.'),
          ),
        );
      }
    }
  }

  Future<void> _startInAppUpdate() async {
    if (!AppApkInstaller.instance.isAndroid) {
      _launchUpdateUrl(context);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _statusText = 'Mempersiapkan installer...';
    });

    _cancelToken = CancelToken();

    try {
      // 1. Resolve direct APK URL (resolves GitHub release assets or direct URLs)
      final directApkUrl = await AppApkInstaller.instance.resolveDirectApkUrl(widget.update.updateUrl);
      if (!mounted) return;

      setState(() {
        _statusText = 'Mengunduh Moko ${widget.update.version}...';
      });

      // 2. Download APK to cache/temp directory
      final savePath = await AppApkInstaller.instance.downloadApk(
        downloadUrl: directApkUrl,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _downloadedFilePath = savePath;
        _statusText = 'Unduhan selesai! Membuka installer...';
      });

      // 3. Trigger APK install via native Android PackageInstaller
      await _triggerInstall(savePath);
    } on DioException catch (e) {
      if (!mounted) return;
      if (CancelToken.isCancel(e)) {
        setState(() {
          _isDownloading = false;
          _progress = 0.0;
          _statusText = 'Unduhan dibatalkan.';
        });
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Gagal mengunduh: ${e.message ?? "Koneksi terputus"}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    final canInstall = await AppApkInstaller.instance.canRequestPackageInstalls();
    if (!canInstall && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Izin Pembaruan Diperlukan'),
          content: const Text(
            'Untuk menginstal pembaruan Moko secara otomatis, aktifkan izin "Instal aplikasi tidak dikenal" untuk Moko di pengaturan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await AppApkInstaller.instance.openInstallPermissionSettings();
      }
      return;
    }

    final success = await AppApkInstaller.instance.installApk(filePath);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Installer tertutup atau dibatalkan. Ketuk "Pasang Sekarang" untuk mengulang.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    setState(() {
      _isDownloading = false;
      _progress = 0.0;
      _statusText = 'Unduhan dibatalkan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMandatory = AppUpdateService.isUpdateMandatory(
      widget.update,
      isManual: widget.isManual,
    );
    final isUpdateAvailable = AppUpdateService.isUpdateAvailable(widget.update);
    final isUpToDate = !isUpdateAvailable;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section with App Icon & Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: Image.asset(
                        'assets/icons/moko.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          CupertinoIcons.arrow_down_circle_fill,
                          color: isDark ? Colors.white : Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eyebrow Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isMandatory
                                  ? AppColors.iosRed.withValues(alpha: 0.15)
                                  : (isUpToDate
                                      ? AppColors.iosGreen.withValues(alpha: 0.15)
                                      : const Color(0xFF007AFF).withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMandatory
                                      ? CupertinoIcons.exclamationmark_triangle_fill
                                      : (isUpToDate
                                          ? CupertinoIcons.checkmark_seal_fill
                                          : CupertinoIcons.sparkles),
                                  size: 10,
                                  color: isMandatory
                                      ? AppColors.iosRed
                                      : (isUpToDate ? AppColors.iosGreen : const Color(0xFF007AFF)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMandatory
                                      ? 'PEMBARUAN WAJIB'
                                      : (isUpToDate
                                          ? 'VERSI TERKINI'
                                          : 'VERSI BARU TERSEDIA'),
                                  style: TextStyle(
                                    color: isMandatory
                                        ? AppColors.iosRed
                                        : (isUpToDate ? AppColors.iosGreen : const Color(0xFF007AFF)),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isUpToDate ? 'Info Versi Moko' : 'Pembaruan Moko',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isMandatory && !_isDownloading) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 15,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Version Badges Bar (Apple Inset Strip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.update.version,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (widget.update.fileSize != null && widget.update.fileSize!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.update.fileSize!,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Saat ini: ${widget.currentVersion}',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Release Notes / Changelog (Scrollable Body)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.update.releaseNotes != null && widget.update.releaseNotes!.isNotEmpty)
                        _buildFormattedText(
                          widget.update.releaseNotes!,
                          isDark,
                        )
                      else if (widget.update.changelog.isNotEmpty)
                        _buildFormattedText(
                          widget.update.changelog.first.changes,
                          isDark,
                        )
                      else
                        Text(
                          'Pembaruan baru tersedia untuk meningkatkan performa dan stabilitas aplikasi.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Action Area (Download Progress, Install Button, or Update CTA)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  children: [
                    if (_isDownloading) ...[
                      _buildDownloadingCard(isDark),
                    ] else if (_downloadedFilePath != null) ...[
                      _buildInstallReadyCard(isDark),
                    ] else if (_errorMessage != null) ...[
                      _buildErrorCard(isDark),
                    ] else if (isUpToDate) ...[
                      // If already up-to-date
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            elevation: 4,
                            shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      if (widget.update.updateUrl.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: TextButton(
                            onPressed: _startInAppUpdate,
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Unduh Ulang Installer',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Update Available - Primary In-App Update Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _startInAppUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            elevation: 4,
                            shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.arrow_down_circle_fill, size: 19),
                              SizedBox(width: 8),
                              Text(
                                'Update Sekarang',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // External link fallback
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => _launchUpdateUrl(context),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            child: Text(
                              'Buka di Browser',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (!isMandatory) ...[
                            Text(
                              '•',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              child: Text(
                                widget.isManual ? 'Tutup' : 'Nanti Saja',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isMandatory) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Pembaruan ini wajib diinstal untuk melanjutkan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadingCard(bool isDark) {
    final pct = (_progress * 100).toInt();
    final receivedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = _totalBytes > 0
        ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1)
        : (widget.update.fileSize ?? '??');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText.isNotEmpty ? _statusText : 'Mengunduh pembaruan...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$receivedMb MB / $totalMb MB',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: _cancelDownload,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    'Batalkan',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.iosRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallReadyCard(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _triggerInstall(_downloadedFilePath!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.checkmark_seal_fill, size: 20),
                SizedBox(width: 8),
                Text(
                  'Pasang Sekarang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Berkas APK telah siap. Ketuk untuk membuka installer Android.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.iosRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.iosRed.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppColors.iosRed, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Gagal mengunduh pembaruan.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.iosRed, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _launchUpdateUrl(context),
                child: const Text('Buka di Browser', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _startInAppUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Coba Lagi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return const SizedBox(height: 6);
        }

        final isHeader = trimmed.startsWith('🎬') ||
            trimmed.startsWith('🔄') ||
            trimmed.startsWith('💬') ||
            trimmed.startsWith('📱') ||
            trimmed.startsWith('🚀') ||
            trimmed.startsWith('✨') ||
            trimmed.startsWith('**') ||
            trimmed.startsWith('Fitur') ||
            trimmed.startsWith('Perbaikan');

        final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-');

        String displayText = trimmed;
        if (isBullet) {
          displayText = trimmed.replaceFirst(RegExp(r'^[•\-]\s*'), '');
        }
        displayText = displayText.replaceAll('**', '');

        if (isHeader) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          );
        }

        if (isBullet) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSecondary,
                      height: 1.35,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.35,
            ),
          ),
        );
      }).toList(),
    );
  }
}
