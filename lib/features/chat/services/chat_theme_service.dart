import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../data/chat_repository.dart';

class ChatBubblePreset {
  final String id;
  final String name;
  final String description;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color accentColor;
  final IconData icon;
  final String? gifUrl;
  final bool isAnimated;
  final String? defaultTextColor;

  const ChatBubblePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.gradientColors,
    required this.borderColor,
    required this.accentColor,
    required this.icon,
    this.gifUrl,
    this.isAnimated = false,
    this.defaultTextColor,
  });
}

class ChatThemeService extends ChangeNotifier {
  ChatThemeService._();
  static final ChatThemeService instance = ChatThemeService._();

  static const String _keyPreset = 'chat_theme_preset_id';
  static const String _keyCustomMedia = 'chat_theme_custom_media';
  static const String _keyCustomType = 'chat_theme_custom_type';
  static const String _keyTextColor = 'chat_theme_text_color';
  static const String _keyRoomWallpaper = 'chat_theme_room_wallpaper';
  static const String _keyAnimSpeed = 'chat_theme_anim_speed';

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

  /// Helper to safely parse hex string like #RRGGBB or #AARRGGBB to Color
  static Color parseHexColor(String hex, {Color fallback = Colors.white}) {
    var c = hex.replaceAll('#', '').trim();
    if (c.length == 6) {
      c = 'FF$c';
    }
    if (c.length != 8) return fallback;
    final val = int.tryParse(c, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  String _selectedPresetId = 'default';
  String? _customMediaUrl;
  String _customMediaType = 'image'; // 'image' or 'gif'
  String? _customTextColor;
  String? _chatRoomWallpaper;
  double _animSpeed = 0.70;
  bool _isLoaded = false;

  String get selectedPresetId => _selectedPresetId;
  String? get customMediaUrl => _customMediaUrl;
  String get customMediaType => _customMediaType;
  String? get customTextColor => _customTextColor;
  String? get chatRoomWallpaper => _chatRoomWallpaper;
  double get animSpeed => _animSpeed;
  bool get isLoaded => _isLoaded;
  bool get isCustom => _selectedPresetId == 'custom' && _customMediaUrl != null && _customMediaUrl!.isNotEmpty;

  /// Absolute helper for custom media url
  String? get fullCustomMediaUrl {
    if (_customMediaUrl == null || _customMediaUrl!.isEmpty) return null;
    if (_customMediaUrl!.startsWith('http://') || _customMediaUrl!.startsWith('https://')) {
      return _customMediaUrl;
    }
    if (_customMediaUrl!.startsWith('/data/') ||
        _customMediaUrl!.startsWith('/storage/emulated/') ||
        _customMediaUrl!.contains(':\\') ||
        File(_customMediaUrl!).existsSync()) {
      return _customMediaUrl;
    }
    final clean = _customMediaUrl!.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  /// Active background URL to send with chat message
  String? get activeBackgroundUrl {
    if (isCustom) return fullCustomMediaUrl;
    if (_selectedPresetId != 'default') {
      return currentPreset.gifUrl;
    }
    return null;
  }

  /// Active background type ('gif', 'image', 'none')
  String get activeBackgroundType {
    if (isCustom) return _customMediaType;
    if (_selectedPresetId != 'default' && currentPreset.gifUrl != null) {
      return 'gif';
    }
    return 'none';
  }

  /// Active text color to send with chat message
  String? get activeTextColor {
    if (_customTextColor != null && _customTextColor!.isNotEmpty) {
      return _customTextColor;
    }
    return currentPreset.defaultTextColor;
  }

  static const List<ChatBubblePreset> presets = [
    ChatBubblePreset(
      id: 'default',
      name: 'Bawaan Klasik',
      description: 'Gelembung chat bersih minimalis',
      gradientColors: [Color(0xFF007AFF), Color(0xFF0062CC)],
      borderColor: Color(0xFF007AFF),
      accentColor: Color(0xFF007AFF),
      icon: Icons.chat_bubble_rounded,
      isAnimated: false,
      defaultTextColor: '#FFFFFF',
    ),
    ChatBubblePreset(
      id: 'sakura',
      name: 'Sakura Glow',
      description: 'Animasi kelopak bunga sakura berguguran',
      gradientColors: [Color(0xFF281017), Color(0xFF3B1422)],
      borderColor: Color(0xFFFF2D55),
      accentColor: Color(0xFFFF2D55),
      icon: Icons.local_florist_rounded,
      gifUrl: 'https://media4.giphy.com/media/PoHVT5kEyNWcN0CWNj/giphy.gif',
      isAnimated: true,
      defaultTextColor: '#FFE4E6',
    ),
    ChatBubblePreset(
      id: 'midnight',
      name: 'Midnight Rain',
      description: 'Animasi jendela hujan malam lo-fi syahdu',
      gradientColors: [Color(0xFF0D1424), Color(0xFF14213D)],
      borderColor: Color(0xFF007AFF),
      accentColor: Color(0xFF007AFF),
      icon: Icons.water_drop_rounded,
      gifUrl: 'https://media1.giphy.com/media/ZyFCksxxD9tmLYfGJo/giphy.gif',
      isAnimated: true,
      defaultTextColor: '#E0F2FE',
    ),
    ChatBubblePreset(
      id: 'cyberpunk',
      name: 'Cyberpunk Neon',
      description: 'Animasi 80s retro synthwave grid neon',
      gradientColors: [Color(0xFF1A0F2B), Color(0xFF26123D)],
      borderColor: Color(0xFFAF52DE),
      accentColor: Color(0xFF00F5D4),
      icon: Icons.electric_bolt_rounded,
      gifUrl: 'https://media0.giphy.com/media/v2WuhMBzb3h5e/giphy.gif',
      isAnimated: true,
      defaultTextColor: '#00F5D4',
    ),
    ChatBubblePreset(
      id: 'sunset',
      name: 'Sunset Warmth',
      description: 'Animasi langit senja anime hangat nan damai',
      gradientColors: [Color(0xFF2B1809), Color(0xFF3D210B)],
      borderColor: Color(0xFFFF9500),
      accentColor: Color(0xFFFF9500),
      icon: Icons.wb_sunny_rounded,
      gifUrl: 'https://media0.giphy.com/media/gFPxNhzEWdFCCRAqf0/giphy.gif',
      isAnimated: true,
      defaultTextColor: '#FFEDD5',
    ),
    ChatBubblePreset(
      id: 'emerald',
      name: 'Emerald Garden',
      description: 'Animasi taman anime hijau rindang tenang',
      gradientColors: [Color(0xFF0A1F13), Color(0xFF112E1C)],
      borderColor: Color(0xFF34C759),
      accentColor: Color(0xFF34C759),
      icon: Icons.eco_rounded,
      gifUrl: 'https://media2.giphy.com/media/8gOtTSdJk6Y6jw3nNV/giphy.gif',
      isAnimated: true,
      defaultTextColor: '#DCFCE7',
    ),
  ];

  ChatBubblePreset get currentPreset {
    return presets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => presets.first,
    );
  }

  Future<void> init({String? userId}) async {
    if (userId != null) _activeUserId = userId;
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedPresetId = prefs.getString(_scopedKey(_keyPreset)) ?? 'default';
      _customMediaUrl = prefs.getString(_scopedKey(_keyCustomMedia));
      _customMediaType = prefs.getString(_scopedKey(_keyCustomType)) ?? 'image';
      _customTextColor = prefs.getString(_scopedKey(_keyTextColor));
      _chatRoomWallpaper = prefs.getString(_scopedKey(_keyRoomWallpaper));
      _animSpeed = prefs.getDouble(_scopedKey(_keyAnimSpeed)) ?? 0.70;
      _isLoaded = true;
      notifyListeners();

      // Sinkronisasi data asli dari server database User
      _syncWithServer();
    } catch (_) {}
  }

  /// Sinkronkan background langsung dari database server user
  Future<void> _syncWithServer() async {
    try {
      final res = await ChatRepository.instance.getUserChatBackground();
      if (res != null) {
        final bg = res['background']?.toString() ?? res['background_url']?.toString();
        final bgType = res['background_type']?.toString() ?? 'none';
        final txtCol = res['text_color']?.toString();

        if (bg != null && bg.isNotEmpty && bgType != 'none') {
          // Cocokkan apakah ini preset
          ChatBubblePreset? match;
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

        if (txtCol != null && txtCol.isNotEmpty) {
          _customTextColor = txtCol;
        }

        notifyListeners();

        // Update cache lokal agar selaras dengan server
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_scopedKey(_keyPreset), _selectedPresetId);
        if (_customMediaUrl != null) {
          await prefs.setString(_scopedKey(_keyCustomMedia), _customMediaUrl!);
          await prefs.setString(_scopedKey(_keyCustomType), _customMediaType);
        } else {
          await prefs.remove(_scopedKey(_keyCustomMedia));
          await prefs.remove(_scopedKey(_keyCustomType));
        }
        if (_customTextColor != null) {
          await prefs.setString(_scopedKey(_keyTextColor), _customTextColor!);
        }
      }
    } catch (_) {}
  }

  Future<void> setPreset(String presetId) async {
    _selectedPresetId = presetId;
    _customMediaUrl = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_keyPreset), presetId);
    await prefs.remove(_scopedKey(_keyCustomMedia));

