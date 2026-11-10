import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../anime/data/anime_repository.dart';

/// Preset definition for comment cards
class CommentThemePreset {
  final String id;
  final String name;
  final String description;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color accentColor;
  final IconData icon;
  final String? gifUrl;
  final bool isAnimated;

  const CommentThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.gradientColors,
    required this.borderColor,
    required this.accentColor,
    required this.icon,
    this.gifUrl,
    this.isAnimated = false,
  });
}

/// Comment Theme & Background Service.
/// Manages user's customizable comment card backgrounds, custom images/GIFs,
/// and provides decoration styling for episode comments.
class CommentThemeService extends ChangeNotifier {
  CommentThemeService._();
  static final CommentThemeService instance = CommentThemeService._();

  static const String _keyPreset = 'comment_theme_preset';
  static const String _keyCustomMedia = 'comment_theme_custom_media';
  static const String _keyCustomType = 'comment_theme_custom_type';
  static const String _keyOverlayOpacity = 'comment_theme_overlay_opacity';
  static const String _keyApplyToAll = 'comment_theme_apply_to_all';
  static const String _keyBorderGlow = 'comment_theme_border_glow';
  static const String _keyEnableGifCard = 'comment_theme_enable_gif_card';
  static const String _keyAnimSpeed = 'comment_theme_anim_speed';

  // Active User Scoping
  String? _activeUserId;

  String _scopedKey(String key) {
    final uid = _activeUserId ?? TokenStore.savedUser?.id.toString();
    if (uid != null && uid.isNotEmpty) {
      return '${key}_$uid';
    }
    return key;
  }

  Future<void> switchUser(String? userId) async {
    _activeUserId = userId;
    _isLoaded = false;
    await init();
  }

  // State
  String _selectedPresetId = 'default';
  String? _customMediaUrl;
  String _customMediaType = 'image'; // 'image' or 'gif'
  double _overlayOpacity = 0.40;
  bool _applyToAll = false;
  bool _borderGlow = true;
  bool _enableGifCard = true;
  double _animSpeed = 0.70; // 0.70x = calm and relaxed
  bool _isLoaded = false;

  String get selectedPresetId => _selectedPresetId;
  String? get customMediaUrl => _customMediaUrl;
  String get customMediaType => _customMediaType;
  double get overlayOpacity => _overlayOpacity;
  bool get applyToAll => _applyToAll;
  bool get borderGlow => _borderGlow;
  bool get enableGifCard => _enableGifCard;
  double get animSpeed => _animSpeed;
  bool get isLoaded => _isLoaded;
  bool get isCustom => _selectedPresetId == 'custom' && _customMediaUrl != null && _customMediaUrl!.isNotEmpty;

