import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/smooth_entrance_transition.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../data/profile_repository.dart';
import 'profile_font_picker_modal.dart';
import '../../../shared/widgets/app_image_crop_screen.dart';
import '../../../shared/widgets/smooth_avatar_decoration.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});
  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;
  final _repo = ProfileRepository.instance;
  bool _saving = false;
  File? _avatarFile;
  File? _coverFile;
  bool _removeAvatar = false;
  bool _removeCover = false;
  DateTime? _birthday;
  String _birthdayVisibility = 'public';

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.user.displayName ?? widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _emailCtrl = TextEditingController(text: widget.user.email);
    _userCtrl = TextEditingController(text: '@${widget.user.username}');
    _locationCtrl = TextEditingController(text: widget.user.location ?? '');
    _websiteCtrl = TextEditingController(text: widget.user.website ?? '');
    if (widget.user.tanggalLahir != null && widget.user.tanggalLahir!.trim().isNotEmpty) {
      try {
        _birthday = DateTime.tryParse(widget.user.tanggalLahir!.trim());
      } catch (_) {}
    }
    final vis = widget.user.birthdayVisibility;
    if (vis != null && const {'public', 'age_only', 'private'}.contains(vis)) {
      _birthdayVisibility = vis;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final file = File(x.path);
    final ext = x.path.split('.').last.toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Format tidak didukung. Gunakan PNG, JPG, GIF, atau WEBP.'),
          ),
        );
      }
      return;
    }
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran file avatar maksimal 5MB'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (ext == 'gif') {
      final choice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Format Animasi GIF'),
          message: const Text('Ingin mempertahankan animasi GIF penuh atau memotong frame gambar?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Pertahankan Animasi Penuh (GIF)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'crop'),
              child: const Text('Potong (Crop) Foto'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ),
      );
      if (choice == null) return;
      if (choice == 'keep') {
        setState(() {
          _avatarFile = file;
          _removeAvatar = false;
        });
        return;
      }
    }

    if (!mounted) return;
    final cropped = await AppImageCropScreen.open(
      context: context,
      imageFile: file,
      cropType: CropType.avatar,
    );
    if (cropped != null && mounted) {
      setState(() {
        _avatarFile = cropped;
        _removeAvatar = false;
      });
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final file = File(x.path);
    final ext = x.path.split('.').last.toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Format tidak didukung. Gunakan PNG, JPG, GIF, atau WEBP.'),
          ),
        );
      }
      return;
    }
    if (await file.length() > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran file cover maksimal 10MB'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (ext == 'gif') {
      final choice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Format Animasi GIF'),
          message: const Text('Ingin mempertahankan animasi GIF penuh atau memotong frame gambar?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Pertahankan Animasi Penuh (GIF)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'crop'),
              child: const Text('Potong (Crop) Sampul'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ),
      );
      if (choice == null) return;
      if (choice == 'keep') {
        setState(() {
          _coverFile = file;
          _removeCover = false;
        });
        return;
      }
    }

    if (!mounted) return;
    final cropped = await AppImageCropScreen.open(
      context: context,
      imageFile: file,
      cropType: CropType.cover,
    );
    if (cropped != null && mounted) {
      setState(() {
        _coverFile = cropped;
        _removeCover = false;
      });
    }
  }

  void _onTapAvatar() {
    final hasCustomAvatar = _avatarFile != null ||
        (widget.user.avatarUrl != null &&
            !widget.user.avatarUrl!.contains('default-avatar'));

    if (!hasCustomAvatar) {
      _pickAvatar();
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Foto Profil'),
        actions: [
          if (_avatarFile != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                final cropped = await AppImageCropScreen.open(
                  context: context,
                  imageFile: _avatarFile!,
                  cropType: CropType.avatar,
                );
                if (cropped != null && mounted) {
                  setState(() {
                    _avatarFile = cropped;
                    _removeAvatar = false;
                  });
                }
              },
              child: const Text('Potong / Atur Ulang Foto Ini'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAvatar();
            },
            child: const Text('Pilih Foto Baru dari Galeri'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _avatarFile = null;
                _removeAvatar = true;
              });
            },
            child: const Text('Hapus Foto (Gunakan Bawaan)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _onTapCover() {
    final hasCustomCover = _coverFile != null ||
        (widget.user.coverUrl != null &&
            !widget.user.coverUrl!.contains('default-cover'));

    if (!hasCustomCover) {
      _pickCover();
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Foto Sampul'),
        actions: [
          if (_coverFile != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                final cropped = await AppImageCropScreen.open(
                  context: context,
                  imageFile: _coverFile!,
                  cropType: CropType.cover,
                );
                if (cropped != null && mounted) {
                  setState(() {
                    _coverFile = cropped;
                    _removeCover = false;
                  });
                }
              },
              child: const Text('Potong / Atur Ulang Sampul Ini'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickCover();
            },
            child: const Text('Pilih Sampul Baru dari Galeri'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _coverFile = null;
                _removeCover = true;
              });
            },
            child: const Text('Hapus Sampul (Gunakan Bawaan)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      UserModel updated = widget.user;

      // Handle avatar changes
      if (_removeAvatar) {
        updated = await _repo.deleteAvatar(widget.user.username);
      } else if (_avatarFile != null) {
        updated = await _repo.uploadAvatar(widget.user.username, _avatarFile!);
      }

      // Handle cover changes
      if (_removeCover) {
        updated = await _repo.deleteCover(widget.user.username);
      } else if (_coverFile != null) {
        updated = await _repo.uploadCover(widget.user.username, _coverFile!);
      }

      // Remember fresh avatar and cover before updating text fields
      final latestAvatar = updated.avatarUrl;
      final latestCover = updated.coverUrl;

      // Update text profile
      final rawUsername = _userCtrl.text.trim().replaceAll('@', '');
      final cleanUsername = rawUsername.toLowerCase().replaceAll(' ', '_');
      final usernameChanged = cleanUsername.isNotEmpty && cleanUsername != widget.user.username.toLowerCase();

      if (usernameChanged && !RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(cleanUsername)) {
        throw Exception('Username hanya boleh berisi huruf, angka, titik, atau garis bawah.');
      }

      final name = _nameCtrl.text.trim();
      final bio = _bioCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final location = _locationCtrl.text.trim();
      final website = _websiteCtrl.text.trim();
      final currentDobStr = _birthday != null
          ? "${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}"
          : (_birthday == null && widget.user.tanggalLahir != null ? '' : null);
      final originalDobStr = widget.user.tanggalLahir;
      final dobChanged = currentDobStr != null && currentDobStr != (originalDobStr ?? '');
      final originalVis = widget.user.birthdayVisibility ?? 'public';
      final visChanged = _birthdayVisibility != originalVis;

      final textChanged = usernameChanged ||
          name != (widget.user.displayName ?? '') ||
          bio != (widget.user.bio ?? '') ||
          email != widget.user.email ||
          location != (widget.user.location ?? '') ||
          website != (widget.user.website ?? '') ||
          dobChanged ||
          visChanged;

      if (textChanged) {
        if (visChanged) {
          try {
            await _repo.setBirthdayVisibility(_birthdayVisibility);
          } catch (_) {}
        }
        final textUpdated = await _repo.updateProfile(
          username: usernameChanged ? cleanUsername : null,
          displayName: name.isNotEmpty ? name : null,
          bio: bio,
          email: email.isNotEmpty ? email : null,
          location: location.isNotEmpty ? location : null,
          website: website.isNotEmpty ? website : null,
          tanggalLahir: dobChanged ? currentDobStr : null,
          birthdayVisibility: visChanged ? _birthdayVisibility : null,
        );
        updated = textUpdated.copyWith(
          username: usernameChanged ? cleanUsername : textUpdated.username,
          birthdayVisibility: _birthdayVisibility,
        );
      }

      // Preserve newly uploaded avatar or cover if uploaded in this session
      if (latestAvatar != null) {
        updated = updated.copyWith(avatarUrl: latestAvatar);
      }
      if (latestCover != null) {
        updated = updated.copyWith(coverUrl: latestCover);
      }

      // Evict stale cached images so Flutter immediately paints the new avatar
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      context.read<AuthProvider>().setUser(updated);
      final fresh = await context.read<AuthProvider>().refreshUser();
      if (fresh != null && visChanged && fresh.birthdayVisibility != _birthdayVisibility) {
        if (mounted) {
          context.read<AuthProvider>().setUser(fresh.copyWith(birthdayVisibility: _birthdayVisibility));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Profil berhasil diperbarui'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SmoothEntranceTransition(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + Avatar Section
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover Image Container (Proportioned Height 180px)
                  GestureDetector(
                    onTap: _onTapCover,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightSurfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.5),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_removeCover)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sampul akan dihapus (kembali ke bawaan)',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_coverFile != null)
                              ((_coverFile!.path.toLowerCase().contains('.gif') ||
                                      _coverFile!.path.toLowerCase().contains('.webp'))
                                  ? CalmGif(
                                      source: _coverFile!.path,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      speed: 1.0,
                                      minFrameDurationMs: 20,
                                      errorWidget: Image.file(
                                        _coverFile!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      ),
                                    )
                                  : Image.file(
                                      _coverFile!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                    ))
                            else if (widget.user.coverUrl != null &&
                                widget.user.coverUrl!.isNotEmpty)
                              ((widget.user.coverUrl!.toLowerCase().contains('.gif') ||
                                      widget.user.coverUrl!.toLowerCase().contains('.webp'))
                                  ? CalmGif(
                                      source: widget.user.coverUrl!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      speed: 1.0,
                                      minFrameDurationMs: 20,
                                      errorWidget: Image.network(
                                        widget.user.coverUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      ),
                                    )
                                  : Image.network(
                                      widget.user.coverUrl!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                    ))
                            else
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ketuk untuk memilih foto sampul',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Subtle gradient vignette
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x77000000),
                                  ],
                                  stops: [0.55, 1.0],
                                ),
                              ),
                            ),

                            // Camera indicator button on top right of cover
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.camera_fill,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4.5),
                                    Text(
                                      'Ubah Sampul',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Avatar Container
                  Positioned(
                    bottom: -36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _onTapAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkCard : Colors.white,
                                border: Border.all(
                                  color: isDark ? AppColors.darkBackground : Colors.white,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildAvatarContent(),
                              ),
                            ),

                            // Decoration Frame Overlay
                            // Decoration Frame Overlay (Hardware-accelerated 60fps Native Animation)
                            if (widget.user.fullAvatarDecorationUrl != null)
                              IgnorePointer(
                                child: SizedBox(
                                  width: 90 * 1.20,
                                  height: 90 * 1.20,
                                  child: SmoothAvatarDecoration(
                                    decorationUrl: widget.user.fullAvatarDecorationUrl,
                                    decorationCode: widget.user.avatarDecorationCode,
                                    size: 90 * 1.20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white : Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBackground : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.camera_fill,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 52),

            _buildSectionLabel('Nama Lengkap', isDark),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Nama Tampilan Anda',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.person,
                  size: 19,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildSectionLabel('Bio / Deskripsi Singkat', isDark),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ceritakan sedikit tentang dirimu...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 19,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildSectionLabel('Email', isDark),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Alamat Email',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.mail,
                  size: 19,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildSectionLabel('Lokasi', isDark),
            TextField(
              controller: _locationCtrl,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Kota, Negara (cth: Jakarta, Indonesia)',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.location,
                  size: 19,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildSectionLabel('Situs Web', isDark),
            TextField(
              controller: _websiteCtrl,
              keyboardType: TextInputType.url,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'https://example.com',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.globe,
                  size: 19,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildSectionLabel('Tanggal Lahir', isDark),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthday ?? DateTime(2000, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: isDark
                          ? ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.white,
                                onPrimary: Colors.black,
                                surface: Color(0xFF1C1C1E),
                                onSurface: Colors.white,
                              ),
                            )
                          : ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.black,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _birthday = picked;
                  });
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 19,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _birthday != null
                            ? "${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}"
                            : 'Pilih tanggal lahir (YYYY-MM-DD)',
                        style: TextStyle(
                          fontSize: 15,
                          color: _birthday != null
                              ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                    ),
                    if (_birthday != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _birthday = null;
                          });
                        },
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 18,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      )
                    else
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                  ],
                ),
              ),
            ),

            if (_birthday != null) ...[
              const SizedBox(height: 12),
              _buildBirthdayVisibilityPicker(isDark),
            ],

            const SizedBox(height: 18),

            _buildSectionLabel('Username (@username)', isDark),
            TextField(
              controller: _userCtrl,
              enabled: true,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Username unik Anda (contoh: kage_master)',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.at,
                  size: 19,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionLabel('Tampilan Kartu', isDark),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
                  width: 0.8,
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.textformat, color: isDark ? Colors.white : Colors.black, size: 20),
                ),
                title: const Text('Font Profil Card', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  widget.user.profileFontData != null ? widget.user.profileFontData!.name : 'System Default',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  showProfileFontPicker(
                    context,
                    user: widget.user,
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // Save Button (Welcome Screen Pill Style)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  disabledBackgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                  elevation: 4,
                  shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _saving
                    ? CupertinoActivityIndicator(color: isDark ? Colors.black : Colors.white)
                    : Text(
                        'Simpan Perubahan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildAvatarContent() {
    if (_removeAvatar) {
      return Container(
        color: const Color(0xFF2C2C2E),
        child: Center(
          child: Text(
            (widget.user.displayName ?? widget.user.username).isNotEmpty
                ? (widget.user.displayName ?? widget.user.username)[0].toUpperCase()
                : '?',
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (_avatarFile != null) {
      if (_avatarFile!.path.toLowerCase().contains('.gif') ||
          _avatarFile!.path.toLowerCase().contains('.webp')) {
        return CalmGif(
          source: _avatarFile!.path,
          fit: BoxFit.cover,
          speed: 1.0,
          minFrameDurationMs: 20,
          errorWidget: Image.file(_avatarFile!, fit: BoxFit.cover),
        );
      }
      return Image.file(_avatarFile!, fit: BoxFit.cover);
    }
    if (widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty) {
      if (widget.user.avatarUrl!.toLowerCase().contains('.gif') ||
          widget.user.avatarUrl!.toLowerCase().contains('.webp')) {
        return CalmGif(
          source: widget.user.avatarUrl!,
          fit: BoxFit.cover,
          speed: 1.0,
          minFrameDurationMs: 20,
          errorWidget: Image.network(
            widget.user.avatarUrl!,
            fit: BoxFit.cover,
          ),
        );
      }
      return Image.network(
        widget.user.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          CupertinoIcons.person_fill,
          color: Colors.white,
          size: 40,
        ),
      );
    }
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        CupertinoIcons.person_fill,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildBirthdayVisibilityPicker(bool isDark) {
    final options = [
      {
        'key': 'public',
        'title': 'Publik',
        'icon': CupertinoIcons.globe,
        'desc': 'Tanggal lahir, umur, dan zodiak dapat dilihat oleh semua orang.',
      },
      {
        'key': 'age_only',
        'title': 'Hanya Umur',
        'icon': CupertinoIcons.person_badge_minus,
        'desc': 'Hanya umur dan zodiak yang ditampilkan. Tanggal lahir lengkap disembunyikan.',
      },
      {
        'key': 'private',
        'title': 'Privat',
        'icon': CupertinoIcons.lock_fill,
        'desc': 'Tanggal lahir, umur, dan zodiak hanya dapat dilihat oleh kamu sendiri.',
      },
    ];

    final currentOption = options.firstWhere(
      (o) => o['key'] == _birthdayVisibility,
      orElse: () => options[0],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0x1F000000),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.eye,
                size: 14,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Privasi Tanggal Lahir',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((opt) {
              final isSelected = _birthdayVisibility == opt['key'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _birthdayVisibility = opt['key'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt['title'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentOption['desc'] as String,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
