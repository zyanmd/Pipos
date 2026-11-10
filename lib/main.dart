import 'dart:io' show Platform;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'core/network/api_client.dart';
import 'core/services/admob_service.dart';
import 'core/services/adult_content_service.dart';
import 'core/services/anime_watch_progress_service.dart';
import 'core/services/display_mode_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/onesignal_service.dart';
import 'core/services/pip_service.dart';
import 'core/theme/app_theme.dart';
import 'features/anime/data/anime_repository.dart';
import 'features/notifications/services/universal_notification_service.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/widgets/app_404_screen.dart';
import 'shared/widgets/app_network_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    final isAndroid = Platform.isAndroid;
    fvp.registerWith(
      options: {
        'platforms': ['android', 'windows', 'linux', 'macos', 'ios'],
        'video.decoders': isAndroid
            ? ['AMediaCodec', 'FFmpeg', 'dav1d']
            : ['D3D11', 'DXVA', 'NVDEC', 'FFmpeg'],
        'player': {
          'buffer.range': isAndroid ? '30000' : '60000',
          'demuxer.max_bytes': isAndroid ? '33554432' : '104857600',
          'demuxer.max_back_bytes': isAndroid ? '16777216' : '33554432',
          'avio.buffer_size': '65536',
          'avio.reconnect': '1',
          'avio.reconnect_streamed': '1',
          'avio.reconnect_delay_max': '7',
        },
        'global': {
          'demuxer.max_bytes': isAndroid ? 33554432 : 104857600,
        },
      },
    );
  }

  // Clear any residual image disk cache so local storage is not occupied permanently
  AppNetworkImage.clearDiskCache().ignore();

  // Optimasi ImageCache Flutter untuk scrolling komik dan anime mulus tanpa evicted / reload
  final isWindowsDesktop = !kIsWeb && Platform.isWindows;
  PaintingBinding.instance.imageCache.maximumSize = isWindowsDesktop ? 1000 : 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = isWindowsDesktop ? (500 << 20) : (350 << 20);

  // Paksa display mode ke refresh rate tertinggi tanpa memblokir thread awal
  DisplayModeService.instance.forceHighRefreshRate().ignore();

  // Shield users from raw red screen errors in Flutter runtime
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AppNotFoundWidget(
          title: 'Terjadi Kendala Tampilan',
          subtitle: 'Komponen layar ini mengalami kendala sementara.',
        ),
      ),
    );
  };

  // Edge-to-edge display with transparent navigation bar (iOS style)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inisialisasi service inti secara paralel (hemat waktu startup puluhan kali lipat)
  await Future.wait([
    ApiClient.init(),
    ThemeProvider.instance.init(),
    AdultContentService.instance.init(),
    AnimeWatchProgressService.instance.init(),
  ]);

  // Restore session auth secara instan dari cache lokal (0ms, tanpa flicker)
  AuthProvider.instance.fastRestore();

  // Background services & validasi profil (berjalan di background tanpa memblokir layar pertama)
  AdMobService.instance.init();
  UniversalNotificationService.instance.init();
  OneSignalService.instance.init().ignore();
  AuthProvider.instance.refreshProfileInBackground().ignore();

  // Prefetch data anime home saat splash screen mulai berjalan
  AnimeRepository.instance.prefetchHome();

  runApp(const MokoApp());
}

class MokoApp extends StatefulWidget {
  const MokoApp({super.key});

  @override
  State<MokoApp> createState() => _MokoAppState();
}

class _MokoAppState extends State<MokoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidgetService.instance.init(OneSignalService.navigatorKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DisplayModeService.instance.reassertOnResume();
      UniversalNotificationService.instance.refreshUnreadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ThemeProvider.instance),
        ChangeNotifierProvider.value(value: AuthProvider.instance),
        ChangeNotifierProvider.value(value: AdultContentService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (ctx, theme, _) {
          return MaterialApp(
            navigatorKey: OneSignalService.navigatorKey,
            title: 'MOKO',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildLight(animationsEnabled: theme.isAnimationEnabled),
            darkTheme: AppTheme.buildDark(animationsEnabled: theme.isAnimationEnabled),
            themeMode: theme.flutterMode,
            navigatorObservers: [PipService.routeObserver],
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
              physics: (!kIsWeb && Platform.isWindows)
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              scrollbars: !kIsWeb && Platform.isWindows,
            ),
            home: const SplashScreen(),
            onUnknownRoute: (settings) => CupertinoPageRoute(
              builder: (_) => const App404Screen(),
            ),
            builder: (ctx, child) {
              return MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  // Make text scale a bit more readable on big phones.
                  textScaler: TextScaler.linear(
                    (MediaQuery.of(ctx).textScaler.scale(1.0)).clamp(0.9, 1.15),
                  ),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

typedef AnimeVerseApp = MokoApp;
