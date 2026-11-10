import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption { light, dark, system }

extension ThemeModeOptionExt on ThemeModeOption {
  ThemeMode toFlutterMode() {
    switch (this) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }

  String get label {
    switch (this) {
      case ThemeModeOption.light:
        return 'Terang';
      case ThemeModeOption.dark:
        return 'Gelap';
      case ThemeModeOption.system:
        return 'Sistem';
    }
  }

  IconData get icon {
    switch (this) {
      case ThemeModeOption.light:
        return Icons.light_mode_rounded;
      case ThemeModeOption.dark:
        return Icons.dark_mode_rounded;
      case ThemeModeOption.system:
        return Icons.brightness_auto_rounded;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  static const String _kPrefKey = 'theme_mode';
  static const String _kAnimationPrefKey = 'system_animations_enabled';

  ThemeModeOption _mode = ThemeModeOption.system;
  ThemeModeOption get mode => _mode;

  bool _isAnimationEnabled = true;
  bool get isAnimationEnabled => _isAnimationEnabled;

  ThemeMode get flutterMode => _mode.toFlutterMode();
  bool get isDark => _mode == ThemeModeOption.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kPrefKey);
    if (v != null) {
      _mode = ThemeModeOption.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ThemeModeOption.system,
      );
    }
    final animPref = prefs.getBool(_kAnimationPrefKey);
    if (animPref != null) {
      _isAnimationEnabled = animPref;
    }
    notifyListeners();
  }

  Future<void> setAnimationEnabled(bool enabled) async {
    if (_isAnimationEnabled == enabled) return;
    _isAnimationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAnimationPrefKey, enabled);
    notifyListeners();
  }

  Future<void> setMode(ThemeModeOption mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, mode.name);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(_mode == ThemeModeOption.dark
        ? ThemeModeOption.light
        : ThemeModeOption.dark,);
  }
}
