import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../data/models/app_update_model.dart';
import '../presentation/app_update_dialog.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String currentVersion = '1.2.4';
  static const int currentBuildNumber = 2044;

  /// Notifier untuk update yang tersedia (agar UI profil & navbar dapat merespons tanpa pop-up)
  final ValueNotifier<AppUpdateModel?> availableUpdateNotifier = ValueNotifier<AppUpdateModel?>(null);
  AppUpdateModel? get availableUpdate => availableUpdateNotifier.value;

  static List<String> get updateUrls => [
    '${ApiConfig.baseUrl}/api/version/update',
    '${ApiConfig.baseUrl}/version_config.json',
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'Moko/$currentVersion (Android; Mobile)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Fetch remote version configuration from API or GitHub Releases
  Future<AppUpdateModel?> fetchVersionConfig() async {
    AppUpdateModel? backendModel;

    // 1. Try backend endpoints first
    for (final url in updateUrls) {
      try {
        final resp = await _dio.get<dynamic>(url);
        if (resp.statusCode == 200 && resp.data != null) {
          final data = resp.data is Map
              ? Map<String, dynamic>.from(resp.data as Map)
              : null;
          if (data != null) {
            backendModel = AppUpdateModel.fromJson(data);
            break;
          }
        }
      } catch (_) {
        // Continue to fallback url
      }
    }

    // 2. Query GitHub Releases API for latest release directly
    try {
      final ghResp = await _dio.get<dynamic>(
        'https://api.github.com/repos/zyanmd/Pipos/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Moko-InAppUpdater',
          },
        ),
      );

      if (ghResp.statusCode == 200 && ghResp.data is Map) {
        final d = Map<String, dynamic>.from(ghResp.data as Map);
        final rawTag = (d['tag_name']?.toString() ?? '')
            .replaceAll(RegExp(r'^[vV]'), '')
            .trim();
        final body = d['body']?.toString() ?? '';
        final htmlUrl = d['html_url']?.toString() ?? 'https://github.com/zyanmd/Pipos/releases/latest';

        // Check assets size
        String? assetSizeStr;
        final assets = d['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          final firstApk = assets.firstWhere(
            (a) => (a['name']?.toString() ?? '').toLowerCase().endsWith('.apk'),
            orElse: () => null,
          );
          if (firstApk != null && firstApk['size'] is num) {
            final mb = (firstApk['size'] as num) / (1024 * 1024);
            assetSizeStr = '~${mb.toStringAsFixed(0)} MB';
          }
        }

        final ghModel = AppUpdateModel(
          version: rawTag.isNotEmpty ? rawTag : currentVersion,
          buildDate: d['published_at']?.toString(),
          buildNumber: 0,
          forceUpdate: false,
          updateUrl: htmlUrl,
          fileSize: assetSizeStr ?? '~68 MB',
          releaseNotes: body,
          changelog: [
            UpdateChangelogItem(
              version: rawTag,
              date: d['published_at']?.toString().split('T').first,
              changes: body.isNotEmpty
                  ? body
                  : '🚀 **Pembaruan v$rawTag**\nPeningkatan performa dan perbaikan bug.',
            ),
          ],
        );

        // If backend model is absent, or if GitHub release is newer than backend model, prefer GitHub!
        if (backendModel == null) {
          return ghModel;
        } else if (isVersionHigher(ghModel.version, backendModel.version)) {
          return ghModel;
        }
      }
    } catch (_) {
      // Continue with backendModel if GitHub is unreachable
    }

    return backendModel;
  }

  /// Check if remote version is newer than current version.
  /// If current version is already higher than remote or equal, no update needed.
  static bool isUpdateAvailable(AppUpdateModel remote) {
    // 1. If current version is strictly higher than remote, no update needed
    if (isVersionHigher(currentVersion, remote.version)) {
      return false;
    }
    // 2. If remote version is strictly higher than current version, update is available
    if (isVersionHigher(remote.version, currentVersion)) {
      return true;
    }
    // 3. If version strings are equal (e.g. both 1.1.0):
    // Only available if remote build number is strictly higher than current build number
    if (remote.buildNumber > currentBuildNumber) {
      return true;
    }
    // Same version and same/lower build number -> NO UPDATE
    return false;
  }

  /// Whether an update must be enforced (blocking popup).
  ///
  /// RULES:
  /// 1. If manual check -> NEVER mandatory (user must be able to dismiss).
  /// 2. If current version is equal to or higher than remote -> NEVER mandatory.
  ///    (If the user already has the same version or higher, never force update!)
  /// 3. Only mandatory if remote version is strictly higher than current version
  ///    AND (remote.forceUpdate is true OR current version is lower than remote.minimumVersion).
  static bool isUpdateMandatory(AppUpdateModel remote, {bool isManual = false}) {
    if (isManual) return false;

    // SAMA VERSI / LEBIH TINGGI -> JANGAN PERNAH PAKSA UPDATE!
    if (!isVersionHigher(remote.version, currentVersion)) {
      return false;
    }

    if (remote.minimumVersion != null && remote.minimumVersion!.isNotEmpty) {
      if (isVersionHigher(remote.minimumVersion!, currentVersion)) {
        return true;
      }
    }

    return remote.forceUpdate;
  }

  /// Returns true if [v1] version string is strictly higher than [v2]
  static bool isVersionHigher(String v1, String v2) {
    try {
      final p1 = v1.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final p2 = v2.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

      final maxLen = p1.length > p2.length ? p1.length : p2.length;
      for (var i = 0; i < maxLen; i++) {
        final a = i < p1.length ? p1[i] : 0;
        final b = i < p2.length ? p2[i] : 0;
        if (a > b) return true;
        if (a < b) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Automatically check update and display popup dialog if available.
  ///
  /// When [isManual] is true (triggered from Profile), shows feedback
  /// even when no update or server is unreachable.
  Future<void> checkAndShowUpdate(
    BuildContext context, {
    bool isManual = false,
  }) async {
    final update = await fetchVersionConfig();

    if (!context.mounted) return;

    if (update != null) {
      if (isUpdateAvailable(update)) {
        availableUpdateNotifier.value = update;
        // Permintaan user: Jangan tampilkan pop up otomatis lagi, cukup notif di profil saja.
        // Dialog pembaruan HANYA ditampilkan jika dipicu secara manual (isManual == true).
        if (isManual) {
          AppUpdateDialog.show(
            context,
            update: update,
            currentVersion: currentVersion,
            isManual: true,
          );
        }
      } else {
        availableUpdateNotifier.value = null;
        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aplikasi Moko sudah versi terbaru ($currentVersion).',
            ),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'Lihat Info',
              textColor: Colors.white,
              onPressed: () {
                AppUpdateDialog.show(
                  context,
                  update: update,
                  currentVersion: currentVersion,
                  isManual: true,
                );
              },
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } else if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Server tidak tersedia. Menampilkan info versi terakhir.',
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Lihat',
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) {
                AppUpdateDialog.show(
                  context,
                  update: _localVersionInfo,
                  currentVersion: currentVersion,
                  isManual: true,
                );
              }
            },
          ),
        ),
      );
    }
    // When !isManual and server unreachable â†’ do nothing silently
  }

  /// Sample update config (dipakai untuk keperluan testing)
  static final AppUpdateModel sampleUpdateConfig = AppUpdateModel(
    version: '1.0.15',
    buildDate: '2026-09-08 00:00:00',
    buildNumber: 15,
    forceUpdate: false,
    minimumVersion: '1.0.15',
    updateUrl: 'https://sfile.co/Dj19cVRkhLH',
    fileSize: '~98 MB',
    changelog: const [
      UpdateChangelogItem(
        version: '1.1.6',
        date: '2026-09-28',
        changes:
            '✨ **Versi 1.1.6 - Desain Baru ala Instagram & Ticker Berita!**\n'
            '• **Tampilan Feed ala Instagram** - Stories tray anime rilis hari ini dengan ring gradient IG, kartu feed modern dengan rasio sinematik 16:10, serta tombol aksi cepat\n'
            '• **Running Teks Berita Komunitas** - Marquee ticker tanpa jeda menampilkan 5 pesan komunitas terkini\n'
            '• **Navigasi Docked & Instagram Web** - Tombol navigasi minimalis, ring avatar profil, dan navigasi samping desktop yang elegan\n'
            '• **Optimasi Pemutar Video** - Pemuatan resolusi bertahap yang lebih lancar dan aman',
      ),
      UpdateChangelogItem(
        version: '1.0.15',
        date: '2026-09-08',
        changes:
            'ðŸŽ¬ **Fitur Baru dan Perbaikan!**\nâ€¢ **Dropdown Episode Anime**\nâ€¢ **Penanda Episode Ditonton**\nâ€¢ **Perbaikan History**\nâ€¢ **Sembunyikan 0m ditonton**\nâ€¢ **Sembunyikan Status Bar**\nâ€¢ **Perbaikan berbagai bug**',
      ),
      UpdateChangelogItem(
        version: '1.0.14',
        date: '2026-09-02',
        changes:
            'ðŸ”„ **Update Icon dan Splash Screen!**\nâ€¢ Pembaruan icon aplikasi\nâ€¢ Pembaruan splash screen\nâ€¢ Perbaikan tampilan di Android',
      ),
    ],
    releaseNotes:
        'ðŸŽ¬ **Versi 1.0.15 - Fitur Baru dan Perbaikan!**\n\nðŸ“± **Update sekarang untuk pengalaman menonton yang lebih baik!**',
  );

  /// Local version info (ditampilkan saat server unreachable)
  static final AppUpdateModel _localVersionInfo = AppUpdateModel(
    version: currentVersion,
    buildDate: '2026-09-14 00:00:00',
    buildNumber: currentBuildNumber,
    forceUpdate: false,
    minimumVersion: '1.0.15',
    updateUrl: 'https://sfile.co/Dj19cVRkhLH',
    fileSize: '~98 MB',
    changelog: const [
      UpdateChangelogItem(
        version: '1.2.4',
        date: '2026-11-10',
        changes:
            '✨ **Versi 1.2.4 - Desain Apple iOS Modern & Rotasi Fullscreen Otomatis!**\n'
            '• **Desain Apple iOS HIG Modern & Elegan** - Pembaruan visual menyeluruh pada tab Ulasan, Lembar Komentar (gaya iOS Messages), Dialog Tulis Ulasan, dan Pemilih Judul dengan efek Frosted Glass (blur).\n'
            '• **Rotasi Fullscreen Cerdas 180° (Sensor Landscape)** - Layar otomatis berputar saat HP diputar ke arah berlawanan saat fullscreen, bahkan jika rotasi otomatis dikunci.\n'
            '• **Perbaikan Posting Ulasan & Komentar** - Penanganan target ID andal, auto-prefill ulasan lama, notifikasi sukses, dan aksi tulis ulasan langsung dari feed.',
      ),
      UpdateChangelogItem(
        version: '1.2.3',
        date: '2026-10-17',
        changes:
            '🤖 **Versi 1.2.3 - Moko AI Universal Assistant & Kustomisasi Lengkap!**\n'
            '• **Moko AI Floating Bubble** - Asisten AI mengambang di seluruh layar yang responsif dengan auto-snap dan auto-hide saat fullscreen\n'
            '• **Kustomisasi Profil Lengkap ("Ganti Semuanya")** - AI dapat mengubah username, nama tampilan, bio, bingkai avatar, font profil, tema gelap/terang, dan mode 18+ dalam satu perintah\n'
            '• **Perbaikan Ganti Username** - Username kini dapat diubah bebas baik di Edit Profil maupun otomatis via Moko AI\n'
            '• **Dukungan Light Novel & Web Novel** - Integrasi pencarian cerdas katalog novel dan analisis multimodal dari unggahan foto/screenshot\n'
            '• **Visual Bersih & Aman** - Seluruh konfigurasi sensitif backend tersembunyi rapi',
      ),
      UpdateChangelogItem(
        version: '1.2.2',
        date: '2026-10-14',
        changes:
            '🖼️ **Versi 1.2.2 - Foto Profil di Notifikasi & Optimasi 120 FPS!**\n'
            '• **Foto Profil & Bingkai di Notifikasi** - Menampilkan avatar asli, animasi GIF/WebP, dan bingkai interaktif (dapat diketuk untuk membuka kartu profil)\n'
            '• **Performa 60-120 FPS Super Mulus** - Isolasi RepaintBoundary pada seluruh efek blur layar bebas lag & hemat baterai\n'
            '• **Desain Konsisten & Ringan** - Penyesuaian sigma blur ringan (8), momentum scroll elastis (Bouncing Physics), dan perbaikan kontras tema modern',
      ),
      UpdateChangelogItem(
        version: '1.2.1',
        date: '2026-10-13',
        changes:
            '🎬 **Versi 1.2.1 - Pemutar Video Universal & Auto-Fallback Server!**\n'
            '• **Dukungan Semua HP (10-Bit H.264 & MKV)** - Engine FFmpeg / fvp yang mendukung decoding format 10-bit di seluruh smartphone (Gintama eps 70 dsb)\n'
            '• **Smart Multi-Server Auto-Fallback** - Otomatis beralih ke Server 2, Server 3, atau resolusi cadangan jika server utama bermasalah\n'
            '• **Bypass Blokir ISP via Stream Proxy** - Stream langsung dapat diputar lancar tanpa hambatan DNS/ISP',
      ),
      UpdateChangelogItem(
        version: '1.2.0',
        date: '2026-10-06',
        changes:
            '🚀 **Versi 1.2.0 - Pemutar Video Baru & Optimasi Playback!**\n'
            '• **Engine Pemutar Video Baru** - Migrasi ke ExoPlayer & Chewie untuk pemutaran video langsung lancar tanpa freeze atau deadlock\n'
            '• **Riwayat Nonton Bersih** - Pencatatan riwayat fokus per episode tanpa bug broken resume\n'
            '• **Peningkatan Kecepatan & Stabilitas** - Pengurangan background timer dan koneksi S3 instan',
      ),
      UpdateChangelogItem(
        version: '1.1.9',
        date: '2026-10-05',
        changes:
            '📢 **Versi 1.1.9 - Integrasi Pemberitahuan & Perapian Profil!**\n'
            '• **Sistem Pemberitahuan Terpadu** - Banner pengumuman aktif terhubung ke server dan OneSignal di Anime, Komik, Anime 18+, dan Komik 18+\n'
            '• **Penyempurnaan Profil** - Pembersihan menu ganda dan tata letak frosted yang lebih elegan\n'
            '• **Peningkatan performa dan kestabilan aplikasi**',
      ),
      UpdateChangelogItem(
        version: '1.1.6',
        date: '2026-09-28',
        changes:
            '✨ **Versi 1.1.6 - Desain Baru ala Instagram & Ticker Berita!**\n'
            '• **Tampilan Feed ala Instagram** - Stories tray anime rilis hari ini dengan ring gradient IG, kartu feed modern dengan rasio sinematik 16:10, serta tombol aksi cepat\n'
            '• **Running Teks Berita Komunitas** - Marquee ticker tanpa jeda menampilkan 5 pesan komunitas terkini\n'
            '• **Navigasi Docked & Instagram Web** - Tombol navigasi minimalis, ring avatar profil, dan navigasi samping desktop yang elegan\n'
            '• **Optimasi Pemutar Video** - Pemuatan resolusi bertahap yang lebih lancar dan aman',
      ),
      UpdateChangelogItem(
        version: '1.1.5',
        date: '2026-09-20',
        changes:
            'ðŸŽ¬ **Versi 1.1.5 - Perbaikan Kecepatan & Kontrol Pemutar!**\n'
            'â€¢ **Perbaikan Kecepatan Pemutaran Fullscreen** - Kontrol kecepatan kini responsif dan bekerja mulus saat mode layar penuh\n'
            'â€¢ **Penyempurnaan Sinkronisasi Progres Nonton** - Durasi riwayat nonton kini presisi per episode tanpa bug duplikasi\n'
            'â€¢ **Optimasi Tampilan Layar Penuh Anime & Nekopoi**',
      ),
      UpdateChangelogItem(
        version: '1.1.4',
        date: '2026-09-19',
        changes:
            'ðŸŽ¬ **Versi 1.1.4 - Fitur Picture-in-Picture (PiP)!**\n'
            'â€¢ **Mode PiP di Anime & Nekopoi** - Tonton video di jendela mengambang mini sambil membuka aplikasi lain\n'
            'â€¢ **Auto-PiP Support** - Otomatis masuk mode PiP saat menekan tombol Home (Android 8.0+)\n'
            'â€¢ **Pemutaran Latar Belakang** - Video tetap berjalan lancar tanpa terhenti saat jendela PiP aktif\n'
            'â€¢ **Peningkatan performa dan stabilitas**',
      ),
      UpdateChangelogItem(
        version: '1.1.3',
        date: '2026-09-17',
        changes:
            'ðŸŽ¬ **Versi 1.1.3 - Perbaikan Pemutar Video!**\n'
            'â€¢ **Perbaikan Ganti Server & Resolusi** - Transisi video mulus tanpa error interupsi\n'
            'â€¢ **Swipe to Reply** - Geser pesan chat & komentar untuk membalas cepat\n'
            'â€¢ **Sinkronisasi Waktu Perangkat** - Jam chat & komentar akurat sesuai waktu lokal\n'
            'â€¢ **Penyempurnaan Font & Bingkai Profil** - Tampilan profil lebih presisi\n'
            'â€¢ **Peningkatan performa dan stabilitas**',
      ),
      UpdateChangelogItem(
        version: '1.1.1',
        date: '2026-09-17',
        changes:
            'ðŸŽ¬ **Versi 1.1.1 - Fitur Baru & Perbaikan Waktu!**\n'
            'â€¢ **Swipe to Reply** - Geser pesan chat & komentar untuk membalas cepat\n'
            'â€¢ **Sinkronisasi Waktu Perangkat** - Jam chat & komentar akurat sesuai waktu lokal\n'
            'â€¢ **Penyempurnaan Font & Bingkai Profil** - Tampilan profil lebih presisi\n'
            'â€¢ **Peningkatan performa dan stabilitas**',
      ),
      UpdateChangelogItem(
        version: '1.1.0',
        date: '2026-09-14',
        changes:
            'ðŸŽ¬ **Versi 1.1.0 - Update Besar!**\n'
            'â€¢ **Daftar Anime A-Z** - Jelajahi katalog anime lengkap berdasarkan alfabet\n'
            'â€¢ **Slider Informasi** - Banner info & pengumuman di beranda\n'
            'â€¢ **Desain Login & Register baru** - Tampilan minimalis modern\n'
            '• **Ganti Icon & Nama** - Icon baru dari logos.png, nama Moko\n'
            'â€¢ **Popup Update** - Notifikasi pembaruan otomatis dari server\n'
            'â€¢ **YLnime Fallback** - Detail anime otomatis dari YLnime\n'
            'â€¢ **Perbaikan berbagai bug** dan peningkatan performa',
      ),
      UpdateChangelogItem(
        version: '1.0.15',
        date: '2026-09-08',
        changes:
            'ðŸŽ¬ **Fitur Baru dan Perbaikan!**\n'
            'â€¢ **Dropdown Episode Anime** - Lihat daftar semua episode dengan cepat\n'
            'â€¢ **Penanda Episode Ditonton** - Tanda hijau untuk episode yang sudah ditonton\n'
            'â€¢ **Perbaikan History** - History sekarang menampilkan episode yang benar\n'
            'â€¢ **Sembunyikan Status Bar** - Pengalaman menonton lebih imersif',
      ),
    ],
    releaseNotes:
        '🎬 **Moko $currentVersion**\n\n'
        'Anda sudah menggunakan versi terbaru.\n\n'
        '**Fitur Terbaru:**\n'
        'â€¢ Daftar Anime A-Z\n'
        'â€¢ Slider Informasi\n'
        'â€¢ Desain Login & Register baru\n'
        'â€¢ Popup Update Otomatis\n\n'
        'ðŸ“± **Tidak ada pembaruan yang tersedia.**',
  );
}