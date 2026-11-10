import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Service untuk memaksa layar berjalan di 90Hz / 120Hz (high refresh rate)
/// di semua perangkat Android yang mendukung (Samsung, Xiaomi, Oppo, Vivo, Pixel, dll)
class DisplayModeService {
  DisplayModeService._();
  static final DisplayModeService instance = DisplayModeService._();

  bool _initialized = false;

  /// Paksa layar berjalan di refresh rate tertinggi (90fps / 120fps)
  Future<void> forceHighRefreshRate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. Panggil setHighRefreshRate bawaan plugin
      await FlutterDisplayMode.setHighRefreshRate();

      // 2. Periksa seluruh mode yang didukung layar perangkat
      final List<DisplayMode> modes = await FlutterDisplayMode.supported;
      if (modes.isNotEmpty) {
        DisplayMode? bestMode;
        double highestRate = 0.0;

        for (final m in modes) {
          if (m.refreshRate > highestRate) {
            highestRate = m.refreshRate;
            bestMode = m;
          } else if ((m.refreshRate - highestRate).abs() < 0.5 && bestMode != null) {
            // Jika refresh rate sama, pilih resolusi paling tajam
            if ((m.width * m.height) > (bestMode.width * bestMode.height)) {
              bestMode = m;
            }
          }
        }

        // Jika ditemukan mode >= 88Hz (90Hz, 120Hz, 144Hz, 165Hz)
        if (bestMode != null && bestMode.refreshRate >= 88.0) {
          await FlutterDisplayMode.setPreferredMode(bestMode);
          debugPrint(
            '[DisplayMode] Berhasil mengunci refresh rate: ${bestMode.refreshRate.round()}Hz (${bestMode.width}x${bestMode.height})',
          );
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[DisplayMode] Gagal mengunci mode layar: $e');
    }
  }

  /// Tegaskan kembali refresh rate tinggi saat aplikasi kembali aktif (resume)
  Future<void> reassertOnResume() async {
    if (!_initialized) return;
    try {
      await forceHighRefreshRate();
    } catch (_) {}
  }
}

