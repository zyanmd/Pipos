import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../data/models/profile_font_model.dart';
import '../data/profile_repository.dart';

/// Shows an iOS-styled bottom sheet modal to pick Google Fonts for profile card.
Future<void> showProfileFontPicker(
  BuildContext context, {
  UserModel? user,
  Function(UserModel)? onUpdated,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _ProfileFontPickerSheet(
      initialUser: user,
      onUpdated: onUpdated,
    ),
  );
}

class _ProfileFontPickerSheet extends StatefulWidget {
  final UserModel? initialUser;
  final Function(UserModel)? onUpdated;

  const _ProfileFontPickerSheet({
    this.initialUser,
    this.onUpdated,
  });

  @override
  State<_ProfileFontPickerSheet> createState() => _ProfileFontPickerSheetState();
}

class _ProfileFontPickerSheetState extends State<_ProfileFontPickerSheet> {
  final _repo = ProfileRepository.instance;
  List<ProfileFontModel> _fonts = ProfileFontModel.defaultCatalog;
  String _selectedCategory = 'all';
  ProfileFontModel? _selectedFont;
  double _selectedSize = 16.0;
  bool _isSaving = false;
  String? _error;

  final Map<String, String> _categoryLabels = {
    'all': 'Semua',
    'sans': 'Sans-Serif',
    'serif': 'Serif',
    'display': 'Display',
    'handwriting': 'Tulis Tangan',
    'mono': 'Monospace',
    'pixel': 'Pixel',
  };

  @override
  void initState() {
    super.initState();
    final authUser = widget.initialUser ?? context.read<AuthProvider>().user;
    if (authUser?.profileFont != null && authUser!.profileFont!.isNotEmpty) {
      _selectedFont = ProfileFontModel.fromKey(authUser.profileFont);
    }
    if (authUser?.profileFontSize != null && authUser!.profileFontSize! > 0) {
      _selectedSize = authUser.profileFontSize!.toDouble().clamp(12.0, 24.0);
    }
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    try {
      final catalog = await _repo.getProfileFonts();
      if (mounted && catalog.isNotEmpty) {
        setState(() {
          _fonts = catalog;
          // Re-sync selected font with loaded catalog if needed
          final cur = _selectedFont;
          if (cur != null) {
            try {
              _selectedFont = catalog.firstWhere((f) => f.key == cur.key);
            } catch (_) {}
          }
        });
      }
    } catch (_) {
      // Graceful fallback to defaultCatalog already loaded
    }
  }