    // Simpan permanen ke database server user
    try {
      final p = presets.firstWhere((x) => x.id == presetId, orElse: () => presets.first);
      if (p.id == 'default') {
        await ChatRepository.instance.deleteUserChatBackground();
      } else if (p.gifUrl != null) {
        await ChatRepository.instance.setUserChatBackground(
          background: p.gifUrl!,
          bgType: 'gif',
          textColor: _customTextColor ?? p.defaultTextColor,
        );
      }
    } catch (_) {}
  }

  Future<void> setCustomMedia({
    required String mediaUrl,
    String mediaType = 'image',
    String? textColor,
  }) async {
    _selectedPresetId = 'custom';
    _customMediaUrl = mediaUrl;
    _customMediaType = mediaType;
    if (textColor != null) _customTextColor = textColor;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_keyPreset), 'custom');
    await prefs.setString(_scopedKey(_keyCustomMedia), mediaUrl);
    await prefs.setString(_scopedKey(_keyCustomType), mediaType);
    if (textColor != null) await prefs.setString(_scopedKey(_keyTextColor), textColor);

    // Simpan permanen ke database server jika bukan path file lokal mentah
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://') || mediaUrl.startsWith('uploads/')) {
      try {
        await ChatRepository.instance.setUserChatBackground(
          background: mediaUrl,
          bgType: mediaType,
          textColor: _customTextColor,
        );
      } catch (_) {}
    }
  }

  Future<void> setTextColor(String? hexColor) async {
    _customTextColor = hexColor;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (hexColor != null) {
      await prefs.setString(_scopedKey(_keyTextColor), hexColor);
    } else {
      await prefs.remove(_scopedKey(_keyTextColor));
    }

    // Sync warna teks ke database server
    try {
      final bg = activeBackgroundUrl;
      final type = activeBackgroundType;
      if (bg != null && bg.isNotEmpty) {
        await ChatRepository.instance.setUserChatBackground(
          background: bg,
          bgType: type,
          textColor: hexColor,
        );
      }
    } catch (_) {}
  }

  Future<void> setChatRoomWallpaper(String? urlOrPath) async {
    _chatRoomWallpaper = urlOrPath;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (urlOrPath != null) {
      await prefs.setString(_scopedKey(_keyRoomWallpaper), urlOrPath);
    } else {
      await prefs.remove(_scopedKey(_keyRoomWallpaper));
    }
  }

  Future<void> setAnimSpeed(double val) async {
    _animSpeed = val.clamp(0.4, 1.2);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scopedKey(_keyAnimSpeed), _animSpeed);
  }

  Future<void> reset() async {
    _selectedPresetId = 'default';
    _customMediaUrl = null;
    _customMediaType = 'image';
    _customTextColor = null;
    _chatRoomWallpaper = null;
    _animSpeed = 0.70;
    notifyListeners();

    // Hapus dari database server user
    try {
      await ChatRepository.instance.deleteUserChatBackground();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_keyPreset));
    await prefs.remove(_scopedKey(_keyCustomMedia));
    await prefs.remove(_scopedKey(_keyCustomType));
    await prefs.remove(_scopedKey(_keyTextColor));
    await prefs.remove(_scopedKey(_keyRoomWallpaper));
    await prefs.remove(_scopedKey(_keyAnimSpeed));
  }

  /// Simpan status background & warna teks saat ini langsung ke server database
  Future<bool> saveToServer() async {
    try {
      final bg = activeBackgroundUrl;
      final type = activeBackgroundType;

      if (_selectedPresetId == 'default' || bg == null || bg.isEmpty || type == 'none') {
        final ok = await ChatRepository.instance.deleteUserChatBackground();
        return ok;
      }

      final res = await ChatRepository.instance.setUserChatBackground(
        background: bg,
        bgType: type,
        textColor: activeTextColor,
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Upload custom background media LANGSUNG ke server dan simpan ke User di database
  Future<String?> uploadCustomBackground(File file, {String? textColor}) async {
    try {
      final res = await ChatRepository.instance.uploadUserChatBackground(
        file,
        textColor: textColor ?? _customTextColor,
      );
      if (res != null) {
        final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
        final url = data['background']?.toString() ?? data['background_url']?.toString();
        final ext = file.path.split('.').last.toLowerCase();
        final isGif = ext == 'gif' || (url != null && url.toLowerCase().endsWith('.gif'));
        final type = data['background_type']?.toString() ?? (isGif ? 'gif' : 'image');

        if (url != null && url.isNotEmpty) {
          _selectedPresetId = 'custom';
          _customMediaUrl = url;
          _customMediaType = type;
          if (textColor != null) _customTextColor = textColor;
          notifyListeners();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_scopedKey(_keyPreset), 'custom');
          await prefs.setString(_scopedKey(_keyCustomMedia), url);
          await prefs.setString(_scopedKey(_keyCustomType), type);
          if (textColor != null) await prefs.setString(_scopedKey(_keyTextColor), textColor);

          return url;
        }
      }
    } catch (_) {}
    return null;
  }
}
