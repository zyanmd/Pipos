import '../../../core/constants/app_colors.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../../core/services/mal_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/ios_capsule_text_field.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_episode_player.dart';
import '../data/models/nobar_model.dart';
import '../data/nobar_repository.dart';

class NobarRoomScreen extends StatefulWidget {
  final NobarRoomModel initialRoom;
  final bool isHost;

  const NobarRoomScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
  });

  @override
  State<NobarRoomScreen> createState() => _NobarRoomScreenState();
}

class _NobarRoomScreenState extends State<NobarRoomScreen> {
  late NobarRoomModel _room;
  late bool _isHost;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  // Video position notifier for 60fps scrubber without full-screen rebuilds
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  bool _lastIsPlaying = false;
  bool _lastIsBuffering = false;
  bool _isPollingChat = false;
  bool _isHeartbeating = false;

  // Host Away State (if host leaves, paused until host returns, max 1 min auto delete)
  bool _isHostAway = false;
  int _hostTimeoutSec = 60;

  // Controls Visibility & Fullscreen
  bool _showControls = true;
  Timer? _controlsHideTimer;
  bool _isFullscreen = false;
  late final FocusNode _playerFocusNode = FocusNode();
  double _lastVolumeBeforeMute = 1.0;

  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<NobarMessageModel> _messages = [];
  int _lastMessageId = 0;

  Timer? _heartbeatTimer;
  Timer? _chatPollingTimer;
  bool _isDisposing = false;
  bool _isSyncing = false;

  // Floating reaction emojis & Danmaku / Bullet chat
  final List<_FloatingReaction> _reactions = [];
  bool _showFullscreenChat = true;
  final List<_DanmakuItem> _danmakuQueue = [];
  int _danmakuRowCounter = 0;

  // Riwayat Tontonan & MyAnimeList Sync
  int _lastHistoryRecordSeconds = 0;
  bool _isMalCompletedScrobbled = false;

  // Video Resolution & Quality State (360p, 480p, 720p, 1080p)
  String _selectedResolution = '720p';
  bool _isLoadingResolution = false;
  List<String> _availableResolutions = ['1080p', '720p', '480p', '360p'];
  YlnimeEpisodeStreams? _ylnimeStream;
  int _selectedServerIndex = 0;
  String? _streamSwitchingStatus;
  Timer? _streamSwitchingTimer;

  // Monotonic Host Sync Tracking
  int _lastServerPos = 0;
  DateTime _lastServerPosReceivedAt = DateTime.now();
  bool _lastServerPlaying = true;

  void _setStreamSwitchingStatus(String status, {Duration timeout = const Duration(seconds: 7)}) {
    _streamSwitchingTimer?.cancel();
    if (mounted) {
      setState(() => _streamSwitchingStatus = status);
    }
    _streamSwitchingTimer = Timer(timeout, () {
      if (mounted && _streamSwitchingStatus != null) {
        setState(() => _streamSwitchingStatus = null);
      }
    });
  }

  void _clearStreamSwitchingStatus() {
    _streamSwitchingTimer?.cancel();
    if (mounted && _streamSwitchingStatus != null) {
      setState(() => _streamSwitchingStatus = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _isHost = widget.isHost;

    _initVideoPlayer();
    _fetchAvailableResolutions();
    _startTimers();
    _fetchInitialMessages();
  }

  Future<void> _initVideoPlayer() async {
    var streamUrl = _resolveNobarStreamUrl(_room.streamUrl);

    // Dynamic resolution fallback if streamUrl is empty
    if (streamUrl.isEmpty) {
      try {
        final epUrl = await _resolveWorkingEpisodeUrl();
        if (epUrl != null && epUrl.isNotEmpty) {
          final seriesSlug = (_room.animeId.isNotEmpty && !_room.animeId.startsWith('http')) ? _room.animeId : null;
          final fetchedStream = await AnimeRepository.instance.ylnimeEpisode(
            epUrl,
            seriesSlug: seriesSlug,
          );
          final freshUrl = fetchedStream?.bestPlayable?.proxyUrl ?? fetchedStream?.bestPlayable?.url;
          if (freshUrl != null && freshUrl.isNotEmpty) {
            _room = _room.copyWith(streamUrl: freshUrl);
            streamUrl = _resolveNobarStreamUrl(freshUrl);
          }
        }
      } catch (e) {
        debugPrint('[Nobar] Auto-resolve stream on init error: $e');
      }
    }

    if (streamUrl.isEmpty) {
      if (mounted) setState(() => _hasVideoError = true);
      return;
    }

    // Clean up old controller safely
    final oldController = _videoController;
    _videoController = null;
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
        _hasVideoError = false;
      });
    }
    if (oldController != null) {
      oldController.removeListener(_onVideoControllerUpdate);
      await oldController.dispose();
    }

    try {
      final uri = Uri.parse(streamUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: _getHeadersForUrl(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      _videoController = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Inisialisasi video nobar timeout setelah 15 detik'),
      );
      if (!mounted || _isDisposing) {
        controller.dispose();
        return;
      }

      setState(() {
        _isVideoInitialized = true;
        _hasVideoError = false;
        _streamSwitchingStatus = null;
      });
      _streamSwitchingTimer?.cancel();

      if (_room.currentPositionMs > 0) {
        await controller.seekTo(Duration(milliseconds: _room.currentPositionMs));
      }

      // Always play video automatically on join for both host and viewers!
      await controller.play();

      if (_isHost) {
        unawaited(
          NobarRepository.instance.syncPlayback(
            _room.code,
            currentPositionMs: _room.currentPositionMs,
            isPlaying: true,
          ),
        );
      }

      controller.addListener(_onVideoControllerUpdate);
      _startControlsHideTimer();
    } catch (e) {
      debugPrint('[Nobar] Video init error: $e');

      // Attempt fallback if initial stream failed to initialize
      try {
        final epUrl = await _resolveWorkingEpisodeUrl();
        if (epUrl != null && epUrl.isNotEmpty) {
          final seriesSlug = (_room.animeId.isNotEmpty && !_room.animeId.startsWith('http')) ? _room.animeId : null;
          final fetchedStream = await AnimeRepository.instance.ylnimeEpisode(
            epUrl,
            seriesSlug: seriesSlug,
          );
          final freshUrl = fetchedStream?.bestPlayable?.proxyUrl ?? fetchedStream?.bestPlayable?.url;
          if (freshUrl != null && freshUrl.isNotEmpty && freshUrl != _room.streamUrl) {
            _room = _room.copyWith(streamUrl: freshUrl);
            final fallbackUrl = _resolveNobarStreamUrl(freshUrl);
            final fallbackController = VideoPlayerController.networkUrl(
              Uri.parse(fallbackUrl),
              httpHeaders: _getHeadersForUrl(fallbackUrl),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
            );
            _videoController = fallbackController;
            await fallbackController.initialize().timeout(const Duration(seconds: 15));
            if (mounted && !_isDisposing) {
              setState(() {
                _isVideoInitialized = true;
                _hasVideoError = false;
              });
              if (_room.currentPositionMs > 0) {
                await fallbackController.seekTo(Duration(milliseconds: _room.currentPositionMs));
              }
              await fallbackController.play();
              fallbackController.addListener(_onVideoControllerUpdate);
              _startControlsHideTimer();
              return;
            }
          }
        }
      } catch (fallbackErr) {
        debugPrint('[Nobar] Video init fallback error: $fallbackErr');
      }

      if (mounted) {
        setState(() => _hasVideoError = true);
      }
    }
  }

  String _resolveNobarStreamUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return url;

    // Handle relative endpoint
    if (url.startsWith('/')) {
      return '${ApiConfig.ipv4BaseUrl}$url';
    }

    // Force replace legacy IPs or domain names with current IPv4 VPS
    url = url.replaceAll('103.119.237.37:2028', '31.59.119.142:2028')
             .replaceAll('103.119.237.37:2026', '31.59.119.142:2026')
             .replaceAll('https://api.pipinipon.site:2028', ApiConfig.ipv4BaseUrl)
             .replaceAll('http://api.pipinipon.site:2028', ApiConfig.ipv4BaseUrl)
             .replaceAll('https://api.pipinipon.site', ApiConfig.ipv4BaseUrl)
             .replaceAll('http://api.pipinipon.site', ApiConfig.ipv4BaseUrl);

    // Pixeldrain: Wajib proxy ke VPS IPv4 stream-proxy agar tidak diblokir ISP Indonesia
    if (url.contains('pixeldrain.com/u/') || url.contains('pixeldrain.com/l/')) {
      final pixelMatch = RegExp(r'pixeldrain\.com/(?:u|l)/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
      if (pixelMatch != null) {
        final fileId = pixelMatch.group(1);
        final pdUrl = 'https://pixeldrain.com/api/file/$fileId?download';
        return '${ApiConfig.ipv4BaseUrl}/api/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(pdUrl)}';
      }
    }
    if (url.contains('pixeldrain.com/api/file/') && !url.contains('/stream-proxy')) {
      return '${ApiConfig.ipv4BaseUrl}/api/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(url)}';
    }

    // Direct S3 CDN: Proxy ke VPS stream-proxy sama seperti pemutar anime reguler agar Content-Type dipaksa video/mp4
    if (url.contains('s3.animeverse.id') && !url.contains('/stream-proxy')) {
      return '${ApiConfig.ipv4BaseUrl}/api/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(url)}';
    }

    return url;
  }