  /// Absolute helper for custom media url
  String? get fullCustomMediaUrl {
    if (_customMediaUrl == null || _customMediaUrl!.isEmpty) return null;
    if (_customMediaUrl!.startsWith('http://') || _customMediaUrl!.startsWith('https://')) {
      return _customMediaUrl;
    }
    // If it's a local device file path (from local storage, cache, or picker fallback)
    if (_customMediaUrl!.startsWith('/data/') ||
        _customMediaUrl!.startsWith('/storage/emulated/') ||
        _customMediaUrl!.contains(':\\') ||
        File(_customMediaUrl!).existsSync()) {
      return _customMediaUrl;
    }
    final clean = _customMediaUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  /// Returns the active media URL (GIF/Image) for comment cards if enabled
  String? get currentCardMediaUrl {
    if (isCustom && fullCustomMediaUrl != null) {
      if (!_enableGifCard && _customMediaType == 'gif') return null;
      return fullCustomMediaUrl;
    }
    if (_enableGifCard && currentPreset.gifUrl != null) {
      return currentPreset.gifUrl;
    }
    return null;
  }

  /// Whether current active theme has an animated GIF background
  bool get hasGifBackground {
    if (!_enableGifCard) return false;
    if (isCustom && _customMediaType == 'gif') return true;
    return currentPreset.gifUrl != null;
  }

  /// Available preset designs with rich animated looping GIFs
  static const List<CommentThemePreset> presets = [
    CommentThemePreset(
      id: 'default',
      name: 'Sistem Klasik',
      description: 'Gaya minimalis bersih',
      gradientColors: [Color(0xFF1C1C1E), Color(0xFF1C1C1E)],
      borderColor: Color(0xFF2C2C2E),
      accentColor: Color(0xFF8E8E93),
      icon: Icons.chat_bubble_outline_rounded,
      isAnimated: false,
    ),
    CommentThemePreset(
      id: 'sakura',
      name: 'Sakura Glow',
      description: 'Animasi kelopak bunga sakura berguguran',
      gradientColors: [Color(0xFF281017), Color(0xFF3B1422)],
      borderColor: Color(0xFFFF2D55),
      accentColor: Color(0xFFFF2D55),
      icon: Icons.local_florist_rounded,
      gifUrl: 'https://media4.giphy.com/media/PoHVT5kEyNWcN0CWNj/giphy.gif',
      isAnimated: true,
    ),
    CommentThemePreset(
      id: 'midnight',
      name: 'Midnight Rain',
      description: 'Animasi jendela hujan malam lo-fi syahdu',
      gradientColors: [Color(0xFF0D1424), Color(0xFF14213D)],
      borderColor: Color(0xFF007AFF),
      accentColor: Color(0xFF007AFF),
      icon: Icons.water_drop_rounded,
      gifUrl: 'https://media1.giphy.com/media/ZyFCksxxD9tmLYfGJo/giphy.gif',
      isAnimated: true,
    ),
    CommentThemePreset(
      id: 'cyberpunk',
      name: 'Cyberpunk Neon',
      description: 'Animasi 80s retro synthwave neon grid',
      gradientColors: [Color(0xFF1A0F2B), Color(0xFF26123D)],
      borderColor: Color(0xFFAF52DE),
      accentColor: Color(0xFF00F5D4),
      icon: Icons.electric_bolt_rounded,
      gifUrl: 'https://media0.giphy.com/media/v2WuhMBzb3h5e/200.gif',
      isAnimated: true,
    ),
    CommentThemePreset(
      id: 'sunset',
      name: 'Sunset Horizon',
      description: 'Animasi langit senja anime hangat nan damai',
      gradientColors: [Color(0xFF2B1809), Color(0xFF3D210B)],
      borderColor: Color(0xFFFF9500),
      accentColor: Color(0xFFFF9500),
      icon: Icons.wb_sunny_rounded,
      gifUrl: 'https://media0.giphy.com/media/gFPxNhzEWdFCCRAqf0/200.gif',
      isAnimated: true,
    ),
    CommentThemePreset(
      id: 'emerald',
      name: 'Emerald Garden',
      description: 'Animasi taman anime hijau rindang tenang',
      gradientColors: [Color(0xFF0A1F13), Color(0xFF112E1C)],
      borderColor: Color(0xFF34C759),
      accentColor: Color(0xFF34C759),
      icon: Icons.eco_rounded,
      gifUrl: 'https://media2.giphy.com/media/8gOtTSdJk6Y6jw3nNV/giphy.gif',
      isAnimated: true,
    ),
  ];

  CommentThemePreset get currentPreset {
    return presets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => presets.first,
    );
  }

