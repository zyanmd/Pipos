import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adult_content_service.dart';
import '../../features/anime/presentation/anime_detail_screen.dart';
import '../../features/comic/presentation/comic_detail_screen.dart';
import '../../features/jav/data/models/jav_model.dart';
import '../../features/jav/presentation/jav_player_screen.dart';
import '../../features/novel/presentation/novel_detail_screen.dart';
import '../../features/zpic/data/models/zpic_model.dart';
import '../../features/zpic/presentation/zpic_player_screen.dart';

/// Handles incoming `moko://` deep links and builds shareable app links
/// that open MOKO directly to the targeted Anime, Comic, Novel, ZPic, or JAV screen.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('com.moko.app/deeplink');

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  bool _isAppReady = false;
  String? _pendingUri;
  String? _lastHandledUri;
  DateTime? _lastHandledAt;

  static String buildAnimeLink({required String animeId, String? title}) {
    return Uri(
      scheme: 'moko',
      host: 'anime',
      queryParameters: {'id': animeId},
    ).toString();
  }

  static String buildComicLink({required String slug, String? title}) {
    return Uri(
      scheme: 'moko',
      host: 'comic',
      queryParameters: {'slug': slug},
    ).toString();
  }

  static String buildNovelLink({required String slug, String? title}) {
    return Uri(
      scheme: 'moko',
      host: 'novel',
      queryParameters: {'slug': slug},
    ).toString();
  }

  static String buildZpicLink({
    required String videoId,
    String? title,
    String? url,
  }) {
    final params = <String, String>{'id': videoId};
    if (url != null && url.trim().isNotEmpty) {
      params['url'] = url.trim();
    }
    return Uri(
      scheme: 'moko',
      host: 'zpic',
      queryParameters: params,
    ).toString();
  }

  static String buildJavLink({
    required String id,
    String? code,
    String? title,
    String? url,
  }) {
    final params = <String, String>{'id': id};
    if (code != null && code.trim().isNotEmpty) {
      params['code'] = code.trim();
    }
    return Uri(
      scheme: 'moko',
      host: 'jav',
      queryParameters: params,
    ).toString();
  }

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uriString = call.arguments as String?;
        if (uriString != null && uriString.isNotEmpty) {
          _enqueueOrHandle(uriString);
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) {
        _enqueueOrHandle(initial);
      }
    } catch (_) {}
  }

  /// Called once the authenticated main shell ([RootShell]) is mounted.
  void markAppReady() {
    _isAppReady = true;
    final pending = _pendingUri;
    if (pending != null && pending.isNotEmpty) {
      _pendingUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleUri(pending);
      });
    }
  }

  void _enqueueOrHandle(String rawUri) {
    if (!_isAppReady || _navigatorKey?.currentState == null) {
      _pendingUri = rawUri;
      return;
    }
    _handleUri(rawUri);
  }

  void _handleUri(String rawUri) {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'moko') return;

    final now = DateTime.now();
    if (_lastHandledUri == rawUri &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inMilliseconds < 1500) {
      return;
    }
    _lastHandledUri = rawUri;
    _lastHandledAt = now;

    var routeType = uri.host.toLowerCase();
    if (routeType.isEmpty && uri.pathSegments.isNotEmpty) {
      routeType = uri.pathSegments.first.toLowerCase();
    }
    if (routeType.isEmpty) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      _pendingUri = rawUri;
      return;
    }

    final params = uri.queryParameters;

    switch (routeType) {
      case 'anime':
        final id = (params['id'] ?? '').trim();
        if (id.isEmpty) return;
        nav.push(
          CupertinoPageRoute(
            builder: (_) => AnimeDetailScreen(animeId: id),
          ),
        );
        break;

      case 'comic':
        final slug = (params['slug'] ?? params['id'] ?? '').trim();
        if (slug.isEmpty) return;
        nav.push(
          CupertinoPageRoute(
            builder: (_) => ComicDetailScreen(slug: slug),
          ),
        );
        break;

      case 'novel':
        final slug = (params['slug'] ?? params['id'] ?? '').trim();
        if (slug.isEmpty) return;
        final title = params['title']?.trim();
        final poster = params['poster']?.trim();
        nav.push(
          CupertinoPageRoute(
            builder: (_) => NovelDetailScreen(
              slug: slug,
              initialTitle: (title != null && title.isNotEmpty) ? title : null,
              initialPoster: (poster != null && poster.isNotEmpty) ? poster : null,
            ),
          ),
        );
        break;

      case 'zpic':
        final videoId = (params['id'] ?? '').trim();
        final url = (params['url'] ?? (videoId.isNotEmpty ? '/$videoId' : '')).trim();
        if (videoId.isEmpty && url.isEmpty) return;
        final title = (params['title'] ?? 'Video').trim();
        final video = ZpicVideoModel(
          title: title.isNotEmpty ? title : 'Video',
          url: url,
          fullUrl: url,
          thumbnail: '',
          views: '',
          isNsfw: false,
          videoId: videoId.isNotEmpty ? videoId : url.replaceFirst(RegExp(r'^/'), ''),
        );
        nav.push(
          CupertinoPageRoute(
            builder: (_) => ZpicPlayerScreen(video: video),
          ),
        );
        break;

      case 'jav':
        final id = (params['id'] ?? '').trim();
        if (id.isEmpty) return;
        if (!AdultContentService.instance.is18Unlocked) {
          final ctx = _navigatorKey?.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Aktifkan mode 18+ terlebih dahulu untuk membuka tautan ini.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        final code = (params['code'] ?? '').trim();
        final title = (params['title'] ?? (code.isNotEmpty ? code : 'Video 18+')).trim();
        final url = (params['url'] ?? '').trim();
        final video = JavVideoModel(
          id: id,
          code: code,
          title: title,
          url: url,
          thumbnail: '',
          image: '',
          duration: '',
          views: '',
          quality: '',
          timeAgo: '',
          type: '',
          previewVideo: '',
        );
        nav.push(
          CupertinoPageRoute(
            builder: (_) => JavPlayerScreen(video: video),
          ),
        );
        break;
    }
  }
}
