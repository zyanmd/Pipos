import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileFontModel {
  final String key;
  final String name;
  final String googleKey;
  final String category;
  final String fallback;
  final String sample;
  final int? size;
  final bool isDefault;

  const ProfileFontModel({
    required this.key,
    required this.name,
    required this.googleKey,
    this.category = 'sans',
    this.fallback = 'sans-serif',
    this.sample = 'The quick brown fox',
    this.size,
    this.isDefault = false,
  });

  factory ProfileFontModel.fromJson(Map<String, dynamic> j) {
    final rawKey = j['key']?.toString() ?? '';
    final matched = fromKey(rawKey.isNotEmpty ? rawKey : (j['google_key']?.toString() ?? j['name']?.toString()));
    final effectiveKey = rawKey.isNotEmpty ? rawKey : (matched?.key ?? '');
    final effectiveName = j['name']?.toString() ?? matched?.name ?? (effectiveKey.isNotEmpty ? effectiveKey : 'Default');
    final effectiveGoogleKey = (j['google_key'] != null && j['google_key'].toString().isNotEmpty)
        ? j['google_key'].toString()
        : (matched?.googleKey ?? effectiveName);

    return ProfileFontModel(
      key: effectiveKey,
      name: effectiveName,
      googleKey: effectiveGoogleKey,
      category: j['category']?.toString() ?? matched?.category ?? 'sans',
      fallback: j['fallback']?.toString() ?? matched?.fallback ?? 'sans-serif',
      sample: j['sample']?.toString() ?? matched?.sample ?? 'The quick brown fox',
      size: (j['size'] is num) ? (j['size'] as num).toInt() : int.tryParse(j['size']?.toString() ?? ''),
      isDefault: j['is_default'] == true || (effectiveKey.isEmpty && effectiveGoogleKey.isEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'google_key': googleKey,
    'category': category,
    'fallback': fallback,
    'sample': sample,
    if (size != null) 'size': size,
    'is_default': isDefault,
  };

  /// Safely resolves TextStyle with GoogleFonts
  TextStyle textStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextStyle? baseStyle,
    bool inheritSize = true,
  }) {
    final double? effectiveSize = fontSize ?? (inheritSize ? size?.toDouble() : null);
    if (isDefault || googleKey.isEmpty) {
      return (baseStyle ?? const TextStyle()).copyWith(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    try {
      return GoogleFonts.getFont(
        googleKey,
        textStyle: baseStyle,
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    } catch (_) {
      return (baseStyle ?? const TextStyle()).copyWith(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  /// Built-in fallback catalog matching backend routes/user_routes.py
  static const List<ProfileFontModel> defaultCatalog = [
    // SANS-SERIF
    ProfileFontModel(key: 'inter', name: 'Inter', googleKey: 'Inter', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'roboto', name: 'Roboto', googleKey: 'Roboto', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'poppins', name: 'Poppins', googleKey: 'Poppins', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'montserrat', name: 'Montserrat', googleKey: 'Montserrat', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'nunito', name: 'Nunito', googleKey: 'Nunito', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'quicksand', name: 'Quicksand', googleKey: 'Quicksand', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'opensans', name: 'Open Sans', googleKey: 'Open Sans', category: 'sans', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'lato', name: 'Lato', googleKey: 'Lato', category: 'sans', sample: 'The quick brown fox'),

    // SERIF
    ProfileFontModel(key: 'playfair', name: 'Playfair Display', googleKey: 'Playfair Display', category: 'serif', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'merriweather', name: 'Merriweather', googleKey: 'Merriweather', category: 'serif', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'lora', name: 'Lora', googleKey: 'Lora', category: 'serif', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'crimson', name: 'Crimson Text', googleKey: 'Crimson Text', category: 'serif', sample: 'The quick brown fox'),

    // DISPLAY
    ProfileFontModel(key: 'bebas', name: 'Bebas Neue', googleKey: 'Bebas Neue', category: 'display', sample: 'THE QUICK BROWN FOX'),
    ProfileFontModel(key: 'oswald', name: 'Oswald', googleKey: 'Oswald', category: 'display', sample: 'THE QUICK BROWN FOX'),
    ProfileFontModel(key: 'anton', name: 'Anton', googleKey: 'Anton', category: 'display', sample: 'THE QUICK BROWN FOX'),
    ProfileFontModel(key: 'righteous', name: 'Righteous', googleKey: 'Righteous', category: 'display', sample: 'THE QUICK BROWN FOX'),

    // HANDWRITING
    ProfileFontModel(key: 'dancing', name: 'Dancing Script', googleKey: 'Dancing Script', category: 'handwriting', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'pacifico', name: 'Pacifico', googleKey: 'Pacifico', category: 'handwriting', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'caveat', name: 'Caveat', googleKey: 'Caveat', category: 'handwriting', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'satisfy', name: 'Satisfy', googleKey: 'Satisfy', category: 'handwriting', sample: 'The quick brown fox'),
    ProfileFontModel(key: 'greatvibes', name: 'Great Vibes', googleKey: 'Great Vibes', category: 'handwriting', sample: 'The quick brown fox'),

    // MONO
    ProfileFontModel(key: 'jetbrains', name: 'JetBrains Mono', googleKey: 'JetBrains Mono', category: 'mono', sample: 'const x = 42;'),
    ProfileFontModel(key: 'fira', name: 'Fira Code', googleKey: 'Fira Code', category: 'mono', sample: 'const x = 42;'),
    ProfileFontModel(key: 'source_code', name: 'Source Code Pro', googleKey: 'Source Code Pro', category: 'mono', sample: 'const x = 42;'),
    ProfileFontModel(key: 'inconsolata', name: 'Inconsolata', googleKey: 'Inconsolata', category: 'mono', sample: 'const x = 42;'),

    // PIXEL
    ProfileFontModel(key: 'pressstart', name: 'Press Start 2P', googleKey: 'Press Start 2P', category: 'pixel', sample: 'GAME OVER'),
    ProfileFontModel(key: 'vt323', name: 'VT323', googleKey: 'VT323', category: 'pixel', sample: 'SYSTEM READY'),
    ProfileFontModel(key: 'silkscreen', name: 'Silkscreen', googleKey: 'Silkscreen', category: 'pixel', sample: 'PIXEL ART'),
  ];

  static String _normalizeKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  static ProfileFontModel? fromKey(String? key) {
    if (key == null || key.isEmpty || key.toLowerCase() == 'default') return null;
    final normKey = _normalizeKey(key);
    try {
      return defaultCatalog.firstWhere(
        (f) {
          final fk = _normalizeKey(f.key);
          final fgk = _normalizeKey(f.googleKey);
          final fn = _normalizeKey(f.name);
          return fk == normKey || fgk == normKey || fn == normKey ||
                 normKey.startsWith(fk) || fk.startsWith(normKey);
        },
      );
    } catch (_) {
      return ProfileFontModel(key: key, name: key, googleKey: key);
    }
  }
}

