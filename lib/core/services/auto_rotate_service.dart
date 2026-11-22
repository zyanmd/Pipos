import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk mengontrol status rotasi otomatis sistem Android.
/// Memungkinkan aplikasi mematikan rotasi otomatis (auto-rotate) saat aplikasi ditutup / background
/// serta mengaktifkan auto-rotate secara cerdas saat video diputar dalam mode layar penuh (fullscreen).
class AutoRotateService extends ChangeNotifier {
  AutoRotateService._privateConstructor();
  static final AutoRotateService instance = AutoRotateService._privateConstructor();

  static const MethodChannel _channel = MethodChannel('com.moko.app/auto_rotate');

  static const String _keyAutoDisableOnExit = 'auto_disable_rotate_on_exit';
  static const String _keyAutoEnableInPlayer = 'auto_enable_rotate_in_player';

  bool _isAutoDisableOnExit = true;
  bool _isAutoEnableInPlayer = true;
  bool _hasWriteSettingsPermission = false;
  bool _isInitialized = false;

  bool get isAutoDisableOnExit => _isAutoDisableOnExit;
  bool get isAutoEnableInPlayer => _isAutoEnableInPlayer;
  bool get hasWriteSettingsPermission => _hasWriteSettingsPermission;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isAutoDisableOnExit = prefs.getBool(_keyAutoDisableOnExit) ?? true;
      _isAutoEnableInPlayer = prefs.getBool(_keyAutoEnableInPlayer) ?? true;
      await checkPermission();
    } catch (e) {
      debugPrint('[AutoRotateService] init error: $e');
    }
  }

  /// Memeriksa apakah aplikasi memiliki izin mengubah setelan sistem (WRITE_SETTINGS)
  Future<bool> checkPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('canModifySystemSettings');
      final bool prev = _hasWriteSettingsPermission;
      _hasWriteSettingsPermission = granted ?? false;
      if (prev != _hasWriteSettingsPermission) {
        notifyListeners();
      }
      return _hasWriteSettingsPermission;
    } catch (e) {
      debugPrint('[AutoRotateService] checkPermission error: $e');
      return false;
    }
  }

  /// Membuka layar setelan Android untuk memberikan izin "Izinkan mengubah setelan sistem"
  Future<void> openPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openWriteSettings');
    } catch (e) {
      debugPrint('[AutoRotateService] openPermissionSettings error: $e');
    }
  }

  /// Mengatur preferensi matikan auto-rotate saat keluar / aplikasi ditutup
  Future<void> setAutoDisableOnExit(bool value) async {
    _isAutoDisableOnExit = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoDisableOnExit, value);
      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod('setAutoDisableOnExit', {'enabled': value});
      }
    } catch (_) {}
  }

  /// Mengatur preferensi nyalakan auto-rotate saat masuk mode fullscreen
  Future<void> setAutoEnableInPlayer(bool value) async {
    _isAutoEnableInPlayer = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoEnableInPlayer, value);
    } catch (_) {}
  }

  /// Mengubah status rotasi otomatis sistem Android secara langsung
  Future<bool> setSystemAutoRotate(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool? res = await _channel.invokeMethod<bool>('setSystemAutoRotate', {'enabled': enabled});
      return res ?? false;
    } catch (e) {
      debugPrint('[AutoRotateService] setSystemAutoRotate error: $e');
      return false;
    }
  }

  /// Mengecek apakah rotasi otomatis sistem Android saat ini sedang aktif
  Future<bool> isSystemAutoRotateEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool? res = await _channel.invokeMethod<bool>('isSystemAutoRotateEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dipanggil saat aplikasi masuk ke background, diminimalkan, atau ditutup
  Future<void> handleAppBackground() async {
    if (!_isAutoDisableOnExit) return;
    if (kIsWeb || !Platform.isAndroid) return;
    debugPrint('[AutoRotateService] Turning off system auto-rotate on background/exit');
    await setSystemAutoRotate(false);
  }

  /// Dipanggil saat masuk mode fullscreen pemutar video
  Future<void> handleFullscreenEnter() async {
    if (!_isAutoEnableInPlayer) return;
    if (kIsWeb || !Platform.isAndroid) return;
    debugPrint('[AutoRotateService] Turning on system auto-rotate for fullscreen');
    await setSystemAutoRotate(true);
  }

  /// Dipanggil saat keluar mode fullscreen pemutar video
  Future<void> handleFullscreenExit() async {
    if (!_isAutoDisableOnExit) return;
    if (kIsWeb || !Platform.isAndroid) return;
    debugPrint('[AutoRotateService] Turning off system auto-rotate on fullscreen exit');
    await setSystemAutoRotate(false);
  }

  /// Dipanggil saat widget pemutar video di-dispose
  Future<void> handlePlayerDisposed() async {
    if (!_isAutoDisableOnExit) return;
    if (kIsWeb || !Platform.isAndroid) return;
    await setSystemAutoRotate(false);
  }
}
