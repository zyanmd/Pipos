import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ComicReadProgress {
  final String comicSlug;
  final String chapterId;
  final String? chapterLabel;
  final String? comicTitle;
  final String? thumb;
  final int pageIndex; // 0-indexed
  final int totalPages;
  final double scrollOffset;
  final int updatedAtMillis;

  const ComicReadProgress({
    required this.comicSlug,
    required this.chapterId,
    this.chapterLabel,
    this.comicTitle,
    this.thumb,
    required this.pageIndex,
    required this.totalPages,
    this.scrollOffset = 0.0,
    required this.updatedAtMillis,
  });

  bool get isCompleted {
    if (totalPages <= 0) return false;
    return pageIndex >= (totalPages - 1);
  }

  Map<String, dynamic> toJson() => {
        'comicSlug': comicSlug,
        'chapterId': chapterId,
        if (chapterLabel != null) 'chapterLabel': chapterLabel,
        if (comicTitle != null) 'comicTitle': comicTitle,
        if (thumb != null) 'thumb': thumb,
        'pageIndex': pageIndex,
        'totalPages': totalPages,
        'scrollOffset': scrollOffset,
        'updatedAtMillis': updatedAtMillis,
      };

  factory ComicReadProgress.fromJson(Map<String, dynamic> json) {
    return ComicReadProgress(
      comicSlug: json['comicSlug']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      chapterLabel: json['chapterLabel']?.toString(),
      comicTitle: json['comicTitle']?.toString(),
      thumb: json['thumb']?.toString(),
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      updatedAtMillis: (json['updatedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}

class ComicReadProgressService {
  ComicReadProgressService._();
  static final ComicReadProgressService instance = ComicReadProgressService._();

  static const String _kPrefixChapter = 'comic_pos_';
  static const String _kPrefixComic = 'comic_last_read_';

  String _chKey(String comicSlug, String chapterId) =>
      '$_kPrefixChapter${comicSlug.trim().toLowerCase()}_${chapterId.trim().toLowerCase()}';

  String _comicKey(String comicSlug) =>
      '$_kPrefixComic${comicSlug.trim().toLowerCase()}';

  /// Save reading progress instantly to local SharedPreferences
  Future<void> saveProgress({
    required String comicSlug,
    required String chapterId,
    required int pageIndex,
    required int totalPages,
    double scrollOffset = 0.0,
    String? chapterLabel,
    String? comicTitle,
    String? thumb,
  }) async {
    if (comicSlug.isEmpty || chapterId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = ComicReadProgress(
        comicSlug: comicSlug,
        chapterId: chapterId,
        chapterLabel: chapterLabel,
        comicTitle: comicTitle,
        thumb: thumb,
        pageIndex: pageIndex,
        totalPages: totalPages,
        scrollOffset: scrollOffset,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );

      // Save chapter specific progress
      await prefs.setString(_chKey(comicSlug, chapterId), jsonEncode(progress.toJson()));

      // Save last read chapter for this comic
      await prefs.setString(_comicKey(comicSlug), jsonEncode(progress.toJson()));
    } catch (_) {}
  }

  /// Get saved progress for a specific chapter
  Future<ComicReadProgress?> getSavedProgress({
    required String comicSlug,
    required String chapterId,
  }) async {
    if (comicSlug.isEmpty || chapterId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chKey(comicSlug, chapterId));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ComicReadProgress.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Get the last read chapter and position for a comic
  Future<ComicReadProgress?> getLastReadChapter(String comicSlug) async {
    if (comicSlug.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_comicKey(comicSlug));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ComicReadProgress.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Helper to extract numeric chapter number (e.g. 12 from "Chapter 12", "Ch. 12", "ch-12", "12")
  static int? extractChapterNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final chMatch = RegExp(r'(?:Chapter|Ch|Bab)\.?\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (chMatch != null) return int.tryParse(chMatch.group(1)!);
    final hyphenMatch = RegExp(r'(?:chapter|ch|bab)[-_](\d+)', caseSensitive: false).firstMatch(text);
    if (hyphenMatch != null) return int.tryParse(hyphenMatch.group(1)!);
    final numOnly = RegExp(r'^(\d+)$').firstMatch(text.trim());
    if (numOnly != null) return int.tryParse(numOnly.group(1)!);
    final anyDigit = RegExp(r'(\d+)').firstMatch(text);
    if (anyDigit != null) return int.tryParse(anyDigit.group(1)!);
    return null;
  }

  /// Get all comics with reading history
  Future<List<ComicReadProgress>> getAllReadComics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefixComic)).toList();
      final list = <ComicReadProgress>[];
      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        try {
          list.add(ComicReadProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {}
      }
      list.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Clear progress for a chapter if needed
  Future<void> clearProgress({
    required String comicSlug,
    required String chapterId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chKey(comicSlug, chapterId));
    } catch (_) {}
  }
}

