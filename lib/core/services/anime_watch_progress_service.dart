import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/anime/data/models/ylnime_extra_models.dart';
import 'home_widget_service.dart';

class AnimeWatchProgress {
  final String animeId;
  final String episodeId;
  final String? episodeLabel;
  final String? episodeUrl;
  final String? animeTitle;
  final String? thumb;
  final int positionSeconds;
  final int totalDurationSeconds;
  final int updatedAtMillis;

  const AnimeWatchProgress({
    required this.animeId,
    required this.episodeId,
    this.episodeLabel,
    this.episodeUrl,
    this.animeTitle,
    this.thumb,
    required this.positionSeconds,
    required this.totalDurationSeconds,
    required this.updatedAtMillis,
  });

  bool get isCompleted {
    if (totalDurationSeconds <= 0) return false;
    return positionSeconds >= (totalDurationSeconds - 20) ||
        (positionSeconds / totalDurationSeconds) >= 0.95;
  }

  Map<String, dynamic> toJson() => {
        'animeId': animeId,
        'episodeId': episodeId,
        if (episodeLabel != null) 'episodeLabel': episodeLabel,
        if (episodeUrl != null) 'episodeUrl': episodeUrl,
        if (animeTitle != null) 'animeTitle': animeTitle,
        if (thumb != null) 'thumb': thumb,
        'positionSeconds': positionSeconds,
        'totalDurationSeconds': totalDurationSeconds,
        'updatedAtMillis': updatedAtMillis,
      };

