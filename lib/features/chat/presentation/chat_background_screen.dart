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
import '../services/chat_theme_service.dart';

class ChatBackgroundScreen extends StatefulWidget {
  const ChatBackgroundScreen({super.key});

  @override
  State<ChatBackgroundScreen> createState() => _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends State<ChatBackgroundScreen> {
  final _service = ChatThemeService.instance;
  bool _uploading = false;
  bool _saving = false;
  File? _localPreviewFile;

  static const List<Map<String, String>> _textColorOptions = [
    {'name': 'Putih', 'hex': '#FFFFFF'},
    {'name': 'Biru Es', 'hex': '#E0F2FE'},
    {'name': 'Pink Sakura', 'hex': '#FFE4E6'},
    {'name': 'Neon Cyan', 'hex': '#00F5D4'},
    {'name': 'Emas Kuning', 'hex': '#FFD700'},
    {'name': 'Hijau Mint', 'hex': '#DCFCE7'},
    {'name': 'Ungu Pastel', 'hex': '#F3E8FF'},
  ];

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
    // Do not pass imageQuality to preserve animated GIF frames
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
          content: Text('Format .$ext tidak didukung. Gunakan PNG, JPG, GIF, atau WebP.'),
        ),
      );
      return;
    }

    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ukuran file terlalu besar! Maksimal 5MB.'),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _localPreviewFile = file;
    });

    try {
      final uploadedUrl = await _service.uploadCustomBackground(file);
      if (!mounted) return;

      setState(() => _localPreviewFile = null);
      if (uploadedUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.iosGreen,
            behavior: SnackBarBehavior.floating,
            content: const Text('Background chat berhasil diunggah dan disimpan ke server!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal mengunggah ke server. Pastikan backend aktif dan coba lagi.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Gagal mengunggah: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveToServer() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          content: Text('Silakan login terlebih dahulu untuk menyimpan background.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final ok = await _service.saveToServer();
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.iosGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Background chat berhasil disimpan ke database server!'),
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
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final displayName = user?.displayName ?? user?.username ?? 'Saya';
    final avatarUrl = user?.avatarUrl;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final activeBg = _localPreviewFile?.path ?? _service.activeBackgroundUrl;
        final hasActiveBg = activeBg != null && activeBg.isNotEmpty;
        final currentTextHex = _service.activeTextColor;
        final effectiveTextColor = hasActiveBg ? _parseHex(currentTextHex, Colors.white) : (isDark ? Colors.black : Colors.white);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.back,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Background Chat Khusus',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _service.reset();
                  setState(() => _localPreviewFile = null);
                },
                child: const Text('Reset', style: TextStyle(color: Colors.grey)),
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
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Live Preview Bubble
              Text(
                'PRATINJAU GELEMBUNG CHAT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: hasActiveBg
                                  ? Colors.transparent
                                  : (isDark ? Colors.white : Colors.black),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(4),
                              ),
                              border: Border.all(
                                color: hasActiveBg
                                    ? _service.currentPreset.borderColor.withValues(alpha: 0.6)
                                    : (isDark ? Colors.white : Colors.black),
                                width: 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15.5),
                                topRight: Radius.circular(15.5),
                                bottomLeft: Radius.circular(15.5),
                                bottomRight: Radius.circular(3.5),
                              ),
                              child: Stack(
                                children: [
                                  // Background layer
                                  if (hasActiveBg)
                                    Positioned.fill(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CalmGif(
                                            source: activeBg,
                                            fit: BoxFit.cover,
                                            speed: _service.animSpeed,
                                          ),
                                          Container(
                                            color: Colors.black.withValues(alpha: 0.35),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Content
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: effectiveTextColor.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Halo semuanya! Ini tampilan bubble chat khusus dengan background pilihan saya ✨',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            color: effectiveTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              '14:20',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: effectiveTextColor.withValues(alpha: 0.65),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(
                                              CupertinoIcons.checkmark_alt,
                                              size: 11,
                                              color: effectiveTextColor.withValues(alpha: 0.75),
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
                        const SizedBox(width: 8),
                        // Avatar with decoration frame
                        DecoratedAvatar(
                          radius: 14,
                          avatarUrl: avatarUrl,
                          decorationUrl: user?.fullAvatarDecorationUrl,
                          decorationScale: 1.0,
                          fallbackName: displayName,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Upload Custom Image/GIF
              Text(
                'UNGGAH BACKGROUND SENDIRI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _service.isCustom
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: _service.isCustom ? 1.2 : 0.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(CupertinoIcons.photo_on_rectangle, color: isDark ? Colors.white : Colors.black, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto atau Animasi GIF Kustom',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                'Format PNG, JPG, GIF, WebP (Maksimal 5MB)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_uploading) const CupertinoActivityIndicator(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickAndUploadMedia,
                        icon: const Icon(CupertinoIcons.cloud_upload_fill, size: 16),
                        label: Text(_uploading ? 'Mengunggah...' : 'Pilih Gambar / GIF dari Galeri'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black26, width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Preset Designs
              Text(
                'TEMA PRESET BERGERAK (GIF)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: ChatThemeService.presets.map((preset) {
                    final isSelected = !_service.isCustom && _service.selectedPresetId == preset.id;
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
                                  border: Border.all(color: preset.borderColor.withValues(alpha: 0.8)),
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        if (preset.isAnimated) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: preset.accentColor.withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              'GIF',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: preset.accentColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      preset.description,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(CupertinoIcons.checkmark_circle_fill, color: isDark ? Colors.white : Colors.black, size: 20)
                              else
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Custom Text Color
              Text(
                'WARNA TEKS CHAT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.5,
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _textColorOptions.map((opt) {
                    final hex = opt['hex']!;
                    final color = _parseHex(hex, Colors.white);
                    final isSel = (currentTextHex?.toUpperCase() == hex.toUpperCase()) ||
                        (currentTextHex == null && hex == '#FFFFFF');

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _service.setTextColor(hex);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              opt['name']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // 5. Animation Speed
              Text(
                'KECEPATAN GERAKAN GIF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atur kelambatan animasi agar tenang dan tidak terburu-buru',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
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
                ),
              ),

              // AdMob Banner
              const SizedBox(height: 24),
              const AdBannerWidget(
                adUnitId: AdMobService.chatBannerUnitId,
                margin: EdgeInsets.zero,
              ),

              const SizedBox(height: 36),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveToServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 4,
                    shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: _saving
                      ? CupertinoActivityIndicator(color: isDark ? Colors.black : Colors.white)
                      : Icon(CupertinoIcons.cloud_upload_fill, size: 19, color: isDark ? Colors.black : Colors.white),
                  label: Text(
                    _saving ? 'Menyimpan ke Database...' : 'Simpan Background ke Akun',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.black : Colors.white,
                    ),
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

