import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/admob_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../services/comment_theme_service.dart';

/// Apple iOS HIG Comment Background Customization Screen.
/// Allows users to pick preset styles or upload custom images/GIFs
/// to customize comment cards in the episode player, complete with live preview.
class CommentBackgroundSettingsScreen extends StatefulWidget {
  const CommentBackgroundSettingsScreen({super.key});

  @override
  State<CommentBackgroundSettingsScreen> createState() =>
      _CommentBackgroundSettingsScreenState();
}

class _CommentBackgroundSettingsScreenState
    extends State<CommentBackgroundSettingsScreen> {
  final _service = CommentThemeService.instance;
  bool _uploading = false;
  bool _saving = false;
  File? _localPreviewFile;

  @override
  void initState() {
    super.initState();
    _service.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickAndUploadMedia() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (x == null) return;

    final file = File(x.path);
    final name = x.name.isNotEmpty ? x.name : file.path.split(Platform.pathSeparator).last;
    final ext = (name.contains('.') ? name.split('.').last : file.path.split('.').last).toLowerCase();
    final allowedExts = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

    if (!allowedExts.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Format .$ext tidak didukung. Gunakan PNG, JPG, GIF, atau WebP.'),
        ),
      );
      return;
    }

    // Check file size (max 5MB as defined in routes/ylnime_routes.py)
    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Ukuran file terlalu besar! Maksimal 5MB.'),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _localPreviewFile = file;
    });

    try {
      final uploadedUrl = await _service.uploadMedia(file);
      if (!mounted) return;

      if (uploadedUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Background komentar kustom berhasil diunggah!'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Gagal mengunggah ke server. Silakan coba beberapa saat lagi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Gagal mengunggah: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _resetToDefault() async {
    HapticFeedback.selectionClick();
    await _service.reset();
    setState(() {
      _localPreviewFile = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('Background komentar telah dikembalikan ke standar.'),
      ),
    );
  }

  Future<bool> _saveToServer() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          content: Text('Silakan login terlebih dahulu untuk menyimpan background.'),
        ),
      );
      return false;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final ok = await _service.saveToServer();
    if (!mounted) return false;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.iosGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Background komentar berhasil disimpan ke database server!'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Gagal menyimpan ke server. Pastikan backend aktif dan coba lagi.'),
        ),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.username.isNotEmpty == true ? user!.username : 'Pengguna');
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: isDark ? Colors.white : Colors.black,
            size: 26,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Background Komentar',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _saveToServer,
              icon: _saving
                  ? const CupertinoActivityIndicator()
                  : Icon(CupertinoIcons.cloud_upload_fill, size: 16, color: isDark ? Colors.white : Colors.black),
              label: Text(
                _saving ? '...' : 'Simpan',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Interactive Preview Section
                _buildSectionHeader('PRATINJAU LANGSUNG', isDark),
                _buildLivePreviewCard(isDark, displayName, avatarUrl, decorationUrl: user?.fullAvatarDecorationUrl),
                const SizedBox(height: 24),

                // Preset Theme Cards
                _buildSectionHeader('PILIH TEMA PRESET', isDark),
                _buildPresetSelector(isDark),
                const SizedBox(height: 24),

                // Custom Media Background (Upload Image / GIF)
                _buildSectionHeader('BACKGROUND KUSTOM (MEDIA)', isDark),
                _buildCustomMediaCard(isDark),
                const SizedBox(height: 24),

                // Transparency & Readability Controls
                _buildSectionHeader('PENGATURAN TAMPILAN', isDark),
                _buildSettingsCard(isDark),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            AdMobService.instance.showRewardedAd(
                              onRewardEarned: () async {
                                if (!mounted) return;
                                final ok = await _saveToServer();
                                if (ok && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 4,
                      shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.cloud_upload_fill, size: 19),
                              const SizedBox(width: 8),
                              Text(
                                'Terapkan & Simpan ke Server',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // AdMob Banner
                const SizedBox(height: 20),
                const AdBannerWidget(
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  /// Reliable user avatar with custom URL, decoration frame, and letter placeholder
  Widget _buildUserAvatar(
    String? avatarUrl,
    String displayName, {
    double radius = 14,
    String? decorationUrl,
  }) {
    return DecoratedAvatar(
      radius: radius,
      avatarUrl: avatarUrl,
      decorationUrl: decorationUrl,
      decorationScale: 1.0,
      fallbackName: displayName,
    );
  }

  /// Interactive Live Preview of Comment Card
  Widget _buildLivePreviewCard(
    bool isDark,
    String displayName,
    String? avatarUrl, {
    String? decorationUrl,
  }) {
    final decoration = _service.getCardDecoration(
      isDark: isDark,
      isOwner: true,
    );

    final mediaUrl = _localPreviewFile != null
        ? null
        : _service.currentCardMediaUrl;
    final hasMediaBg = _localPreviewFile != null || mediaUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.eye_fill,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Tampilan di episode player:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const Spacer(),
              if (_service.hasGifBackground)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFFFF375F)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.animation_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'GIF CARD AKTIF',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Actual comment card simulation with background decoration
          Container(
            decoration: decoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5),
              child: Stack(
                children: [
                  // Active Image / GIF Background
                  if (hasMediaBg)
                    Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_localPreviewFile != null)
                            Image.file(
                              _localPreviewFile!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          else if (mediaUrl != null)
                            (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://'))
                                ? Image.network(
                                    mediaUrl,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                    ),
                                  )
                                : Image.file(
                                    File(mediaUrl),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                    ),
                                  ),
                          CalmGif(
                            source: _localPreviewFile?.path ?? mediaUrl!,
                            fit: BoxFit.cover,
                            speed: _service.animSpeed,
                          ),
                          // Darkening overlay for text readability
                          Container(
                            color: Colors.black.withValues(
                              alpha: _service.overlayOpacity,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Card Container content
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: hasMediaBg ? null : decoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Row
                      Row(
                        children: [
                          _buildUserAvatar(avatarUrl, displayName, radius: 15, decorationUrl: decorationUrl),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'VIP',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Baru saja',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.heart,
                            size: 15,
                            color: Colors.white60,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Sample comment text
                      Text(
                        'Episode ini grafisnya gila banget! Pertarungannya sangat epik dan animasi 60fps-nya mulus 🔥',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: isDark ? Colors.white.withValues(alpha: 0.95) : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sample media attachment preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.photo_fill, size: 12, color: Colors.white70),
                            SizedBox(width: 5),
                            Text(
                              'Media Komentar Terlampir (GIF/Gambar)',
                              style: TextStyle(fontSize: 10.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  /// Preset Cards Selector
  Widget _buildPresetSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: CommentThemeService.presets.map((preset) {
          final isSelected = _service.selectedPresetId == preset.id;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _service.setPreset(preset.id);
                setState(() => _localPreviewFile = null);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Preset gradient swatch icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: preset.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: preset.borderColor.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(preset.icon, size: 17, color: preset.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                preset.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (preset.isAnimated) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: preset.accentColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: preset.accentColor.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'GIF',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: preset.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Custom Media Upload Card
  Widget _buildCustomMediaCard(bool isDark) {
    final isCustomSelected = _service.isCustom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCustomSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isCustomSelected ? 1.0 : 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  CupertinoIcons.photo_on_rectangle,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unggah Foto atau Animasi GIF',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Format: PNG, JPG, GIF, WebP (Maksimal 5MB)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const CupertinoActivityIndicator()
              else if (isCustomSelected)
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _pickAndUploadMedia,
              icon: const Icon(CupertinoIcons.cloud_upload_fill, size: 16),
              label: Text(_uploading ? 'Mengunggah ke Server...' : 'Pilih Gambar / GIF dari Galeri'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.black26, width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (isCustomSelected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aktif: ${_service.customMediaType.toUpperCase()} background',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _service.setPreset('default');
                    setState(() => _localPreviewFile = null);
                  },
                  child: const Text(
                    'Hapus Media',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Transparency & Settings
  Widget _buildSettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GIF Card Animation Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Animasi GIF Card',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Putar animasi GIF di latar belakang kartu komentar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _service.enableGifCard,
                activeTrackColor: isDark ? Colors.white : Colors.black,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  _service.setEnableGifCard(val);
                },
              ),
            ],
          ),
          if (_service.enableGifCard) ...[
            const SizedBox(height: 12),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kecepatan Gerakan GIF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atur tempo animasi agar tenang dan nyaman dilihat',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<double>(
                groupValue: _service.animSpeed <= 0.55
                    ? 0.50
                    : (_service.animSpeed <= 0.85 ? 0.70 : 1.00),
                children: {
                  0.50: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Tenang (0.5x)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  0.70: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Normal (0.7x)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  1.00: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Asli (1.0x)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                },
                onValueChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    _service.setAnimSpeed(val);
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          const SizedBox(height: 12),

          // Darkening Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tingkat Kegelapan Latar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                '${(_service.overlayOpacity * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Gelapkan latar agar teks komentar tetap terbaca jelas',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          CupertinoSlider(
            value: _service.overlayOpacity,
            min: 0.10,
            max: 0.85,
            activeColor: isDark ? Colors.white : Colors.black,
            onChanged: (val) {
              _service.setOverlayOpacity(val);
            },
          ),
          const SizedBox(height: 12),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          const SizedBox(height: 12),

          // Border Glow Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Glow & Border Kartu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tampilkan border halus dengan warna aksen tema',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _service.borderGlow,
                activeTrackColor: isDark ? Colors.white : Colors.black,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  _service.setBorderGlow(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          const SizedBox(height: 12),

          // Apply to all comments indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terapkan ke Semua Komentar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gaya latar belakang aktif otomatis ke seluruh komentar di pemutar episode',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.iosGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.iosGreen.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_alt, size: 14, color: AppColors.iosGreen),
                    SizedBox(width: 4),
                    Text(
                      'Semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.iosGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
