import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/anime/data/models/anime_model.dart';
import '../../features/anime/data/models/ylnime_extra_models.dart';
import '../../features/anime/presentation/anime_detail_screen.dart';
import '../../features/anime/presentation/anime_episode_player.dart';
import 'anime_watch_progress_service.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> init([GlobalKey<NavigatorState>? key]) async {
    if (key != null) _navigatorKey = key;
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // Check if launched from Home Widget initially
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _handleWidgetUri(initialUri);
      }

      // Listen to widget clicks while app is running / in background
      HomeWidget.widgetClicked.listen(_handleWidgetUri);
    } catch (e) {
      debugPrint('[HomeWidgetService] init error: $e');
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || _navigatorKey == null) return;
    debugPrint('[HomeWidgetService] Widget clicked with URI: $uri');

    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;

    try {
      final host = uri.host;
      final url = uri.queryParameters['url'];

      if (url != null && url.isNotEmpty) {
        if (host == 'anime' || host == 'continue') {
          // If it contains episode parameter, open episode player directly
          if (url.contains('&episode=') || url.contains('episodeId=')) {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => AnimeEpisodePlayerScreen(
                  episodeId: url,
                  episodeLabel: 'Episode',
                  episodeUrl: url,
                ),
              ),
            );
          } else {
            // Otherwise open AnimeDetailScreen
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => AnimeDetailScreen(
                  animeId: url,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeWidgetService] handleUri error: $e');
    }
  }

  /// Download and cache an image locally so RemoteViews can decode it
  Future<String?> _cacheWidgetImage(String? imageUrl, String filename) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$filename');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.bytes,
        ),
      );

      final response = await dio.get<List<int>>(imageUrl);
      if (response.statusCode == 200 && response.data != null) {
        await targetFile.writeAsBytes(response.data!);
        return targetFile.path;
      }
    } catch (e) {
      debugPrint('[HomeWidgetService] _cacheWidgetImage failed: $e');
    }
    return null;
  }

  /// Update Android Widget "Anime Terbaru" with a list of at least 5 anime
  Future<void> updateLatestAnimeList(List<AnimeModel> animeList) async {
    if (kIsWeb || !Platform.isAndroid || animeList.isEmpty) return;

    try {
      final count = animeList.length > 10 ? 10 : animeList.length;
      final subList = animeList.sublist(0, count);

      final itemsJson = <Map<String, dynamic>>[];
      for (int i = 0; i < subList.length; i++) {
        final a = subList[i];
        final title = a.title.trim();
        final episode = a.episode != null
            ? '${AnimeModel.formatEpisode(a.episode)} • Sub Indo'
            : (a.status ?? 'Rilis Baru');
        final time = a.releasedOn ?? 'Baru Saja';
        final url = (a.url != null && a.url!.isNotEmpty) ? a.url! : a.id;
        final imagePath = await _cacheWidgetImage(
          a.thumb,
          'widget_latest_$i.png',
        );

        itemsJson.add({
          'title': title,
          'episode': episode,
          'time': time,
          'url': url,
          'image': imagePath ?? '',
        });
      }

      final jsonStr = jsonEncode(itemsJson);
      await HomeWidget.saveWidgetData<String>('latest_anime_list_json', jsonStr);

      // Keep single fallback keys
      if (itemsJson.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('latest_anime_title', itemsJson[0]['title'] as String);
        await HomeWidget.saveWidgetData<String>('latest_anime_episode', itemsJson[0]['episode'] as String);
        await HomeWidget.saveWidgetData<String>('latest_anime_time', itemsJson[0]['time'] as String);
        await HomeWidget.saveWidgetData<String>('latest_anime_url', itemsJson[0]['url'] as String);
        final firstImg = itemsJson[0]['image'] as String;
        if (firstImg.isNotEmpty) {
          await HomeWidget.saveWidgetData<String>('latest_anime_image', firstImg);
        }
      }

      await HomeWidget.updateWidget(
        name: 'AnimeLatestWidgetProvider',
        androidName: 'AnimeLatestWidgetProvider',
      );
      debugPrint('[HomeWidgetService] Updated AnimeLatestWidgetProvider with ${itemsJson.length} items');
    } catch (e) {
      debugPrint('[HomeWidgetService] updateLatestAnimeList error: $e');
    }
  }

  /// Update single item fallback
  Future<void> updateLatestAnime(AnimeModel anime) async {
    await updateLatestAnimeList([anime]);
  }

  /// Update Android Widget "Lanjut Nonton & Bookmark" with a list of at least 5 anime
  Future<void> updateContinueWatchingList(List<ContinueWatchingItem> continueList) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      if (continueList.isEmpty) {
        await HomeWidget.saveWidgetData<String>('bookmark_anime_list_json', '[]');
        await HomeWidget.updateWidget(
          name: 'AnimeBookmarkWidgetProvider',
          androidName: 'AnimeBookmarkWidgetProvider',
        );
        return;
      }

      final count = continueList.length > 10 ? 10 : continueList.length;
      final subList = continueList.sublist(0, count);

      final itemsJson = <Map<String, dynamic>>[];
      for (int i = 0; i < subList.length; i++) {
        final item = subList[i];
        final title = item.title.trim();
        if (title.isEmpty) continue;
        final ep = item.episode;
        final episode = (ep != null && ep.isNotEmpty) ? ep : 'Episode Terakhir';
        final progress = item.progress.round().clamp(0, 100);
        final url = item.url ?? item.animeId ?? '';
        final imagePath = await _cacheWidgetImage(
          item.cover,
          'widget_bookmark_$i.png',
        );

        itemsJson.add({
          'title': title,
          'episode': episode,
          'progress': progress,
          'url': url,
          'image': imagePath ?? '',
        });
      }

      final jsonStr = jsonEncode(itemsJson);
      await HomeWidget.saveWidgetData<String>('bookmark_anime_list_json', jsonStr);

      // Keep single fallback keys
      if (itemsJson.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('bookmark_anime_title', itemsJson[0]['title'] as String);
        await HomeWidget.saveWidgetData<String>('bookmark_anime_episode', itemsJson[0]['episode'] as String);
        await HomeWidget.saveWidgetData<int>('bookmark_anime_progress', itemsJson[0]['progress'] as int);
        await HomeWidget.saveWidgetData<String>('bookmark_anime_url', itemsJson[0]['url'] as String);
        final firstImg = itemsJson[0]['image'] as String;
        if (firstImg.isNotEmpty) {
          await HomeWidget.saveWidgetData<String>('bookmark_anime_image', firstImg);
        }
      }

      await HomeWidget.updateWidget(
        name: 'AnimeBookmarkWidgetProvider',
        androidName: 'AnimeBookmarkWidgetProvider',
      );
      debugPrint('[HomeWidgetService] Updated AnimeBookmarkWidgetProvider with ${itemsJson.length} items');
    } catch (e) {
      debugPrint('[HomeWidgetService] updateContinueWatchingList error: $e');
    }
  }

  /// Update single continue watching item fallback
  Future<void> updateContinueWatching({
    required String title,
    required String episode,
    required int progressPercent,
    required String url,
    String? posterUrl,
  }) async {
    final item = ContinueWatchingItem(
      title: title,
      episode: episode,
      progress: progressPercent.toDouble(),
      url: url,
      cover: posterUrl,
    );
    await updateContinueWatchingList([item]);
  }

  /// Overload for AnimeWatchProgress
  Future<void> updateFromWatchProgress(AnimeWatchProgress progress) async {
    try {
      final list = await AnimeWatchProgressService.instance.getRecentContinueWatching(limit: 10);
      if (list.isNotEmpty) {
        await updateContinueWatchingList(list);
        return;
      }
    } catch (_) {}

    final title = progress.animeTitle ?? progress.animeId;
    final epLabel = progress.episodeLabel ?? progress.episodeId;
    final percent = progress.totalDurationSeconds > 0
        ? ((progress.positionSeconds / progress.totalDurationSeconds) * 100).round()
        : 0;

    await updateContinueWatching(
      title: title,
      episode: epLabel.isNotEmpty ? epLabel : 'Episode Terakhir',
      progressPercent: percent,
      url: progress.episodeUrl ?? progress.animeId,
      posterUrl: progress.thumb,
    );
  }

  /// Overload for ContinueWatchingItem
  Future<void> updateFromContinueItem(ContinueWatchingItem item) async {
    try {
      final list = await AnimeWatchProgressService.instance.getRecentContinueWatching(limit: 10);
      if (list.isNotEmpty) {
        await updateContinueWatchingList(list);
        return;
      }
    } catch (_) {}

    await updateContinueWatchingList([item]);
  }
}