  /// Initialize and load saved comment background preferences
  Future<void> init({String? userId}) async {
    if (userId != null) _activeUserId = userId;
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedPresetId = prefs.getString(_scopedKey(_keyPreset)) ?? 'default';
      _customMediaUrl = prefs.getString(_scopedKey(_keyCustomMedia));
      _customMediaType = prefs.getString(_scopedKey(_keyCustomType)) ?? 'image';
      _overlayOpacity = prefs.getDouble(_scopedKey(_keyOverlayOpacity)) ?? 0.40;
      _applyToAll = prefs.getBool(_scopedKey(_keyApplyToAll)) ?? false;
      _borderGlow = prefs.getBool(_scopedKey(_keyBorderGlow)) ?? true;
      _enableGifCard = prefs.getBool(_scopedKey(_keyEnableGifCard)) ?? true;
      _animSpeed = prefs.getDouble(_scopedKey(_keyAnimSpeed)) ?? 0.70;
      _isLoaded = true;
      notifyListeners();

      _syncWithServer();
    } catch (_) {}
  }

  /// Sinkronkan background komentar langsung dari database server user
  Future<void> _syncWithServer() async {
    try {
      final res = await AnimeRepository.instance.getUserCommentBackground();
      if (res != null) {
        final bg = res['background']?.toString();
        final bgType = res['background_type']?.toString() ?? 'none';

        if (bg != null && bg.isNotEmpty && bgType != 'none') {
          CommentThemePreset? match;
          for (final p in presets) {
            if (p.gifUrl != null && p.gifUrl == bg) {
              match = p;
              break;
            }
          }
          if (match != null) {
            _selectedPresetId = match.id;
            _customMediaUrl = null;
          } else {
            _selectedPresetId = 'custom';
            _customMediaUrl = bg;
            _customMediaType = bgType;
          }
        } else {
          _selectedPresetId = 'default';
          _customMediaUrl = null;
          _customMediaType = 'image';
        }

        if (res['opacity'] != null) {
          final op = double.tryParse(res['opacity'].toString());
          if (op != null) _overlayOpacity = op.clamp(0.0, 0.85);
        }

        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_scopedKey(_keyPreset), _selectedPresetId);
        if (_customMediaUrl != null) {
          await prefs.setString(_scopedKey(_keyCustomMedia), _customMediaUrl!);
          await prefs.setString(_scopedKey(_keyCustomType), _customMediaType);
        } else {
          await prefs.remove(_scopedKey(_keyCustomMedia));
          await prefs.remove(_scopedKey(_keyCustomType));
        }
      }
    } catch (_) {}
  }

  /// Set selected preset and save to server
  Future<void> setPreset(String presetId) async {
    _selectedPresetId = presetId;
    _customMediaUrl = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_keyPreset), presetId);
    await prefs.remove(_scopedKey(_keyCustomMedia));

    try {
      final p = presets.firstWhere((x) => x.id == presetId, orElse: () => presets.first);
      if (p.id == 'default') {
        await AnimeRepository.instance.deleteUserCommentBackground();
      } else if (p.gifUrl != null) {
        await AnimeRepository.instance.setUserCommentBackground(
          background: p.gifUrl!,
          bgType: 'gif',
          opacity: _overlayOpacity,
        );
      }
    } catch (_) {}
  }

  /// Set custom media background (URL or local path)
  Future<void> setCustomMedia({
    required String mediaUrl,
    String mediaType = 'image',
  }) async {
    _selectedPresetId = 'custom';
    _customMediaUrl = mediaUrl;
    _customMediaType = mediaType;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_keyPreset), 'custom');
    await prefs.setString(_scopedKey(_keyCustomMedia), mediaUrl);
    await prefs.setString(_scopedKey(_keyCustomType), mediaType);

    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://') || mediaUrl.startsWith('uploads/')) {
      try {
        await AnimeRepository.instance.setUserCommentBackground(
          background: mediaUrl,
          bgType: mediaType,
          opacity: _overlayOpacity,
        );
      } catch (_) {}
    }
  }

  /// Toggle enable GIF animation on comment cards
  Future<void> setEnableGifCard(bool val) async {
    _enableGifCard = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_keyEnableGifCard), val);
  }

  /// Set overlay opacity (0.0 = bright, 0.85 = dark)
  Future<void> setOverlayOpacity(double val) async {
    _overlayOpacity = val.clamp(0.0, 0.85);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scopedKey(_keyOverlayOpacity), _overlayOpacity);
  }

  /// Toggle apply to all comments or owner comments only
  Future<void> setApplyToAll(bool val) async {
    _applyToAll = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_keyApplyToAll), val);
  }

  /// Toggle glowing border
  Future<void> setBorderGlow(bool val) async {
    _borderGlow = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_keyBorderGlow), val);
  }

  /// Set animation speed multiplier (0.4 - 1.2)
  Future<void> setAnimSpeed(double val) async {
    _animSpeed = val.clamp(0.4, 1.2);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scopedKey(_keyAnimSpeed), _animSpeed);
  }

  /// Reset to default system background
  Future<void> reset() async {
    _selectedPresetId = 'default';
    _customMediaUrl = null;
    _customMediaType = 'image';
    _overlayOpacity = 0.40;
    _applyToAll = false;
    _borderGlow = true;
    _enableGifCard = true;
    _animSpeed = 0.70;
    notifyListeners();

    try {
      await AnimeRepository.instance.deleteUserCommentBackground();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_keyPreset));
    await prefs.remove(_scopedKey(_keyCustomMedia));
    await prefs.remove(_scopedKey(_keyCustomType));
    await prefs.remove(_scopedKey(_keyOverlayOpacity));
    await prefs.remove(_scopedKey(_keyApplyToAll));
    await prefs.remove(_scopedKey(_keyBorderGlow));
    await prefs.remove(_scopedKey(_keyEnableGifCard));
    await prefs.remove(_scopedKey(_keyAnimSpeed));
  }

  /// Simpan konfigurasi ke server database profil user
  Future<bool> saveToServer() async {
    try {
      if (_selectedPresetId == 'default') {
        final ok = await AnimeRepository.instance.deleteUserCommentBackground();
        return ok;
      }
      final bg = isCustom ? fullCustomMediaUrl : currentPreset.gifUrl;
      final type = isCustom ? _customMediaType : (currentPreset.gifUrl != null ? 'gif' : 'none');
      if (bg == null || bg.isEmpty || type == 'none') {
        final ok = await AnimeRepository.instance.deleteUserCommentBackground();
        return ok;
      }
      final res = await AnimeRepository.instance.setUserCommentBackground(
        background: bg,
        bgType: type,
        opacity: _overlayOpacity,
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Upload custom background media directly to user's database record
  Future<String?> uploadMedia(File file) async {
    try {
      final res = await AnimeRepository.instance.uploadUserCommentBackground(
        file,
        opacity: _overlayOpacity,
      );
      if (res != null) {
        final d = res['data'] is Map ? (res['data'] as Map) : res;
        final url = d['background']?.toString() ?? d['background_url']?.toString();
        final ext = file.path.split('.').last.toLowerCase();
        final isGif = ext == 'gif' || (url != null && url.toLowerCase().endsWith('.gif'));
        final serverType = d['background_type']?.toString();
        final type = isGif ? 'gif' : (serverType ?? 'image');
        if (url != null && url.isNotEmpty) {
          await setCustomMedia(mediaUrl: url, mediaType: type);
          return url;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Generates the BoxDecoration for a comment card.
  BoxDecoration getCardDecoration({
    required bool isDark,
    bool isOwner = false,
    bool isPinned = false,
  }) {
    // 1. Pinned comment has high priority rose border accent
    if (isPinned) {
      return BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    // 2. Active Image / GIF Card Background (Animated preset or custom upload)
    final activeMedia = currentCardMediaUrl;
    if (activeMedia != null) {
      final borderColor = currentPreset.gifUrl != null ? currentPreset.borderColor : (isDark ? Colors.white : Colors.black);
      final accentColor = currentPreset.gifUrl != null ? currentPreset.accentColor : (isDark ? Colors.white : Colors.black);

      return BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderGlow
              ? borderColor.withValues(alpha: isDark ? 0.65 : 0.45)
              : (isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.08)),
          width: _borderGlow ? 1.2 : 0.6,
        ),
        boxShadow: _borderGlow
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: isDark ? 0.22 : 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      );
    }

    // 3. Preset Theme (when GIF is disabled or preset has no GIF)
    if (_selectedPresetId != 'default') {
      final preset = currentPreset;
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? preset.gradientColors
              : preset.gradientColors.map((c) => c.withValues(alpha: 0.15)).toList(),
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderGlow
              ? preset.borderColor.withValues(alpha: 0.55)
              : (isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.08)),
          width: _borderGlow ? 1.0 : 0.6,
        ),
        boxShadow: _borderGlow
            ? [
                BoxShadow(
                  color: preset.accentColor.withValues(alpha: isDark ? 0.20 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      );
    }

    // 4. Default iOS/Telegram Bubble System Card
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
        width: 0.6,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