  Map<String, String> _getHeadersForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/stream-proxy') || lower.contains(':2028') || lower.contains('31.59.119.142')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    if (lower.contains('s3.animeverse.id') ||
        lower.contains('animeverse.id') ||
        lower.contains('animeverse.')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://ylnime.com/',
      };
    }
    return const {};
  }

  void _onVideoControllerUpdate() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
    final val = _videoController!.value;
    _positionNotifier.value = val.position;

    // Detect completion and scrobble to MAL
    final dur = val.duration;
    final pos = val.position;
    if (dur > Duration.zero) {
      final isNearEnd = pos >= dur - const Duration(milliseconds: 2500) ||
          (!val.isPlaying && pos >= dur - const Duration(seconds: 5) && pos > Duration.zero);
      if (isNearEnd && !_isMalCompletedScrobbled) {
        _isMalCompletedScrobbled = true;
        unawaited(_recordHistory(isCompleted: true, force: true));
      }
    }

    // Only trigger full setState when play/pause or buffering state changes
    if (_lastIsPlaying != val.isPlaying || _lastIsBuffering != val.isBuffering) {
      _lastIsPlaying = val.isPlaying;
      _lastIsBuffering = val.isBuffering;
      setState(() {});
    }
  }

  void _triggerMalScrobble({bool isCompleted = false}) {
    if (!MalService.instance.isConnected || !MalService.instance.isAutoScrobbleEnabled) return;
    final title = _room.animeTitle;
    final animeId = _room.animeId;
    if (title.isEmpty) return;

    final epNum = int.tryParse(RegExp(r'\d+').firstMatch(_room.episodeNumber)?.group(0) ?? '') ??
        int.tryParse(RegExp(r'\d+').firstMatch(_room.episodeKey)?.group(0) ?? '') ?? 1;

    debugPrint('[Nobar] Auto-Scrobble MAL: $title (ID: $animeId) Eps $epNum (isCompleted: $isCompleted)');
    unawaited(
      MalService.instance.scrobbleEpisode(
        animeTitle: title,
        animeId: animeId.isNotEmpty ? animeId : null,
        episodeNumber: epNum,
        isCompleted: isCompleted,
      ),
    );
  }

  Future<void> _recordHistory({bool? isCompleted, bool force = false}) async {
    if (_isDisposing && !force) return;
    final animeId = _room.animeId;
    if (animeId.isEmpty) return;

    final vp = _videoController;
    final currentPosSec = (vp != null && vp.value.isInitialized)
        ? vp.value.position.inSeconds
        : (_room.currentPositionMs ~/ 1000);
    final totalDurSec = (vp != null && vp.value.isInitialized)
        ? vp.value.duration.inSeconds
        : 0;

    // Rate-limit record to once every 8 seconds unless forced
    if (!force && (currentPosSec - _lastHistoryRecordSeconds).abs() < 8) {
      return;
    }
    _lastHistoryRecordSeconds = currentPosSec;

    final title = _room.animeTitle;
    final epLabel = _room.episodeNumber.isNotEmpty ? 'Episode ${_room.episodeNumber}' : 'Episode';
    final epKey = _room.episodeKey;
    final epNumStr = _room.episodeNumber.isNotEmpty ? _room.episodeNumber : '1';

    // 1. Simpan progress lokal agar muncul di Home "Lanjut Nonton"
    await AnimeWatchProgressService.instance.saveProgress(
      animeId: animeId,
      episodeId: epKey.isNotEmpty ? epKey : 'ep_$epNumStr',
      positionSeconds: currentPosSec,
      totalDurationSeconds: totalDurSec,
      episodeLabel: epLabel,
      episodeUrl: epKey,
      animeTitle: title,
      thumb: _room.animePoster,
    );

    // 2. Simpan ke database riwayat akun pengguna
    try {
      await AnimeRepository.instance.addToHistory(
        animeId: animeId,
        episodeId: epKey.isNotEmpty ? epKey : 'ep_$epNumStr',
        title: title,
        seriesKey: animeId,
        episodeLabel: epLabel,
        episodeUrl: epKey,
        seriesUrl: 'https://ylnime.com/?series=$animeId',
        thumb: _room.animePoster,
        position: currentPosSec,
        duration: totalDurSec,
        watchDuration: currentPosSec,
        episodeNumber: epNumStr,
        isCompleted: isCompleted,
        force: force,
      );
    } catch (e) {
      debugPrint('[Nobar] History remote sync error: $e');
    }

    // 3. Sinkronisasi MyAnimeList
    _triggerMalScrobble(isCompleted: isCompleted == true);
  }

  void _switchSoloWatching() {
    HapticFeedback.mediumImpact();
    final curPosSec = (_videoController?.value.position.inSeconds ?? (_room.currentPositionMs ~/ 1000));
    _recordHistory(force: true);

    Navigator.of(context).pop();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AnimeEpisodePlayerScreen(
          episodeId: _room.episodeKey.isNotEmpty ? _room.episodeKey : _room.episodeNumber,
          episodeLabel: 'Episode ${_room.episodeNumber}',
          episodeUrl: _room.episodeKey,
          animeId: _room.animeId,
          animeTitle: _room.animeTitle,
          animeThumb: _room.animePoster,
          startAt: Duration(seconds: curPosSec),
        ),
      ),
    );
  }

  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel();
    if (_videoController != null && _videoController!.value.isPlaying) {
      _controlsHideTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted && _showControls && (_videoController?.value.isPlaying ?? false)) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsHideTimer();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    if (next) {
      await PipService.instance.enterFullscreen();
    } else {
      await PipService.instance.exitFullscreen();
    }
    _startControlsHideTimer();
  }

  void _startTimers() {
    // 1. Heartbeat & Sync polling every 1 second (Responsif & Real-time)
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _performHeartbeat();
    });

    // 2. Chat polling every 1.8 seconds
    _chatPollingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _pollChatMessages();
    });
  }

  Future<void> _performHeartbeat() async {
    if (!mounted || _isDisposing || _isHeartbeating) return;
    _isHeartbeating = true;
    try {
      if (_isHost && _videoController != null && _videoController!.value.isInitialized) {
        final currentPos = _videoController!.value.position.inMilliseconds;
        final isPlaying = _videoController!.value.isPlaying;

        unawaited(
          NobarRepository.instance.syncPlayback(
            _room.code,
            currentPositionMs: currentPos,
            isPlaying: isPlaying,
          ),
        );
      }

      // Ping to stay active and get room state
      final pingRes = await NobarRepository.instance.ping(_room.code);
      if (!mounted || _isDisposing) return;

      if (pingRes != null) {
        if (pingRes['room_ended'] == true) {
          _handleRoomEndedByHost();
          return;
        }

        final int pCount = pingRes['participants_count'] is int
            ? pingRes['participants_count'] as int
            : int.tryParse('${pingRes['participants_count']}') ?? _room.participantsCount;
        final safeCount = pCount < 1 ? 1 : pCount;

        if (_room.participantsCount != safeCount) {
          setState(() {
            _room = _room.copyWith(participantsCount: safeCount);
          });
        }

        // Check host away status
        final isHostAwayServer = pingRes['host_away'] == true;
        final timeoutSec = (pingRes['host_timeout_sec'] as num?)?.toInt() ?? 60;
        if (isHostAwayServer != _isHostAway || timeoutSec != _hostTimeoutSec) {
          setState(() {
            _isHostAway = isHostAwayServer;
            _hostTimeoutSec = timeoutSec;
          });
        }

        // If viewer: sync episode and playback state
        if (!_isHost) {
          // If host is away, force video pause!
          if (isHostAwayServer) {
            if (_videoController != null && _videoController!.value.isPlaying) {
              _videoController!.pause();
              setState(() => _showControls = true);
            }
            return;
          }

          // Detect episode OR resolution/stream change from host
          final serverEpNumber = pingRes['episode_number']?.toString();
          final serverStreamUrl = pingRes['stream_url']?.toString();
          final serverEpKey = pingRes['episode_key']?.toString();

          final serverPos = pingRes['current_position_ms'] is int
              ? pingRes['current_position_ms'] as int
              : int.tryParse('${pingRes['current_position_ms']}') ?? _room.currentPositionMs;
          final serverPlaying = pingRes['is_playing'] == true;

          // Estimasi posisi host yang sebenarnya saat ini (memperhitungkan waktu berjalan sejak update terakhir)
          final now = DateTime.now();
          if (serverPos != _lastServerPos || serverPlaying != _lastServerPlaying) {
            _lastServerPos = serverPos;
            _lastServerPlaying = serverPlaying;
            _lastServerPosReceivedAt = now;
          }
          final elapsedSinceSync = serverPlaying
              ? now.difference(_lastServerPosReceivedAt).inMilliseconds.clamp(0, 5000)
              : 0;
          final estimatedHostPos = serverPos + elapsedSinceSync;

          final bool epChanged = serverEpNumber != null &&
              serverEpNumber.isNotEmpty &&
              serverEpNumber != _room.episodeNumber;
          final bool streamChanged = serverStreamUrl != null &&
              serverStreamUrl.isNotEmpty &&
              serverStreamUrl != _room.streamUrl;

          // 1. Host ganti episode atau ganti resolusi / server -> Penonton wajib ikut!
          if (epChanged || streamChanged) {
            _setStreamSwitchingStatus(
              epChanged ? 'Host berpindah episode...' : 'Host sedang mengubah resolusi/server video...',
            );
            setState(() {
              _room = _room.copyWith(
                episodeNumber: serverEpNumber ?? _room.episodeNumber,
                streamUrl: serverStreamUrl,
                episodeKey: serverEpKey ?? _room.episodeKey,
                currentPositionMs: epChanged ? 0 : serverPos,
                isPlaying: serverPlaying,
              );
            });
            _initVideoPlayer();
            if (epChanged) {
              _fetchAvailableResolutions();
            }
            return;
          }

          // 2. Playback sync ketat (Penonton dilarang mendahului host, toleransi lambat maks 5 detik)
          if (_videoController != null && _videoController!.value.isInitialized) {
            final localPos = _videoController!.value.position.inMilliseconds;
            final localPlaying = _videoController!.value.isPlaying;

            // Play/Pause sync
            if (serverPlaying != localPlaying && !_isSyncing) {
              _isSyncing = true;
              if (serverPlaying) {
                // Jika saat play posisi penonton lebih maju dari host, tarik mundur seketika!
                if (localPos > estimatedHostPos) {
                  _videoController!.seekTo(Duration(milliseconds: estimatedHostPos));
                }
                _videoController!.play();
                _startControlsHideTimer();
              } else {
                _videoController!.pause();
                _videoController!.seekTo(Duration(milliseconds: serverPos));
                setState(() => _showControls = true);
              }
              Future.delayed(const Duration(milliseconds: 400), () => _isSyncing = false);
            }

            // Aturan Ketat: Penonton TIDAK BOLEH mendahului host!
            // - Jika penonton lebih maju dari host (> 1500ms): tarik mundur seketika ke menit host
            // - Jika penonton tertinggal lebih dari 5 detik (> 5000ms): tarik maju ke menit host
            // - Jika penonton dalam rentang [0 sampai 5 detik di belakang host]: biarkan berputar mulus!
            if (!_isSyncing && serverPlaying) {
              final diff = localPos - estimatedHostPos;
              if (diff > 1500) {
                // Penonton mendahului host lebih dari 1.5 detik -> Tarik mundur seketika ke posisi host!
                _isSyncing = true;
                _videoController!.seekTo(Duration(milliseconds: estimatedHostPos));
                Future.delayed(const Duration(milliseconds: 500), () => _isSyncing = false);
              } else if (diff < -5000) {
                // Penonton tertinggal lebih dari 5 detik -> Tarik maju ke posisi host!
                _isSyncing = true;
                _videoController!.seekTo(Duration(milliseconds: estimatedHostPos));
                Future.delayed(const Duration(milliseconds: 500), () => _isSyncing = false);
              }
            }
          }
        }
      }

      // Throttled history save
      if (_videoController != null && _videoController!.value.isInitialized && _videoController!.value.isPlaying) {
        _recordHistory();
      }
    } finally {
      _isHeartbeating = false;
    }
  }

  Future<void> _fetchInitialMessages() async {
    final list = await NobarRepository.instance.getMessages(_room.code, afterId: 0);
    if (!mounted) return;
    if (list.isNotEmpty) {
      final displayable = list.where((m) => m.type == 'chat' || m.type == 'reaction' || m.type == 'system').toList();
      setState(() {
        _messages.addAll(displayable);
        if (_messages.length > 150) {
          _messages.removeRange(0, _messages.length - 150);
        }
        _lastMessageId = list.last.id;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pollChatMessages() async {
    if (!mounted || _isDisposing || _isPollingChat) return;
    _isPollingChat = true;
    try {
      final newMsgs = await NobarRepository.instance.getMessages(_room.code, afterId: _lastMessageId);
      if (!mounted || newMsgs.isEmpty) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final uniqueNew = newMsgs.where((m) => !existingIds.contains(m.id)).toList();
      if (uniqueNew.isEmpty) return;

      for (final m in uniqueNew) {
        if (m.type == 'reaction') {
          _triggerFloatingReaction(m.message);
        } else if (m.type == 'chat') {
          _triggerDanmaku(m);
        } else if (m.type == 'announcement' && !_isHost) {
          if (m.message.contains('mengubah resolusi video ke')) {
            final match = RegExp(r'resolusi video ke (\w+)', caseSensitive: false).firstMatch(m.message);
            final newRes = match?.group(1);
            _setStreamSwitchingStatus('Host sedang mengubah resolusi video${newRes != null ? ' ke $newRes' : ''}...');
            if (newRes != null && newRes.isNotEmpty && mounted) {
              setState(() => _selectedResolution = newRes);
              _showInPlayerToast('Host mengubah resolusi ke $newRes');
            }
          } else if (m.message.contains('mengganti server video')) {
            _setStreamSwitchingStatus('Host sedang mengganti server video...');
            if (mounted) {
              _showInPlayerToast(m.message);
            }
          }
        }
      }

      final displayable = uniqueNew.where((m) => m.type == 'chat' || m.type == 'reaction' || m.type == 'system').toList();
      setState(() {
        if (displayable.isNotEmpty) {
          _messages.addAll(displayable);
          if (_messages.length > 150) {
            _messages.removeRange(0, _messages.length - 150);
          }
        }
        _lastMessageId = uniqueNew.last.id;
      });
      if (displayable.isNotEmpty) {
        _scrollToBottom();
      }
    } finally {
      _isPollingChat = false;
    }
  }

  void _triggerFloatingReaction(String emoji) {
    if (!mounted) return;
    if (_reactions.length >= 8) {
      _reactions.removeAt(0);
    }
    final reaction = _FloatingReaction(
      id: UniqueKey(),
      emoji: emoji,
      startX: 0.62 + (Random().nextDouble() * 0.28),
      wobblePhase: Random().nextDouble() * 6.28,
    );
    setState(() => _reactions.add(reaction));

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _reactions.removeWhere((r) => r.id == reaction.id));
      }
    });
  }

  void _triggerDanmaku(NobarMessageModel msg) {
    if (!mounted || !_showFullscreenChat) return;
    if (_danmakuQueue.length >= 8) {
      _danmakuQueue.removeAt(0);
    }
    final item = _DanmakuItem(
      id: UniqueKey(),
      text: msg.message,
      username: msg.username,
      isHost: msg.username == _room.hostUsername,
      row: (_danmakuRowCounter++) % 4,
    );
    setState(() => _danmakuQueue.add(item));

    Future.delayed(const Duration(milliseconds: 7000), () {
      if (mounted) {
        setState(() => _danmakuQueue.removeWhere((i) => i.id == item.id));
      }
    });
  }

  void _toggleFullscreenChat() {
    HapticFeedback.selectionClick();
    setState(() => _showFullscreenChat = !_showFullscreenChat);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        backgroundColor: _showFullscreenChat ? const Color(0xFF007AFF) : Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showFullscreenChat ? CupertinoIcons.bubble_left_bubble_right_fill : CupertinoIcons.bubble_left_bubble_right,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _showFullscreenChat ? 'Chat di Video (Danmaku): ON' : 'Chat di Video (Danmaku): OFF',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenChatInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

    showCupertinoDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Kirim Pesan Nobar'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'Tulis obrolan live...',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            onSubmitted: (val) {
              Navigator.of(ctx).pop();
              _sendChatMessage(explicitMsg: val);
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendChatMessage(explicitMsg: controller.text);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendChatMessage({String? explicitMsg, String type = 'chat'}) async {
    final text = explicitMsg ?? _chatInputController.text.trim();
    if (text.isEmpty) return;

    if (explicitMsg == null) {
      _chatInputController.clear();
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final username = user?.username ?? (_isHost ? 'Host' : 'Penonton');
    final avatar = user?.avatarUrl ?? '';

    if (type == 'reaction') {
      _triggerFloatingReaction(text);
    } else {
      _triggerDanmaku(NobarMessageModel(
        id: DateTime.now().millisecondsSinceEpoch,
        roomCode: _room.code,
        userId: user?.id ?? 0,
        username: username,
        avatar: avatar,
        message: text,
        type: 'chat',
        createdAt: DateTime.now(),
      ),);
    }

    final sent = await NobarRepository.instance.sendMessage(
      _room.code,
      text,
      type: type,
      username: username,
      avatar: avatar,
    );

    if (sent != null && mounted) {
      final exists = _messages.any((m) => m.id == sent.id);
      if (!exists) {
        setState(() {
          _messages.add(sent);
          if (_messages.length > 150) {
            _messages.removeRange(0, _messages.length - 150);
          }
          _lastMessageId = sent.id;
        });
        _scrollToBottom();
      }
    }
  }

  bool _isTextEditingActive() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  void _changeVolume(double delta) {
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) return;
    final current = vc.value.volume;
    final next = (current + delta).clamp(0.0, 1.0);
    vc.setVolume(next);
    if (next > 0) _lastVolumeBeforeMute = next;
    _showInPlayerToast('Volume: ${(next * 100).round()}%');
  }

  void _toggleMute() {
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) return;
    final current = vc.value.volume;
    if (current > 0.0) {
      _lastVolumeBeforeMute = current;
      vc.setVolume(0.0);
      _showInPlayerToast('Audio: Senyap (Mute)');
    } else {
      final restore = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0;
      vc.setVolume(restore);
      _showInPlayerToast('Volume: ${(restore * 100).round()}%');
    }
  }

  Map<ShortcutActivator, VoidCallback> _buildKeyboardShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.keyF): () {
        if (_isTextEditingActive()) return;
        _toggleFullscreen();
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_isFullscreen) {
          _toggleFullscreen();
        }
      },
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (_isTextEditingActive()) return;
        _togglePlayPause();
      },
      const SingleActivator(LogicalKeyboardKey.keyK): () {
        if (_isTextEditingActive()) return;
        _togglePlayPause();
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        if (_isTextEditingActive()) return;
        _seekRelative(-10);
      },
      const SingleActivator(LogicalKeyboardKey.keyJ): () {
        if (_isTextEditingActive()) return;
        _seekRelative(-10);
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        if (_isTextEditingActive()) return;
        _seekRelative(10);
      },
      const SingleActivator(LogicalKeyboardKey.keyL): () {
        if (_isTextEditingActive()) return;
        _seekRelative(10);
      },
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        if (_isTextEditingActive()) return;
        _changeVolume(0.1);
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        if (_isTextEditingActive()) return;
        _changeVolume(-0.1);
      },
      const SingleActivator(LogicalKeyboardKey.keyM): () {
        if (_isTextEditingActive()) return;
        _toggleMute();
      },
    };
  }

  void _togglePlayPause() {
    if (!_isHost) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya Host yang dapat menjeda atau memutar video nobar'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    if (_videoController == null || !_videoController!.value.isInitialized) return;
    HapticFeedback.lightImpact();

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() => _showControls = true);
      _controlsHideTimer?.cancel();
    } else {
      _videoController!.play();
      _startControlsHideTimer();
    }

    NobarRepository.instance.syncPlayback(
      _room.code,
      currentPositionMs: _videoController!.value.position.inMilliseconds,
      isPlaying: _videoController!.value.isPlaying,
      action: _videoController!.value.isPlaying ? 'play' : 'pause',
    );
  }

  void _seekRelative(int seconds) {
    if (!_isHost) return;
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    HapticFeedback.selectionClick();
    _startControlsHideTimer();

    final cur = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    var target = cur + Duration(seconds: seconds);
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (target > dur) {
      target = dur;
    }

    _videoController!.seekTo(target);

    NobarRepository.instance.syncPlayback(
      _room.code,
      currentPositionMs: target.inMilliseconds,
      isPlaying: _videoController!.value.isPlaying,
      action: 'seek',
    );
  }

  void _handleRoomEndedByHost() {
    if (!mounted || _isDisposing) return;
    _isDisposing = true;
    _heartbeatTimer?.cancel();
    _chatPollingTimer?.cancel();

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nobar Selesai'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Room ini telah dibubarkan oleh Host. Terima kasih sudah nobar bersama!'),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Kembali ke Hub'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveOrEnd() async {
    HapticFeedback.mediumImpact();
    if (_isHost) {
      final action = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Opsi Keluar Host'),
          message: const Text(
            'Jika Anda meninggalkan sementara, film akan otomatis dijeda hingga Anda kembali (maksimal 1 menit). Jika tidak kembali dalam 1 menit, room akan otomatis dibubarkan.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('leave_temp'),
              child: const Text('Tinggalkan Sementara (Jeda Video)'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop('end_permanent'),
              child: const Text('Bubarkan Room Sekarang'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Batal'),
          ),
        ),
      );

      if (action == 'leave_temp' && mounted) {
        _isDisposing = true;
        _heartbeatTimer?.cancel();
        _chatPollingTimer?.cancel();
        await NobarRepository.instance.leaveRoom(_room.code);
        if (mounted) Navigator.of(context).pop();
      } else if (action == 'end_permanent' && mounted) {
        _isDisposing = true;
        _heartbeatTimer?.cancel();
        _chatPollingTimer?.cancel();
        await NobarRepository.instance.endRoom(_room.code);
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Keluar dari Nobar?'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Apakah Anda yakin ingin keluar dari room nobar ini?'),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Keluar'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        _isDisposing = true;
        _heartbeatTimer?.cancel();
        _chatPollingTimer?.cancel();
        await NobarRepository.instance.leaveRoom(_room.code);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _room.code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode room #${_room.code} disalin ke clipboard! Bagikan ke teman.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Host: Ganti Episode Sheet
  Future<void> _openChangeEpisodeSheet() async {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChangeEpisodeModal(
        animeId: _room.animeId,
        currentEpisodeNumber: _room.episodeNumber,
        onEpisodeSelected: (epNumber, epKey, streamUrl) async {
          Navigator.of(ctx).pop();
          await _handleHostEpisodeChanged(epNumber, epKey, streamUrl);
        },
      ),
    );
  }

  Future<void> _handleHostEpisodeChanged(String epNumber, String epKey, String streamUrl) async {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengganti ke Episode $epNumber...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    final ok = await NobarRepository.instance.changeEpisode(
      _room.code,
      episodeNumber: epNumber,
      episodeKey: epKey,
      streamUrl: streamUrl,
    );

    if (ok && mounted) {
      setState(() {
        _room = _room.copyWith(
          episodeNumber: epNumber,
          episodeKey: epKey,
          streamUrl: streamUrl,
          currentPositionMs: 0,
          isPlaying: true,
        );
      });
      _initVideoPlayer();
      _fetchAvailableResolutions();
    }
  }

  Future<String?> _resolveWorkingEpisodeUrl() async {
    final seriesSlug = (_room.animeId.isNotEmpty && !_room.animeId.startsWith('http'))
        ? _room.animeId
        : null;
    var epUrl = _room.episodeKey;

    if (epUrl.isNotEmpty && (epUrl.contains('episode=') || epUrl.contains('ylnime.com'))) {
      return epUrl;
    }

    int? epNum;
    final cleanEp = RegExp(r'\d+').firstMatch(_room.episodeNumber)?.group(0);
    if (cleanEp != null) {
      epNum = int.tryParse(cleanEp);
    }

    final resolved = await AnimeRepository.instance.resolveYlnimeEpisodeUrl(
      title: _room.animeTitle,
      seriesSlug: seriesSlug,
      episodeNumber: epNum,
    );

    if (resolved != null && resolved.isNotEmpty) {
      if (mounted) {
        setState(() {
          _room = _room.copyWith(episodeKey: resolved);
        });
      }
      return resolved;
    }
    return epUrl.isNotEmpty ? epUrl : null;
  }

  Future<void> _fetchAvailableResolutions() async {
    try {
      final seriesSlug = (_room.animeId.isNotEmpty && !_room.animeId.startsWith('http'))
          ? _room.animeId
          : null;
      final epUrl = await _resolveWorkingEpisodeUrl();
      if (epUrl == null || epUrl.isEmpty) return;

      final streams = await AnimeRepository.instance.ylnimeEpisode(
        epUrl,
        seriesSlug: seriesSlug,
        quality: _selectedResolution,
      );

      if (streams != null && mounted) {
        _ylnimeStream = streams;
        final list = <String>[];
        for (final q in streams.qualities) {
          if (q.title.isNotEmpty && q.title.toLowerCase() != 'default' && !list.contains(q.title)) {
            list.add(q.title);
          }
        }
        for (final def in ['1080p', '720p', '480p', '360p']) {
          if (!list.any((item) => item.toLowerCase().replaceAll('p', '') == def.toLowerCase().replaceAll('p', ''))) {
            list.add(def);
          }
        }
        list.sort((a, b) {
          final aNum = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
          final bNum = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
          return bNum.compareTo(aNum);
        });

        setState(() {
          _availableResolutions = list;
          if (streams.currentQuality.isNotEmpty && streams.currentQuality.toLowerCase() != 'default') {
            _selectedResolution = streams.currentQuality;
          }
        });
      }
    } catch (e) {
      debugPrint('[Nobar] _fetchAvailableResolutions error: $e');
    }
  }

  void _showInPlayerToast(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _handleResolutionChange(String reso) async {
    if (!_isHost) {
      _showInPlayerToast('Hanya Host yang dapat mengubah resolusi nobar');
      return;
    }
    final cleanTarget = reso.toLowerCase().replaceAll('p', '').trim();
    final cleanSelected = _selectedResolution.toLowerCase().replaceAll('p', '').trim();
    if (cleanTarget == cleanSelected) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoadingResolution = true);

    _showInPlayerToast(
      _isHost
          ? 'Mengganti resolusi nobar ke $reso untuk semua penonton...'
          : 'Mengganti resolusi ke $reso...',
    );

    try {
      final curPos = _videoController?.value.position.inMilliseconds ?? _room.currentPositionMs;
      final isPlaying = _videoController?.value.isPlaying ?? true;
      String newStreamUrl = '';

      // 1. Cek apakah resolusi ini sudah pernah di-fetch dan tersimpan di memori _ylnimeStream
      if (_ylnimeStream != null && _ylnimeStream!.qualities.isNotEmpty) {
        final match = _ylnimeStream!.qualities.firstWhere(
          (q) {
            final qClean = q.title.toLowerCase().replaceAll('p', '').trim();
            final isLowMatch = (cleanTarget == '320' || cleanTarget == '360') && (qClean == '360' || qClean == '320');
            return q.title.toLowerCase() != 'default' &&
                (qClean == cleanTarget ||
                 qClean.contains(cleanTarget) ||
                 cleanTarget.contains(qClean) ||
                 isLowMatch);
          },
          orElse: () => const YlnimeQualityStream(title: ''),
        );

        if (match.title.isNotEmpty && match.serverList.isNotEmpty) {
          final validServers = match.serverList.where((s) {
            final u = s.url;
            return u.isNotEmpty && u.startsWith('http');
          }).toList();

          if (validServers.isNotEmpty) {
            newStreamUrl = validServers.first.url;
          }
        }
      }

      // 2. Jika belum ada di cache memori, panggil changeEpisodeResolution
      if (newStreamUrl.isEmpty) {
        final seriesSlug = (_room.animeId.isNotEmpty && !_room.animeId.startsWith('http'))
            ? _room.animeId
            : null;
        final epUrl = await _resolveWorkingEpisodeUrl() ?? _room.episodeKey;

        final newStream = await AnimeRepository.instance.changeEpisodeResolution(
          episodeUrl: epUrl,
          reso: reso,
          seriesSlug: seriesSlug,
        ).timeout(const Duration(seconds: 12), onTimeout: () => null);

        if (newStream != null && (newStream.qualities.isNotEmpty || newStream.bestPlayable != null)) {
          final existingQualities = List<YlnimeQualityStream>.from(_ylnimeStream?.qualities ?? []);
          for (final nq in newStream.qualities) {
            final idx = existingQualities.indexWhere(
              (eq) => eq.title.toLowerCase().replaceAll('p', '') == nq.title.toLowerCase().replaceAll('p', ''),
            );
            if (idx >= 0) {
              existingQualities[idx] = nq;
            } else {
              existingQualities.add(nq);
            }
          }

          _ylnimeStream = YlnimeEpisodeStreams(
            currentQuality: newStream.resoDipakai ?? reso,
            episodeId: newStream.episodeId ?? _ylnimeStream?.episodeId,
            episodeNumber: newStream.episodeNumber ?? _ylnimeStream?.episodeNumber,
            title: newStream.title ?? _ylnimeStream?.title,
            url: newStream.url.isNotEmpty ? newStream.url : (_ylnimeStream?.url ?? ''),
            seriesName: newStream.seriesName ?? _ylnimeStream?.seriesName,
            seriesKey: newStream.seriesKey ?? _ylnimeStream?.seriesKey,
            seriesUrl: newStream.seriesUrl ?? _ylnimeStream?.seriesUrl,
            nextEpisode: newStream.nextEpisode ?? _ylnimeStream?.nextEpisode,
            nextEpisodeNumber: newStream.nextEpisodeNumber ?? _ylnimeStream?.nextEpisodeNumber,
            prevEpisode: newStream.prevEpisode ?? _ylnimeStream?.prevEpisode,
            prevEpisodeNumber: newStream.prevEpisodeNumber ?? _ylnimeStream?.prevEpisodeNumber,
            qualities: existingQualities,
            bestPlayable: newStream.bestPlayable ?? _ylnimeStream?.bestPlayable,
            resoDipakai: newStream.resoDipakai,
            resoFallback: newStream.resoFallback,
          );

          newStreamUrl = newStream.bestPlayable?.proxyUrl ?? newStream.bestPlayable?.url ?? '';
        }
      }

      if (newStreamUrl.isNotEmpty) {
        if (newStreamUrl.startsWith('/')) {
          newStreamUrl = '${ApiConfig.ipv4BaseUrl}$newStreamUrl';
        }
        newStreamUrl = newStreamUrl.replaceAll('103.119.237.37:2028', '31.59.119.142:2028');
        _setStreamSwitchingStatus(_isHost ? 'Mengubah resolusi ke $reso...' : 'Host sedang mengubah resolusi ke $reso...');

        if (_isHost) {
          unawaited(
            NobarRepository.instance.changeEpisode(
              _room.code,
              episodeNumber: _room.episodeNumber,
              episodeKey: _room.episodeKey,
              streamUrl: newStreamUrl,
            ),
          );

          unawaited(
            NobarRepository.instance.sendMessage(
              _room.code,
              'Host mengubah resolusi video ke $reso',
              type: 'announcement',
            ),
          );

          unawaited(
            NobarRepository.instance.syncPlayback(
              _room.code,
              currentPositionMs: curPos,
              isPlaying: isPlaying,
            ),
          );
        }

        // Update player at curPos seamlessly
        if (mounted) {
          setState(() {
            _selectedResolution = reso;
            _room = _room.copyWith(
              streamUrl: newStreamUrl,
              currentPositionMs: curPos,
              isPlaying: isPlaying,
            );
            _isLoadingResolution = false;
          });
          await _initVideoPlayer();

          if (mounted) {
            _showInPlayerToast('✓ Resolusi $reso aktif');
          }
        }
      } else {
        _clearStreamSwitchingStatus();
        if (mounted) {
          setState(() => _isLoadingResolution = false);
          _showInPlayerToast('Resolusi $reso tidak tersedia pada anime ini');
        }
      }
    } catch (e) {
      _clearStreamSwitchingStatus();
      if (mounted) {
        setState(() => _isLoadingResolution = false);
        _showInPlayerToast('Gagal memuat resolusi $reso');
      }
    }
  }

  void _openResolutionSheet() {
    if (!_isHost) {
      _showInPlayerToast('Hanya Host yang dapat mengubah resolusi nobar');
      return;
    }
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * (_isFullscreen ? 0.85 : 0.65),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Resolusi Video',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isHost
                                  ? 'Resolusi yang dipilih otomatis berlaku untuk semua penonton'
                                  : 'Pilih kualitas video sesuai jaringan kamu',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.5, color: hairlineColor),
                ...(() {
                  final qualities = <String>[];
                  if (_ylnimeStream != null && _ylnimeStream!.qualities.isNotEmpty) {
                    for (final item in _ylnimeStream!.qualities) {
                      if (item.title.isNotEmpty && item.title.toLowerCase() != 'default' && !qualities.contains(item.title)) {
                        qualities.add(item.title);
                      }
                    }
                  }
                  for (final def in _availableResolutions) {
                    if (!qualities.any((item) => item.toLowerCase().replaceAll('p', '') == def.toLowerCase().replaceAll('p', ''))) {
                      qualities.add(def);
                    }
                  }
                  qualities.sort((a, b) {
                    final aNum = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
                    final bNum = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
                    return bNum.compareTo(aNum);
                  });
                  return qualities;
                })().map((q) {
                  final cleanQ = q.toLowerCase().replaceAll('p', '').trim();
                  final cleanSelected = _selectedResolution.toLowerCase().replaceAll('p', '').trim();
                  final active = cleanSelected == cleanQ ||
                      ((cleanSelected.isEmpty || cleanSelected == 'default') && cleanQ == '720');
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        q,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                    title: Text(
                      q == '1080p'
                          ? 'Full HD (1080p)'
                          : q == '720p'
                              ? 'HD (720p - Rekomendasi)'
                              : q == '480p'
                                  ? 'Standar (480p)'
                                  : q == '360p'
                                      ? 'Hemat Kuota (360p)'
                                      : q,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: active
                        ? const Icon(CupertinoIcons.checkmark_alt, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleResolutionChange(q);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  List<YlnimeServer> _getCurrentQualityServers() {
    if (_ylnimeStream == null || _ylnimeStream!.qualities.isEmpty) return [];
    final cleanSelected = _selectedResolution.toLowerCase().replaceAll('p', '').trim();
    for (final q in _ylnimeStream!.qualities) {
      final qClean = q.title.toLowerCase().replaceAll('p', '').trim();
      if (qClean == cleanSelected || qClean.contains(cleanSelected) || cleanSelected.contains(qClean)) {
        return q.serverList;
      }
    }
    return _ylnimeStream!.qualities.first.serverList;
  }

  String _formatServerLabel(String raw, int index) {
    var label = raw.trim();
    if (label.isEmpty ||
        label.toLowerCase().startsWith('http') ||
        label.contains('://') ||
        label.contains('.com') ||
        label.contains('.net') ||
        label.contains('.org') ||
        label.contains('.io') ||
        label.contains('/')) {
      return 'Server ${index + 1}';
    }
    return label;
  }

  Future<void> _switchServer(int index) async {
    if (!_isHost) {
      _showInPlayerToast('Hanya Host yang dapat mengganti server nobar');
      return;
    }
    try {
      final servers = _getCurrentQualityServers();
      if (index < 0 || index >= servers.length) return;
      HapticFeedback.selectionClick();

      final s = servers[index];
      var newUrl = s.url;
      if (newUrl.isEmpty) return;

      if (newUrl.startsWith('/')) {
        newUrl = '${ApiConfig.ipv4BaseUrl}$newUrl';
      }
      newUrl = newUrl.replaceAll('103.119.237.37:2028', '31.59.119.142:2028');
      _setStreamSwitchingStatus(_isHost ? 'Mengganti server video...' : 'Host sedang mengganti server video...');

      final curPos = _videoController?.value.position.inMilliseconds ?? _room.currentPositionMs;
      final isPlaying = _videoController?.value.isPlaying ?? true;

      if (_isHost) {
        unawaited(
          NobarRepository.instance.changeEpisode(
            _room.code,
            episodeNumber: _room.episodeNumber,
            episodeKey: _room.episodeKey,
            streamUrl: newUrl,
          ),
        );
        unawaited(
          NobarRepository.instance.sendMessage(
            _room.code,
            'Host mengganti server video ke ${_formatServerLabel(s.server, index)}',
            type: 'announcement',
          ),
        );
        unawaited(
          NobarRepository.instance.syncPlayback(
            _room.code,
            currentPositionMs: curPos,
            isPlaying: isPlaying,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _selectedServerIndex = index;
          _room = _room.copyWith(
            streamUrl: newUrl,
            currentPositionMs: curPos,
            isPlaying: isPlaying,
          );
        });
        await _initVideoPlayer();

        if (mounted) {
          _showInPlayerToast('✓ ${_formatServerLabel(s.server, index)} aktif');
        }
      }
    } catch (e) {
      _clearStreamSwitchingStatus();
      debugPrint('[Nobar] Switch server error: $e');
      if (mounted) {
        _showInPlayerToast('Gagal mengganti server');
      }
    }
  }

  void _showServerPickerModal(BuildContext context) {
    if (!_isHost) {
      _showInPlayerToast('Hanya Host yang dapat mengganti server nobar');
      return;
    }
    HapticFeedback.lightImpact();
    final servers = _getCurrentQualityServers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * (_isFullscreen ? 0.85 : 0.65),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.tv, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Server Video',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isHost
                                  ? 'Server yang dipilih otomatis berlaku untuk semua penonton'
                                  : 'Ganti server cadangan jika video buffering',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.5, color: hairlineColor),
                if (servers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Tidak ada server lain tersedia.',
                      style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  )
                else
                  ...servers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    final active = _selectedServerIndex == idx;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'S${idx + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      title: Text(
                        _formatServerLabel(s.server, idx),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      trailing: active
                          ? const Icon(CupertinoIcons.checkmark_alt, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchServer(idx);
                      },
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  @override
  void dispose() {
    _isDisposing = true;
    _controlsHideTimer?.cancel();
    _streamSwitchingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _chatPollingTimer?.cancel();
    if (_isFullscreen) {
      PipService.instance.exitFullscreen();
    }
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.dispose();
    _positionNotifier.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _playerFocusNode.dispose();
    unawaited(_recordHistory(force: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body;
    if (_isFullscreen) {
      body = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: _buildVideoSection(isDark, isFullscreen: true),
          ),
        ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.windows ||
               defaultTargetPlatform == TargetPlatform.macOS ||
               defaultTargetPlatform == TargetPlatform.linux) &&
              constraints.maxWidth >= 900;

          if (isDesktop) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF2F2F7),
              body: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Player & Room Controls
                    Expanded(
                      child: Column(
                        children: [
                          _buildDesktopTopBar(isDark),
                          Container(
                            color: Colors.black,
                            constraints: BoxConstraints(
                              maxHeight: (constraints.maxHeight - 52) * 0.72,
                            ),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _buildVideoSection(isDark, isFullscreen: false),
                              ),
                            ),
                          ),
                          _buildRoomInfoBar(isDark),
                          if (_streamSwitchingStatus != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const CupertinoActivityIndicator(radius: 7),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _streamSwitchingStatus!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _buildDesktopRoomDetails(isDark),
                          ),
                        ],
                      ),
                    ),
                    // Right Column: Live Chat Sidebar
                    Container(
                      width: 380,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16161A) : Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildChatSection(isDark, isDesktopSidebar: true),
                    ),
                  ],
                ),
              ),
            );
          }

          // Mobile / Compact Layout
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            body: SafeArea(
              top: true,
              bottom: true, // Prevents bottom collision with Android gesture pill
              child: Column(
                children: [
                  // 1. Top Header Bar (iOS Consistent Design)
                  _buildTopBar(isDark),

                  // 2. Synchronized Video Player
                  _buildVideoSection(isDark, isFullscreen: false),

                  // 3. Room Details, Ganti Episode Pill, & Live Reactions Tray
                  _buildRoomInfoBar(isDark),

                  // 4. Live Chat Section
                  Expanded(
                    child: _buildChatSection(isDark, isDesktopSidebar: false),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return CallbackShortcuts(
      bindings: _buildKeyboardShortcuts(),
      child: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        child: body,
      ),
    );
  }

  Widget _buildDesktopTopBar(bool isDark) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131317) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          BouncyTap(
            onTap: _confirmLeaveOrEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.chevron_back,
                    size: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Kembali',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Room Title & Anime Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.circle_fill, size: 6, color: Color(0xFFFF3B30)),
                          SizedBox(width: 4),
                          Text(
                            'LIVE NOBAR',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${_room.animeTitle} • Eps ${_room.episodeNumber} • Host: ${_room.hostUsername} 👑',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Fullscreen Shortcut Hint (F / Esc)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Tekan [F] Fullscreen',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Fullscreen Toggle Button
          BouncyTap(
            onTap: _toggleFullscreen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.fullscreen, size: 14, color: Color(0xFF007AFF)),
                  SizedBox(width: 4),
                  Text(
                    'Fullscreen',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Leave / End Button
          BouncyTap(
            onTap: _confirmLeaveOrEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isHost ? CupertinoIcons.stop_circle_fill : CupertinoIcons.square_arrow_right,
                    size: 13,
                    color: const Color(0xFFFF3B30),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isHost ? 'Bubarkan' : 'Keluar',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRoomDetails(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Peserta Nobar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_room.participantsCount}/20',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34C759),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Kode Room: ${_room.code}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _room.participants.isEmpty
                ? Center(
                    child: Text(
                      'Menunggu penonton lain bergabung...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _room.participants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final p = _room.participants[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              DecoratedAvatar(
                                avatarUrl: p.avatar,
                                radius: 20,
                                fallbackName: p.username,
                              ),
                              if (p.isHost)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF9500),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text('👑', style: TextStyle(fontSize: 8)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              p.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: p.isHost ? FontWeight.bold : FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightCard,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // iOS Back Chevron
          BouncyTap(
            onTap: _confirmLeaveOrEnd,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(
                CupertinoIcons.chevron_back,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Title & Subtitle (bounded to prevent overflow)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _room.isPrivate
                            ? const Color(0xFFFF9500).withValues(alpha: 0.15)
                            : const Color(0xFF34C759).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _room.isPrivate ? 'Privat' : 'Publik',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _room.isPrivate ? const Color(0xFFFF9500) : const Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${_room.animeTitle} • Eps ${_room.episodeNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Room Code Badge
          BouncyTap(
            onTap: _copyRoomCode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.number, size: 12, color: Color(0xFF007AFF)),
                  const SizedBox(width: 3),
                  Text(
                    _room.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Bubarkan / Keluar Action
          BouncyTap(
            onTap: _confirmLeaveOrEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isHost ? 'Bubarkan' : 'Keluar',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(bool isDark, {required bool isFullscreen}) {
    final vc = _videoController;
    final isInitialized = _isVideoInitialized && vc != null && vc.value.isInitialized;

    final videoWidget = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9,
              child: VideoPlayer(vc, key: ValueKey(vc)),
            ),
          )
        else if (_hasVideoError)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.orange, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Gagal memuat video streaming nobar',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: Colors.white24,
                onPressed: _initVideoPlayer,
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          )
        else
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(color: Colors.white, radius: 14),
              SizedBox(height: 10),
              Text('Menghubungkan ke stream nobar...', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),

        // 1. Danmaku / Running Chat on Video (Can be toggled ON/OFF)
        if (_showFullscreenChat)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Stack(
                  children: _danmakuQueue.map((item) => _buildDanmakuItem(item, isFullscreen)).toList(),
                ),
              ),
            ),
          ),

        // 2. Floating Emoji Reactions Animation Layer
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: Stack(
                children: _reactions.map((r) => _buildFloatingEmoji(r)).toList(),
              ),
            ),
          ),
        ),

        // 3. Video Controls Overlay (Fade in/out toggle & auto-hide)
        if (isInitialized)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: _buildVideoControlsOverlay(isFullscreen),
              ),
            ),
          ),

        // 4. Host Away Overlay (Film dijeda sampai host kembali, maks 1 menit)
        if (_isHostAway && !_isHost)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 1.5),
                      ),
                      child: const Icon(CupertinoIcons.pause_fill, size: 28, color: Colors.amber),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Host Sedang Keluar',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Film dijeda sampai host kembali.\nRoom akan otomatis dihapus jika host tidak kembali dalam $_hostTimeoutSec detik.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 5. Host Changing Stream/Resolution Overlay
        if (_streamSwitchingStatus != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.82),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF007AFF), width: 1.5),
                      ),
                      child: const CupertinoActivityIndicator(color: Colors.white, radius: 14),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _streamSwitchingStatus!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isHost
                          ? 'Menerapkan resolusi/server baru ke semua penonton...'
                          : 'Mohon tunggu, video akan otomatis disinkronkan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_playerFocusNode.hasFocus) {
          _playerFocusNode.requestFocus();
        }
        _toggleControls();
      },
      onDoubleTap: _toggleFullscreen,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: isFullscreen
            ? SizedBox.expand(child: videoWidget)
            : AspectRatio(aspectRatio: 16 / 9, child: videoWidget),
      ),
    );
  }

  Widget _buildDanmakuItem(_DanmakuItem item, bool isFullscreen) {
    final double laneHeight = isFullscreen ? 36.0 : 26.0;
    return LayoutBuilder(
      key: ValueKey(item.id),
      builder: (ctx, constraints) {
        final double topPos = (constraints.maxHeight * 0.06) + (item.row * laneHeight);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.05, end: -0.65),
          duration: const Duration(milliseconds: 6500),
          curve: Curves.linear,
          builder: (context, progress, child) {
            return Transform.translate(
              offset: Offset(constraints.maxWidth * progress, topPos),
              child: Align(
                alignment: Alignment.topLeft,
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isHost
                    ? const Color(0xFFFF9500).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isHost) ...[
                  const Text('👑 ', style: TextStyle(fontSize: 10)),
                ],
                Text(
                  '${item.username}: ',
                  style: TextStyle(
                    fontSize: isFullscreen ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    color: item.isHost
                        ? const Color(0xFFFF9500)
                        : const Color(0xFF60A5FA),
                  ),
                ),
                Text(
                  item.text,
                  style: TextStyle(
                    fontSize: isFullscreen ? 13 : 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                        offset: Offset(0, 1),
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
  }

  String _normalizeReactionEmoji(String raw) {
    switch (raw.trim()) {
      case 'Keren':
      case 'flame':
      case 'api':
        return '🔥';
      case 'Suka':
      case 'heart':
      case 'love':
        return '❤️';
      case 'Mantap':
      case 'thumbsup':
      case 'like':
        return '👍';
      case 'Bintang':
      case 'star':
        return '⭐';
      case 'Hype':
      case 'bolt':
      case 'petir':
        return '⚡';
      default:
        return raw.trim();
    }
  }

  Widget _buildFloatingEmoji(_FloatingReaction r) {
    final displayEmoji = _normalizeReactionEmoji(r.emoji);

    return TweenAnimationBuilder<double>(
      key: ValueKey(r.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final double opacity = value < 0.65
            ? 1.0
            : (1.0 - ((value - 0.65) / 0.35)).clamp(0.0, 1.0);

        final double scale = value < 0.12
            ? (value / 0.12) * 1.35
            : value < 0.25
                ? 1.35 - ((value - 0.12) / 0.13) * 0.35
                : 1.0 + sin((value - 0.25) * pi * 3) * 0.08;

        final double drift = sin(value * pi * 3.5 + r.wobblePhase) * 22.0;
        final double dy = -(value * 230.0);
        final double rotation = sin(value * pi * 2.5 + r.wobblePhase) * 0.22;

        return Align(
          alignment: Alignment(
            ((r.startX - 0.5) * 2.0).clamp(-0.9, 0.9),
            0.85,
          ),
          child: Transform.translate(
            offset: Offset(drift, dy),
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      displayEmoji,
                      style: const TextStyle(
                        fontSize: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoControlsOverlay(bool isFullscreen) {
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final isPlaying = vc.value.isPlaying;
    final duration = vc.value.duration;
    final isBuffering = vc.value.isBuffering;

    String formatDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top overlay status / fullscreen header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isFullscreen ? 24 : 12,
              vertical: isFullscreen ? 14 : 8,
            ),
            child: Row(
              children: [
                if (isFullscreen) ...[
                  BouncyTap(
                    onTap: _toggleFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                      child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_room.animeTitle} • Eps ${_room.episodeNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isHost) ...[
                    BouncyTap(
                      onTap: _openChangeEpisodeSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.square_list_fill, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Ganti Eps',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Resolusi Video Pill Button (Full screen)
                  if (_isHost) ...[
                    BouncyTap(
                      onTap: _openResolutionSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoadingResolution)
                              const CupertinoActivityIndicator(color: Colors.white, radius: 6)
                            else
                              const Icon(CupertinoIcons.slider_horizontal_3, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _selectedResolution.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    BouncyTap(
                      onTap: () => _showInPlayerToast('Resolusi video diatur oleh Host: ${_selectedResolution.toUpperCase()}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoadingResolution)
                              const CupertinoActivityIndicator(color: Colors.white, radius: 6)
                            else
                              const Icon(CupertinoIcons.slider_horizontal_3, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _selectedResolution.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Server Pill Button (Full screen)
                  if (_isHost) ...[
                    BouncyTap(
                      onTap: () => _showServerPickerModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.tv, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'S${_selectedServerIndex + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    BouncyTap(
                      onTap: () => _showInPlayerToast('Server video diatur oleh Host: S${_selectedServerIndex + 1}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.tv, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'S${_selectedServerIndex + 1}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  BouncyTap(
                    onTap: _toggleFullscreenChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _showFullscreenChat
                            ? const Color(0xFF007AFF).withValues(alpha: 0.85)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showFullscreenChat
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showFullscreenChat
                                ? CupertinoIcons.bubble_left_bubble_right_fill
                                : CupertinoIcons.bubble_left_bubble_right,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _showFullscreenChat ? 'Chat Layar: ON' : 'Chat Layar: OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Nonton Sendiri Pill Button (Full screen)
                  BouncyTap(
                    onTap: _switchSoloWatching,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5856D6).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF5856D6).withValues(alpha: 0.7)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Nonton Sendiri',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.circle_fill, size: 6, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'LIVE NOBAR',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncyTap(
                    onTap: _toggleFullscreenChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _showFullscreenChat
                            ? const Color(0xFF007AFF).withValues(alpha: 0.85)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showFullscreenChat
                                ? CupertinoIcons.bubble_left_bubble_right_fill
                                : CupertinoIcons.bubble_left_bubble_right,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _showFullscreenChat ? 'Chat ON' : 'Chat OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  BouncyTap(
                    onTap: _isHost
                        ? () => _showServerPickerModal(context)
                        : () => _showInPlayerToast('Server video diatur oleh Host: S${_selectedServerIndex + 1}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.tv, color: Colors.white, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            'S${_selectedServerIndex + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Host: ${_room.hostUsername} 👑',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Middle playback buttons (Host controls or Viewer Live Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isHost) ...[
                BouncyTap(
                  onTap: () => _seekRelative(-10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                    child: const Icon(CupertinoIcons.gobackward_10, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 28),
                if (isBuffering)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                    child: const CupertinoActivityIndicator(color: Colors.white, radius: 14),
                  )
                else
                  BouncyTap(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: Icon(
                        isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                const SizedBox(width: 28),
                BouncyTap(
                  onTap: () => _seekRelative(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                    child: const Icon(CupertinoIcons.goforward_10, color: Colors.white, size: 24),
                  ),
                ),
              ] else ...[
                // Penonton: Sleek Live Status Badge (Matches clean live streaming UI, zero redundant fullscreen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isPlaying ? const Color(0xFF34C759) : Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPlaying ? 'LIVE' : 'DIJEDA HOST',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Fullscreen Floating Reactions & Chat Trigger Bar
          if (isFullscreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['🔥', '❤️', '😂', '👏', '😭', '🎉'].map((emoji) {
                        return BouncyTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _sendChatMessage(explicitMsg: emoji, type: 'reaction');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Spacer(),
                  BouncyTap(
                    onTap: _openFullscreenChatInput,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.pencil, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Kirim Pesan...',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Bar (Scrubber, Timestamps, and Exactly 1 Fullscreen Button)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isFullscreen ? 24 : 12,
              vertical: isFullscreen ? 14 : 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _positionNotifier,
                    builder: (context, pos, _) {
                      return Row(
                        children: [
                          Text(
                            formatDuration(pos),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isHost
                                ? SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.5,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: const Color(0xFF007AFF),
                                      secondaryActiveTrackColor: Colors.white30,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      overlayColor: const Color(0x33007AFF),
                                    ),
                                    child: Slider(
                                      value: duration.inMilliseconds > 0
                                          ? pos.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble())
                                          : 0.0,
                                      min: 0.0,
                                      max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                      onChanged: (val) {
                                        _videoController?.seekTo(Duration(milliseconds: val.toInt()));
                                      },
                                      onChangeEnd: (val) {
                                        final curVc = _videoController;
                                        if (curVc != null && curVc.value.isInitialized) {
                                          NobarRepository.instance.syncPlayback(
                                            _room.code,
                                            currentPositionMs: val.toInt(),
                                            isPlaying: curVc.value.isPlaying,
                                            action: 'seek',
                                          );
                                        }
                                      },
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: duration.inMilliseconds > 0
                                          ? (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                          : 0.0,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                                      minHeight: 4,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatDuration(duration),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Fullscreen Toggle Button (Standard Single Button)
                BouncyTap(
                  onTap: _toggleFullscreen,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isFullscreen ? CupertinoIcons.fullscreen_exit : CupertinoIcons.fullscreen,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomInfoBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightCard,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Live participant count (X/20 Penonton)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_room.participantsCount}/20 Penonton',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34C759),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Host: Ganti Episode Pill Button
            if (_isHost) ...[
              BouncyTap(
                onTap: _openChangeEpisodeSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.square_list_fill, size: 12, color: Color(0xFF007AFF)),
                      SizedBox(width: 4),
                      Text(
                        'Ganti Eps',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Resolusi Pill Button (Host can change for all, Penonton read-only)
            if (_isHost) ...[
              BouncyTap(
                onTap: _openResolutionSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingResolution)
                        const CupertinoActivityIndicator(radius: 5.5)
                      else
                        const Icon(CupertinoIcons.slider_horizontal_3, size: 11, color: Color(0xFF007AFF)),
                      const SizedBox(width: 4),
                      Text(
                        _selectedResolution.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              // Penonton: Read-only badge displaying resolution set by host
              BouncyTap(
                onTap: () => _showInPlayerToast('Resolusi video diatur oleh Host: ${_selectedResolution.toUpperCase()}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingResolution)
                        const CupertinoActivityIndicator(radius: 5.5)
                      else
                        Icon(CupertinoIcons.slider_horizontal_3, size: 11, color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        _selectedResolution.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Server Pill Button (Host can change for all, Penonton read-only)
            if (_isHost) ...[
              BouncyTap(
                onTap: () => _showServerPickerModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.tv, size: 11, color: Color(0xFFFF9500)),
                      const SizedBox(width: 4),
                      Text(
                        'S${_selectedServerIndex + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              // Penonton: Read-only badge displaying server set by host
              BouncyTap(
                onTap: () => _showInPlayerToast('Server video diatur oleh Host: S${_selectedServerIndex + 1}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.tv, size: 11, color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        'S${_selectedServerIndex + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Nonton Sendiri Pill Button (Portrait)
            BouncyTap(
              onTap: _switchSoloWatching,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF5856D6).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.play_circle_fill, size: 11, color: Color(0xFF5856D6)),
                    SizedBox(width: 4),
                    Text(
                      'Nonton Sendiri',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5856D6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Divider
            Container(
              width: 1,
              height: 16,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(width: 10),

            // Quick Reaction Icon Tray (Clean Cupertino SF Icons)
            ...[
              (CupertinoIcons.flame_fill, const Color(0xFFFF453A), '🔥'),
              (CupertinoIcons.heart_fill, const Color(0xFFFF2D55), '❤️'),
              (CupertinoIcons.hand_thumbsup_fill, const Color(0xFF0A84FF), '👍'),
              (CupertinoIcons.star_fill, const Color(0xFFFFD60A), '⭐'),
              (CupertinoIcons.bolt_fill, const Color(0xFFBF5AF2), '⚡'),
            ].map((r) {
              return BouncyTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _sendChatMessage(explicitMsg: r.$3, type: 'reaction');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: r.$2.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(r.$1, size: 14, color: r.$2),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiReactionTray(bool isDark) {
    final emojis = [
      ('🔥', 'Api'),
      ('❤️', 'Suka'),
      ('😂', 'Ngakak'),
      ('👏', 'Tepuk'),
      ('😭', 'Sedih'),
      ('🎉', 'Hore'),
      ('⚡', 'Keren'),
      ('👍', 'Mantap'),
      ('⭐', 'Bintang'),
      ('😱', 'Kaget'),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131317) : const Color(0xFFF7F7F9),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = emojis[i];
          return BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              _sendChatMessage(explicitMsg: item.$1, type: 'reaction');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  item.$1,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatSection(bool isDark, {bool isDesktopSidebar = false}) {
    return Column(
      children: [
        // Desktop Sidebar Header
        if (isDesktopSidebar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131317) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  size: 16,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Chat Nobar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                // Danmaku Toggle Switch
                BouncyTap(
                  onTap: _toggleFullscreenChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _showFullscreenChat
                          ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showFullscreenChat
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFullscreenChat ? CupertinoIcons.captions_bubble_fill : CupertinoIcons.captions_bubble,
                          size: 11,
                          color: _showFullscreenChat
                              ? const Color(0xFF007AFF)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showFullscreenChat ? 'Layar: ON' : 'Layar: OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _showFullscreenChat
                                ? const Color(0xFF007AFF)
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Live Chat Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2,
                          size: 32,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada obrolan.\nKirim pesan atau reaksi emotikon untuk menyapa teman nobar! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageTile(msg, isDark);
                  },
                ),
        ),

        // Quick Emoji Reaction Tray (Viewers & Host can 1-tap reaction emojis!)
        _buildEmojiReactionTray(isDark),

        // iOS iMessage-style Input Box
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightCard,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: IosCapsuleTextField(
                  controller: _chatInputController,
                  hintText: 'Ketik pesan nobar live...',
                  prefixIcon: CupertinoIcons.chat_bubble_fill,
                  height: 42,
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              BouncyTap(
                onTap: () => _sendChatMessage(),
                child: const Icon(
                  CupertinoIcons.arrow_up_circle_fill,
                  color: Color(0xFF007AFF),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageTile(NobarMessageModel msg, bool isDark) {
    if (msg.type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            msg.message,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMe = (auth.user != null && auth.user!.id == msg.userId) ||
        (auth.user?.username == msg.username);
    final isHostMsg = msg.username == _room.hostUsername;

    if (msg.type == 'reaction') {
      final emoji = _normalizeReactionEmoji(msg.message);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isMe) ...[
              DecoratedAvatar(
                avatarUrl: msg.avatar,
                radius: 12,
                fallbackName: msg.username,
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFF007AFF).withValues(alpha: 0.35)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? 'Kamu ' : '${msg.username} ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? const Color(0xFF007AFF)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final timeStr = msg.createdAt != null
        ? '${msg.createdAt!.hour.toString().padLeft(2, '0')}:${msg.createdAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            DecoratedAvatar(
              avatarUrl: msg.avatar,
              radius: 13,
              fallbackName: msg.username,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.username,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (isHostMsg) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HOST 👑',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF9500),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (!isMe) const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF007AFF)
                        : (isDark ? const Color(0xFF26252A) : const Color(0xFFE9E9EB)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0xFF007AFF).withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          msg.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingReaction {
  final Key id;
  final String emoji;
  final double startX;
  final double wobblePhase;

  _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.startX,
    this.wobblePhase = 0.0,
  });
}

class _DanmakuItem {
  final Key id;
  final String text;
  final String username;
  final bool isHost;
  final int row;

  _DanmakuItem({
    required this.id,
    required this.text,
    required this.username,
    required this.isHost,
    required this.row,
  });
}

// ─────────────────────────────────────────────────────────────
// HOST CHANGE EPISODE MODAL (iOS Style)
// ─────────────────────────────────────────────────────────────
class _ChangeEpisodeModal extends StatefulWidget {
  final String animeId;
  final String currentEpisodeNumber;
  final void Function(String episodeNumber, String episodeKey, String streamUrl) onEpisodeSelected;

  const _ChangeEpisodeModal({
    required this.animeId,
    required this.currentEpisodeNumber,
    required this.onEpisodeSelected,
  });

  @override
  State<_ChangeEpisodeModal> createState() => _ChangeEpisodeModalState();
}

class _ChangeEpisodeModalState extends State<_ChangeEpisodeModal> {
  bool _isLoading = true;
  List<EpisodeModel> _episodes = [];
  String? _resolvingEpId;

  @override
  void initState() {
    super.initState();
    _fetchEpisodes();
  }

  Future<void> _fetchEpisodes() async {
    try {
      final detail = await AnimeRepository.instance.detail(widget.animeId);
      if (mounted) {
        setState(() {
          _episodes = detail.episodes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectEpisode(EpisodeModel ep) async {
    final epNumber = ep.episodeNumber?.isNotEmpty == true ? ep.episodeNumber! : '1';
    final epKey = ep.id.isNotEmpty ? ep.id : (ep.url ?? '');

    setState(() => _resolvingEpId = epKey);

    try {
      final streams = await AnimeRepository.instance.ylnimeStreams(url: epKey);
      final streamUrl = streams?.bestPlayable?.proxyUrl ?? streams?.bestPlayable?.url ?? '';

      if (!mounted) return;
      setState(() => _resolvingEpId = null);

      if (streamUrl.isNotEmpty) {
        widget.onEpisodeSelected(epNumber, epKey, streamUrl);
      } else {
        _showError('Gagal memuat link video untuk episode ini');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resolvingEpId = null);
        _showError('Gagal memuat streaming episode: $e');
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Info Episode'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                const Icon(CupertinoIcons.square_list_fill, color: Color(0xFF007AFF), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ganti Episode Nobar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                BouncyTap(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Episodes List
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _episodes.isEmpty
                    ? Center(
                        child: Text(
                          'Daftar episode tidak ditemukan.',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        itemCount: _episodes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final ep = _episodes[index];
                          final epNumber = ep.episodeNumber?.isNotEmpty == true ? ep.episodeNumber! : '${index + 1}';
                          final epKey = ep.id.isNotEmpty ? ep.id : (ep.url ?? '');
                          final isCurrent = epNumber == widget.currentEpisodeNumber;
                          final isResolving = _resolvingEpId == epKey;

                          return BouncyTap(
                            onTap: isResolving ? () {} : () => _selectEpisode(ep),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFF007AFF)
                                      : (isDark ? Colors.white10 : Colors.black12),
                                  width: isCurrent ? 1.4 : 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Episode $epNumber',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      color: isCurrent ? const Color(0xFF007AFF) : null,
                                    ),
                                  ),
                                  if (ep.label.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ep.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ] else
                                    const Spacer(),
                                  if (isResolving)
                                    const CupertinoActivityIndicator(radius: 8)
                                  else if (isCurrent)
                                    const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Color(0xFF007AFF), size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
