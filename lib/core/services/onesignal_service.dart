import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../../../features/anime/presentation/anime_detail_screen.dart';
import '../../../features/comic/presentation/comic_detail_screen.dart';
import '../../../features/notifications/presentation/universal_notification_modal.dart';
import '../../../features/auth/data/models/user_model.dart';
import 'package:moko/features/announcement/data/models/announcement_model.dart';
import 'package:moko/features/announcement/data/announcement_repository.dart';
import 'package:moko/features/announcement/presentation/widgets/announcement_banner.dart';

/// Centralized service untuk mengelola Push Notifications OneSignal.
/// Langsung meminta izin ke pengguna saat app dibuka, menampilkan banner notifikasi
/// baik di foreground maupun background, dan otomatis membuka anime saat diklik.
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  /// OneSignal App ID
  static const String defaultAppId = "49b24944-db96-43b7-bfb6-da98bf1c6dcd";
  static const String _kCustomAppIdKey = "onesignal_app_id_custom";

  /// Global NavigatorKey untuk navigasi langsung ke detail anime
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isInitialized = false;
  Completer<void> _initCompleter = Completer<void>();
  String? _pendingExternalId;
  final Map<String, String> _pendingTags = {};

  Future<bool> _ensureInitialized() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    if (_isInitialized) return true;
    try {
      await _initCompleter.future.timeout(const Duration(seconds: 12));
    } catch (_) {}
    return _isInitialized;
  }

  static const String kNotifModeKey = "notif_release_mode"; // 'all' atau 'bookmarked'
  static const String kAnimeNotifModeKey = "notif_anime_release_mode"; // 'all', 'bookmarked', 'off'
  static const String kComicNotifModeKey = "notif_comic_release_mode"; // 'all', 'bookmarked', 'off'
  static const String kBirthdayNotifEnabledKey = "notif_birthday_enabled"; // bool

  /// Mode notifikasi rilisan:
  String _notifMode = 'all';
  String _animeNotifMode = 'all';
  String _comicNotifMode = 'all';
  bool _birthdayNotifEnabled = true;

  String get notifMode => _notifMode;
  String get animeNotifMode => _animeNotifMode;
  String get comicNotifMode => _comicNotifMode;
  bool get birthdayNotifEnabled => _birthdayNotifEnabled;

  String get summaryLabel {
    final a = _animeNotifMode == 'all'
        ? 'Semua'
        : (_animeNotifMode == 'bookmarked' ? 'Bookmark' : 'Mati');
    final c = _comicNotifMode == 'all'
        ? 'Semua'
        : (_comicNotifMode == 'bookmarked' ? 'Bookmark' : 'Mati');
    final b = _birthdayNotifEnabled ? 'Aktif' : 'Mati';
    return 'Anime: $a • Komik: $c • Ultah: $b';
  }

  /// Cek apakah suatu series_key / anime_id ada di daftar bookmark
  Future<bool> _isAnimeBookmarked(String animeKey) async {
    if (animeKey.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedList = prefs.getStringList('local_bookmarked_anime_ids') ?? [];
      final cleanKey = animeKey.toLowerCase().replaceAll('/', '').trim();
      for (final id in cachedList) {
        final cleanId = id.toLowerCase().replaceAll('/', '').trim();
        if (cleanId == cleanKey || cleanKey.contains(cleanId) || cleanId.contains(cleanKey)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Cek apakah suatu comic slug ada di daftar bookmark
  Future<bool> _isComicBookmarked(String comicSlug) async {
    if (comicSlug.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedList = prefs.getStringList('local_bookmarked_comic_slugs') ?? [];
      final cleanSlug = comicSlug.toLowerCase().replaceAll('/', '').trim();
      for (final s in cachedList) {
        final cleanS = s.toLowerCase().replaceAll('/', '').trim();
        if (cleanS == cleanSlug || cleanSlug.contains(cleanS) || cleanS.contains(cleanSlug)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Ubah preferensi notifikasi anime ('all', 'bookmarked', atau 'off')
  Future<void> setAnimeNotifMode(String mode) async {
    _animeNotifMode = mode;
    _notifMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAnimeNotifModeKey, mode);
    await prefs.setString(kNotifModeKey, mode);
    await addTag('notif_anime', mode);
    if (mode == 'bookmarked') {
      await addTag('notif_preference', 'bookmarked_only');
    } else if (mode == 'off') {
      await addTag('notif_preference', 'off');
    } else {
      await addTag('notif_preference', 'all');
    }
    _syncWithBackend();
  }

  /// Ubah preferensi notifikasi komik ('all', 'bookmarked', atau 'off')
  Future<void> setComicNotifMode(String mode) async {
    _comicNotifMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kComicNotifModeKey, mode);
    await addTag('notif_comic', mode);
    _syncWithBackend();
  }

  /// Ubah preferensi notifikasi ulang tahun (true = aktif, false = mati)
  Future<void> setBirthdayNotifEnabled(bool enabled) async {
    _birthdayNotifEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBirthdayNotifEnabledKey, enabled);
    await addTag('notif_birthday', enabled ? 'true' : 'false');
    _syncWithBackend();
  }

  /// Sinkronisasi preferensi notifikasi dari profil pengguna yang didapat dari server
  Future<void> syncFromServer(
    String serverMode, {
    String? animeMode,
    String? comicMode,
    bool? birthdayEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final aMode = animeMode ?? serverMode;
      final cMode = comicMode ?? serverMode;
      final bEnabled = birthdayEnabled ?? true;

      _notifMode = serverMode.isNotEmpty ? serverMode : 'all';
      _animeNotifMode = aMode.isNotEmpty ? aMode : _notifMode;
      _comicNotifMode = cMode.isNotEmpty ? cMode : _notifMode;
      _birthdayNotifEnabled = bEnabled;

      await prefs.setString(kNotifModeKey, _notifMode);
      await prefs.setString(kAnimeNotifModeKey, _animeNotifMode);
      await prefs.setString(kComicNotifModeKey, _comicNotifMode);
      await prefs.setBool(kBirthdayNotifEnabledKey, _birthdayNotifEnabled);

      await addTag('notif_anime', _animeNotifMode);
      await addTag('notif_comic', _comicNotifMode);
      await addTag('notif_birthday', _birthdayNotifEnabled ? 'true' : 'false');

      if (_animeNotifMode == 'bookmarked' || _notifMode == 'bookmarked') {
        await addTag('notif_preference', 'bookmarked_only');
      } else if (_animeNotifMode == 'off' && _comicNotifMode == 'off') {
        await addTag('notif_preference', 'off');
      } else {
        await addTag('notif_preference', 'all');
      }
    } catch (e) {
      debugPrint('[OneSignal] syncFromServer error: $e');
    }
  }

  /// Ubah preferensi notifikasi umum (backward compatible)
  Future<void> setNotifMode(String mode) async {
    _notifMode = (mode == 'bookmarked' || mode == 'off') ? mode : 'all';
    _animeNotifMode = _notifMode;
    _comicNotifMode = _notifMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kNotifModeKey, _notifMode);
    await prefs.setString(kAnimeNotifModeKey, _animeNotifMode);
    await prefs.setString(kComicNotifModeKey, _comicNotifMode);

    if (_notifMode == 'bookmarked') {
      await addTag('notif_preference', 'bookmarked_only');
    } else if (_notifMode == 'off') {
      await addTag('notif_preference', 'off');
    } else {
      await addTag('notif_preference', 'all');
    }
    _syncWithBackend();
  }

  void _syncWithBackend() async {
    try {
      final token = await TokenStore.access;
      if (token != null && token.isNotEmpty) {
        final String effectiveMode;
        if (_animeNotifMode == 'off') {
          effectiveMode = 'off';
        } else if (_animeNotifMode == 'bookmarked' || _notifMode == 'bookmarked') {
          effectiveMode = 'bookmarked';
        } else {
          effectiveMode = 'all';
        }
        final res = await ApiClient.instance.post(
          ApiEndpoints.userNotificationPreference,
          data: {
            'notif_mode': effectiveMode,
            'anime_notif_mode': _animeNotifMode,
            'comic_notif_mode': _comicNotifMode,
            'birthday_notif_enabled': _birthdayNotifEnabled,
          },
        );
        debugPrint('[OneSignal] Synced preference to backend: ${res.statusCode} (mode: $effectiveMode)');
      }
    } catch (e) {
      debugPrint('[OneSignal] Error syncing preference with backend: $e');
    }
  }

  /// Tampilkan modal pilihan preferensi notifikasi rilisan anime/komik
  static Future<void> showPreferenceModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final animeMode = instance.animeNotifMode;
            final comicMode = instance.comicNotifMode;
            final birthdayEnabled = instance.birthdayNotifEnabled;

            Widget buildOptionTile({
              required String title,
              required String subtitle,
              required IconData icon,
              required Color color,
              required bool isSelected,
              required VoidCallback onTap,
            }) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70)),
                ),
                trailing: isSelected
                    ? Icon(CupertinoIcons.checkmark_alt_circle_fill, color: color, size: 22)
                    : Icon(CupertinoIcons.circle, color: isDark ? Colors.white24 : Colors.black26, size: 20),
                onTap: onTap,
              );
            }

            Widget buildSectionHeader(String title, IconData icon, Color color) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                child: Row(
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                            ),
                            child: const Icon(CupertinoIcons.bell_fill, color: Color(0xFFFF9500), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pengaturan Notifikasi Push',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        'Atur notifikasi anime, komik, dan ulang tahun yang muncul di layar HP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        children: [
                          // 1. Anime Section
                          buildSectionHeader('NOTIFIKASI ANIME', CupertinoIcons.play_rectangle_fill, const Color(0xFF007AFF)),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              children: [
                                buildOptionTile(
                                  title: 'Semua Episode Baru',
                                  subtitle: 'Terima notifikasi untuk semua anime yang baru rilis',
                                  icon: CupertinoIcons.bell_fill,
                                  color: const Color(0xFF007AFF),
                                  isSelected: animeMode == 'all',
                                  onTap: () async {
                                    await instance.setAnimeNotifMode('all');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Anime: Semua Rilisan Baru'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, indent: 46, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                buildOptionTile(
                                  title: 'Khusus Anime Bookmark',
                                  subtitle: 'Hanya anime yang sudah Anda simpan di daftar Bookmark',
                                  icon: CupertinoIcons.bookmark_fill,
                                  color: const Color(0xFFFF9500),
                                  isSelected: animeMode == 'bookmarked',
                                  onTap: () async {
                                    await instance.setAnimeNotifMode('bookmarked');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Anime: Khusus Anime Bookmark'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, indent: 46, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                buildOptionTile(
                                  title: 'Matikan Notifikasi Anime',
                                  subtitle: 'Tidak menerima notifikasi push untuk rilisan anime',
                                  icon: CupertinoIcons.bell_slash_fill,
                                  color: const Color(0xFF8E8E93),
                                  isSelected: animeMode == 'off',
                                  onTap: () async {
                                    await instance.setAnimeNotifMode('off');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Anime: Dimatikan'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 2. Comic Section
                          buildSectionHeader('NOTIFIKASI KOMIK', CupertinoIcons.book_fill, const Color(0xFFAF52DE)),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              children: [
                                buildOptionTile(
                                  title: 'Semua Chapter Baru',
                                  subtitle: 'Terima notifikasi untuk semua komik yang baru rilis',
                                  icon: CupertinoIcons.bell_fill,
                                  color: const Color(0xFFAF52DE),
                                  isSelected: comicMode == 'all',
                                  onTap: () async {
                                    await instance.setComicNotifMode('all');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Komik: Semua Chapter Baru'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, indent: 46, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                buildOptionTile(
                                  title: 'Khusus Komik Bookmark',
                                  subtitle: 'Hanya komik yang sudah Anda simpan di daftar Bookmark',
                                  icon: CupertinoIcons.bookmark_fill,
                                  color: const Color(0xFFFF9500),
                                  isSelected: comicMode == 'bookmarked',
                                  onTap: () async {
                                    await instance.setComicNotifMode('bookmarked');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Komik: Khusus Komik Bookmark'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, indent: 46, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                buildOptionTile(
                                  title: 'Matikan Notifikasi Komik',
                                  subtitle: 'Tidak menerima notifikasi push untuk rilisan komik',
                                  icon: CupertinoIcons.bell_slash_fill,
                                  color: const Color(0xFF8E8E93),
                                  isSelected: comicMode == 'off',
                                  onTap: () async {
                                    await instance.setComicNotifMode('off');
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Komik: Dimatikan'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 3. Birthday Section
                          buildSectionHeader('NOTIFIKASI ULANG TAHUN', Icons.cake_rounded, const Color(0xFFFF2D55)),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              children: [
                                buildOptionTile(
                                  title: 'Aktifkan Notifikasi Ulang Tahun',
                                  subtitle: 'Terima ucapan ulang tahun & info ulang tahun teman di Moko',
                                  icon: Icons.cake_rounded,
                                  color: const Color(0xFFFF2D55),
                                  isSelected: birthdayEnabled,
                                  onTap: () async {
                                    await instance.setBirthdayNotifEnabled(true);
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Ulang Tahun: Diaktifkan 🎂'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, indent: 46, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                buildOptionTile(
                                  title: 'Matikan Notifikasi Ulang Tahun',
                                  subtitle: 'Tidak menerima pemberitahuan push untuk ulang tahun',
                                  icon: CupertinoIcons.bell_slash_fill,
                                  color: const Color(0xFF8E8E93),
                                  isSelected: !birthdayEnabled,
                                  onTap: () async {
                                    await instance.setBirthdayNotifEnabled(false);
                                    setModalState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifikasi Ulang Tahun: Dimatikan'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Simpan atau hapus anime ID dari cache bookmark notifikasi lokal
  static Future<void> syncBookmarkCache(String animeId, bool isAdded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('local_bookmarked_anime_ids') ?? [];
      final clean = animeId.trim();
      if (clean.isEmpty) return;
      if (isAdded) {
        if (!list.contains(clean)) list.add(clean);
      } else {
        list.remove(clean);
      }
      await prefs.setStringList('local_bookmarked_anime_ids', list);
    } catch (_) {}
  }

  /// Sinkronkan seluruh list bookmark anime dari server ke lokal
  static Future<void> syncAllBookmarks(List<String> animeIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanList = animeIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
      await prefs.setStringList('local_bookmarked_anime_ids', cleanList);
    } catch (_) {}
  }

  /// Simpan atau hapus komik slug dari cache bookmark notifikasi lokal
  static Future<void> syncComicBookmarkCache(String slug, bool isAdded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('local_bookmarked_comic_slugs') ?? [];
      final clean = slug.trim().toLowerCase();
      if (clean.isEmpty) return;
      if (isAdded) {
        if (!list.contains(clean)) list.add(clean);
      } else {
        list.remove(clean);
      }
      await prefs.setStringList('local_bookmarked_comic_slugs', list);
    } catch (_) {}
  }

  /// Sinkronkan seluruh list bookmark komik dari server ke lokal
  static Future<void> syncAllComicBookmarks(List<String> slugs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanList = slugs.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
      await prefs.setStringList('local_bookmarked_comic_slugs', cleanList);
    } catch (_) {}
  }

  /// Inisialisasi OneSignal (Aman di Android, iOS, Desktop, dan Web)
  Future<void> init([String? customAppId]) async {
    // OneSignal native SDK hanya aktif di Android & iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[OneSignal] Skipped on non-mobile platform (${Platform.operatingSystem})');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      return;
    }

    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final appId = customAppId ?? prefs.getString(_kCustomAppIdKey) ?? defaultAppId;

      if (appId.isEmpty) {
        debugPrint('[OneSignal] Warning: App ID belum dikonfigurasi.');
        if (!_initCompleter.isCompleted) {
          _initCompleter.complete();
        }
        return;
      }

      _notifMode = prefs.getString(kNotifModeKey) ?? 'all';
      _animeNotifMode = prefs.getString(kAnimeNotifModeKey) ?? _notifMode;
      _comicNotifMode = prefs.getString(kComicNotifModeKey) ?? _notifMode;
      _birthdayNotifEnabled = prefs.getBool(kBirthdayNotifEnabledKey) ?? true;

      // 1. Set log level minimal
      OneSignal.Debug.setLogLevel(OSLogLevel.none);

      // 2. Inisialisasi SDK OneSignal
      OneSignal.initialize(appId);

      // 3. Langsung minta izin notifikasi ke user (Muncul dialog resmi "Izinkan notifikasi?" Android 13+ & iOS)
      await OneSignal.Notifications.requestPermission(true);

      // 4. Pastikan notifikasi TAMPIL di layar sesuai preferensi user
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        debugPrint('[OneSignal] Notification received in foreground: ${event.notification.title}');
        final data = event.notification.additionalData;
        final type = data?['type']?.toString().toLowerCase() ?? '';
        final category = data?['category']?.toString().toLowerCase() ?? '';
        final title = (event.notification.title ?? '').toLowerCase();
        final body = (event.notification.body ?? '').toLowerCase();

        final isBirthdayNotif = type == 'user_birthday' ||
            type == 'birthday' ||
            type == 'birthday_greeting' ||
            category == 'birthday' ||
            category == 'user_birthday' ||
            title.contains('ulang tahun') ||
            title.contains('happy birthday') ||
            title.contains('hbd') ||
            body.contains('ulang tahun') ||
            body.contains('happy birthday');

        // Filter notifikasi Ulang Tahun
        if (isBirthdayNotif) {
          if (!_birthdayNotifEnabled) {
            debugPrint('[OneSignal] Notifikasi ulang tahun diblokir karena dinonaktifkan oleh pengguna');
            event.preventDefault();
            return;
          }
          event.notification.display();
          return;
        }

        // Filter notifikasi Anime
        if (type == 'anime_episode' || category == 'anime') {
          if (_animeNotifMode == 'off') {
            debugPrint('[OneSignal] Notifikasi anime diblokir karena dinonaktifkan');
            event.preventDefault();
            return;
          }
          if (_animeNotifMode == 'bookmarked') {
            final seriesKey = data?['series_key']?.toString() ?? '';
            final url = data?['url']?.toString() ?? '';
            final isSaved = await _isAnimeBookmarked(seriesKey) || await _isAnimeBookmarked(url);
            if (!isSaved) {
              debugPrint('[OneSignal] Notifikasi diabaikan karena anime bukan bookmark: $seriesKey');
              event.preventDefault();
              return;
            }
          }
        }

        // Filter notifikasi Komik
        if (type == 'comic_chapter' || type == 'comic' || category == 'comic') {
          if (_comicNotifMode == 'off') {
            debugPrint('[OneSignal] Notifikasi komik diblokir karena dinonaktifkan');
            event.preventDefault();
            return;
          }
          if (_comicNotifMode == 'bookmarked') {
            final slug = data?['slug']?.toString() ?? '';
            final isSaved = await _isComicBookmarked(slug);
            if (!isSaved) {
              debugPrint('[OneSignal] Notifikasi diabaikan karena komik bukan bookmark: $slug');
              event.preventDefault();
              return;
            }
          }
        }

        // Tampilkan banner notifikasi di status bar / heads-up
        event.notification.display();
      });

      // 5. Listener saat notifikasi DIKETUK/DIKLIK oleh pengguna (Langsung buka anime)
      OneSignal.Notifications.addClickListener(_handleNotificationClicked);

      _isInitialized = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      if (_notifMode == 'bookmarked' || _animeNotifMode == 'bookmarked' || _comicNotifMode == 'bookmarked') {
        addTag('notif_preference', 'bookmarked_only');
      } else {
        addTag('notif_preference', 'all');
      }
      addTag('notif_anime', _animeNotifMode);
      addTag('notif_comic', _comicNotifMode);
      addTag('notif_birthday', _birthdayNotifEnabled ? 'true' : 'false');
      addTag('birthday_notif_enabled', _birthdayNotifEnabled ? 'true' : 'false');

      // Flush pending login jika dipanggil sebelum inisialisasi selesai
      if (_pendingExternalId != null) {
        final extId = _pendingExternalId!;
        try {
          await OneSignal.login(extId);
          debugPrint('[OneSignal] Flushed pending login with ID: $extId');
        } catch (e) {
          debugPrint('[OneSignal] Flushed pending login error: $e');
        }
      }

      // Flush pending tags
      if (_pendingTags.isNotEmpty) {
        final entries = Map<String, String>.from(_pendingTags).entries;
        for (final entry in entries) {
          try {
            await OneSignal.User.addTagWithKey(entry.key, entry.value);
          } catch (_) {}
        }
      }

      debugPrint('[OneSignal] Initialized & permission requested for App ID: ${appId.substring(0, 8)}...');
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Menangani aksi klik notifikasi (Membuka anime, komik, atau modal ulang tahun)
  void _handleNotificationClicked(OSNotificationClickEvent event) {
    try {
      final data = event.notification.additionalData;
      debugPrint('[OneSignal] Notification clicked, additionalData: $data');

      final type = data?['type']?.toString().toLowerCase() ?? '';
      final category = data?['category']?.toString().toLowerCase() ?? '';
      final notifTitle = (event.notification.title ?? '').toLowerCase();
      final notifBody = (event.notification.body ?? '').toLowerCase();

      final isBirthday = type == 'user_birthday' ||
          type == 'birthday' ||
          type == 'birthday_greeting' ||
          category == 'birthday' ||
          category == 'user_birthday' ||
          notifTitle.contains('ulang tahun') ||
          notifTitle.contains('happy birthday') ||
          notifTitle.contains('hbd') ||
          notifBody.contains('ulang tahun') ||
          notifBody.contains('happy birthday');

      // Navigasi ke Modal Notifikasi jika notifikasi adalah ulang tahun
      if (isBirthday) {
        Future.delayed(const Duration(milliseconds: 300), () {
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            UniversalNotificationModal.show(ctx);
          }
        });
        return;
      }

      if (data == null) return;

      // Navigasi ke Dialog Pemberitahuan jika type adalah announcement
      if (type == 'announcement') {
        final title = data['title']?.toString() ?? 'Pemberitahuan';
        final content = data['content']?.toString() ?? '';
        final badge = data['badge']?.toString() ?? 'PENGUMUMAN';
        final id = int.tryParse(data['id']?.toString() ?? '0') ?? 0;
        final actionUrl = data['action_url']?.toString();
        final actionLabel = data['action_label']?.toString();

        final item = AnnouncementModel(
          id: id,
          title: title,
          content: content,
          badge: badge,
          actionUrl: actionUrl,
          actionLabel: actionLabel,
        );

        AnnouncementRepository.instance.addOrUpdateFromPush(item);

        Future.delayed(const Duration(milliseconds: 300), () {
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            AnnouncementBanner.showDetail(ctx, item);
          }
        });
        return;
      }

      // Navigasi ke Komik jika type adalah comic_chapter
      if (type == 'comic_chapter' || type == 'comic') {
        final slug = data['slug']?.toString() ?? '';
        if (slug.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            final nav = navigatorKey.currentState;
            if (nav != null) {
              nav.push(
                CupertinoPageRoute(
                  builder: (_) => ComicDetailScreen(slug: slug),
                ),
              );
            }
          });
          return;
        }
      }

      // Navigasi ke Anime (default)
      final seriesKey = data['series_key']?.toString();
      final url = data['url']?.toString();
      final targetId = (seriesKey != null && seriesKey.isNotEmpty) ? seriesKey : url;

      if (targetId != null && targetId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          final nav = navigatorKey.currentState;
          if (nav != null) {
            nav.push(
              CupertinoPageRoute(
                builder: (_) => AnimeDetailScreen(animeId: targetId),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[OneSignal] Error handling click event: $e');
    }
  }

  /// Hubungkan ID User login dengan OneSignal untuk segmentasi personal
  Future<void> login(String externalId) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    _pendingExternalId = externalId;
    final ready = await _ensureInitialized();
    if (!ready) return;
    try {
      await OneSignal.login(externalId);
      debugPrint('[OneSignal] login success: externalId $externalId');
    } catch (e) {
      debugPrint('[OneSignal] login error: $e');
    }
  }

  /// Logout ID User dari OneSignal
  Future<void> logout() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    _pendingExternalId = null;
    final ready = await _ensureInitialized();
    if (!ready) return;
    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] logout success');
    } catch (e) {
      debugPrint('[OneSignal] logout error: $e');
    }
  }

  /// Tambah custom tag user
  Future<void> addTag(String key, String value) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    _pendingTags[key] = value;
    final ready = await _ensureInitialized();
    if (!ready) return;
    try {
      await OneSignal.User.addTagWithKey(key, value);
    } catch (e) {
      debugPrint('[OneSignal] addTag error ($key: $value): $e');
    }
  }

  /// Hapus custom tag user
  Future<void> removeTag(String key) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    _pendingTags.remove(key);
    final ready = await _ensureInitialized();
    if (!ready) return;
    try {
      await OneSignal.User.removeTag(key);
    } catch (e) {
      debugPrint('[OneSignal] removeTag error ($key): $e');
    }
  }

  /// Sinkronisasi tag pengguna untuk notifikasi OneSignal (termasuk tanggal lahir, ultah, preferensi)
  Future<void> syncUserTags(UserModel user) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final uidStr = user.id > 0 ? user.id.toString() : null;
      if (uidStr != null) {
        await login(uidStr);
      }

      await addTag('user_id', user.id > 0 ? user.id.toString() : '');
      await addTag('username', user.username);
      await addTag('notif_birthday', user.birthdayNotifEnabled ? 'true' : 'false');
      await addTag('birthday_notif_enabled', user.birthdayNotifEnabled ? 'true' : 'false');

      if (user.displayName != null && user.displayName!.isNotEmpty) {
        await addTag('display_name', user.displayName!);
      }

      final dobStr = user.tanggalLahir;
      final dob = _parseBirthDate(dobStr);

      if (dob != null && user.birthdayNotifEnabled) {
        final mStr = dob.month.toString().padLeft(2, '0');
        final dStr = dob.day.toString().padLeft(2, '0');
        final yStr = dob.year.toString().padLeft(4, '0');
        final fullDob = '$yStr-$mStr-$dStr';
        final monthDay = '$mStr-$dStr';

        await addTag('birth_date', fullDob);
        await addTag('birth_month', mStr);
        await addTag('birth_day', dStr);
        await addTag('birth_month_day', monthDay);
        await addTag('birthday_month_day', monthDay);
        await addTag('tanggal_lahir', fullDob);
        await addTag('user_birthday', fullDob);
        await addTag('is_birthday_today', user.isBirthdayToday ? 'true' : 'false');
      } else {
        await removeTag('birth_date');
        await removeTag('birth_month');
        await removeTag('birth_day');
        await removeTag('birth_month_day');
        await removeTag('birthday_month_day');
        await removeTag('user_birthday');
        await removeTag('tanggal_lahir');
      }

      debugPrint('[OneSignal] Synced user tags for ${user.username} (DOB: $dobStr, birthdayNotif: ${user.birthdayNotifEnabled})');
    } catch (e) {
      debugPrint('[OneSignal] syncUserTags error: $e');
    }
  }

  static DateTime? _parseBirthDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;

    final parts = s.split(RegExp(r'[-/.]'));
    if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 != null && p1 != null && p2 != null) {
        if (p0 > 1000) {
          return DateTime(p0, p1, p2);
        } else if (p2 > 1000) {
          return DateTime(p2, p1, p0);
        }
      }
    }
    return null;
  }

  /// Update App ID secara dinamis jika diperlukan
  Future<void> updateAppId(String newAppId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCustomAppIdKey, newAppId);
    _isInitialized = false;
    _initCompleter = Completer<void>();
    await init(newAppId);
  }
}
