import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_anime_service.dart';
import '../../features/anime/presentation/anime_detail_screen.dart';
import '../../features/comic/presentation/comic_detail_screen.dart';
import '../../features/novel/presentation/novel_detail_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../core/services/adult_content_service.dart';
import '../../features/avatar_decoration/data/models/avatar_decoration_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/decorated_avatar.dart';
import '../providers/auth_provider.dart';
import '../widgets/poster_card.dart';

class MokoAiUniversalModal extends StatefulWidget {
  final String? initialPrompt;
  const MokoAiUniversalModal({super.key, this.initialPrompt});

  static Future<void> show(BuildContext context, {String? initialPrompt}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MokoAiUniversalModal(initialPrompt: initialPrompt),
    );
  }

  @override
  State<MokoAiUniversalModal> createState() => _MokoAiUniversalModalState();
}

class _MokoAiUniversalModalState extends State<MokoAiUniversalModal> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;
  String? _error;
  AiUniversalResult? _latestResult;

  // State untuk unggah foto / gambar
  Uint8List? _selectedImageBytes;
  String? _selectedImageBase64;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      _inputCtrl.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitCommand(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageBase64 = b64;
      _selectedImageName = picked.name;
    });
  }

  Future<void> _submitCommand([String? text]) async {
    final q = (text ?? _inputCtrl.text).trim();
    if (q.isEmpty && _selectedImageBase64 == null) return;

    if (text != null) {
      _inputCtrl.text = text;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    final imgToSend = _selectedImageBase64;

    try {
      final res = await AiAnimeService.instance.processUniversalCommand(
        q,
        imageBase64: imgToSend,
      );
      if (!mounted) return;
      setState(() {
        _latestResult = res;
        _loading = false;
        _selectedImageBytes = null;
        _selectedImageBase64 = null;
        _selectedImageName = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memproses permintaan AI: $e';
        _loading = false;
      });
    }
  }

  Future<void> _equipFrame(AiFrameRecommendation item) async {
    HapticFeedback.heavyImpact();
    final ok = await AiAnimeService.instance.equipFrame(
      item.decoration.code,
      name: item.decoration.name,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bingkai "${item.decoration.name}" berhasil dipasang ke avatarmu!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memasang bingkai.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _applyName(AiNameSuggestion item) async {
    HapticFeedback.heavyImpact();
    final updated = await AiAnimeService.instance.updateProfileName(
      displayName: item.name,
      bio: item.bio,
    );
    if (!mounted) return;
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama profil berhasil diubah jadi "${item.name}"!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui profil. Pastikan kamu sudah login.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _applyUsername(String username) async {
    HapticFeedback.heavyImpact();
    final updated = await AiAnimeService.instance.updateProfileUsername(username);
    if (!mounted) return;
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username berhasil diubah menjadi @${updated.username}! ✨'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengubah username. Coba username lain.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _applyAllChanges(AiProfileChanges changes) async {
    HapticFeedback.heavyImpact();
    final res = await AiAnimeService.instance.applyProfileChanges(
      username: changes.username,
      displayName: changes.displayName,
      bio: changes.bio,
      frameCode: changes.frameCode,
      frameName: changes.frameName,
      profileFont: changes.profileFont,
      theme: changes.theme,
      is18Enabled: changes.is18Enabled,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _applyFont(String font) async {
    HapticFeedback.mediumImpact();
    try {
      final user = await ProfileRepository.instance.setProfileFont(font: font);
      AuthProvider.instance.setUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Font profil berhasil diubah jadi "$font"!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  Future<void> _applyTheme(String theme) async {
    HapticFeedback.mediumImpact();
    final lower = theme.toLowerCase();
    if (lower.contains('dark') || lower.contains('gelap') || lower.contains('hitam')) {
      await ThemeProvider.instance.setMode(ThemeModeOption.dark);
    } else if (lower.contains('light') || lower.contains('terang') || lower.contains('putih')) {
      await ThemeProvider.instance.setMode(ThemeModeOption.light);
    } else {
      await ThemeProvider.instance.setMode(ThemeModeOption.system);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tema aplikasi berhasil disesuaikan ($theme)!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final safeBottom = mq.padding.bottom;
    final screenH = mq.size.height;

    // Available height considering keyboard when open
    final maxAllowedH = bottomInset > 0
        ? (screenH - bottomInset - 40)
        : (screenH * 0.88);

    // Bottom padding: when keyboard is down, respect navigation bar + breathing space.
    // When keyboard is up, just add clean spacing above keyboard.
    final effectiveBottomPad = bottomInset > 0
        ? 12.0
        : (safeBottom > 0 ? safeBottom + 16 : 22.0);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxAllowedH,
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottomPad),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13131A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
        children: [
          // Drag handle
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
          const SizedBox(height: 12),

          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moko AI Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Asisten Cerdas • Ubah Nama, Bingkai & Cari Konten',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.clear),
                iconSize: 18,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Action Shortcut Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickActionPill(
                  icon: CupertinoIcons.wand_stars_inverse,
                  label: 'Ganti Semuanya',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _submitCommand('Ganti semuanya: buatkan username wibu keren, nama tampilan, bio, dan pasang bingkai paling epik!'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.at_badge_plus,
                  label: 'Ganti Username',
                  color: const Color(0xFF3B82F6),
                  onTap: () => _submitCommand('Saran username wibu keren dan ganti username saya'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.sparkles,
                  label: 'Pilih Bingkai Keren',
                  color: const Color(0xFFA855F7),
                  onTap: () => _submitCommand('Pilihkan bingkai avatar paling keren dan pasang sendiri'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.person_badge_plus_fill,
                  label: 'Ubah Nama Keren',
                  color: const Color(0xFF6366F1),
                  onTap: () => _submitCommand('Saran nama wibu keren dan ganti nama saya'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.play_circle_fill,
                  label: 'Cari Anime',
                  color: const Color(0xFFEC4899),
                  onTap: () => _submitCommand('Rekomendasi anime overpower terbaru yang seru'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.book_fill,
                  label: 'Cari Komik/Manga',
                  color: const Color(0xFF10B981),
                  onTap: () => _submitCommand('Rekomendasi manhwa hunter dungeon mirip solo leveling'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionPill(
                  icon: CupertinoIcons.book_circle_fill,
                  label: 'Cari Novel',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _submitCommand('Rekomendasi light novel atau web novel isekai terbaik'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Content View (Results or Skeleton)
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Moko AI sedang memproses...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Menganalisis katalog, tema, dan menyesuaikan preferensimu',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _latestResult != null
                        ? _buildResultContent(_latestResult!, isDark)
                        : _buildWelcomeContent(isDark),
          ),
          const SizedBox(height: 10),

          // Image Attachment Preview Chip
          if (_selectedImageBytes != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232336) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedImageName ?? 'Foto terlampir',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Moko AI akan menganalisis foto ini',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImageBytes = null;
                        _selectedImageBase64 = null;
                        _selectedImageName = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Command Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0xFF32324A) : const Color(0xFFE5E7EB),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _selectedImageBytes != null
                          ? const Color(0xFFA855F7).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.photo_camera,
                      size: 20,
                      color: _selectedImageBytes != null
                          ? const Color(0xFFA855F7)
                          : (isDark ? Colors.white60 : Colors.black45),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    onSubmitted: (val) => _submitCommand(),
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: _selectedImageBytes != null
                          ? 'Tanya sesuatu tentang foto ini (atau langsung kirim)...'
                          : 'Suruh Moko AI (mis: "Pilih bingkai", "Ubah nama", ...)',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _submitCommand();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 15),
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

  Widget _buildQuickActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12.5, color: color),
              const SizedBox(width: 5.5),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeContent(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF6366F1).withValues(alpha: 0.22),
                      const Color(0xFFA855F7).withValues(alpha: 0.14),
                    ]
                  : [
                      const Color(0xFFEEF2FF),
                      const Color(0xFFFAF5FF),
                    ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                'Halo! Apa yang ingin kamu perbarui hari ini?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Moko AI siap membantumu menyesuaikan profil dan mencari konten favorit secara otomatis. Tulis perintah atau pilih aksi cepat:',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem(CupertinoIcons.wand_stars_inverse, 'Ganti Semuanya: nama, bio, dan bingkai sekaligus', isDark),
                    _buildFeatureItem(CupertinoIcons.sparkles, 'Pilihkan bingkai avatar paling keren dan pasang otomatis', isDark),
                    _buildFeatureItem(CupertinoIcons.person_badge_plus_fill, 'Ubah nama tampilan dan bio wibu keren', isDark),
                    _buildFeatureItem(CupertinoIcons.play_circle_fill, 'Cari anime, komik, atau novel sesuai selera', isDark),
                    _buildFeatureItem(CupertinoIcons.camera_fill, 'Upload foto/screenshot untuk dicari langsung oleh AI', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFA855F7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.8,
                height: 1.35,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(AiUniversalResult res, bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Explanation Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.sparkles, size: 15, color: Color(0xFFA855F7)),
                    const SizedBox(width: 6),
                    Text(
                      'Balasan Moko AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6B21A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                res.explanation,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 0. Kustomisasi Profil Lengkap & Ganti Semuanya
        if (res.profileChanges != null && res.profileChanges!.hasAnyChange) ...[
          _buildProfileCustomizerCard(res.profileChanges!, isDark),
          const SizedBox(height: 14),
        ],

        // 1. Tampilan Hasil Bingkai Avatar
        if (res.frameList.isNotEmpty) ...[
          Text(
            'Pilihan Bingkai Avatar Keren (${res.frameList.length}):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ...res.frameList.map((item) {
            final auth = context.read<AuthProvider>();
            final myUser = auth.user;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A28) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C40) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  // Live Avatar Preview with Decoration
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Center(
                      child: DecoratedAvatar(
                        avatarUrl: myUser?.avatarUrl,
                        decorationUrl: item.decoration.fullImageUrl,
                        fallbackName: myUser?.displayName ?? myUser?.username ?? 'U',
                        radius: 20,
                        decorationScale: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.decoration.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.reason,
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _equipFrame(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Pasang'),
                  ),
                ],
              ),
            );
          }),
        ],

        // 2. Tampilan Hasil Ubah Nama Profil
        if (res.nameList.isNotEmpty) ...[
          Text(
            'Saran Nama & Bio Keren (${res.nameList.length}):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ...res.nameList.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A28) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          item.theme,
                          style: const TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _applyName(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Pakai Nama Ini'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${item.bio}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // 3. Tampilan Hasil Anime
        if (res.animeList.isNotEmpty) ...[
          Text(
            'Anime Rekomendasi (${res.animeList.length}):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: res.animeList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final a = res.animeList[i];
                return SizedBox(
                  width: 125,
                  child: PosterCard(
                    title: a.title,
                    imageUrl: a.thumb,
                    subtitle: a.episode != null && a.episode!.isNotEmpty ? 'Ep ${a.episode}' : a.status,
                    badge: a.score != null ? '★ ${a.score}' : null,
                    width: 125,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => AnimeDetailScreen(animeId: a.id, anime: a),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],

        // 4. Tampilan Hasil Komik
        if (res.comicList.isNotEmpty) ...[
          Text(
            'Komik / Manga Rekomendasi (${res.comicList.length}):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: res.comicList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final c = res.comicList[i];
                return SizedBox(
                  width: 125,
                  child: PosterCard(
                    title: c.title,
                    imageUrl: c.thumb,
                    subtitle: c.type ?? 'Manga',
                    badge: c.rating != null ? '★ ${c.rating}' : null,
                    width: 125,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => ComicDetailScreen(slug: c.slug, comic: c),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],

        // 5. Tampilan Hasil Novel
        if (res.novelList.isNotEmpty) ...[
          Text(
            'Light Novel Rekomendasi (${res.novelList.length}):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: res.novelList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final n = res.novelList[i];
                return SizedBox(
                  width: 125,
                  child: PosterCard(
                    title: n.title,
                    imageUrl: n.effectivePosterUrl,
                    subtitle: n.status,
                    badge: '★ ${n.rating}',
                    width: 125,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => NovelDetailScreen(
                            slug: n.slug,
                            initialTitle: n.title,
                            initialPoster: n.effectivePosterUrl,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileCustomizerCard(AiProfileChanges changes, bool isDark) {
    final auth = context.read<AuthProvider>();
    final myUser = auth.user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B2A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kustomisasi Profil AI',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Rancangan kustomisasi otomatis dari Moko AI',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tombol Besar Ganti Semuanya
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _applyAllChanges(changes),
                borderRadius: BorderRadius.circular(22),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.wand_stars_inverse, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Terapkan Semua Perubahan (Ganti Semuanya)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Detail per Item
          // 1. Username
          if (changes.username != null && changes.username!.isNotEmpty) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.at,
              label: 'Username (@)',
              value: '@${changes.username}',
              actionLabel: 'Ganti Username',
              color: const Color(0xFF3B82F6),
              onTap: () => _applyUsername(changes.username!),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // 2. Display Name
          if (changes.displayName != null && changes.displayName!.isNotEmpty) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.person_badge_plus,
              label: 'Nama Tampilan',
              value: changes.displayName!,
              actionLabel: 'Ganti Nama',
              color: const Color(0xFF6366F1),
              onTap: () => _applyName(
                AiNameSuggestion(
                  name: changes.displayName!,
                  bio: changes.bio ?? '',
                  theme: 'AI Choice',
                  reason: '',
                ),
              ),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // 3. Bio
          if (changes.bio != null && changes.bio!.isNotEmpty) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.pencil,
              label: 'Bio Profil',
              value: '"${changes.bio}"',
              actionLabel: 'Ganti Bio',
              color: const Color(0xFF10B981),
              onTap: () => _applyName(
                AiNameSuggestion(
                  name: changes.displayName ?? myUser?.displayName ?? myUser?.username ?? 'User',
                  bio: changes.bio!,
                  theme: 'AI Choice',
                  reason: '',
                ),
              ),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // 4. Bingkai Avatar
          if (changes.frameCode != null && changes.frameCode!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232338) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF33334D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: DecoratedAvatar(
                        avatarUrl: myUser?.avatarUrl,
                        decorationUrl: 'https://discord-decoration.art/decorations/${changes.frameCode}.png',
                        fallbackName: myUser?.displayName ?? myUser?.username ?? 'U',
                        radius: 15,
                        decorationScale: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bingkai: ${changes.frameName ?? changes.frameCode}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Akan langsung dipasang ke profilmu',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _equipFrame(
                      AiFrameRecommendation(
                        decoration: AvatarDecorationModel(
                          id: 0,
                          code: changes.frameCode!,
                          name: changes.frameName ?? changes.frameCode!,
                          category: 'anime',
                          imageUrl: 'https://discord-decoration.art/decorations/${changes.frameCode}.png',
                          thumbnailUrl: 'https://discord-decoration.art/decorations/${changes.frameCode}.png',
                          isActive: true,
                          isOwned: true,
                        ),
                        reason: '',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Pasang'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 5. Font Profil
          if (changes.profileFont != null && changes.profileFont!.isNotEmpty) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.textformat,
              label: 'Font Profil',
              value: changes.profileFont!,
              actionLabel: 'Terapkan Font',
              color: const Color(0xFFEC4899),
              onTap: () => _applyFont(changes.profileFont!),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // 6. Tema
          if (changes.theme != null && changes.theme!.isNotEmpty) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.circle_righthalf_fill,
              label: 'Tema Tampilan',
              value: changes.theme!.toLowerCase().contains('dark') ? 'Mode Gelap' : 'Mode Terang',
              actionLabel: 'Ubah Tema',
              color: const Color(0xFFF59E0B),
              onTap: () => _applyTheme(changes.theme!),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // 7. Konten 18+
          if (changes.is18Enabled != null) ...[
            _buildCustomizerRow(
              icon: CupertinoIcons.eye_fill,
              label: 'Konten Dewasa 18+',
              value: changes.is18Enabled! ? 'Diaktifkan' : 'Dinonaktifkan',
              actionLabel: 'Terapkan',
              color: const Color(0xFFEF4444),
              onTap: () async {
                await AdultContentService.instance.setHiddenFeature(changes.is18Enabled!);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mode 18+ telah ${changes.is18Enabled! ? 'diaktifkan' : 'dinonaktifkan'}!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomizerRow({
    required IconData icon,
    required String label,
    required String value,
    required String actionLabel,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232338) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF33334D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