  List<ProfileFontModel> get _filteredFonts {
    if (_selectedCategory == 'all') {
      return _fonts;
    }
    return _fonts.where((f) => f.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
  }

  Future<void> _saveFont() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    HapticFeedback.lightImpact();

    try {
      UserModel updatedUser;
      if (_selectedFont == null) {
        // Reset to default
        updatedUser = await _repo.resetProfileFont();
      } else {
        updatedUser = await _repo.setProfileFont(
          font: _selectedFont!.key,
          size: _selectedSize.round(),
        );
      }

      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      widget.onUpdated?.call(updatedUser);

      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.black,
          content: Row(
            children: [
              const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _selectedFont == null
                    ? 'Font profil direset ke default'
                    : 'Font profil diganti ke ${_selectedFont!.name}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = _repo.errorMessage(e);
        });
      }
    }
  }

  Future<void> _resetFont() async {
    setState(() {
      _selectedFont = null;
      _selectedSize = 16.0;
    });
    await _saveFont();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = widget.initialUser ?? context.watch<AuthProvider>().user;
    final displayName = authUser?.displayName?.isNotEmpty == true
        ? authUser!.displayName!
        : (authUser?.username.isNotEmpty == true ? authUser!.username : 'Pengguna');
    final userBio = authUser?.bio?.isNotEmpty == true
        ? authUser!.bio!
        : 'Halo! Saya penggemar anime dan komik di MOKO.';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // Top Grabber Pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(CupertinoIcons.textformat, color: isDark ? Colors.white : Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Profil Card',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'Ubah gaya tulisan nama dan bio kartu profilmu',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const BouncingScrollPhysics(),
                children: [
                  // ── 1. LIVE PREVIEW CARD ────────────────────────────────
                  _buildPreviewCard(
                    isDark: isDark,
                    authUser: authUser,
                    displayName: displayName,
                    bio: userBio,
                  ),

                  const SizedBox(height: 16),

                  // ── 2. FONT SIZE SLIDER ────────────────────────────────
                  _buildSizeSlider(isDark),

                  const SizedBox(height: 16),

                  // ── 3. CATEGORY CHIPS ──────────────────────────────────
                  _buildCategoryChips(isDark),

                  const SizedBox(height: 14),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),

                  // ── 4. FONT LIST / GRID ────────────────────────────────
                  _buildFontGrid(isDark),
                ],
              ),
            ),

            // Bottom Action Controls
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard({
    required bool isDark,
    required UserModel? authUser,
    required String displayName,
    required String bio,
  }) {
    final previewStyle = _selectedFont != null
        ? _selectedFont!.textStyle(
            fontSize: _selectedSize,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          )
        : TextStyle(
            fontSize: _selectedSize,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          );

    final bioStyle = _selectedFont != null
        ? _selectedFont!.textStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            height: 1.35,
          )
        : TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            height: 1.35,
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E24), const Color(0xFF252530)]
              : [const Color(0xFFFFF0F5), const Color(0xFFF3F4F8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.20),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedAvatar(
                avatarUrl: authUser?.avatarUrl,
                decorationUrl: authUser?.fullAvatarDecorationUrl,
                fallbackName: displayName,
                radius: 26,
                decorationScale: authUser?.avatarDecorationScale ?? 1.0,
                offsetX: authUser?.avatarDecorationOffsetX ?? 0,
                offsetY: authUser?.avatarDecorationOffsetY ?? 0,
                borderColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderWidth: 2.0,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${authUser?.username ?? 'username'}',
                      style: _selectedFont != null
                          ? _selectedFont!.textStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            )
                          : TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25)),
                ),
                child: Text(
                  _selectedFont?.name ?? 'System Default',
                  style: _selectedFont != null
                      ? _selectedFont!.textStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        )
                      : TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bioStyle,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPreviewChip('24 Anime', CupertinoIcons.play_circle_fill, isDark),
              Text(
                '•',
                style: _selectedFont != null
                    ? _selectedFont!.textStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      )
                    : TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
              ),
              _buildPreviewChip('18 Komik', CupertinoIcons.book_fill, isDark),
              Text(
                '•',
                style: _selectedFont != null
                    ? _selectedFont!.textStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      )
                    : TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
              ),
              _buildPreviewChip('5 Favorit', CupertinoIcons.heart_fill, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewChip(String label, IconData icon, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: _selectedFont != null
              ? _selectedFont!.textStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                )
              : TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
        ),
      ],
    );
  }

  Widget _buildSizeSlider(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ukuran Font Judul',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_selectedSize.round()} pt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? Colors.white : Colors.black,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: isDark ? Colors.white : Colors.black,
              overlayColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _selectedSize,
              min: 14.0,
              max: 24.0,
              divisions: 10,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _selectedSize = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categoryLabels.entries.map((entry) {
          final isSelected = _selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              backgroundColor: isDark ? const Color(0xFF222228) : const Color(0xFFF0F1F5),
              selectedColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = entry.key);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFontGrid(bool isDark) {
    final list = _filteredFonts;

    return Column(
      children: [
        // Default System Font Card (always available)
        _buildFontCard(
          isDark: isDark,
          font: null,
          isSelected: _selectedFont == null,
          title: 'System Default',
          subtitle: 'Font bawaan sistem perangkat',
          category: 'Default',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedFont = null);
          },
        ),
        const SizedBox(height: 8),

        // List of fonts
        ...list.map((font) {
          final isSelected = _selectedFont?.key == font.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildFontCard(
              isDark: isDark,
              font: font,
              isSelected: isSelected,
              title: font.name,
              subtitle: font.sample,
              category: font.category.toUpperCase(),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFont = font);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFontCard({
    required bool isDark,
    required ProfileFontModel? font,
    required bool isSelected,
    required String title,
    required String subtitle,
    required String category,
    required VoidCallback onTap,
  }) {
    final titleStyle = font != null
        ? font.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
          )
        : TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
          );

    final sampleStyle = font != null
        ? font.textStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          )
        : TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.16 : 0.08)
                : (isDark ? const Color(0xFF1B1B1F) : const Color(0xFFFAFAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
              width: isSelected ? 1.5 : 0.6,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon or Checkmark
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? CupertinoIcons.checkmark_alt : CupertinoIcons.textformat,
                  color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black54),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Font details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: titleStyle),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sampleStyle,
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(CupertinoIcons.checkmark_seal_fill, color: isDark ? Colors.white : Colors.black, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reset Button
          OutlinedButton(
            onPressed: _isSaving ? null : _resetFont,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Reset'),
          ),
          const SizedBox(width: 12),
          // Save Button
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveFont,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 4,
                shadowColor: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.black : Colors.white),
                      ),
                    )
                  : Text(
                      'Terapkan Font',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

