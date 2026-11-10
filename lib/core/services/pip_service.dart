import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service terpusat untuk mengontrol Picture-in-Picture (PiP) dan Fullscreen khusus pemutar video.
/// Mendukung Android (Native OS PiP) dan Windows (Floating Always-on-Top PiP).
/// Menjamin bahwa layar selain pemutar video (komik, home, profil, dll.) TIDAK AKAN PERNAH masuk ke mode PiP.
class PipService {
  PipService._privateConstructor() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  static final PipService instance = PipService._privateConstructor();

  /// Global route observer untuk mendeteksi perpindahan screen
  static final RouteObserver<ModalRoute<dynamic>> routeObserver = RouteObserver<ModalRoute<dynamic>>();

  final List<VoidCallback> _pauseCallbacks = [];

  /// Daftarkan callback jeda (pause) dari pemutar video aktif
  void registerActivePlayer({required VoidCallback onPause}) {
    if (!_pauseCallbacks.contains(onPause)) {
      _pauseCallbacks.add(onPause);
    }
  }

  /// Hapus callback pemutar video
  void unregisterActivePlayer({required VoidCallback onPause}) {
    _pauseCallbacks.remove(onPause);
  }

  /// Menjeda secara instan semua pemutar video yang sedang aktif di aplikasi
  void pauseAllPlayers() {
    for (final cb in List<VoidCallback>.from(_pauseCallbacks)) {
      try {
        cb();
      } catch (e) {
        debugPrint('[PipService] pauseAllPlayers error: $e');
      }
    }
  }

  final MethodChannel _channel = const MethodChannel('com.moko.app/pip');
  final ValueNotifier<bool> isInPip = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isFullscreen = ValueNotifier<bool>(false);

  bool isAutoPipEnabled = false;
  bool _isVideoScreenActive = false;
  bool _isVideoPlaying = false;

  bool get isVideoScreenActive => _isVideoScreenActive;
  bool get isVideoPlaying => _isVideoPlaying;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipChanged') {
      final bool inPip = call.arguments as bool;
      if (isInPip.value == inPip) {
        return;
      }
      isInPip.value = inPip;
      if (!inPip) {
        // Saat keluar dari PiP, sinkronkan kembali status pemutaran
        if (!_isVideoScreenActive || !_isVideoPlaying) {
          setAutoPip(false);
        }
      }
    } else if (call.method == 'onFullscreenChanged') {
      final bool fs = call.arguments as bool;
      if (isFullscreen.value != fs) {
        isFullscreen.value = fs;
      }
    }
  }

  Future<bool> get isPipSupported async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.windows)) {
      try {
        final result = await _channel.invokeMethod<bool>('isPipSupported');
        return result ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Memperbarui state pemutaran video secara presisi.
  /// Auto-PiP HANYA aktif jika:
  /// 1. Sedang berada di layar video ([isVideoScreen] == true)
  /// 2. Video benar-benar sedang diputar ([isPlaying] == true)
  void updateVideoPlaybackState({required bool isVideoScreen, required bool isPlaying}) {
    _isVideoScreenActive = isVideoScreen;
    _isVideoPlaying = isPlaying;
    final bool shouldEnable = isVideoScreen && isPlaying;
    setAutoPip(shouldEnable);
  }

  /// Memaksa matikan PiP seketika (dipanggil saat buka komik, navigasi keluar video, dll.)
  void disablePipNow() {
    if (isInPip.value && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      exitPip();
    }
    if (isFullscreen.value && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      exitFullscreen();
    }
    _isVideoScreenActive = false;
    _isVideoPlaying = false;
    isInPip.value = false;
    isFullscreen.value = false;
    setAutoPip(false);
  }

  /// Masuk mode fullscreen (True OS Fullscreen di Windows, Immersive di Mobile)
  Future<bool> enterFullscreen() async {
    isFullscreen.value = true;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final result = await _channel.invokeMethod<bool>('setFullScreen', {'fullscreen': true});
        return result ?? true;
      } catch (e) {
        debugPrint('[PipService] enterFullscreen error: $e');
        return false;
      }
    } else {
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
             defaultTargetPlatform == TargetPlatform.iOS)) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          try {
            await _channel.invokeMethod<bool>('enterFullscreen');
          } catch (e) {
            debugPrint('[PipService] enterFullscreen native error: $e');
          }
        }
        return true;
      } catch (e) {
        debugPrint('[PipService] enterFullscreen mobile error: $e');
        return false;
      }
    }
  }

  /// Keluar dari mode fullscreen dan kembalikan window/orientasi normal
  Future<bool> exitFullscreen() async {
    isFullscreen.value = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final result = await _channel.invokeMethod<bool>('setFullScreen', {'fullscreen': false});
        return result ?? true;
      } catch (e) {
        debugPrint('[PipService] exitFullscreen error: $e');
        return false;
      }
    } else {
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
             defaultTargetPlatform == TargetPlatform.iOS)) {
          try {
            await _channel.invokeMethod<bool>('exitFullscreen');
          } catch (e) {
            debugPrint('[PipService] exitFullscreen native error: $e');
          }
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
        return true;
      } catch (e) {
        debugPrint('[PipService] exitFullscreen mobile error: $e');
        return false;
      }
    }
  }

  /// Masuk mode PiP secara manual (hanya jika sedang di layar video yang aktif)
  Future<bool> enterPip() async {
    if (!_isVideoScreenActive) {
      debugPrint('[PipService] Denied enterPip: not in an active video screen');
      return false;
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.windows)) {
      isInPip.value = true;
      try {
        final result = await _channel.invokeMethod<bool>('enterPip');
        if (result != true) {
          isInPip.value = false;
        }
        return result ?? false;
      } catch (e) {
        isInPip.value = false;
        debugPrint('[PipService] enterPip error: $e');
        return false;
      }
    }
    return false;
  }

  /// Keluar dari mode PiP secara manual (terutama di Windows untuk merestorasi window)
  Future<bool> exitPip() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final result = await _channel.invokeMethod<bool>('exitPip');
        if (result == true) {
          isInPip.value = false;
        }
        return result ?? false;
      } catch (e) {
        debugPrint('[PipService] exitPip error: $e');
        isInPip.value = false;
        return false;
      }
    }
    isInPip.value = false;
    return true;
  }

  /// Memulai drag window di desktop (Windows) saat dalam mode PiP
  Future<void> startDragging() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await _channel.invokeMethod('startDragging');
      } catch (_) {}
    }
  }

  Future<void> setAutoPip(bool enabled) async {
    isAutoPipEnabled = enabled;
    // Pengaman: Jangan biarkan Auto-PiP aktif jika layar video tidak aktif
    final bool effectiveEnabled = enabled && _isVideoScreenActive;
    isAutoPipEnabled = effectiveEnabled;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('setAutoPip', {'enabled': effectiveEnabled});
      } catch (e) {
        debugPrint('[PipService] setAutoPip error: $e');
      }
    }
  }
}