  factory AnimeWatchProgress.fromJson(Map<String, dynamic> json) {
    return AnimeWatchProgress(
      animeId: json['animeId']?.toString() ?? '',
      episodeId: json['episodeId']?.toString() ?? '',
      episodeLabel: json['episodeLabel']?.toString(),
      episodeUrl: json['episodeUrl']?.toString(),
      animeTitle: json['animeTitle']?.toString(),
      thumb: json['thumb']?.toString(),
      positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      updatedAtMillis: (json['updatedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnimeWatchProgressService {
  AnimeWatchProgressService._();
  static final AnimeWatchProgressService instance = AnimeWatchProgressService._();

  static const String _kPrefixEp = 'anime_pos_';
  static const String _kPrefixAnime = 'anime_last_watched_';

  final Map<String, int> _lastSavedTimestamp = {};
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize cached preferences for instant synchronous writes during exit
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  /// Extracts the series/anime slug from URLs, query params, or plain strings
  static String cleanAnimeSlug(String val) {
    var s = val.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      if (uri != null) {
        if (uri.queryParameters.containsKey('series')) {
          s = uri.queryParameters['series']!;
        } else if (uri.pathSegments.isNotEmpty) {
          s = uri.pathSegments.last;
        }
      }
    }
    if (s.contains('series=')) {
      final m = RegExp(r'series=([^&]+)').firstMatch(s);
      if (m != null) s = m.group(1)!;
    }
    if (s.contains('?')) s = s.split('?').first;
    return s.trim().toLowerCase();
  }

  /// Extracts the episode ID/slug from URLs, query params, or plain strings
  static String cleanEpisodeSlug(String val) {
    var s = val.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      if (uri != null) {
        if (uri.queryParameters.containsKey('episode')) {
          s = uri.queryParameters['episode']!;
        } else if (uri.queryParameters.containsKey('id')) {
          s = uri.queryParameters['id']!;
        } else if (uri.pathSegments.isNotEmpty && !s.contains('series=')) {
          s = uri.pathSegments.last;
        }
      }
    }
    if (s.contains('episode=')) {
      final m = RegExp(r'episode=([^&]+)').firstMatch(s);
      if (m != null) s = m.group(1)!;
    } else if (s.contains('id=')) {
      final m = RegExp(r'id=([^&]+)').firstMatch(s);
      if (m != null) s = m.group(1)!;
    }
    // Match ylnime episode format like al-151864-54 or al-149262-1
    final alMatch = RegExp(r'(al-[a-z0-9]+-\d+)', caseSensitive: false).firstMatch(s);
    if (alMatch != null) {
      return alMatch.group(1)!.trim().toLowerCase();
    }
    if (s.contains('?')) s = s.split('?').first;
    return s.trim().toLowerCase();
  }

  /// Helper to extract numeric episode number (e.g. 54 from "al-151864-54", "Episode 54 END", "ep_54", "episode-54", or "54")
  static String? extractEpisodeNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final alMatch = RegExp(r'al-\d+-(\d+)', caseSensitive: false).firstMatch(text);
    if (alMatch != null) return alMatch.group(1);
    final epMatch = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (epMatch != null) return epMatch.group(1);
    final epScoreMatch = RegExp(r'ep_(\d+)', caseSensitive: false).firstMatch(text);
    if (epScoreMatch != null) return epScoreMatch.group(1);
    final queryMatch = RegExp(r'[?&]episode=(\d+)', caseSensitive: false).firstMatch(text);
    if (queryMatch != null) return int.tryParse(queryMatch.group(1)!)?.toString() ?? queryMatch.group(1);
    final hyphenMatch = RegExp(r'(?:episode|ep|eps)[-_](\d+)', caseSensitive: false).firstMatch(text);
    if (hyphenMatch != null) return int.tryParse(hyphenMatch.group(1)!)?.toString() ?? hyphenMatch.group(1);
    final numOnly = RegExp(r'^(\d+)$').firstMatch(text.trim());
    if (numOnly != null) return int.tryParse(numOnly.group(1)!)?.toString() ?? numOnly.group(1);
    return null;
  }

  /// Backward compatibility alias
  static String cleanSlug(String val) {
    return cleanAnimeSlug(val);
  }

  String _epKey(String animeId, String episodeId) =>
      '$_kPrefixEp${animeId.trim().toLowerCase()}_${episodeId.trim().toLowerCase()}';

  String _animeKey(String animeId) =>
      '$_kPrefixAnime${animeId.trim().toLowerCase()}';

  /// 🔥 Save playback progress instantly to local SharedPreferences
  /// 🔥 Save playback progress instantly to local SharedPreferences (Disabled per user request)
  Future<void> saveProgress({
    required String animeId,
    required String episodeId,
    required int positionSeconds,
    required int totalDurationSeconds,
    String? episodeLabel,
    String? episodeUrl,
    String? animeTitle,
    String? thumb,
  }) async {
    if (animeId.isEmpty || episodeId.isEmpty) return;

    final cleanAId = cleanAnimeSlug(animeId);
    final cleanEId = cleanEpisodeSlug(episodeId);
    final cacheKey = '${cleanAId}_$cleanEId';

    // ⚡ Cegah penulisan berulang jika episode yang sama baru saja dicatat kurang dari 10 detik lalu
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final lastSaved = _lastSavedTimestamp[cacheKey];
    if (lastSaved != null && (nowMillis - lastSaved) < 10000) {
      return;
    }
    _lastSavedTimestamp[cacheKey] = nowMillis;

    try {
      final prefs = await _getPrefs();
      final rawAId = animeId.trim().toLowerCase();
      final rawEId = episodeId.trim().toLowerCase();

      final safePosition = positionSeconds >= 0 ? positionSeconds : 0;

      final progress = AnimeWatchProgress(
        animeId: animeId,
        episodeId: episodeId,
        episodeLabel: episodeLabel,
        episodeUrl: episodeUrl,
        animeTitle: animeTitle,
        thumb: thumb,
        positionSeconds: safePosition,
        totalDurationSeconds: totalDurationSeconds,
        updatedAtMillis: nowMillis,
      );

      final jsonStr = jsonEncode(progress.toJson());

      // Canonical key (cukup simpan yang esensial, tidak perlu puluhan kombinasi)
      final primaryA = cleanAId.isNotEmpty ? cleanAId : rawAId;
      final primaryE = cleanEId.isNotEmpty ? cleanEId : rawEId;

      await prefs.setInt(_epKey(primaryA, primaryE), safePosition);
      await prefs.setString('${_epKey(primaryA, primaryE)}_data', jsonStr);

      if (rawAId != primaryA || rawEId != primaryE) {
        await prefs.setInt(_epKey(rawAId, rawEId), safePosition);
        await prefs.setString('${_epKey(rawAId, rawEId)}_data', jsonStr);
      }

      final epNum = extractEpisodeNumber(episodeId) ??
          extractEpisodeNumber(episodeUrl) ??
          extractEpisodeNumber(episodeLabel);
      if (epNum != null && epNum.isNotEmpty) {
        await prefs.setInt(_epKey(primaryA, 'ep_$epNum'), safePosition);
        await prefs.setString('${_epKey(primaryA, 'ep_$epNum')}_data', jsonStr);
      }

      // Save last watched anime info (untuk tray Lanjut Nonton)
      await prefs.setString(_animeKey(primaryA), jsonStr);
      if (rawAId != primaryA) {
        await prefs.setString(_animeKey(rawAId), jsonStr);
      }

      // Update Android Home Widget Lanjut Nonton
      HomeWidgetService.instance.updateFromWatchProgress(progress).ignore();
    } catch (e) {
      debugPrint('[LocalProgress] Save error: $e');
    }
    return;
  }

  /// ⚡ Format seconds to mm:ss or hh:mm:ss
  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final m = (totalSeconds ~/ 60);
    final s = (totalSeconds % 60);
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 🔥 Get saved position in seconds for a specific episode
  Future<int?> getSavedPosition({
    required String animeId,
    required String episodeId,
    int? totalDurationSeconds,
    String? episodeUrl,
    String? episodeLabel,
  }) async {
    final data = await getSavedProgressData(
      animeId: animeId,
      episodeId: episodeId,
      episodeUrl: episodeUrl,
      episodeLabel: episodeLabel,
    );
    if (data == null) return null;
    final pos = (data['positionSeconds'] as num?)?.toInt() ?? 0;
    final dur = totalDurationSeconds ?? (data['totalDurationSeconds'] as num?)?.toInt() ?? 0;
    // Jika sudah hampir selesai (misal tinggal 15 detik), jangan resume dari akhir, mulai dari awal
    if (dur > 30 && pos >= (dur - 15)) {
      return null;
    }
    return pos > 3 ? pos : null;
  }

  /// 🔥 Get full progress data
  /// Disabled per user request: selalu mulai dari awal tanpa resume posisi menit/detik
  Future<Map<String, dynamic>?> getSavedProgressData({
    required String animeId,
    required String episodeId,
    String? episodeUrl,
    String? episodeLabel,
  }) async {
    if (animeId.isEmpty || episodeId.isEmpty) return null;
    try {
      final prefs = await _getPrefs();
      final cleanAId = cleanAnimeSlug(animeId);
      final cleanEId = cleanEpisodeSlug(episodeId);
      final rawAId = animeId.trim().toLowerCase();
      final rawEId = episodeId.trim().toLowerCase();

      final aKeys = <String>{cleanAId, rawAId}..removeWhere((k) => k.isEmpty);
      final eKeys = <String>{cleanEId, rawEId}..removeWhere((k) => k.isEmpty);

      if (episodeUrl != null && episodeUrl.isNotEmpty) {
        final urlEId = cleanEpisodeSlug(episodeUrl);
        if (urlEId.isNotEmpty) eKeys.add(urlEId);
      }

      final epNum = extractEpisodeNumber(episodeId) ??
          extractEpisodeNumber(episodeUrl) ??
          extractEpisodeNumber(episodeLabel);
      if (epNum != null && epNum.isNotEmpty) {
        eKeys.add('ep_$epNum');
        eKeys.add(epNum);
      }

      String? raw;
      for (final a in aKeys) {
        for (final e in eKeys) {
          raw = prefs.getString('${_epKey(a, e)}_data');
          if (raw != null && raw.isNotEmpty) break;
        }
        if (raw != null && raw.isNotEmpty) break;
      }

      if (raw == null || raw.isEmpty) {
        // Fallback: baca dari int only
        int? pos;
        for (final a in aKeys) {
          for (final e in eKeys) {
            pos = prefs.getInt(_epKey(a, e));
            if (pos != null) break;
          }
          if (pos != null) break;
        }
        if (pos == null) return null;
        return {'positionSeconds': pos, 'totalDurationSeconds': 0};
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 🔥 Get the last watched episode and progress for an anime
  Future<AnimeWatchProgress?> getLastWatchedAnime(String animeId) async {
    if (animeId.isEmpty) return null;
    try {
      final prefs = await _getPrefs();
      final cleanAId = cleanAnimeSlug(animeId);
      final raw = prefs.getString(_animeKey(cleanAId)) ??
          prefs.getString(_animeKey(animeId.trim().toLowerCase()));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AnimeWatchProgress.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// 🔥 Reset or clear progress when an episode is completely watched
  Future<void> clearProgress({
    required String animeId,
    required String episodeId,
    String? episodeUrl,
    String? episodeLabel,
  }) async {
    if (animeId.isEmpty || episodeId.isEmpty) return;
    try {
      final prefs = await _getPrefs();
      final cleanAId = cleanAnimeSlug(animeId);
      final cleanEId = cleanEpisodeSlug(episodeId);
      final rawAId = animeId.trim().toLowerCase();
      final rawEId = episodeId.trim().toLowerCase();

      final aKeys = <String>{cleanAId, rawAId}..removeWhere((k) => k.isEmpty);
      final eKeys = <String>{cleanEId, rawEId}..removeWhere((k) => k.isEmpty);

      if (episodeUrl != null && episodeUrl.isNotEmpty) {
        final urlEId = cleanEpisodeSlug(episodeUrl);
        if (urlEId.isNotEmpty) eKeys.add(urlEId);
      }

      final epNum = extractEpisodeNumber(episodeId) ??
          extractEpisodeNumber(episodeUrl) ??
          extractEpisodeNumber(episodeLabel);
      if (epNum != null && epNum.isNotEmpty) {
        eKeys.add('ep_$epNum');
        eKeys.add(epNum);
      }

      for (final a in aKeys) {
        for (final e in eKeys) {
          await prefs.remove(_epKey(a, e));
          await prefs.remove('${_epKey(a, e)}_data');
        }
      }

      // Catatan: _animeKey(a) sengaja dipertahankan agar 'Lanjut Nonton' tetap tahu episode terakhir yang ditonton
      debugPrint('[LocalProgress] Cleared episode timestamps: ${cleanAId}_$cleanEId');
    } catch (e) {
      debugPrint('[LocalProgress] Clear error: $e');
    }
  }

  /// Ambil daftar episode terakhir ditonton untuk tray Lanjut Nonton (History Terbaru di Depan)
  Future<List<ContinueWatchingItem>> getRecentContinueWatching({int limit = 20}) async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefixAnime)).toList();
      final items = <AnimeWatchProgress>[];

      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          items.add(AnimeWatchProgress.fromJson(data));
        } catch (_) {}
      }

      // Sort history terbaru selalu di depan (updatedAtMillis descending)
      items.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));

