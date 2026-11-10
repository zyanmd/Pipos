import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import 'models/announcement_model.dart';

/// Centralized repository untuk memuat dan mengelola Pengumuman / Pemberitahuan.
/// Terhubung langsung dengan endpoint `/api/announcements` dan OneSignal push alert.
class AnnouncementRepository {
  AnnouncementRepository._();
  static final AnnouncementRepository instance = AnnouncementRepository._();

  static const String _kDismissedIdsKey = 'dismissed_announcement_ids';
  static const String _kSeenPopupIdsKey = 'seen_announcement_popup_ids';

  final ValueNotifier<List<AnnouncementModel>> announcements = ValueNotifier<List<AnnouncementModel>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  Set<int> _dismissedIds = {};
  bool _dismissedLoaded = false;
  Set<int> _seenPopupIds = {};
  bool _seenPopupLoaded = false;
  DateTime? _lastFetch;

  Future<void> _loadDismissedIds() async {
    if (_dismissedLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDismissedIdsKey) ?? [];
      _dismissedIds = list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toSet();
      _dismissedLoaded = true;
    } catch (_) {
      _dismissedLoaded = true;
    }
  }

  Future<void> _loadSeenPopupIds() async {
    if (_seenPopupLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kSeenPopupIdsKey) ?? [];
      _seenPopupIds = list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toSet();
      _seenPopupLoaded = true;
    } catch (_) {
      _seenPopupLoaded = true;
    }
  }

  /// Menandai satu pengumuman sebagai sudah pernah muncul di popup
  Future<void> markPopupAsSeen(int id) async {
    await _loadSeenPopupIds();
    _seenPopupIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kSeenPopupIdsKey,
        _seenPopupIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  /// Mengambil pengumuman aktif baru yang belum pernah dilihat dalam popup dialog
  Future<AnnouncementModel?> getUnseenPopupAnnouncement() async {
    await _loadSeenPopupIds();
    final visible = visibleAnnouncements;
    for (final item in visible) {
      if (!_seenPopupIds.contains(item.id)) {
        return item;
      }
    }
    return null;
  }

  /// Memuat pengumuman aktif dari backend `/api/announcements`.
  Future<List<AnnouncementModel>> fetchActiveAnnouncements({bool forceRefresh = false}) async {
    await _loadDismissedIds();

    if (!forceRefresh &&
        announcements.value.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 5)) {
      return visibleAnnouncements;
    }

    try {
      isLoading.value = true;
      final res = await ApiClient.instance.get(ApiEndpoints.announcements);
      if (res.statusCode == 200 && res.data != null) {
        final dynamic body = res.data;
        List rawList = [];
        if (body is Map && body['data'] is List) {
          rawList = body['data'];
        } else if (body is List) {
          rawList = body;
        }

        final items = rawList
            .map((e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
            .toList();

        announcements.value = items;
        _lastFetch = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Announcement] Gagal memuat pengumuman: $e');
    } finally {
      isLoading.value = false;
    }

    return visibleAnnouncements;
  }

  /// Ambil daftar pengumuman yang belum ditutup/di-dismiss oleh pengguna.
  List<AnnouncementModel> get visibleAnnouncements {
    return announcements.value.where((item) => !_dismissedIds.contains(item.id)).toList();
  }

  /// Menandai satu pengumuman sebagai sudah ditutup / disembunyikan.
  Future<void> dismissAnnouncement(int id) async {
    _dismissedIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kDismissedIdsKey,
        _dismissedIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
    // Trigger update notifier
    announcements.value = List<AnnouncementModel>.from(announcements.value);
  }

  /// Menambahkan atau memperbarui pengumuman baru dari push notification OneSignal.
  void addOrUpdateFromPush(AnnouncementModel item) {
    final list = List<AnnouncementModel>.from(announcements.value);
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }
    _dismissedIds.remove(item.id);
    announcements.value = list;
  }
}