      // Deduplikasi per animeId (ambil yang paling baru)
      final seenAnime = <String>{};
      final uniqueItems = <AnimeWatchProgress>[];
      for (final item in items) {
        final canonicalId = cleanAnimeSlug(item.animeId).isNotEmpty
            ? cleanAnimeSlug(item.animeId)
            : item.animeId.trim().toLowerCase();
        if (canonicalId.isEmpty || seenAnime.contains(canonicalId)) continue;
        seenAnime.add(canonicalId);
        uniqueItems.add(item);
      }

      return uniqueItems.take(limit).map((p) {
        final prog = (p.totalDurationSeconds > 0 && p.positionSeconds > 0)
            ? ((p.positionSeconds / p.totalDurationSeconds) * 100.0).clamp(0.0, 100.0)
            : 0.0;
        return ContinueWatchingItem(
          title: p.animeTitle ?? p.animeId,
          cover: p.thumb,
          episode: p.episodeLabel ?? p.episodeId,
          url: p.episodeUrl,
          progress: prog,
          currentTime: p.positionSeconds,
          animeId: p.animeId,
          episodeId: p.episodeId,
          episodeUrl: p.episodeUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Ambil riwayat nonton lokal yang diformat sesuai kebutuhan HistoryScreen
  Future<List<Map<String, dynamic>>> getRecentAnimeHistoryMaps({int limit = 50}) async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefixAnime)).toList();
      final items = <AnimeWatchProgress>[];

      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          items.add(AnimeWatchProgress.fromJson(data));
        } catch (_) {}
      }

      // Urutkan history paling baru di awal
      items.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));

      final seenAnime = <String>{};
      final uniqueItems = <AnimeWatchProgress>[];
      for (final item in items) {
        final canonicalId = cleanAnimeSlug(item.animeId).isNotEmpty
            ? cleanAnimeSlug(item.animeId)
            : item.animeId.trim().toLowerCase();
        if (canonicalId.isEmpty || seenAnime.contains(canonicalId)) continue;
        seenAnime.add(canonicalId);
        uniqueItems.add(item);
      }

      return uniqueItems.take(limit).map((p) {
        final isoDate = DateTime.fromMillisecondsSinceEpoch(p.updatedAtMillis).toIso8601String();
        final prog = (p.totalDurationSeconds > 0 && p.positionSeconds > 0)
            ? ((p.positionSeconds / p.totalDurationSeconds) * 100.0).clamp(0.0, 100.0)
            : 0.0;
        final epNum = extractEpisodeNumber(p.episodeId) ??
            extractEpisodeNumber(p.episodeUrl) ??
            extractEpisodeNumber(p.episodeLabel);

        return <String, dynamic>{
          'id': p.animeId,
          'anime_id': p.animeId,
          'anime_title': p.animeTitle ?? p.animeId,
          'episode_id': p.episodeId,
          'episode_number': epNum,
          'episode_title': p.episodeLabel ?? p.episodeId,
          'thumbnail': p.thumb,
          'episode_url': p.episodeUrl,
          'watched_at': isoDate,
          'current_time': p.positionSeconds,
          'total_duration': p.totalDurationSeconds,
          'watch_duration': p.positionSeconds,
          'progress_percent': prog,
          'last_position': formatDuration(p.positionSeconds),
          'is_completed': false,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Hapus anime dari riwayat lokal
  Future<void> removeAnimeHistory(String animeId) async {
    if (animeId.isEmpty) return;
    try {
      final prefs = await _getPrefs();
      final cleanAId = cleanAnimeSlug(animeId);
      final rawAId = animeId.trim().toLowerCase();
      final aKeys = <String>{cleanAId, rawAId}..removeWhere((k) => k.isEmpty);

      for (final a in aKeys) {
        await prefs.remove(_animeKey(a));
      }

      // Hapus juga episode-episode dari anime tersebut
      final allKeys = prefs.getKeys().toList();
      for (final a in aKeys) {
        for (final k in allKeys) {
          if (k.startsWith('$_kPrefixEp${a}_')) {
            await prefs.remove(k);
          }
        }
      }
    } catch (_) {}
  }

  /// 🔥 Ambil semua progress (untuk debug/cleanup)
  Future<Map<String, dynamic>> getAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith(_kPrefixEp) && !k.endsWith('_data'),);
      final result = <String, dynamic>{};
      for (final key in keys) {
        final pos = prefs.getInt(key);
        if (pos != null) result[key] = pos;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// 🔥 Bersihkan progress lama (> 30 hari)
  Future<void> cleanupOldProgress({int daysOld = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;

      final keysToCheck = prefs.getKeys().where((k) =>
          k.startsWith(_kPrefixEp) && !k.endsWith('_data'),).toList();

      for (final key in keysToCheck) {
        final dataKey = '${key}_data';
        final raw = prefs.getString(dataKey);
        if (raw == null) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final updatedAt = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
          if (updatedAt > 0 && updatedAt < cutoff) {
            await prefs.remove(key);
            await prefs.remove(dataKey);
          }
        } catch (_) {}
      }

      // Cleanup last-watched anime keys juga
      final animeKeys = prefs.getKeys().where((k) =>
          k.startsWith(_kPrefixAnime),).toList();
      for (final key in animeKeys) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final updatedAt = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
          if (updatedAt > 0 && updatedAt < cutoff) {
            await prefs.remove(key);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}