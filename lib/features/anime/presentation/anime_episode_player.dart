import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/cinematic_fullscreen_hud.dart';
import 'widgets/desktop_pip_overlay.dart';
import 'widgets/genre_role_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../../core/services/user_decor_resolver.dart';
import '../../../features/anime/data/anime_repository.dart';
import '../../../features/anime/data/models/anime_model.dart';
import '../../../features/profile/services/comment_theme_service.dart';
import '../../../features/profile/data/models/profile_font_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../../shared/widgets/swipe_to_reply.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../core/services/pip_service.dart';
import '../../review/presentation/widgets/review_input_dialog.dart';
import '../../../shared/widgets/bouncy_tap.dart';

class AnimeEpisodePlayerScreen extends StatefulWidget {
  final String episodeId;
  final String episodeLabel;
  final String? episodeUrl;
  final String? animeId;
  final String? animeTitle;
  final String? animeThumb;
  final List<EpisodeModel>? episodes;
  final int? currentEpisodeIndex;
  final Duration? startAt;
  final bool scrollToComments;

  const AnimeEpisodePlayerScreen({
    super.key,
    required this.episodeId,
    required this.episodeLabel,
    this.episodeUrl,
    this.animeId,
    this.animeTitle,
    this.animeThumb,
    this.episodes,
    this.currentEpisodeIndex,
    this.startAt,
    this.scrollToComments = false,
  });

  @override
  State<AnimeEpisodePlayerScreen> createState() =>
      _AnimeEpisodePlayerScreenState();
}

class _AnimeEpisodePlayerScreenState extends State<AnimeEpisodePlayerScreen>
    with WidgetsBindingObserver, RouteAware {
  final _repo = AnimeRepository.instance;
  final _progressService = AnimeWatchProgressService.instance;

  // VideoPlayer Engine (fvp hardware acceleration on Android, iOS, Windows, Linux)
  VideoPlayerController? _videoPlayerController;
  bool _isCompletedHandled = false;

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  bool _isFullscreen = false;
  bool _wasFullscreenBeforePip = false;
  bool _isActuallyInPipMode = false;
  double _savedScrollOffsetBeforePip = 0.0;
  final ValueNotifier<bool> _showPlayerOverlayNotifier = ValueNotifier<bool>(true);
  Timer? _overlayHideTimer;

  // Custom Player Controls State (Moko Monochrome)
  bool _isScrubbing = false;
  double _scrubValue = 0.0;
  String? _seekFeedbackText;
  Timer? _seekFeedbackTimer;
  Timer? _pendingRelativeSeekTimer;
  Duration? _pendingSeekTarget;
  Timer? _bufferingWatchdogTimer;
  DateTime? _bufferingStartTime;
  bool _isAutoRecovering = false;
  Timer? _bufferingDebounceTimer;
  Duration _lastObservedPos = Duration.zero;

  bool _isPlayerInitializing = false;
  bool _isWatched = false;

  String get _effectiveAnimeId {
    if (_currentEpisodeUrl != null && _currentEpisodeUrl!.contains('series=')) {
      final s = AnimeWatchProgressService.cleanAnimeSlug(_currentEpisodeUrl!);
      if (s.isNotEmpty && !s.contains(' ')) return s;
    }
    if (_ylnimeStream?.url != null && _ylnimeStream!.url.contains('series=')) {
      final s = AnimeWatchProgressService.cleanAnimeSlug(_ylnimeStream!.url);
      if (s.isNotEmpty && !s.contains(' ')) return s;
    }
    if (widget.animeId != null && widget.animeId!.isNotEmpty) {
      final s = AnimeWatchProgressService.cleanAnimeSlug(widget.animeId!);
      if (s.isNotEmpty && !s.contains(' ')) return s;
    }
    if (_fallbackStream?.animeId != null && _fallbackStream!.animeId!.isNotEmpty) {
      final s = AnimeWatchProgressService.cleanAnimeSlug(_fallbackStream!.animeId!);
      if (s.isNotEmpty && !s.contains(' ')) return s;
    }
    return '';
  }

  String get _effectiveEpisodeId {
    if (_currentEpisodeId.isNotEmpty && !_currentEpisodeId.startsWith('http')) {
      final clean = AnimeWatchProgressService.cleanEpisodeSlug(_currentEpisodeId);
      if (clean.isNotEmpty) return clean;
    }
    if (widget.episodeId.isNotEmpty && !widget.episodeId.startsWith('http')) {
      final clean = AnimeWatchProgressService.cleanEpisodeSlug(widget.episodeId);
      if (clean.isNotEmpty) return clean;
    }
    if (_currentEpisodeUrl != null && _currentEpisodeUrl!.isNotEmpty) {
      final clean = AnimeWatchProgressService.cleanEpisodeSlug(_currentEpisodeUrl!);
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  // Real-time session delta tracking untuk genre role watch duration
  int _sessionWatchSeconds = 0;

  // Track last stream URL untuk skip re-init kalau sama
  String? _lastStreamUrl;
  bool _hasAttemptedProxyFallback = false;

  // Auto-stop state
  bool _isDisposing = false;

  // Stream state
  YlnimeEpisodeStreams? _ylnimeStream;
  EpisodeStreamModel? _fallbackStream;
  bool _isUsingFallback = false;
  bool _loading = true;
  bool _qualityLoading = false;
  String? _error;
  Duration _lastKnownStartAt = Duration.zero;


  // Active play state
  late String _currentEpisodeId;
  late String _currentEpisodeLabel;
  String? _currentEpisodeUrl;
  int _currentEpisodeIndex = 0;
  List<EpisodeModel> _episodes = [];
  bool _loadingEpisodes = false;

  // LAZY LOAD
  bool _episodesLoadTriggered = false;
  bool _episodesLoaded = false;

  // Quality & Server state
  static const String _kPrefQualityKey = 'preferred_video_quality';
  static String _savedPreferredQuality = '720p';
  String _preferredQuality = _savedPreferredQuality;
  String _selectedQuality = _savedPreferredQuality;
  List<String> get _availableQualities {
    if (_ylnimeStream != null && _ylnimeStream!.qualities.isNotEmpty) {
      final valid = _ylnimeStream!.qualities
          .map((q) => q.title)
          .where((t) => t.isNotEmpty && t.toLowerCase() != 'default')
          .toSet()
          .toList();
      if (valid.isNotEmpty) {
        valid.sort((a, b) {
          final aNum = int.tryParse(a.replaceAll('p', '')) ?? 0;
          final bNum = int.tryParse(b.replaceAll('p', '')) ?? 0;
          return bNum.compareTo(aNum);
        });
        return valid;
      }
    }
    return const ['1080p', '720p', '480p', '360p'];
  }
  int _selectedServerIndex = 0;
  late final ValueNotifier<String> _selectedQualityNotifier;
  late final ValueNotifier<String> _selectedServerNotifier;
  late final ValueNotifier<String> _currentEpisodeLabelNotifier;
  double _playbackSpeed = 1.0;
  late final ValueNotifier<double> _playbackSpeedNotifier;
  late final ValueNotifier<bool> _isScreenLockedNotifier;
  late final ValueNotifier<bool> _isBufferingNotifier;

  // Hold-to-Speed feature (YouTube style 2X boost on long press)
  bool _isHoldingForSpeed = false;
  double _speedBeforeHold = 1.0;
  bool _wasPlayingBeforeHold = false;

  final ScrollController _horizontalEpisodeScrollCtrl = ScrollController();

  void _scrollToCurrentEpisode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalEpisodeScrollCtrl.hasClients || _episodes.isEmpty) return;
      final targetIdx = _currentEpisodeIndex.clamp(0, _episodes.length - 1);
      final offset = (targetIdx * 52.0) - 100.0;
      _horizontalEpisodeScrollCtrl.animateTo(
        offset.clamp(0.0, _horizontalEpisodeScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static Future<void> _savePreferredQuality(String quality) async {
    _savedPreferredQuality = quality;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefQualityKey, quality);
      debugPrint('[Quality] Saved preferred quality: $quality');
    } catch (e) {
      debugPrint('[Quality] Failed to save preferred quality: $e');
    }
  }

  Future<void> _loadPreferredQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kPrefQualityKey);
      if (saved != null && saved.trim().isNotEmpty) {
        final clean = saved.trim();
        _savedPreferredQuality = clean;
        _preferredQuality = clean;
        _selectedQuality = clean;
        _selectedQualityNotifier.value = clean;
        debugPrint('[Quality] Loaded preferred quality from disk: $clean');
      }
    } catch (e) {
      debugPrint('[Quality] Failed to load preferred quality: $e');
    }
  }

  static int _extractResolutionNumber(String title) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  static YlnimeQualityStream _resolveTargetQuality(
    List<YlnimeQualityStream> qualities,
    String preferred,
  ) {
    if (qualities.isEmpty) {
      return const YlnimeQualityStream(title: '');
    }

    final validQualities = qualities.where((q) => q.serverList.isNotEmpty).toList();
    final candidatePool = validQualities.isNotEmpty ? validQualities : qualities;

    final cleanPref = preferred.toLowerCase().replaceAll('p', '').trim();

    // 1. Prioritas kualitas yang dipilih user (misal 1080p / 1080)
    for (final q in candidatePool) {
      final cleanQ = q.title.toLowerCase().replaceAll('p', '').trim();
      final isLowMatch = (cleanPref == '320' || cleanPref == '360') && (cleanQ == '360' || cleanQ == '320');
      if (cleanQ != 'default' && (cleanQ == cleanPref || cleanQ.contains(cleanPref) || cleanPref.contains(cleanQ) || isLowMatch)) {
        return q;
      }
    }

    // 2. Default fallback ke 720p jika kualitas pilihan tidak tersedia di episode ini
    for (final q in candidatePool) {
      final cleanQ = q.title.toLowerCase().replaceAll('p', '').trim();
      if (cleanQ == '720' || cleanQ.contains('720')) {
        return q;
      }
    }

    // 3. Fallback jika ada kualitas "Default" -> konversikan ke resolusi efektif (bukan string 'Default')
    for (final q in candidatePool) {
      if (q.title.toLowerCase() == 'default') {
        final effectiveTitle = cleanPref.isNotEmpty && cleanPref != 'default' ? preferred : '720p';
        return YlnimeQualityStream(
          title: effectiveTitle,
          serverList: q.serverList,
        );
      }
    }

    // 4. Fallback ke resolusi tertinggi berikutnya yang tersedia (misal 480p > 360p)
    final nonDefault = candidatePool.where((q) => q.title.toLowerCase() != 'default').toList();
    final poolToSort = nonDefault.isNotEmpty ? nonDefault : candidatePool;
    final sorted = List<YlnimeQualityStream>.from(poolToSort)
      ..sort((a, b) => _extractResolutionNumber(b.title).compareTo(_extractResolutionNumber(a.title)));

    return sorted.first;
  }

  // LAZY LOAD: Scroll controller
  final ScrollController _scrollController = ScrollController();
  static const double _commentsTriggerOffset = 500.0;

  // Comments state
  List<EpisodeCommentModel> _comments = [];
  bool _loadingComments = false;
  bool _commentsLoadTriggered = false;
  bool _commentsLoaded = false;
  String? _commentsError;
  int _commentsCount = 0;
  String _commentSort = 'newest';
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmittingComment = false;
  bool _commentIsSpoiler = false;
  int? _replyingToCommentId;
  String? _replyingToUsername;
  final Set<int> _revealedSpoilers = {};
  final Set<int> _expandedCommentReplies = {};
  final Set<int> _loadingRepliesFor = {};
  File? _stagedCommentMediaFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CommentThemeService.instance.init();
    _currentEpisodeId = widget.episodeId;
    _currentEpisodeLabel = widget.episodeLabel;
    _currentEpisodeUrl = widget.episodeUrl;
    _currentEpisodeIndex = widget.currentEpisodeIndex ?? 0;
    _preferredQuality = _savedPreferredQuality;
    _selectedQuality = _savedPreferredQuality;
    _selectedQualityNotifier = ValueNotifier<String>(_selectedQuality);
    _selectedServerNotifier = ValueNotifier<String>('Server 1');
    _currentEpisodeLabelNotifier = ValueNotifier<String>(_currentEpisodeLabel);
    _playbackSpeedNotifier = ValueNotifier<double>(_playbackSpeed);
    _isScreenLockedNotifier = ValueNotifier<bool>(false);
    _isBufferingNotifier = ValueNotifier<bool>(false);
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      _episodes = List<EpisodeModel>.from(widget.episodes!);
      _episodesLoaded = true;
      _scrollToCurrentEpisode();
    } else {
      _fetchEpisodesIfNeeded();
    }

    _initPlaybackWithResume();
    // ⚡ Jangan ganggu inisialisasi pemutaran video dengan beban HTTP komentar
    final commentDelay = widget.scrollToComments ? 300 : 1500;
    Future.delayed(Duration(milliseconds: commentDelay), () {
      if (mounted && !_isDisposing && !_commentsLoaded && !_loadingComments) {
        _loadComments();
      }
      if (widget.scrollToComments && mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          650.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
    _scrollController.addListener(_onScroll);

    PipService.instance.isInPip.addListener(_onPipChanged);
    PipService.instance.registerActivePlayer(onPause: _pausePlayer);
    _syncPipState();

    // Cleanup progress lama di background
    unawaited(_progressService.cleanupOldProgress(daysOld: 30));



    // Watchdog — jika 45 detik masih stuck loading, tampilkan error
    Future.delayed(const Duration(seconds: 45), () {
      if (!mounted || _isDisposing) return;
      if ((_loading || _isPlayerInitializing) && _videoPlayerController == null) {
        debugPrint('[Player] Watchdog: stuck loading after 45s, showing error');
        setState(() {
          _loading = false;
          _isPlayerInitializing = false;
          _error = 'Memuat video terlalu lama. Periksa koneksi internet atau coba ganti server.';
        });
      }
    });
  }

  AuthProvider? _authProvider;

  void _pausePlayer() {
    try {
      _videoPlayerController?.pause();
      PipService.instance.setAutoPip(false);
      unawaited(_recordHistory());
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    final route = ModalRoute.of(context);
    if (route != null) {
      PipService.routeObserver.subscribe(this, route);
    }
  }

  @override
  void deactivate() {
    // Dipanggil seketika saat route/screen dicopot dari widget tree
    _pausePlayer();
    super.deactivate();
  }

  @override
  void didPush() {
    _syncPipState();
  }

  @override
  void didPopNext() {
    // Kembali ke layar pemutar video
    _syncPipState();
  }

  @override
  void didPushNext() {
    // Biarkan video tetap berjalan jika user hanya membuka modal/sheet di dalam player,
    // dan jangan langsung matikan state secara agresif.
  }

  @override
  void didPop() {
    // Layar pemutar video ditutup/pop
    _pausePlayer();
    PipService.instance.disablePipNow();
  }

  void _syncPipState() {
    if (!mounted || _isDisposing) {
      PipService.instance.disablePipNow();
      return;
    }
    final isPlaying = _videoPlayerController?.value.isPlaying == true;
    PipService.instance.updateVideoPlaybackState(
      isVideoScreen: true,
      isPlaying: isPlaying,
    );
  }

  void _onPipChanged() {
    if (!mounted || _isDisposing) return;
    final inPip = PipService.instance.isInPip.value;
    if (inPip) {
      _isActuallyInPipMode = true;
      debugPrint('[PiP] Entered PiP mode in Anime player, saving original state');
      _wasFullscreenBeforePip = _isFullscreen;
      if (_scrollController.hasClients) {
        _savedScrollOffsetBeforePip = _scrollController.offset;
      }
      if (_isPlayingNotifier.value && _videoPlayerController?.value.isPlaying == true) {
        try {
          _videoPlayerController?.play();
        } catch (_) {}
      } else {
        try {
          _videoPlayerController?.pause();
        } catch (_) {}
      }
    } else {
      if (!_isActuallyInPipMode) {
        debugPrint('[PiP] Ignored false onPipChanged(false) - player was not in PiP');
        return;
      }
      _isActuallyInPipMode = false;
      debugPrint('[PiP] Exited PiP mode in Anime player, restoring original state: wasFullscreen=$_wasFullscreenBeforePip');
      setState(() {
        _isFullscreen = _wasFullscreenBeforePip;
      });
      if (_wasFullscreenBeforePip) {
        PipService.instance.enterFullscreen();
      } else {
        PipService.instance.exitFullscreen();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients && _savedScrollOffsetBeforePip > 0) {
          _scrollController.jumpTo(_savedScrollOffsetBeforePip);
        }
      });
      _syncPipState();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;

    if (!_commentsLoadTriggered && !_commentsLoaded && pixels > _commentsTriggerOffset) {
      _commentsLoadTriggered = true;
      _loadComments();
    }

    if (!_episodesLoadTriggered && !_episodesLoaded && pixels > 200.0) {
      _episodesLoadTriggered = true;
      _fetchEpisodesIfNeeded();
    }
  }

  /// Mulai pemutaran dari awal (00:00) per permintaan:
  /// "simpan aja episode nonton menit detik jam jangan, klu broken resumenya hapus aja ulang dari awal"
  Future<void> _initPlaybackWithResume() async {
    await _loadPreferredQuality();

    final animeId = _effectiveAnimeId;

    // Simpan episode ini ke progress lokal agar langsung muncul di Lanjut Nonton
    if (animeId.isNotEmpty) {
      unawaited(
        _progressService.saveProgress(
          animeId: animeId,
          episodeId: _currentEpisodeId,
          positionSeconds: 0,
          totalDurationSeconds: 0,
          episodeLabel: _currentEpisodeLabel,
          episodeUrl: _currentEpisodeUrl,
          animeTitle: widget.animeTitle,
          thumb: widget.animeThumb,
        ),
      );
    }

    // ⚡ Jalankan pemuatan stream dengan resume posisi jika ada
    _loadStream(startAt: widget.startAt ?? Duration.zero);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposing) return;

    final isPlaying = _videoPlayerController?.value.isPlaying == true;

    // 🔥 Jika video memang sedang TIDAK diputar oleh user, pastikan tetap pause dan matikan Auto-PiP
    if (!isPlaying) {
      try {
        _videoPlayerController?.pause();
      } catch (_) {}
      PipService.instance.setAutoPip(false);
      return;
    }

    // 🔥 JANGAN pause jika sedang dalam mode PiP aktif!
    if (PipService.instance.isInPip.value) {
      debugPrint('[PlayerLifecycle] App in PiP mode ($state), keeping playback active');
      return;
    }

    // Pause jika app masuk ke background (paused, hidden, atau inactive di Windows)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (Platform.isWindows && state == AppLifecycleState.inactive)) {
      debugPrint('[PlayerLifecycle] App entering background: $state');

      // Jika Auto-PiP aktif dan video sedang berjalan, beri waktu Android transisi ke PiP
      if (PipService.instance.isAutoPipEnabled && isPlaying) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isDisposing) return;
          if (!PipService.instance.isInPip.value) {
            try {
              _videoPlayerController?.pause();
            } catch (_) {}
            unawaited(_recordHistory(force: true));
          }
        });
        return;
      }

      try {
        _videoPlayerController?.pause();
      } catch (_) {}
      unawaited(_recordHistory(force: true));
    }
  }

  Future<void> _fetchEpisodesIfNeeded() async {
    if (_episodes.isNotEmpty || _loadingEpisodes) return;
    final animeId = (widget.animeId != null && widget.animeId!.isNotEmpty)
        ? widget.animeId!
        : (_effectiveAnimeId.isNotEmpty
            ? _effectiveAnimeId
            : (_fallbackStream?.animeId ?? ''));
    if (animeId.isEmpty) return;

    setState(() => _loadingEpisodes = true);
    try {
      final detail = await _repo.detail(animeId);
      if (!mounted || _isDisposing) return;
      if (detail.episodes.isNotEmpty) {
        setState(() {
          _episodes = detail.episodes;
          _episodesLoaded = true;
          _loadingEpisodes = false;
          final idx = _episodes.indexWhere(
            (e) =>
                e.id == _currentEpisodeId ||
                (e.url != null && _currentEpisodeUrl != null && e.url == _currentEpisodeUrl) ||
                e.label.trim().toLowerCase() == _currentEpisodeLabel.trim().toLowerCase(),
          );
          if (idx >= 0) {
            _currentEpisodeIndex = idx;
            if (_currentEpisodeUrl == null || _currentEpisodeUrl!.isEmpty) {
              _currentEpisodeUrl = _episodes[idx].url;
            }
          }
        });
        _scrollToCurrentEpisode();
      } else {
        if (mounted) setState(() => _loadingEpisodes = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  @override
  void dispose() {
    _overlayHideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _pendingRelativeSeekTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _bufferingDebounceTimer?.cancel();
    unawaited(_recordHistory(force: true));

    _isDisposing = true;
    _pausePlayer();
    PipService.instance.unregisterActivePlayer(onPause: _pausePlayer);
    PipService.instance.isFullscreen.value = false;

    if (_isFullscreen) {
      PipService.instance.exitFullscreen();
    }

    PipService.routeObserver.unsubscribe(this);
    PipService.instance.isInPip.removeListener(_onPipChanged);
    PipService.instance.setAutoPip(false);
    PipService.instance.disablePipNow();

    WidgetsBinding.instance.removeObserver(this);

    _stopAndDisposePlayer();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _horizontalEpisodeScrollCtrl.dispose();

    _selectedQualityNotifier.dispose();
    _selectedServerNotifier.dispose();
    _currentEpisodeLabelNotifier.dispose();
    _playbackSpeedNotifier.dispose();
    _isScreenLockedNotifier.dispose();
    _isBufferingNotifier.dispose();
    _showPlayerOverlayNotifier.dispose();
    _commentInputController.dispose();
    _commentFocusNode.dispose();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  int? _extractEpisodeNumber(String label) {
    final m = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(label);
    if (m != null) return int.tryParse(m.group(1)!);
    final match = RegExp(r'\d+').firstMatch(label);
    if (match != null) return int.tryParse(match.group(0)!);
    final idMatch = RegExp(r'(?:episode|ep|eps)[-_]?(\d+)', caseSensitive: false).firstMatch(_currentEpisodeId);
    if (idMatch != null) return int.tryParse(idMatch.group(1)!);
    if (int.tryParse(_currentEpisodeId) != null) return int.tryParse(_currentEpisodeId);
    if (int.tryParse(widget.episodeId) != null) return int.tryParse(widget.episodeId);
    if (_currentEpisodeUrl != null) {
      final urlMatch = RegExp(r'(?:episode|ep|eps)[-_=](\d+)', caseSensitive: false).firstMatch(_currentEpisodeUrl!);
      if (urlMatch != null) return int.tryParse(urlMatch.group(1)!);
    }
    return null;
  }

  Future<void> _loadStream({Duration startAt = Duration.zero}) async {
    if (_isDisposing) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? ylnimeEpUrl = _currentEpisodeUrl;
      String? seriesSlug;
      final effectiveSlug = _effectiveAnimeId;
      if (effectiveSlug.isNotEmpty && !effectiveSlug.contains(' ')) {
        seriesSlug = effectiveSlug;
      } else if (widget.animeId != null &&
          widget.animeId!.isNotEmpty &&
          !widget.animeId!.contains(' ') &&
          !widget.animeId!.startsWith('http')) {
        seriesSlug = widget.animeId;
      }

      var targetStartAt = startAt;
      if (targetStartAt == Duration.zero) {
        final aId = seriesSlug ?? _effectiveAnimeId;
        final eId = _effectiveEpisodeId.isNotEmpty ? _effectiveEpisodeId : _currentEpisodeId;
        if (aId.isNotEmpty && eId.isNotEmpty) {
          final savedSec = await _progressService.getSavedPosition(
            animeId: aId,
            episodeId: eId,
            episodeUrl: _currentEpisodeUrl,
            episodeLabel: _currentEpisodeLabel,
          );
          if (savedSec != null && savedSec > 0) {
            targetStartAt = Duration(seconds: savedSec);
          }
        }
      }

      if (ylnimeEpUrl != null && ylnimeEpUrl.trim().isNotEmpty) {
        ylnimeEpUrl = ylnimeEpUrl.trim();
        if (!ylnimeEpUrl.startsWith('http')) {
          if (ylnimeEpUrl.startsWith('/')) ylnimeEpUrl = ylnimeEpUrl.substring(1);
          if (ylnimeEpUrl.startsWith('index.php')) {
            ylnimeEpUrl = 'https://ylnime.com/$ylnimeEpUrl';
          } else if (ylnimeEpUrl.startsWith('episode=')) {
            ylnimeEpUrl = 'https://ylnime.com/index.php?$ylnimeEpUrl';
          } else if (ylnimeEpUrl.contains('series=') && ylnimeEpUrl.contains('episode=')) {
            final query = ylnimeEpUrl.contains('?') ? ylnimeEpUrl.substring(ylnimeEpUrl.indexOf('?') + 1) : ylnimeEpUrl;
            ylnimeEpUrl = 'https://ylnime.com/index.php?$query';
          } else if (ylnimeEpUrl.contains('episode=')) {
            final epPart = ylnimeEpUrl.contains('?') ? ylnimeEpUrl.substring(ylnimeEpUrl.indexOf('?') + 1) : ylnimeEpUrl;
            if (seriesSlug != null) {
              ylnimeEpUrl = 'https://ylnime.com/index.php?series=$seriesSlug&$epPart';
            } else {
              ylnimeEpUrl = 'https://ylnime.com/index.php?$epPart';
            }
          } else {
            ylnimeEpUrl = 'https://ylnime.com/index.php?episode=$ylnimeEpUrl';
            if (seriesSlug != null) {
              ylnimeEpUrl = 'https://ylnime.com/index.php?series=$seriesSlug&episode=$ylnimeEpUrl';
            } else {
              ylnimeEpUrl = 'https://ylnime.com/index.php?episode=$ylnimeEpUrl';
            }
          }
        }
        if (seriesSlug != null && !ylnimeEpUrl.contains('series=')) {
          if (ylnimeEpUrl.contains('index.php?')) {
            ylnimeEpUrl = ylnimeEpUrl.replaceFirst('index.php?', 'index.php?series=$seriesSlug&');
          } else if (ylnimeEpUrl.contains('?')) {
            ylnimeEpUrl = ylnimeEpUrl.replaceFirst('?', '?series=$seriesSlug&');
          }
        }
        _currentEpisodeUrl = ylnimeEpUrl;
      } else if (_currentEpisodeId.isNotEmpty &&
          _currentEpisodeId.contains('al-') &&
          _currentEpisodeId != seriesSlug &&
          _currentEpisodeId != widget.animeId) {
        ylnimeEpUrl = 'https://ylnime.com/index.php?episode=$_currentEpisodeId';
        if (seriesSlug != null) {
          ylnimeEpUrl = 'https://ylnime.com/index.php?series=$seriesSlug&episode=$_currentEpisodeId';
        }
        _currentEpisodeUrl = ylnimeEpUrl;
      }

      final epNum = _extractEpisodeNumber(_currentEpisodeLabel);

      // Resolve jika episode URL tidak ditemukan sama sekali atau tidak valid
      if (ylnimeEpUrl == null || ylnimeEpUrl.isEmpty || !ylnimeEpUrl.contains('episode=')) {
        final resolved = await _repo.resolveYlnimeEpisodeUrl(
          title: widget.animeTitle ?? '',
          seriesSlug: seriesSlug,
          episodeNumber: epNum,
        );
        if (resolved != null && resolved.isNotEmpty) {
          ylnimeEpUrl = resolved;
          _currentEpisodeUrl = resolved;
        }
      }

      YlnimeEpisodeStreams? yStream;
      if (ylnimeEpUrl != null && ylnimeEpUrl.isNotEmpty) {
        // ⚡ Langsung panggil GET /ylnime/episode untuk memutar video super cepat
        yStream = await _repo.ylnimeEpisode(ylnimeEpUrl, seriesSlug: seriesSlug, quality: _selectedQuality);
      }

      // 🔥 RESCUE FALLBACK: Jika stream masih kosong/gagal (misal link lama kadaluarsa atau hash berubah), resolve ulang URL episode fresh!
      if (yStream == null || (yStream.qualities.isEmpty && yStream.bestPlayable == null)) {
        debugPrint('[Stream] Initial YLnime episode failed or empty, attempting dynamic URL resolution...');
        final freshResolved = await _repo.resolveYlnimeEpisodeUrl(
          title: widget.animeTitle ?? '',
          seriesSlug: seriesSlug,
          episodeNumber: epNum,
        );
        if (freshResolved != null && freshResolved.isNotEmpty && freshResolved != ylnimeEpUrl) {
          debugPrint('[Stream] Found fresh episode URL: $freshResolved (was: $ylnimeEpUrl)');
          ylnimeEpUrl = freshResolved;
          _currentEpisodeUrl = freshResolved;
          yStream = await _repo.ylnimeEpisode(ylnimeEpUrl, seriesSlug: seriesSlug, quality: _selectedQuality);
        }
      }

      if (yStream != null && (yStream.qualities.isNotEmpty || yStream.bestPlayable != null)) {
        debugPrint('[Stream] Got stream from YLnime (qualities: ${yStream.qualities.length}, best: ${yStream.bestPlayable?.server})');
        if (!mounted || _isDisposing) return;
        setState(() {
          _ylnimeStream = yStream;
          _isUsingFallback = false;
          _selectedServerIndex = 0;
          _isPlayerInitializing = false;
        });
        await _applyVideoSource(startAt: targetStartAt);
        return;
      }

      debugPrint('[Stream] /ylnime/episode/quick and /ylnime/episode failed, trying fallback API...');

      // Fallback ke API internal
      if (_currentEpisodeId.isEmpty || _currentEpisodeId.startsWith('http')) {
        // Tidak ada ID episode valid untuk fallback
        if (!mounted || _isDisposing) return;
        setState(() {
          _isUsingFallback = true;
          _error = 'Tidak dapat memuat stream video dari server utama dan tidak ada ID episode cadangan.';
          _loading = false;
          _isPlayerInitializing = false;
        });
        return;
      }

      try {
        final fallback = await _repo.episode(_currentEpisodeId);
        if (!mounted || _isDisposing) return;
        if (fallback.mirrors.isEmpty && fallback.streams.isEmpty &&
            (fallback.defaultStreamingUrl == null || fallback.defaultStreamingUrl!.isEmpty)) {
          // Fallback juga kosong
          setState(() {
            _isUsingFallback = true;
            _error = 'Server utama & server cadangan (fallback) kosong. Coba ganti server atau ulangi nanti.';
            _loading = false;
            _isPlayerInitializing = false;
          });
          return;
        }
        setState(() {
          _isUsingFallback = true;
          _fallbackStream = fallback;
          _isPlayerInitializing = true;
        });
        await _applyFallbackSource(startAt: targetStartAt);
      } catch (fallbackErr) {
        debugPrint('[Stream] Fallback also failed: $fallbackErr');
        if (!mounted || _isDisposing) return;
        setState(() {
          _isUsingFallback = true;
          _error = 'Gagal memuat video (Server utama & cadangan bermasalah: ${AppErrorFormatter.formatVideoError(fallbackErr)}). Silakan ganti server atau coba beberapa saat lagi.';
          _loading = false;
          _isPlayerInitializing = false;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposing) return;
      debugPrint('[Stream] _loadStream caught: $e');
      setState(() {
        _error = AppErrorFormatter.formatVideoError(e);
        _loading = false;
        _isPlayerInitializing = false;
      });
    }
  }



  String _resolveDirectVideoUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return url;

    // Handle endpoint relatif proxy (/api/ylnime/stream-proxy?url=...)
    if (url.startsWith('/')) {
      return '${ApiConfig.baseUrl}$url';
    }

    // Rute direct S3 CDN via VPS stream-proxy agar Content-Type dipaksa video/mp4 (bukan application/octet-stream)
    // Ini krusial agar semua resolusi (360p, 480p, 720p, 1080p) dapat diputar di perangkat 32-bit & 64-bit tanpa error.
    if (url.contains('s3.animeverse.id') && !url.contains('/stream-proxy')) {
      return '${ApiConfig.apiBase}/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(url)}';
    }

    if (url.contains('pixeldrain.com/u/') || url.contains('pixeldrain.com/l/')) {
      final pixelMatch = RegExp(r'pixeldrain\.com/(?:u|l)/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
      if (pixelMatch != null) {
        final fileId = pixelMatch.group(1);
        return 'https://pixeldrain.com/api/file/$fileId?download';
      }
    }

    final gdriveMatch = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
    if (gdriveMatch != null) {
      final fileId = gdriveMatch.group(1);
      return 'https://drive.google.com/uc?id=$fileId&export=download';
    }

    return url;
  }

  Map<String, String> _getHeadersForUrl(String url) {
    final lower = url.toLowerCase();

    // ⚡ Direct storage / S3 bucket atau direct mp4 (tanpa Referer/Origin agar Cloudflare CDN stream langsung 0ms CORS)
    if (lower.contains('s3.animeverse.id') ||
        lower.contains('animeverse.id') ||
        lower.contains('animeverse.') ||
        lower.contains('/stream-proxy') ||
        lower.contains(':2028')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }

    if (lower.contains('desustream.net') || lower.contains('odcloud')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://desustream.net/',
      };
    }

    if (lower.contains('pixeldrain.com')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://pixeldrain.com/',
      };
    }

    if (lower.contains('animekita.org')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://storage.animekita.org/',
      };
    }

    if (lower.contains('ylnime.com') || lower.contains('ylnime.')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://ylnime.com/',
      };
    }

    // Direct MP4 static files
    if (lower.endsWith('.mp4') || lower.contains('.mp4?')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }

    final uri = Uri.tryParse(url);
    final ref = (uri != null && uri.host.isNotEmpty)
        ? '${uri.scheme}://${uri.host}/'
        : 'https://ylnime.com/';

    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': ref,
    };
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
        label.contains('.art') ||
        label.contains('/')) {
      return 'Server ${index + 1}';
    }
    return label;
  }

  Future<void> _applyVideoSource({Duration startAt = Duration.zero}) async {
    if (_isDisposing) return;
    if (_ylnimeStream == null || (_ylnimeStream!.qualities.isEmpty && _ylnimeStream!.bestPlayable == null)) {
      debugPrint('[Stream] Cannot apply: no stream or empty qualities');
      return;
    }

    final targetQuality = _resolveTargetQuality(_ylnimeStream!.qualities, _preferredQuality);

    final validServers = targetQuality.serverList.where((s) {
      final u = s.url.trim();
      return u.isNotEmpty && !u.contains(r'${') && (u.startsWith('http') || u.startsWith('/'));
    }).toList();

    // Prioritaskan server Proxy VPS Cepat (Rekomendasi v7a & Anti-Buffering) di urutan paling atas
    validServers.sort((a, b) {
      final aIsProxy = a.url.contains('/stream-proxy') || a.server.toLowerCase().contains('proxy');
      final bIsProxy = b.url.contains('/stream-proxy') || b.server.toLowerCase().contains('proxy');
      if (aIsProxy && !bIsProxy) return -1;
      if (!aIsProxy && bIsProxy) return 1;

      return 0;
    });

    final serversPool = validServers.isNotEmpty ? validServers : targetQuality.serverList;

    if (serversPool.isEmpty) {
      final best = _ylnimeStream?.bestPlayable;
      if (best != null && best.url.isNotEmpty && !best.url.contains(r'${')) {
        _selectedServerIndex = 0;
        _selectedServerNotifier.value = _formatServerLabel(best.server, 0);
        await _initializePlayer(best.url, startAt: startAt);
      } else {
        debugPrint('[Stream] Server list empty for ${targetQuality.title}');
      }
      return;
    }

    // Gunakan server yang dipilih secara konsisten tanpa diacak atau dioper ke server lain
    final validIndex = (_selectedServerIndex >= 0 && _selectedServerIndex < serversPool.length)
        ? _selectedServerIndex
        : 0;
    _selectedServerIndex = validIndex;
    final selectedServer = serversPool[validIndex];

    final resolvedQuality = (targetQuality.title.isNotEmpty && targetQuality.title.toLowerCase() != 'default')
        ? targetQuality.title
        : (_preferredQuality.isNotEmpty && _preferredQuality.toLowerCase() != 'default' ? _preferredQuality : '720p');
    _selectedQuality = resolvedQuality;
    _selectedQualityNotifier.value = _selectedQuality;

    _selectedServerNotifier.value = _formatServerLabel(selectedServer.server, _selectedServerIndex);

    debugPrint('[Stream] Playing server ${selectedServer.server} (Server ${_selectedServerIndex + 1}) @ ${targetQuality.title}: ${selectedServer.url}');

    final success = await _initializePlayer(
      selectedServer.url,
      startAt: startAt,
    );
    if (!success && mounted && !_isDisposing) {
      setState(() {
        _isPlayerInitializing = false;
        _qualityLoading = false;
        _loading = false;
        _error = 'Gagal memuat video dari Server ${_selectedServerIndex + 1}. Silakan coba lagi atau pilih server lain.';
      });
    }
  }

  // 🔥 FIX: Sama untuk fallback
  Future<void> _applyFallbackSource({Duration startAt = Duration.zero}) async {
    if (_isDisposing) return;
    if (_fallbackStream == null) return;

    String? url;

    if (_fallbackStream!.mirrors.isNotEmpty) {
      final idx = _selectedServerIndex < _fallbackStream!.mirrors.length
          ? _selectedServerIndex
          : 0;
      url = _fallbackStream!.mirrors[idx].url;
    } else if (_fallbackStream!.streams.isNotEmpty) {
      final idx = _selectedServerIndex < _fallbackStream!.streams.length
          ? _selectedServerIndex
          : 0;
      url = _fallbackStream!.streams[idx].url;
    } else if (_fallbackStream!.defaultStreamingUrl != null &&
        _fallbackStream!.defaultStreamingUrl!.isNotEmpty) {
      url = _fallbackStream!.defaultStreamingUrl;
    }

    if (url != null && url.isNotEmpty) {
      final success = await _initializePlayer(url, startAt: startAt);
      if (!success && mounted && !_isDisposing) {
        setState(() {
          _isPlayerInitializing = false;
          _qualityLoading = false;
          _loading = false;
          _error = 'Gagal memuat video dari server ini. Silakan coba server lain.';
        });
      }
    }
  }


  String _cleanStreamUrl(String url) {
    if (url.isEmpty) return '';
    if (url.contains('pixeldrain.com')) {
      return url; // Pixeldrain API membutuhkan parameter ?download untuk streaming
    }
    return url
        .replaceAll('?download', '')
        .replaceAll('&download', '')
        .replaceAll(RegExp(r'\?$'), '')
        .replaceAll(RegExp(r'&$'), '');
  }


  /// Hentikan dan bersihkan controller lama sepenuhnya (Memory & Audio release)
  Future<void> _stopAndDisposePlayer() async {
    _cancelBufferingWatchdog();
    _bufferingDebounceTimer?.cancel();
    _bufferingDebounceTimer = null;
    _lastObservedPos = Duration.zero;
    PipService.instance.disablePipNow();

    final oldVp = _videoPlayerController;
    _videoPlayerController = null;

    if (oldVp != null) {
      try {
        oldVp.removeListener(_onVideoPlayerUpdate);
      } catch (_) {}
      try {
        await oldVp.pause();
      } catch (_) {}
      try {
        await oldVp.dispose();
      } catch (_) {}
    }
  }

  void _startBufferingWatchdog() {
    _bufferingStartTime ??= DateTime.now();
    if (_bufferingWatchdogTimer != null) return;

    _bufferingWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposing || _videoPlayerController == null) {
        timer.cancel();
        _bufferingWatchdogTimer = null;
        return;
      }

      final start = _bufferingStartTime;
      if (start == null) return;
      final elapsed = DateTime.now().difference(start).inSeconds;

      // Jika buffering macet > 15 detik, coba reconnect stream saat ini (JANGAN alihkan server otomatis)
      if (elapsed >= 15 && !_isAutoRecovering) {
        _isAutoRecovering = true;
        timer.cancel();
        _bufferingWatchdogTimer = null;
        _bufferingStartTime = null;

        debugPrint('[BufferingWatchdog] Buffering stalled > 15s. Reconnecting current stream...');
        _refreshOrReconnectPlayer().whenComplete(() {
          _isAutoRecovering = false;
        });
      }
    });
  }

  void _cancelBufferingWatchdog() {
    _bufferingWatchdogTimer?.cancel();
    _bufferingWatchdogTimer = null;
    _bufferingStartTime = null;
  }

  Future<void> _refreshOrReconnectPlayer() async {
    if (!mounted || _isDisposing || _isPlayerInitializing) return;
    final url = _lastStreamUrl;
    if (url == null || url.isEmpty) return;
    final currentPos = _positionNotifier.value;
    debugPrint('[AnimePlayer Watchdog] Reconnecting stream at $currentPos...');
    _cancelBufferingWatchdog();
    await _initializePlayer(url, startAt: currentPos);
  }

  void _onVideoPlayerUpdate() {
    if (!mounted || _isDisposing) return;
    final controller = _videoPlayerController;
    if (controller == null) return;

    final value = controller.value;
    if (value.hasError) {
      final errDesc = value.errorDescription ?? '';
      debugPrint('[VideoPlayer Error] $errDesc');

      _cancelBufferingWatchdog();

      // Auto-fallback ke stream-proxy jika direct CDN error atau gagal decode di perangkat
      if (!_hasAttemptedProxyFallback &&
          _lastStreamUrl != null &&
          !_lastStreamUrl!.contains('/stream-proxy') &&
          !_isDisposing) {
        _hasAttemptedProxyFallback = true;
        final curPos = _positionNotifier.value;
        final proxyUrl = '${ApiConfig.apiBase}/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(_lastStreamUrl!)}';
        debugPrint('[VideoPlayer Error] Auto-fallback to stream-proxy: $proxyUrl at $curPos');
        _initializePlayer(proxyUrl, startAt: curPos);
        return;
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposing) {
            setState(() {
              _isPlayerInitializing = false;
              _qualityLoading = false;
              _loading = false;
              _error = 'Koneksi video terputus ($errDesc). Silakan ketuk tombol coba lagi atau pilih server lain.';
            });
          }
        });
      }
      return;
    }

    if (value.isInitialized) {
      final pos = value.position;
      final dur = value.duration;
      final isPlaying = value.isPlaying;
      final isBuffering = value.isBuffering;

      if (_positionNotifier.value != pos) {
        _positionNotifier.value = pos;
      }
      if (_durationNotifier.value != dur) {
        _durationNotifier.value = dur;
      }
      if (_isPlayingNotifier.value != isPlaying) {
        _isPlayingNotifier.value = isPlaying;
        _syncPipState();
      }
      // Deteksi status buffering cerdas & anti-flicker:
      // Jika posisi video maju (pos > _lastObservedPos), berarti frame video AKTIF berjalan!
      // Kita TIDAK BOLEH menampilkan spinner "Memuat video..." meski di background
      // buffer player sedang mengunduh chunk berikutnya.
      if (pos > _lastObservedPos) {
        _lastObservedPos = pos;
        _bufferingDebounceTimer?.cancel();
        _bufferingDebounceTimer = null;
        if (_isBufferingNotifier.value) {
          _isBufferingNotifier.value = false;
        }
        _cancelBufferingWatchdog();
      } else if (pos < _lastObservedPos) {
        // Kasus seek mundur / rewind
        _lastObservedPos = pos;
        _bufferingDebounceTimer?.cancel();
        _bufferingDebounceTimer = null;
        if (_isBufferingNotifier.value) {
          _isBufferingNotifier.value = false;
        }
      } else if (isBuffering && isPlaying && !_isScrubbing) {
        // Video berniat memutar tapi pos macet di titik yang sama DAN isBuffering bernilai true.
        // Beri toleransi 700ms agar network jitter / micro-buffer tidak memunculkan spinner bolak-balik
        _bufferingDebounceTimer ??= Timer(const Duration(milliseconds: 700), () {
          if (!mounted || _isDisposing) return;
          final currentCtrl = _videoPlayerController;
          if (currentCtrl != null &&
              currentCtrl.value.isBuffering &&
              currentCtrl.value.position == _lastObservedPos) {
            _isBufferingNotifier.value = true;
            _startBufferingWatchdog();
          }
        });
      } else if (!isBuffering) {
        _bufferingDebounceTimer?.cancel();
        _bufferingDebounceTimer = null;
        if (_isBufferingNotifier.value) {
          _isBufferingNotifier.value = false;
        }
        _cancelBufferingWatchdog();
      }

      if (pos > Duration.zero && _error != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _error != null) {
            setState(() => _error = null);
          }
        });
      }
      if (pos.inSeconds > 10 && !_isWatched) {
        _isWatched = true;
      }

      if (dur > const Duration(seconds: 15) &&
          pos >= dur - const Duration(seconds: 1) &&
          !value.isLooping) {
        if (!_isCompletedHandled) {
          _isCompletedHandled = true;
          unawaited(_recordHistory(isCompleted: true, force: true));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposing) {
              _nextEpisode();
            }
          });
        }
      }
    }
  }

  /// Inisialisasi atau buka stream video baru via VideoPlayer / Chewie (didukung fvp / FFmpeg demuxer)
  Future<bool> _initializePlayer(
    String videoUrl, {
    Duration startAt = Duration.zero,
  }) async {
    if (!mounted || _isDisposing) return false;

    final directStreamUrl = _resolveDirectVideoUrl(videoUrl);
    final cleanedDirect = _cleanStreamUrl(directStreamUrl);

    if (cleanedDirect.isEmpty || !cleanedDirect.startsWith('http')) {
      debugPrint('[AnimePlayer] No valid direct stream URL found: $videoUrl');
      if (mounted) {
        setState(() {
          _isPlayerInitializing = false;
          _qualityLoading = false;
          _error = 'Video tidak dapat diputar. Silakan coba server lain.';
        });
      }
      return false;
    }

    final streamHeaders = _getHeadersForUrl(cleanedDirect);

    await _stopAndDisposePlayer();

    if (mounted) {
      setState(() {
        _isPlayerInitializing = true;
        _error = null;
      });
    }

    _lastKnownStartAt = startAt;
    _isCompletedHandled = false;
    if (!videoUrl.contains('/stream-proxy')) {
      _hasAttemptedProxyFallback = false;
    }
    final testUrl = cleanedDirect;
    debugPrint('[AnimePlayer] Attempting VideoPlayer/Chewie init with: $testUrl (startAt: $startAt)');
    _lastStreamUrl = testUrl;

    try {
      final vp = VideoPlayerController.networkUrl(
        Uri.parse(testUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: streamHeaders.isNotEmpty ? streamHeaders : const {},
      );

      _videoPlayerController = vp;
      vp.addListener(_onVideoPlayerUpdate);

      await vp.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Inisialisasi player timeout setelah 15 detik'),
      );

      if (!mounted || _isDisposing) {
        await vp.dispose();
        return false;
      }

      if (_playbackSpeed != 1.0) {
        try {
          await vp.setPlaybackSpeed(_playbackSpeed);
        } catch (_) {}
      }

      if (startAt > Duration.zero) {
        try {
          await vp.seekTo(startAt);
        } catch (e) {
          debugPrint('[AnimePlayer] seekTo $startAt failed: $e');
        }
      }

      PipService.instance.registerActivePlayer(onPause: _pausePlayer);

      await vp.play();

      if (mounted) {
        setState(() {
          _isPlayerInitializing = false;
          _qualityLoading = false;
          _loading = false;
          _error = null;
          _showPlayerOverlayNotifier.value = true;
        });
        _startOverlayTimer();
        WakelockPlus.enable();
      }
      return true;
    } catch (e) {
      debugPrint('[AnimePlayer] VideoPlayer init failed for $testUrl: $e');

      // ⚡ Fallback ke stream-proxy jika direct URL gagal (misal diblokir ISP / SSL / decoder HP lama)
      if (!testUrl.contains('/stream-proxy')) {
        final proxyUrl = '${ApiConfig.apiBase}/ylnime/stream-proxy?url=${Uri.encodeQueryComponent(testUrl)}';
        debugPrint('[AnimePlayer] Direct stream failed, attempting proxy URL: $proxyUrl');
        try {
          final pVp = VideoPlayerController.networkUrl(
            Uri.parse(proxyUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            httpHeaders: streamHeaders.isNotEmpty ? streamHeaders : const {},
          );
          _videoPlayerController = pVp;
          pVp.addListener(_onVideoPlayerUpdate);
          await pVp.initialize().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Inisialisasi proxy player timeout setelah 15 detik'),
          );
          if (mounted && !_isDisposing) {
            if (_playbackSpeed != 1.0) {
              try { await pVp.setPlaybackSpeed(_playbackSpeed); } catch (_) {}
            }
            if (startAt > Duration.zero) {
              try { await pVp.seekTo(startAt); } catch (_) {}
            }
            PipService.instance.registerActivePlayer(onPause: _pausePlayer);
            await pVp.play();
            setState(() {
              _isPlayerInitializing = false;
              _qualityLoading = false;
              _loading = false;
              _error = null;
              _showPlayerOverlayNotifier.value = true;
            });
            _startOverlayTimer();
            WakelockPlus.enable();
            return true;
          }
        } catch (proxyErr) {
          debugPrint('[AnimePlayer] Proxy fallback also failed: $proxyErr');
        }
      }

      if (mounted) {
        setState(() {
          _isPlayerInitializing = false;
          _qualityLoading = false;
          _loading = false;
        });
      }
      return false;
    }
  }

  int get _displayEpisodeNumber {
    final ep = _extractEpisodeNumber(_currentEpisodeLabel);
    if (ep != null && ep > 0) return ep;
    if (_currentEpisodeUrl != null) {
      final match = RegExp(r'episode=al-\d+-(\d+)').firstMatch(_currentEpisodeUrl!);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? (_currentEpisodeIndex + 1);
      }
    }
    return _currentEpisodeIndex + 1;
  }

  bool get _isEpisodesDescending {
    if (_episodes.length >= 2) {
      final nFirst = _extractEpisodeNumber(_episodes.first.label) ?? -1;
      final nLast = _extractEpisodeNumber(_episodes.last.label) ?? -1;
      if (nFirst != -1 && nLast != -1 && nFirst != nLast) {
        return nFirst > nLast;
      }
    }
    return false;
  }

  List<YlnimeServer> _getCurrentQualityServers() {
    if (_ylnimeStream == null || _ylnimeStream!.qualities.isEmpty) return [];
    final target = _resolveTargetQuality(_ylnimeStream!.qualities, _selectedQuality);
    final list = target.serverList.isNotEmpty
        ? target.serverList
        : _ylnimeStream!.qualities.first.serverList;

    final validServers = list.where((s) {
      final u = s.url.trim();
      return u.isNotEmpty && !u.contains(r'${') && (u.startsWith('http') || u.startsWith('/'));
    }).toList();

    // Prioritaskan server Direct CDN / Non-proxy di urutan paling atas agar tidak melewati limit VPS 250KB/s
    validServers.sort((a, b) {
      final aIsDirect = (a.url.contains('s3.animeverse.id') || a.server.toLowerCase().contains('direct cdn')) && !a.url.contains('/stream-proxy');
      final bIsDirect = (b.url.contains('s3.animeverse.id') || b.server.toLowerCase().contains('direct cdn')) && !b.url.contains('/stream-proxy');
      if (aIsDirect && !bIsDirect) return -1;
      if (!aIsDirect && bIsDirect) return 1;

      final aIsProxy = a.url.contains('/stream-proxy') || a.server.toLowerCase().contains('proxy');
      final bIsProxy = b.url.contains('/stream-proxy') || b.server.toLowerCase().contains('proxy');
      if (aIsProxy && !bIsProxy) return 1;
      if (!aIsProxy && bIsProxy) return -1;

      return 0;
    });

    return validServers.isNotEmpty ? validServers : list;
  }

  Future<void> _switchQuality(String quality) async {
    if (_isDisposing) return;
    if (_qualityLoading) return;
    
    final cleanTarget = quality.toLowerCase().replaceAll('p', '').trim();
    final cleanCurrent = _selectedQuality.toLowerCase().replaceAll('p', '').trim();

    final isSame = cleanTarget == cleanCurrent ||
        ((cleanTarget == '320' || cleanTarget == '360') && (cleanCurrent == '360' || cleanCurrent == '320'));
    if (isSame && _error == null) return;

    // Simpan pilihan user sebagai preferensi agar bertahan saat ganti episode
    _preferredQuality = quality;
    unawaited(_savePreferredQuality(quality));

    HapticFeedback.selectionClick();
    debugPrint('[Quality] Switch to $quality (preferred saved)');

    Duration currentPos = Duration.zero;
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      currentPos = _videoPlayerController!.value.position;
    }
    if (currentPos == Duration.zero && _lastKnownStartAt > Duration.zero) {
      currentPos = _lastKnownStartAt;
    }

    // Tampilkan notifikasi beralih
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Beralih ke $quality...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Tampilkan loading overlay segera!
    setState(() {
      _qualityLoading = true;
      _error = null;
    });

    // ⚡ Watchdog 12 detik agar loading overlay TIDAK PERNAH NYANGKUT
    Timer? qualityTimeoutWatchdog;
    qualityTimeoutWatchdog = Timer(const Duration(seconds: 12), () {
      if (mounted && _qualityLoading) {
        debugPrint('[Quality] Watchdog: switch quality timed out after 12s');
        setState(() => _qualityLoading = false);
        try {
          _videoPlayerController?.play();
        } catch (_) {}
      }
    });

    try {
      // 1. Cek apakah resolusi ini sudah pernah di-fetch dan tersimpan di memori
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
            debugPrint('[Quality] Instant switch to ${match.title}');

            _lastStreamUrl = null;

            final keepIndex = (_selectedServerIndex < validServers.length) ? _selectedServerIndex : 0;
            setState(() {
              _error = null;
              _selectedQuality = match.title;
              _selectedQualityNotifier.value = match.title;
              _preferredQuality = match.title;
              _selectedServerIndex = keepIndex;
              _selectedServerNotifier.value = _formatServerLabel(validServers[keepIndex].server, keepIndex);
            });

            await _applyVideoSource(startAt: currentPos);
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ ${validServers[keepIndex].server} — ${match.title}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }
      }

      // 2. Jika belum ada di memori, panggil /api/ylnime/episode/resolution dengan timeout 12 detik
      final seriesSlug = (widget.animeId != null && widget.animeId!.isNotEmpty && !widget.animeId!.startsWith('http'))
          ? widget.animeId!
          : null;
      final ylnimeEpUrl = _currentEpisodeUrl;
      if (ylnimeEpUrl != null && ylnimeEpUrl.isNotEmpty) {
        final newStream = await _repo.changeEpisodeResolution(
          episodeUrl: ylnimeEpUrl,
          reso: quality,
          seriesSlug: seriesSlug,
        ).timeout(const Duration(seconds: 12), onTimeout: () => null);

        if (newStream != null && (newStream.qualities.isNotEmpty || newStream.bestPlayable != null)) {
          if (!mounted || _isDisposing) return;

          final effectiveQuality = newStream.resoDipakai ?? quality;

          if (newStream.resoFallback && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$quality tidak ada, pakai $effectiveQuality'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Merge qualities yang baru diambil ke _ylnimeStream agar tersimpan di cache
          final existingQualities = List<YlnimeQualityStream>.from(_ylnimeStream?.qualities ?? []);
          for (final nq in newStream.qualities) {
            final effectiveTitle = nq.title.toLowerCase() == 'default' ? effectiveQuality : nq.title;
            final normalizedNq = YlnimeQualityStream(title: effectiveTitle, serverList: nq.serverList);
            final idx = existingQualities.indexWhere(
              (eq) =>
                  eq.title.toLowerCase().replaceAll('p', '') ==
                  normalizedNq.title.toLowerCase().replaceAll('p', ''),
            );
            if (idx >= 0) {
              existingQualities[idx] = normalizedNq;
            } else {
              existingQualities.add(normalizedNq);
            }
          }

          final updatedStream = YlnimeEpisodeStreams(
            currentQuality: effectiveQuality,
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

          _lastStreamUrl = null;

          setState(() {
            _ylnimeStream = updatedStream;
            _selectedQuality = effectiveQuality;
            _selectedQualityNotifier.value = effectiveQuality;
            _preferredQuality = effectiveQuality;
          });

          await _applyVideoSource(startAt: currentPos);
          if (mounted) {
            final currentServerName = _selectedServerNotifier.value;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ $currentServerName — $effectiveQuality'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kualitas $quality tidak tersedia atau server cPanel lambat merespons'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        try {
          _videoPlayerController?.play();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Quality] Error during switch: $e');
    } finally {
      qualityTimeoutWatchdog.cancel();
      if (mounted && !_isDisposing) {
        setState(() => _qualityLoading = false);
      }
    }
  }

  void _switchServer(int index) {
    if (_isDisposing) return;
    if (_selectedServerIndex == index && _error == null) return;
    HapticFeedback.selectionClick();
    debugPrint('[Server] Switch to index $index');

    // Matikan video lama SEGERA!
    try {
      _videoPlayerController?.pause();
    } catch (_) {}

    _lastStreamUrl = null;

    setState(() {
      _error = null;
      _selectedServerIndex = index;
      _isPlayerInitializing = true;
    });

    Duration currentPos = (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
        ? _videoPlayerController!.value.position
        : Duration.zero;
    if (currentPos == Duration.zero && _lastKnownStartAt > Duration.zero) {
      currentPos = _lastKnownStartAt;
    }

    if (_ylnimeStream != null && _ylnimeStream!.qualities.isNotEmpty) {
      _applyVideoSource(startAt: currentPos);
    } else if (_fallbackStream != null && _fallbackStream!.mirrors.isNotEmpty) {
      final m = _fallbackStream!.mirrors[index];
      _selectedServerNotifier.value = m.label;
      _initializePlayer(m.url, startAt: currentPos);
    }
  }

  Future<void> _recordHistory({bool? isCompleted, bool force = false}) async {
    if (_isDisposing && !force) return;

    final animeId = _effectiveAnimeId.isNotEmpty
        ? _effectiveAnimeId
        : ((widget.animeId ?? '').isNotEmpty
            ? widget.animeId!
            : (_fallbackStream?.animeId ?? ''));
    final epId = _effectiveEpisodeId.isNotEmpty
        ? _effectiveEpisodeId
        : _currentEpisodeId;

    if (animeId.isEmpty) return;

    final title = (widget.animeTitle != null && widget.animeTitle!.isNotEmpty)
        ? widget.animeTitle!
        : (_ylnimeStream?.seriesName ?? _fallbackStream?.animeTitle ?? '');

    final vp = _videoPlayerController;
    final currentPosSec = (vp != null && vp.value.isInitialized)
        ? vp.value.position.inSeconds
        : _lastKnownStartAt.inSeconds;
    final totalDurSec = (vp != null && vp.value.isInitialized)
        ? vp.value.duration.inSeconds
        : 0;

    // 1. Simpan sementara ke local agar responsif
    await _progressService.saveProgress(
      animeId: animeId,
      episodeId: epId,
      positionSeconds: currentPosSec,
      totalDurationSeconds: totalDurSec,
      episodeLabel: _currentEpisodeLabel,
      episodeUrl: _currentEpisodeUrl,
      animeTitle: title,
      thumb: widget.animeThumb,
    );

    // 2. REMOTE DATABASE SYNC:
    // Sesuai permintaan: "hapus local klu gak tersimpan ke db"
    try {
      await _repo.addToHistory(
        animeId: animeId,
        episodeId: epId,
        title: title,
        seriesKey: _effectiveAnimeId.isNotEmpty ? _effectiveAnimeId : null,
        episodeLabel: _currentEpisodeLabel,
        episodeUrl: _currentEpisodeUrl,
        seriesUrl: _effectiveAnimeId.isNotEmpty ? 'https://ylnime.com/?series=$_effectiveAnimeId' : null,
        thumb: widget.animeThumb,
        position: currentPosSec,
        duration: totalDurSec,
        watchDuration: currentPosSec,
        episodeNumber: _displayEpisodeNumber.toString(),
        isCompleted: isCompleted,
        force: force,
      );
    } catch (e) {
      debugPrint('[History] Gagal simpan ke database ($e), menghapus progress lokal per instruksi...');
      await _progressService.removeAnimeHistory(animeId);
    }

    _sessionWatchSeconds = 0;
  }

  void _playEpisode(EpisodeModel ep, int index) async {
    if (_isDisposing) return;
    HapticFeedback.selectionClick();

    if (_sessionWatchSeconds > 0) {
      unawaited(_recordHistory(force: true));
    }

    _lastStreamUrl = null;
    _sessionWatchSeconds = 0;

    setState(() {
      _currentEpisodeId = ep.id;
      _currentEpisodeLabel = ep.label;
      _currentEpisodeUrl = ep.url;
      _currentEpisodeIndex = index;
      _currentEpisodeLabelNotifier.value = ep.label;
      _selectedQuality = _preferredQuality;
      _selectedQualityNotifier.value = _preferredQuality;
      _selectedServerIndex = 0;
      _commentsLoadTriggered = false;
      _commentsLoaded = false;
      _comments = [];
      _commentsCount = 0;
      _loading = true;
      _isPlayerInitializing = true;
      _error = null;
    });

    try {
      await _videoPlayerController?.pause();
    } catch (_) {}

    if (!mounted || _isDisposing) return;

    _scrollToCurrentEpisode();
    _loadStream(startAt: Duration.zero);
    unawaited(_recordHistory(force: true));
  }

  bool get _hasNextEpisode {
    if (_episodes.isNotEmpty) {
      final nextIdx = _isEpisodesDescending ? _currentEpisodeIndex - 1 : _currentEpisodeIndex + 1;
      if (nextIdx >= 0 && nextIdx < _episodes.length) return true;
    }
    return _ylnimeStream?.nextEpisode != null && _ylnimeStream!.nextEpisode!.isNotEmpty;
  }

  bool get _hasPrevEpisode {
    if (_episodes.isNotEmpty) {
      final prevIdx = _isEpisodesDescending ? _currentEpisodeIndex + 1 : _currentEpisodeIndex - 1;
      if (prevIdx >= 0 && prevIdx < _episodes.length) return true;
    }
    return _ylnimeStream?.prevEpisode != null && _ylnimeStream!.prevEpisode!.isNotEmpty;
  }

  void _nextEpisode() {
    if (_isDisposing) return;
    if (_episodes.isNotEmpty) {
      final nextIdx = _isEpisodesDescending ? _currentEpisodeIndex - 1 : _currentEpisodeIndex + 1;
      if (nextIdx >= 0 && nextIdx < _episodes.length) {
        _playEpisode(_episodes[nextIdx], nextIdx);
        return;
      }
    }
    if (_ylnimeStream?.nextEpisode != null && _ylnimeStream!.nextEpisode!.isNotEmpty) {
      _stopCurrentAndLoadNext(_ylnimeStream!.nextEpisode!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ini adalah episode terakhir.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _prevEpisode() {
    if (_isDisposing) return;
    if (_episodes.isNotEmpty) {
      final prevIdx = _isEpisodesDescending ? _currentEpisodeIndex + 1 : _currentEpisodeIndex - 1;
      if (prevIdx >= 0 && prevIdx < _episodes.length) {
        _playEpisode(_episodes[prevIdx], prevIdx);
        return;
      }
    }
    if (_ylnimeStream?.prevEpisode != null && _ylnimeStream!.prevEpisode!.isNotEmpty) {
      _stopCurrentAndLoadNext(_ylnimeStream!.prevEpisode!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ini adalah episode pertama.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Episode baru — reset state
  Future<void> _stopCurrentAndLoadNext(String nextUrl) async {
    if (_isDisposing) return;

    _lastStreamUrl = null;

    setState(() {
      _currentEpisodeUrl = nextUrl;
      final foundIdx = _episodes.indexWhere((e) => e.url == nextUrl || (e.id.isNotEmpty && nextUrl.contains(e.id)));
      if (foundIdx >= 0) {
        _currentEpisodeIndex = foundIdx;
        _currentEpisodeLabel = _episodes[foundIdx].label;
        _currentEpisodeLabelNotifier.value = _episodes[foundIdx].label;
        _currentEpisodeId = _episodes[foundIdx].id;
      }
      _selectedQuality = _preferredQuality;
      _selectedQualityNotifier.value = _preferredQuality;
      _selectedServerIndex = 0;
      _loading = true;
      _isPlayerInitializing = true;
      _error = null;
    });

    try {
      await _videoPlayerController?.pause();
    } catch (_) {}

    if (!mounted || _isDisposing) return;

    _loadStream();
  }






  String get _commentEpisodeKey {
    if (_currentEpisodeUrl != null && _currentEpisodeUrl!.isNotEmpty) {
      final m = RegExp(r'episode=([^&]+)').firstMatch(_currentEpisodeUrl!);
      if (m != null) return m.group(1)!;
    }
    if (_currentEpisodeId.isNotEmpty) {
      final m = RegExp(r'(al-\d+-\d+)').firstMatch(_currentEpisodeId);
      if (m != null) return m.group(1)!;
      return _currentEpisodeId;
    }
    return widget.episodeId;
  }

  int get _commentEpisodeNumber {
    final m = RegExp(r'(\d+)').firstMatch(_currentEpisodeLabel);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? (_currentEpisodeIndex + 1);
    }
    return _currentEpisodeIndex + 1;
  }

  Future<void> _loadComments() async {
    if (_isDisposing) return;
    final key = _commentEpisodeKey;
    if (key.isEmpty) return;
    if (_loadingComments) return;

    setState(() {
      _loadingComments = true;
      _commentsError = null;
      _commentsLoadTriggered = true;
    });

    try {
      final results = await Future.wait([
        _repo.getEpisodeComments(key, sort: _commentSort).catchError((_) => <EpisodeCommentModel>[]),
        _repo.getCommentsCount(key).catchError((_) => 0),
      ]);
      if (!mounted || _isDisposing) return;
      setState(() {
        _comments = results[0] as List<EpisodeCommentModel>;
        _commentsCount = results[1] as int;
        _loadingComments = false;
        _commentsLoaded = true;
      });

      final usernames = <String>{};
      for (final c in _comments) {
        if (c.user?.username.isNotEmpty == true) usernames.add(c.user!.username);
        for (final r in c.replies) {
          if (r.user?.username.isNotEmpty == true) usernames.add(r.user!.username);
        }
      }
      UserDecorResolver.instance.resolveUsers(usernames);
    } catch (e) {
      if (!mounted || _isDisposing) return;
      setState(() {
        _commentsError = 'Gagal memuat komentar';
        _loadingComments = false;
      });
    }
  }

  Future<void> _pickCommentMedia() async {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Kirim Media ke Komentar'),
        message: const Text('Pilih gambar atau GIF (maks. 5MB)'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickCommentMediaFromSource(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: 20),
                SizedBox(width: 8),
                Text('Galeri / GIF'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickCommentMediaFromSource(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: 20),
                SizedBox(width: 8),
                Text('Kamera'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _pickCommentMediaFromSource(ImageSource source) async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final x = source == ImageSource.camera
        ? await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85)
        : await picker.pickImage(source: source);
    if (x == null) return;

    File file = File(x.path);
    final name = x.name.isNotEmpty ? x.name : file.path.split(Platform.pathSeparator).last;
    final ext = (name.contains('.') ? name.split('.').last : file.path.split('.').last).toLowerCase();
    final isGif = ext == 'gif';
    final allowedExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
    if (!allowedExts.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Format .$ext tidak didukung. Gunakan PNG, JPG, GIF, atau WebP.'),
        ),
      );
      return;
    }

    final len = await file.length();
    if (len > 5 * 1024 * 1024) {
      if (isGif) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran animasi GIF maksimal 5MB!'),
          ),
        );
        return;
      }

      // Kompres otomatis foto resolusi tinggi dari galeri agar muat di bawah 5MB
      try {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1280);
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final tempFile = File('${Directory.systemTemp.path}/compressed_comment_${DateTime.now().millisecondsSinceEpoch}.png');
          await tempFile.writeAsBytes(byteData.buffer.asUint8List());
          if (await tempFile.length() <= 5 * 1024 * 1024) {
            file = tempFile;
          }
        }
      } catch (e) {
        debugPrint('[AnimeEpisodePlayer] Recompression error: $e');
      }

      if (await file.length() > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran file maksimal 5MB! Silakan pilih foto dengan resolusi lebih kecil.'),
          ),
        );
        return;
      }
    }

    setState(() => _stagedCommentMediaFile = file);
  }

  void _viewFullMedia(BuildContext context, String mediaUrl) {
    HapticFeedback.selectionClick();
    _pausePlayer();
    final isHttp = mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text(
              'Media Komentar',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          body: PhotoView(
            imageProvider: isHttp
                ? NetworkImage(mediaUrl) as ImageProvider
                : FileImage(File(mediaUrl)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.0,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, __) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentInputController.text.trim();
    if (content.isEmpty && _stagedCommentMediaFile == null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu untuk berkomentar.')),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      String? mediaUrl;
      String? mediaType;

      if (_stagedCommentMediaFile != null) {
        final stagedFile = _stagedCommentMediaFile!;
        final fileExt = stagedFile.path.split('.').last.toLowerCase();
        final isGifFile = fileExt == 'gif';
        final uploadRes = await _repo.uploadCommentMedia(stagedFile);
        if (uploadRes != null && (uploadRes['media_url'] != null || uploadRes['url'] != null)) {
          mediaUrl = (uploadRes['media_url'] ?? uploadRes['url']).toString();
          final isGifUrl = mediaUrl.toLowerCase().endsWith('.gif') || mediaUrl.toLowerCase().contains('.gif');
          final serverType = uploadRes['media_type']?.toString();
          mediaType = (isGifFile || isGifUrl) ? 'gif' : (serverType ?? 'image');
        } else {
          if (!mounted) return;
          setState(() => _isSubmittingComment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Gagal mengunggah foto komentar. Periksa jaringan Anda dan coba lagi.'),
            ),
          );
          return;
        }
      }

      final newComment = await _repo.addEpisodeComment(
        episodeKey: _commentEpisodeKey,
        animeId: (widget.animeId != null && widget.animeId!.isNotEmpty)
            ? widget.animeId!
            : (_fallbackStream?.animeId ?? 'anime'),
        episodeNumber: _commentEpisodeNumber,
        content: content,
        parentId: _replyingToCommentId,
        isSpoiler: _commentIsSpoiler,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      final wasReplyingToId = _replyingToCommentId;

      if (!mounted) return;

      if (newComment != null) {
        _commentInputController.clear();
        setState(() {
          _isSubmittingComment = false;
          _replyingToCommentId = null;
          _replyingToUsername = null;
          _commentIsSpoiler = false;
          _stagedCommentMediaFile = null;
        });
        if (wasReplyingToId != null) {
          _expandedCommentReplies.add(wasReplyingToId);
        }
        _loadComments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Komentar berhasil dikirim!')),
        );
      } else {
        setState(() => _isSubmittingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim komentar. Silakan coba lagi.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komentar: ${_repo.errorMessage(e)}')),
      );
    }
  }

  Future<void> _toggleLike(EpisodeCommentModel comment) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      final idx = _comments.indexWhere((c) => c.id == comment.id);
      if (idx != -1) {
        final cur = _comments[idx];
        final newLiked = !cur.isLiked;
        _comments[idx] = cur.copyWith(
          isLiked: newLiked,
          likesCount: newLiked ? cur.likesCount + 1 : (cur.likesCount > 0 ? cur.likesCount - 1 : 0),
        );
      }
    });

    try {
      final res = await _repo.toggleCommentLike(comment.id);
      if (res != null && mounted) {
        final serverLiked = res['is_liked'] == true;
        final serverCount = int.tryParse(res['likes_count']?.toString() ?? '') ?? 0;
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx != -1) {
            _comments[idx] = _comments[idx].copyWith(
              isLiked: serverLiked,
              likesCount: serverCount,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteComment(int commentId, {bool isReply = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReply ? 'Hapus Balasan?' : 'Hapus Komentar?'),
        content: Text(
          isReply
              ? 'Balasan yang dihapus tidak dapat dikembalikan.'
              : 'Komentar yang dihapus tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await _repo.deleteComment(commentId);
      if (ok && mounted) {
        setState(() {
          final beforeCount = _comments.length;
          _comments.removeWhere((c) => c.id == commentId);
          if (_comments.length < beforeCount) {
            if (_commentsCount > 0) _commentsCount--;
          } else {
            // It was a reply inside one of the parent comments
            for (int i = 0; i < _comments.length; i++) {
              final parent = _comments[i];
              final beforeReplies = parent.replies.length;
              final newReplies = parent.replies.where((r) => r.id != commentId).toList();
              if (newReplies.length < beforeReplies) {
                final newCount = (parent.repliesCount > 0) ? parent.repliesCount - 1 : 0;
                _comments[i] = parent.copyWith(
                  replies: newReplies,
                  repliesCount: newCount,
                );
                if (_commentsCount > 0) _commentsCount--;
                break;
              }
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isReply ? 'Balasan berhasil dihapus' : 'Komentar dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: ${_repo.errorMessage(e)}')),
        );
      }
    }
  }

  Future<void> _toggleReplies(EpisodeCommentModel comment) async {
    HapticFeedback.selectionClick();
    final isExpanded = _expandedCommentReplies.contains(comment.id);
    if (isExpanded) {
      setState(() => _expandedCommentReplies.remove(comment.id));
      return;
    }

    setState(() => _expandedCommentReplies.add(comment.id));

    if (comment.replies.isEmpty && comment.repliesCount > 0) {
      setState(() => _loadingRepliesFor.add(comment.id));
      try {
        final replies = await _repo.getCommentReplies(comment.id, limit: 30);
        if (mounted) {
          setState(() {
            _loadingRepliesFor.remove(comment.id);
            final idx = _comments.indexWhere((c) => c.id == comment.id);
            if (idx != -1) {
              _comments[idx] = _comments[idx].copyWith(replies: replies);
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _loadingRepliesFor.remove(comment.id));
        }
      }
    }
  }

  String _formatTimeAgo(String? raw) {
    return AppDateUtils.formatTimeAgo(raw);
  }

  Future<void> _enterPip() async {
    if (_videoPlayerController == null) return;
    try {
      if (_isFullscreen) {
        await _toggleFullScreen();
      }
      _videoPlayerController?.play();
      await PipService.instance.enterPip();
    } catch (_) {}
  }

  Future<void> _toggleFullScreen() async {
    final nextFullscreen = !_isFullscreen;
    setState(() {
      _isFullscreen = nextFullscreen;
    });
    if (nextFullscreen) {
      await PipService.instance.enterFullscreen();
    } else {
      await PipService.instance.exitFullscreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) {
          _toggleFullScreen();
          return;
        }
        _pausePlayer();
        PipService.instance.disablePipNow();
        unawaited(_recordHistory(force: true));
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: PipService.instance.isInPip,
        builder: (context, isInPip, _) {
        if (isInPip) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.black,
            body: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildVideoPlayerBox(),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                    DesktopPipOverlay(
                      player: _videoPlayerController,
                      onExpand: () => PipService.instance.exitPip(),
                      onClose: () {
                        PipService.instance.exitPip();
                        _videoPlayerController?.pause();
                      },
                    ),
                ],
              ),
            ),
          );
        }

        if (_isFullscreen) {
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_isFullscreen) _toggleFullScreen();
              },
              const SingleActivator(LogicalKeyboardKey.keyF): () {
                _toggleFullScreen();
              },
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: Colors.black,
                body: SizedBox.expand(
                  child: CinematicFullscreenWrapper(
                    isFullscreen: true,
                    onToggleFullscreen: _toggleFullScreen,
                    child: _buildVideoPlayerBox(),
                  ),
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (isDesktop) {
              return Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF2F2F7),
                body: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Player + Content
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              color: Colors.black,
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.65,
                              ),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CinematicFullscreenWrapper(
                                    isFullscreen: false,
                                    onToggleFullscreen: _toggleFullScreen,
                                    child: _buildVideoPlayerBox(),
                                  ),
                                ),
                              ),
                            ),
                            if (_error != null && !_loading && !_isActuallyPlaying)
                              _buildErrorBanner(isDark),
                            Expanded(
                              child: ListView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                                children: [
                                  RepaintBoundary(child: _buildHeroTitleSection(isDark)),
                                  RepaintBoundary(child: _buildTopActionBar(isDark)),
                                  const SizedBox(height: 10),
                                  RepaintBoundary(child: _buildCommentsSection(context, isDark)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: Episode Sidebar (Always visible on desktop!)
                      Container(
                        width: 360,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF16161A) : Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
                              width: 1,
                            ),
                          ),
                        ),
                        child: _buildDesktopEpisodeSidebar(isDark),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Mobile / Narrow Layout
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
              body: SafeArea(
                bottom: false,
                top: true,
                child: Column(
                  children: [
                    // Constrained Video Player (Never too tall on mobile/window)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.38,
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CinematicFullscreenWrapper(
                          isFullscreen: false,
                          onToggleFullscreen: _toggleFullScreen,
                          child: _buildVideoPlayerBox(),
                        ),
                      ),
                    ),
                    if (_error != null && !_loading && !_isActuallyPlaying)
                      _buildErrorBanner(isDark),
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 50 + bottomInset),
                        children: [
                          RepaintBoundary(child: _buildHeroTitleSection(isDark)),
                          RepaintBoundary(child: _buildTopActionBar(isDark)),
                          const SizedBox(height: 8),
                          RepaintBoundary(child: _buildCommentsSection(context, isDark)),
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
    ),
  );
}

  void _startOverlayTimer() {
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showPlayerOverlayNotifier.value && (_videoPlayerController?.value.isPlaying ?? false)) {
        _showPlayerOverlayNotifier.value = false;
      }
    });
  }

  void _togglePlayerOverlay() {
    _showPlayerOverlayNotifier.value = !_showPlayerOverlayNotifier.value;
    if (_showPlayerOverlayNotifier.value) {
      _startOverlayTimer();
    } else {
      _overlayHideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;
    HapticFeedback.lightImpact();
    if (_videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
      _isPlayingNotifier.value = false;
      _overlayHideTimer?.cancel();
      _showPlayerOverlayNotifier.value = true;
    } else {
      _videoPlayerController!.play();
      _isPlayingNotifier.value = true;
      _startOverlayTimer();
    }
  }

  void _seekRelative(int seconds) {
    if (_videoPlayerController == null) return;
    final current = _pendingSeekTarget ?? _videoPlayerController!.value.position;
    final total = _videoPlayerController!.value.duration;
    var target = current + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;

    _pendingSeekTarget = target;
    HapticFeedback.selectionClick();

    _pendingRelativeSeekTimer?.cancel();
    _pendingRelativeSeekTimer = Timer(const Duration(milliseconds: 220), () {
      if (_pendingSeekTarget != null && _videoPlayerController != null) {
        final toSeek = _pendingSeekTarget!;
        _pendingSeekTarget = null;
        _videoPlayerController!.seekTo(toSeek);
      }
    });

    final currentPos = _videoPlayerController!.value.position;
    final diffSecs = (target - currentPos).inSeconds;
    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedbackText = diffSecs < 0 ? '${diffSecs}s' : '+${diffSecs}s';
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFeedbackText = null);
    });
    _startOverlayTimer();
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_videoPlayerController == null) return;
    if (_isScreenLockedNotifier.value) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth * 0.38) {
      _seekRelative(-10);
    } else if (tapX > screenWidth * 0.62) {
      _seekRelative(10);
    } else {
      _togglePlayPause();
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_videoPlayerController == null) return;
    if (_isScreenLockedNotifier.value) return;
    if (_isScrubbing) return;

    _speedBeforeHold = _playbackSpeed;
    _wasPlayingBeforeHold = _videoPlayerController!.value.isPlaying;

    HapticFeedback.mediumImpact();
    final targetSpeed = _speedBeforeHold >= 2.0 ? 3.0 : 2.0;

    setState(() {
      _isHoldingForSpeed = true;
    });

    _videoPlayerController?.setPlaybackSpeed(targetSpeed);
    if (!_wasPlayingBeforeHold) {
      _videoPlayerController?.play();
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!_isHoldingForSpeed) return;
    HapticFeedback.lightImpact();

    _videoPlayerController?.setPlaybackSpeed(_speedBeforeHold);
    if (!_wasPlayingBeforeHold) {
      _videoPlayerController?.pause();
    }

    setState(() {
      _isHoldingForSpeed = false;
    });
  }

  void _handleLongPressCancel() {
    if (!_isHoldingForSpeed) return;
    _videoPlayerController?.setPlaybackSpeed(_speedBeforeHold);
    if (!_wasPlayingBeforeHold) {
      _videoPlayerController?.pause();
    }

    setState(() {
      _isHoldingForSpeed = false;
    });
  }

  Widget _buildSpeedHoldIndicator() {
    final targetSpeed = _speedBeforeHold >= 2.0 ? 3.0 : 2.0;
    final speedStr = targetSpeed.toStringAsFixed(targetSpeed.truncateToDouble() == targetSpeed ? 0 : 1);

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${speedStr}X Kecepatan',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.fast_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

  void _changePlaybackSpeed(double speed) {
    _videoPlayerController?.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
    _playbackSpeedNotifier.value = speed;
  }

  void _showPlaybackSpeedPicker(BuildContext context) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.speedometer,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kecepatan Pemutaran',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: hairlineColor),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: speeds.length,
                  itemBuilder: (context, index) {
                    final s = speeds[index];
                    final isSelected = (_playbackSpeed - s).abs() < 0.01;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${s}x',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      title: Text(
                        s == 1.0 ? '1.0x (Normal)' : '${s}x',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(CupertinoIcons.checkmark_alt, size: 18)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        _changePlaybackSpeed(s);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } else {
      final minutes = d.inMinutes.toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
  }

  Widget _buildPlayerCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 36,
    double iconSize = 18,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.65),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _buildDoubleTapCue() {
    final isRewind = _seekFeedbackText?.startsWith('-') ?? false;
    return Align(
      alignment: isRewind ? const Alignment(-0.6, 0.0) : const Alignment(0.6, 0.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRewind ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              _seekFeedbackText!,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return const Center(
      child: SizedBox(
        width: 42,
        height: 42,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildUnlockButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _isScreenLockedNotifier.value = false;
        _startOverlayTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Buka Kunci',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Row(
        children: [
          _buildPlayerCircleButton(
            icon: CupertinoIcons.chevron_back,
            tooltip: 'Kembali',
            onTap: () {
              if (_isFullscreen) {
                _toggleFullScreen();
              } else {
                _pausePlayer();
                Navigator.maybePop(context);
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.animeTitle ?? _ylnimeStream?.seriesName ?? 'Episode',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode $_displayEpisodeNumber • $_currentEpisodeLabel',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_isScreenLockedNotifier.value && _selectedQuality.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _startOverlayTimer();
                _showQualityPickerModal(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.high_quality_rounded, color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      _selectedQuality,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isScreenLockedNotifier.value) ...[
            const SizedBox(width: 8),
            _buildPlayerCircleButton(
              icon: Icons.dns_rounded,
              tooltip: 'Ganti Server',
              onTap: () {
                _startOverlayTimer();
                _showServerPickerModalSheet(context);
              },
            ),
            const SizedBox(width: 8),
            _buildPlayerCircleButton(
              icon: Icons.picture_in_picture_alt_rounded,
              tooltip: 'Picture-in-Picture',
              onTap: _enterPip,
            ),
          ],
          const SizedBox(width: 8),
          _buildPlayerCircleButton(
            icon: _isScreenLockedNotifier.value ? Icons.lock_rounded : Icons.lock_open_rounded,
            tooltip: _isScreenLockedNotifier.value ? 'Buka Kunci' : 'Kunci Layar',
            onTap: () {
              HapticFeedback.lightImpact();
              _isScreenLockedNotifier.value = !_isScreenLockedNotifier.value;
              _startOverlayTimer();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCenterControls() {
    if (_videoPlayerController == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _isPlayingNotifier,
      builder: (context, _) {
        final isPlaying = _isPlayingNotifier.value;
        return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_hasPrevEpisode) ...[
          _buildPlayerCircleButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Episode Sebelumnya',
            size: 40,
            iconSize: 22,
            onTap: () {
              _prevEpisode();
              _startOverlayTimer();
            },
          ),
          const SizedBox(width: 22),
        ],
        _buildPlayerCircleButton(
          icon: Icons.replay_10_rounded,
          tooltip: 'Mundur 10 detik',
          size: 46,
          iconSize: 24,
          onTap: () => _seekRelative(-10),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayPause,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.65),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildPlayerCircleButton(
          icon: Icons.forward_10_rounded,
          tooltip: 'Maju 10 detik',
          size: 46,
          iconSize: 24,
          onTap: () => _seekRelative(10),
        ),
        if (_hasNextEpisode) ...[
          const SizedBox(width: 22),
          _buildPlayerCircleButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Episode Selanjutnya',
            size: 40,
            iconSize: 22,
            onTap: () {
              _nextEpisode();
              _startOverlayTimer();
            },
          ),
        ],
      ],
    );
      },
    );
  }

  Widget _buildYouTubeSeekBar(double totalSecs, double currentSecs, Duration posDuration) {
    double bufferSecs = 0.0;
    if (_videoPlayerController != null && _videoPlayerController!.value.buffered.isNotEmpty) {
      bufferSecs = _videoPlayerController!.value.buffered.last.end.inSeconds.toDouble();
    }
    final playedRatio = totalSecs > 0 ? (currentSecs / totalSecs).clamp(0.0, 1.0) : 0.0;
    final bufferedRatio = totalSecs > 0 ? (bufferSecs / totalSecs).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;

        void seekFromLocalPosition(Offset localPos) {
          final x = localPos.dx.clamp(0.0, trackWidth);
          final targetFraction = trackWidth > 0 ? (x / trackWidth).clamp(0.0, 1.0) : 0.0;
          final targetSec = targetFraction * totalSecs;
          _overlayHideTimer?.cancel();
          setState(() {
            _isScrubbing = true;
            _scrubValue = targetSec;
          });
        }

        void finishSeek() {
          final target = Duration(seconds: _scrubValue.round());
          _pendingSeekTarget = null;
          _pendingRelativeSeekTimer?.cancel();
          _videoPlayerController?.seekTo(target);
          setState(() {
            _isScrubbing = false;
          });
          _startOverlayTimer();
        }

        final barHeight = _isScrubbing ? 5.0 : 3.5;
        final thumbRadius = _isScrubbing ? 7.5 : 5.5;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragDown: (details) {
            seekFromLocalPosition(details.localPosition);
          },
          onHorizontalDragUpdate: (details) {
            seekFromLocalPosition(details.localPosition);
          },
          onHorizontalDragEnd: (details) {
            finishSeek();
          },
          onHorizontalDragCancel: () {
            setState(() => _isScrubbing = false);
            _startOverlayTimer();
          },
          onTapDown: (details) {
            seekFromLocalPosition(details.localPosition);
          },
          onTapUp: (details) {
            finishSeek();
          },
          child: Container(
            height: 28,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Base background track (Unbuffered)
                Container(
                  width: trackWidth,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
                // Buffered track (Preloaded)
                Container(
                  width: trackWidth * bufferedRatio,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
                // Played track (Monochrome White)
                Container(
                  width: trackWidth * playedRatio,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
                // Scrubber Thumb (Monochrome White)
                Positioned(
                  left: (trackWidth * playedRatio - thumbRadius).clamp(0.0, trackWidth - thumbRadius * 2),
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: _isScrubbing ? 0.6 : 0.3),
                          blurRadius: _isScrubbing ? 6 : 3,
                          spreadRadius: _isScrubbing ? 1.5 : 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Floating Time Bubble above thumb when scrubbing
                if (_isScrubbing)
                  Positioned(
                    left: (trackWidth * playedRatio - 22).clamp(0.0, trackWidth - 44),
                    bottom: 22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Text(
                        _formatDuration(posDuration),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomBottomBar() {
    if (_videoPlayerController == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_positionNotifier, _durationNotifier]),
      builder: (context, _) {
        final totalSecs = _durationNotifier.value.inSeconds.toDouble();
        final currentSecs = _isScrubbing ? _scrubValue : _positionNotifier.value.inSeconds.toDouble();
        final posDuration = _isScrubbing ? Duration(seconds: _scrubValue.round()) : _positionNotifier.value;
        final durDuration = _durationNotifier.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⚡ Bar Progress YouTube (Buffered + Red Played + Thumb + Floating Time)
              _buildYouTubeSeekBar(totalSecs, currentSecs, posDuration),
              // Baris Kontrol Bawah (Durasi, Kecepatan, Fullscreen)
              Row(
                children: [
                  Text(
                    '${_formatDuration(posDuration)} / ${_formatDuration(durDuration)}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _startOverlayTimer();
                      _showPlaybackSpeedPicker(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedFullscreenButton(
                    isFullscreen: _isFullscreen,
                    onTap: _toggleFullScreen,
                    size: 34,
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomControlsOverlay() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ValueListenableBuilder<bool>(
          valueListenable: _showPlayerOverlayNotifier,
          builder: (context, showOverlay, _) {
          return AnimatedOpacity(
            opacity: (showOverlay && !_isHoldingForSpeed) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !showOverlay || _isHoldingForSpeed,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isScreenLockedNotifier,
                builder: (context, isLocked, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _togglePlayerOverlay,
                          onDoubleTapDown: _handleDoubleTap,
                          onLongPressStart: _handleLongPressStart,
                          onLongPressEnd: _handleLongPressEnd,
                          onLongPressCancel: _handleLongPressCancel,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 90,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xCC000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xEE000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildCustomTopBar(),
                      ),
                      if (!isLocked)
                        Center(
                          child: _buildCustomCenterControls(),
                        ),
                      if (!isLocked)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildCustomBottomBar(),
                        ),
                      if (isLocked)
                        Positioned(
                          bottom: 24,
                          right: 20,
                          child: _buildUnlockButton(),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildMiniProgressBar() {
    if (_videoPlayerController == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _showPlayerOverlayNotifier,
      builder: (context, showOverlay, _) {
        return AnimatedOpacity(
          opacity: showOverlay ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedBuilder(
            animation: Listenable.merge([_positionNotifier, _durationNotifier]),
            builder: (context, _) {
              final totalMs = _durationNotifier.value.inMilliseconds.toDouble();
              if (totalMs <= 0) {
                return const SizedBox.shrink();
              }

              final posMs = _positionNotifier.value.inMilliseconds.toDouble().clamp(0.0, totalMs);
              final playedRatio = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
              double bufferMs = 0.0;
              if (_videoPlayerController != null && _videoPlayerController!.value.buffered.isNotEmpty) {
                bufferMs = _videoPlayerController!.value.buffered.last.end.inMilliseconds.toDouble();
              }
              final bufferedRatio = totalMs > 0 ? (bufferMs / totalMs).clamp(0.0, 1.0) : 0.0;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Container(
                    height: 2.5,
                    width: w,
                    color: Colors.white.withValues(alpha: 0.15),
                    child: Stack(
                      children: [
                        // Buffered track
                        Container(
                          width: w * bufferedRatio,
                          height: 2.5,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        // Played track (Monochrome White)
                        Container(
                          width: w * playedRatio,
                          height: 2.5,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderVideoBox(String loadingMessage) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.animeThumb != null && widget.animeThumb!.isNotEmpty)
            Opacity(
              opacity: 0.25,
              child: Image.network(
                widget.animeThumb!,
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Center(
            child: _error != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xEE16161A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF3B30), size: 28),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(16),
                          onPressed: () => _showServerPickerModalSheet(context),
                          child: const Text(
                            'Pilih Server Lain',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
          ),
          Positioned(
            top: 8,
            left: 10,
            child: _buildPlayerCircleButton(
              icon: CupertinoIcons.chevron_back,
              tooltip: 'Kembali',
              onTap: () {
                _pausePlayer();
                Navigator.maybePop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerBox() {
    final String loadingMessage = _qualityLoading
        ? 'Mengubah resolusi ke $_selectedQuality...'
        : 'Memuat Episode $_displayEpisodeNumber...';

    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      final aspectRatio = _videoPlayerController!.value.aspectRatio;
      return Container(
        key: const ValueKey('anime_video_box_container'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
                child: VideoPlayer(_videoPlayerController!),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayerOverlay,
                onDoubleTapDown: _handleDoubleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressEnd: _handleLongPressEnd,
                onLongPressCancel: _handleLongPressCancel,
                child: const SizedBox.expand(),
              ),
            ),
            if (_seekFeedbackText != null)
              _buildDoubleTapCue(),
            ValueListenableBuilder<bool>(
              valueListenable: _isBufferingNotifier,
              builder: (context, isBuffering, _) {
                final showIndicator = isBuffering || _qualityLoading;
                if (!showIndicator) return const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: _showPlayerOverlayNotifier,
                  builder: (context, showOverlay, _) {
                    return Align(
                      alignment: showOverlay ? const Alignment(0, -0.42) : Alignment.center,
                      child: _buildBufferingIndicator(),
                    );
                  },
                );
              },
            ),
            if (!PipService.instance.isInPip.value)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 2.5,
                child: RepaintBoundary(
                  child: _buildMiniProgressBar(),
                ),
              ),
            if (!PipService.instance.isInPip.value)
              _buildCustomControlsOverlay(),
            if (_isHoldingForSpeed)
              _buildSpeedHoldIndicator(),
          ],
        ),
      );
    }

    return _buildPlaceholderVideoBox(loadingMessage);
  }

  // â”€â”€â”€ HERO TITLE & META â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeroTitleSection(bool isDark) {
    final title = widget.animeTitle ?? _ylnimeStream?.seriesName ?? 'Episode';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 3),
                // Subtitle
                Text(
                  'Episode $_displayEpisodeNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BouncyTap(
            scaleDown: 0.94,
            onTap: () async {
              HapticFeedback.lightImpact();
              final auth = context.read<AuthProvider>();
              if (!auth.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login untuk menulis ulasan')),
                );
                return;
              }
              final targetAnimeId = _effectiveAnimeId.isNotEmpty
                  ? _effectiveAnimeId
                  : (widget.animeId != null && widget.animeId!.isNotEmpty)
                      ? widget.animeId!
                      : widget.episodeId;
              final effectiveTitle = (widget.animeTitle != null && widget.animeTitle!.isNotEmpty)
                  ? widget.animeTitle!
                  : title;
              final res = await ReviewInputDialog.show(
                context,
                itemType: 'anime',
                targetId: targetAnimeId,
                targetTitle: effectiveTitle,
                targetCover: widget.animeThumb,
                subId: widget.episodeId,
                subTitle: 'Episode $_displayEpisodeNumber',
              );
              if (res != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ulasan berhasil disimpan!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEBEBF0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.square_pencil,
                    size: 14,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Ulas',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tombol Klip Anime ke Ulas ──
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final auth = context.read<AuthProvider>();
              if (!auth.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login untuk membuat klip')),
                );
                return;
              }
              final targetAnimeId = _effectiveAnimeId.isNotEmpty
                  ? _effectiveAnimeId
                  : (widget.animeId != null && widget.animeId!.isNotEmpty)
                      ? widget.animeId!
                      : widget.episodeId;
              final effectiveTitle = (widget.animeTitle != null && widget.animeTitle!.isNotEmpty)
                  ? widget.animeTitle!
                  : title;

              final curPosSec = _positionNotifier.value.inSeconds.toDouble();
              final startSec = math.max(0.0, curPosSec - 10.0);
              final endSec = curPosSec + 20.0;

              final res = await ReviewInputDialog.show(
                context,
                itemType: 'anime',
                targetId: targetAnimeId,
                targetTitle: effectiveTitle,
                targetCover: widget.animeThumb,
                subId: widget.episodeId,
                subTitle: 'Episode $_displayEpisodeNumber',
                initialClipStart: startSec,
                initialClipEnd: endSec,
                initialMediaUrl: _lastStreamUrl,
                initialMediaType: 'clip',
              );
              if (res != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Klip berhasil dibagikan ke Ulas!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEBEBF0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.scissors,
                    size: 14,
                    color: Color(0xFFFF2D55),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Klip',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: const Color(0xFFFF2D55),
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

  Widget _buildTopActionBar(bool isDark) {
    if (_episodes.isEmpty && !_loadingEpisodes && !_episodesLoadTriggered) {
      _episodesLoadTriggered = true;
      _fetchEpisodesIfNeeded();
    }

    final pillBg = isDark
        ? const Color(0xFF1E1E22)
        : const Color(0xFFE5E5EA);
    final badgeBg = isDark
        ? const Color(0xFF121214)
        : const Color(0xFFD1D1D6);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subColor = isDark ? Colors.white70 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: [ 720p  Ganti Kualitas ]   [ S1  Ganti Server ]
          Row(
            children: [
              // Quality Pill (Telegram Bubble Style)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showQualityPickerModal(context),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        width: 0.6,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _selectedQuality,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ganti Resolusi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Server Pill (Telegram Bubble Style)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showServerPickerModalSheet(context),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        width: 0.6,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'S${_selectedServerIndex + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ganti Server',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row: Next & Prev Episode Quick Navigation (Telegram Bubble Style)
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: _hasPrevEpisode ? 1.0 : 0.45,
                  child: GestureDetector(
                    onTap: _hasPrevEpisode
                        ? () {
                            HapticFeedback.selectionClick();
                            _prevEpisode();
                          }
                        : null,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.6,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.backward_end_fill,
                            size: 14,
                            color: _hasPrevEpisode ? textColor : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ep Sebelumnya',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _hasPrevEpisode ? textColor : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: _hasNextEpisode ? 1.0 : 0.45,
                  child: GestureDetector(
                    onTap: _hasNextEpisode
                        ? () {
                            HapticFeedback.selectionClick();
                            _nextEpisode();
                          }
                        : null,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.6,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ep Selanjutnya',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _hasNextEpisode ? textColor : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.forward_end_fill,
                            size: 14,
                            color: _hasNextEpisode ? textColor : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 2 Header: "Daftar Episode"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.square_stack_3d_up_fill,
                    size: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Daftar Episode',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  if (_episodes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${_episodes.length})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subColor,
                      ),
                    ),
                  ],
                ],
              ),
              if (_episodes.isNotEmpty)
                GestureDetector(
                  onTap: () => _showEpisodePickerModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Semua',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Horizontal Episode Strip (Telegram Bubble Chips)
          SizedBox(
            height: 42,
            child: _loadingEpisodes && _episodes.isEmpty
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 10),
                  )
                : _episodes.isEmpty
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              '$_displayEpisodeNumber',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _horizontalEpisodeScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemCount: _episodes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final ep = _episodes[idx];
                          final isSelected = _currentEpisodeId == ep.id || _currentEpisodeIndex == idx;
                          final epNumber = ep.episodeNumber?.toString() ?? '${idx + 1}';
                          return RepaintBoundary(
                            child: GestureDetector(
                              onTap: () => _playEpisode(ep, idx),
                              child: Container(
                                height: 42,
                                constraints: const BoxConstraints(minWidth: 46),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : pillBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          width: 0.8,
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.20),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  epNumber,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected
                                        ? (isDark ? Colors.black : Colors.white)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
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

  void _showEpisodePickerModal(BuildContext context) {
    if (_episodes.isEmpty) return;
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final pillBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetCtx, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 10),
                // Handle bar
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.square_stack_3d_up_fill,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pilih Episode (${_episodes.length})',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                        color: isDark ? Colors.white38 : Colors.black38,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                Expanded(
                  child: GridView.builder(
                    controller: scrollCtrl,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    physics: const BouncingScrollPhysics(),
                    scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _episodes.length,
                    itemBuilder: (context, idx) {
                      final ep = _episodes[idx];
                      final isSelected = _currentEpisodeId == ep.id || _currentEpisodeIndex == idx;
                      final epNumber = ep.episodeNumber?.toString() ?? '${idx + 1}';
                      return RepaintBoundary(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(ctx);
                            _playEpisode(ep, idx);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : pillBg,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      width: 0.8,
                                    ),
                            ),
                            child: Text(
                              epNumber,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQualityPickerModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
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
                      Text(
                        'Pilih Resolusi Video',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
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
                  for (final def in _availableQualities) {
                    if (!qualities.any((item) => item.toLowerCase().replaceAll('p', '') == def.toLowerCase().replaceAll('p', ''))) {
                      qualities.add(def);
                    }
                  }
                  qualities.sort((a, b) => _extractResolutionNumber(b).compareTo(_extractResolutionNumber(a)));
                  return qualities;
                })().map((q) {
                  final cleanQ = q.toLowerCase().replaceAll('p', '').trim();
                  final cleanSelected = _selectedQuality.toLowerCase().replaceAll('p', '').trim();
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
                      _switchQuality(q);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showServerPickerModalSheet(BuildContext context) {
    final servers = _getCurrentQualityServers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
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
                      Text(
                        'Pilih Server Video',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
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
        );
      },
    );
  }


  // ─── DESKTOP EPISODE SIDEBAR ──────────────────────────────────────────

  Widget _buildDesktopEpisodeSidebar(bool isDark) {
    final hairlineColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.square_stack_3d_up_fill,
                  color: isDark ? Colors.white : Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Episode',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      _loadingEpisodes
                          ? 'Memuat...'
                          : '${_episodes.length} Episode tersedia',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (_episodes.isNotEmpty)
                IconButton(
                  tooltip: _isEpisodesDescending ? 'Urutan: Terbaru' : 'Urutan: Terlama',
                  icon: Icon(
                    CupertinoIcons.sort_down,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _episodes = _episodes.reversed.toList();
                    });
                  },
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: hairlineColor),

        // Episode List
        Expanded(
          child: _loadingEpisodes && _episodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(radius: 12),
                      const SizedBox(height: 10),
                      Text(
                        'Memuat episode...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              : _episodes.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada episode',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _episodes.length,
                      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: hairlineColor),
                      itemBuilder: (ctx, idx) {
                        final ep = _episodes[idx];
                        final isSelected = _currentEpisodeId == ep.id;
                        return RepaintBoundary(
                          child: InkWell(
                            onTap: () => _playEpisode(ep, idx),
                            borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6), width: 1)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: isSelected
                                      ? Icon(CupertinoIcons.play_fill, color: isDark ? Colors.black : Colors.white, size: 14)
                                      : Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ep.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                                        ),
                                      ),
                                      if (isSelected)
                                        Text(
                                          'Sedang Diputar',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    ),
        ),
      ],
    );
  }


  bool get _isActuallyPlaying =>
      _videoPlayerController != null &&
      _videoPlayerController!.value.isInitialized &&
      (_videoPlayerController!.value.isPlaying ||
       _videoPlayerController!.value.position > Duration.zero ||
       _videoPlayerController!.value.duration > Duration.zero);

  // ─── ERROR BANNER ────────────────────────────────────────────────────────

  Widget _buildErrorBanner(bool isDark) {
    if (_isActuallyPlaying) {
      return const SizedBox.shrink();
    }
    final formattedMsg = AppErrorFormatter.formatVideoError(_error);
    final isFallbackIssue = _isUsingFallback || (_error != null && _error!.toLowerCase().contains('cadangan'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF3B30), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFallbackIssue ? 'Kendala Stream & Server Cadangan' : 'Gagal Memutar Video',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ),
              if (_isUsingFallback)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FALLBACK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            formattedMsg,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                onPressed: () => _showServerPickerModalSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.slider_horizontal_3, size: 13, color: isDark ? Colors.white : Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Ganti Server',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                minimumSize: Size.zero,
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(18),
                onPressed: () {
                  if (_lastStreamUrl != null) {
                    _initializePlayer(_lastStreamUrl!);
                  } else {
                    _loadStream();
                  }
                },
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, bool isDark) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;

    return ListenableBuilder(
      listenable: Listenable.merge([
        CommentThemeService.instance,
        UserDecorResolver.instance,
      ]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.chat_bubble_2_fill, size: 18, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          'Komentar ($_commentsCount)',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _commentsCount > 0 ? '$_commentsCount komentar' : 'Belum ada',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                // Sort row (Terbaru, Populer, Terlama)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sort in [
                        {'id': 'newest', 'label': 'Terbaru', 'icon': Icons.access_time_rounded},
                        {'id': 'popular', 'label': 'Populer', 'icon': Icons.local_fire_department_rounded},
                        {'id': 'oldest', 'label': 'Terlama', 'icon': Icons.arrow_upward_rounded},
                      ]) ...[
                        GestureDetector(
                          onTap: () {
                            if (_commentSort != sort['id']) {
                              setState(() => _commentSort = sort['id'] as String);
                              _loadComments();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8, top: 4, bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _commentSort == sort['id']
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _commentSort == sort['id'] ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sort['icon'] as IconData,
                                  size: 13,
                                  color: _commentSort == sort['id'] ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white54 : Colors.black45),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  sort['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _commentSort == sort['id'] ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

        if (!auth.isAuthenticated)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.black12,
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Masuk untuk menulis komentar.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingToCommentId != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Membalas @$_replyingToUsername',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyingToCommentId = null;
                              _replyingToUsername = null;
                            });
                          },
                          child: Icon(Icons.close_rounded, size: 14, color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserAvatar(
                      currentUser?.avatarUrl,
                      currentUser?.displayName ?? currentUser?.username ?? 'Saya',
                      radius: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentInputController,
                        focusNode: _commentFocusNode,
                        maxLines: null,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: _replyingToCommentId != null
                              ? 'Tulis balasan...'
                              : 'Tulis komentar untuk episode ini...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_stagedCommentMediaFile != null) ...[
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _stagedCommentMediaFile!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _stagedCommentMediaFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickCommentMedia,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _stagedCommentMediaFile != null
                                  ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _stagedCommentMediaFile != null
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.photo_fill,
                                  size: 13,
                                  color: _stagedCommentMediaFile != null ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _stagedCommentMediaFile != null ? 'Media Terpilih' : 'Gambar/GIF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _stagedCommentMediaFile != null ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() => _commentIsSpoiler = !_commentIsSpoiler);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _commentIsSpoiler
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _commentIsSpoiler ? Colors.redAccent : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _commentIsSpoiler ? Icons.warning_amber_rounded : Icons.visibility_off_outlined,
                                  size: 13,
                                  color: _commentIsSpoiler ? Colors.redAccent : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Spoiler',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _commentIsSpoiler ? Colors.redAccent : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        minimumSize: Size.zero,
                        elevation: 2,
                        shadowColor: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _isSubmittingComment ? null : _submitComment,
                      child: _isSubmittingComment
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded, size: 14),
                                SizedBox(width: 4),
                                Text('Kirim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        if (_loadingComments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black),
            ),
          )
        else if (_commentsError != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  _commentsError!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadComments,
                  child: Text('Coba Lagi', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                ),
              ],
            ),
          )
        else ...[
          // ── BANNER IKLAN DI ATAS LIST KOMENTAR ──
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 8),
            child: AdBannerWidget(
              margin: EdgeInsets.zero,
            ),
          ),
          if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada komentar di episode ini.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jadilah yang pertama menulis komentar!',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              scrollCacheExtent: const ScrollCacheExtent.pixels(250.0),
              itemCount: _comments.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                final comment = _comments[i];
                return RepaintBoundary(
                  key: ValueKey('comment_${comment.id}'),
                  child: SwipeToReply(
                    onReply: () {
                      setState(() {
                        _replyingToCommentId = comment.id;
                        _replyingToUsername = comment.user?.username ?? 'Pengguna';
                      });
                      _commentFocusNode.requestFocus();
                    },
                    direction: SwipeToReplyDirection.startToEnd,
                    child: _buildCommentCard(comment, isDark, currentUser?.id),
                  ),
                );
              },
            ),
        ],
      ],
    ),
  );
},
);
  }

  Widget _buildUserAvatar(
    String? avatarUrl,
    String displayName, {
    double radius = 14,
    String? decorationUrl,
    String? decorationCode,
  }) {
    return DecoratedAvatar(
      radius: radius,
      avatarUrl: avatarUrl,
      decorationUrl: decorationUrl,
      decorationCode: decorationCode,
      decorationScale: 1.0,
      fallbackName: displayName,
    );
  }

  Widget _buildCommentCard(EpisodeCommentModel comment, bool isDark, dynamic currentUserId) {
    final isSpoilerRevealed = _revealedSpoilers.contains(comment.id);
    final isOwner = currentUserId != null &&
        comment.user != null &&
        (currentUserId.toString() == comment.user!.id.toString());

    final authUser = _authProvider?.user ?? (mounted ? context.read<AuthProvider>().user : null);
    final resolved = UserDecorResolver.instance.get(comment.user?.username);
    final decorationUrl = isOwner
        ? (authUser?.fullAvatarDecorationUrl ?? comment.user?.fullAvatarDecorationUrl)
        : (comment.user?.fullAvatarDecorationUrl ?? resolved?.decorationUrl);
    final decorationCode = isOwner
        ? (authUser?.avatarDecorationCode ?? comment.user?.avatarDecorationCode)
        : (comment.user?.avatarDecorationCode ?? resolved?.decorationCode);
    final fontModel = isOwner
        ? (authUser?.profileFontData ?? ProfileFontModel.fromKey(authUser?.profileFont))
        : (comment.user?.profileFontData ?? resolved?.profileFontData ?? ProfileFontModel.fromKey(comment.user?.profileFont));

    final themeService = CommentThemeService.instance;
    final shouldApplyMedia = themeService.applyToAll || isOwner;
    final mediaBgUrl = (shouldApplyMedia && !comment.isPinned)
        ? themeService.currentCardMediaUrl
        : null;
    final hasMediaBg = mediaBgUrl != null;

    final cardDecoration = themeService.getCardDecoration(
      isDark: isDark,
      isOwner: isOwner,
      isPinned: comment.isPinned,
    );

    final isAuthorVerified = comment.isAuthorVerified ||
        (isOwner && authUser?.verifiedBadge == true) ||
        (authUser != null &&
            authUser.verifiedBadge &&
            (comment.user?.username == authUser.username ||
                comment.user?.id.toString() == authUser.id.toString()));

    final cardIsDark = isDark || hasMediaBg;
    final cardTextColor = cardIsDark ? Colors.white : AppColors.lightTextPrimary;
    final cardSubtitleColor = cardIsDark ? Colors.white.withValues(alpha: 0.95) : AppColors.lightTextPrimary;
    final cardMutedColor = cardIsDark ? Colors.white70 : AppColors.lightTextSecondary;
    final cardSubtleColor = cardIsDark ? Colors.white54 : Colors.black45;

    final isRepliesExpanded = _expandedCommentReplies.contains(comment.id);
    final hasReplies = comment.repliesCount > 0 || comment.replies.isNotEmpty;
    final isLoadingReplies = _loadingRepliesFor.contains(comment.id);

    final cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: hasMediaBg ? null : cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final targetU = comment.user?.username ?? '';
                  if (targetU.isNotEmpty && targetU != 'Pengguna') {
                    showUserProfileCard(context, username: targetU);
                  }
                },
                child: _buildUserAvatar(
                  comment.user?.fullAvatarUrl ?? resolved?.avatarUrl ?? comment.authorAvatarUrl,
                  comment.user?.username ?? 'Pengguna',
                  radius: 15,
                  decorationUrl: decorationUrl,
                  decorationCode: decorationCode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              final targetU = comment.user?.username ?? '';
                              if (targetU.isNotEmpty && targetU != 'Pengguna') {
                                showUserProfileCard(context, username: targetU);
                              }
                            },
                            child: Text(
                              comment.user?.username ?? 'Pengguna',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: (fontModel != null
                                  ? fontModel.textStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: cardTextColor,
                                    )
                                  : TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: cardTextColor,
                                    )),
                            ),
                          ),
                        ),
                        if (isAuthorVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 13.5,
                            color: Color(0xFF007AFF),
                          ),
                        ],
                        if ((comment.user?.genreRole ?? resolved?.genreRole) != null) ...[
                          const SizedBox(width: 5),
                          GenreRoleBadge(
                            role: (comment.user?.genreRole ?? resolved?.genreRole)!,
                            compact: true,
                            isDark: cardIsDark,
                          ),
                        ],
                        if (comment.isPinned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: (cardIsDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, size: 10, color: cardTextColor),
                                const SizedBox(width: 2),
                                Text(
                                  'Disematkan',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: cardTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: cardSubtleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteComment(comment.id),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (comment.isSpoiler && !isSpoilerRevealed)
            InkWell(
              onTap: () {
                setState(() => _revealedSpoilers.add(comment.id));
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_off_rounded, size: 15, color: Colors.redAccent),
                    SizedBox(width: 6),
                    Text(
                      'Peringatan Spoiler - Ketuk untuk melihat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (comment.content.isNotEmpty)
            Text(
              comment.content,
              textAlign: comment.content.length > 35 ? TextAlign.justify : TextAlign.start,
              style: (fontModel != null
                  ? fontModel.textStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cardSubtitleColor,
                    )
                  : TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cardSubtitleColor,
                    )),
            ),

          if (comment.hasMedia && comment.fullMediaUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _viewFullMedia(context, comment.fullMediaUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220, maxWidth: 300),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.5,
                        ),
                      ),
                      child: (comment.mediaType == 'gif' || comment.fullMediaUrl!.toLowerCase().endsWith('.gif'))
                          ? CalmGif(
                              source: comment.fullMediaUrl!,
                              fit: BoxFit.cover,
                              speed: 0.75,
                              placeholder: Container(
                                height: 120,
                                alignment: Alignment.center,
                                child: const CupertinoActivityIndicator(),
                              ),
                              errorWidget: Container(
                                height: 80,
                                alignment: Alignment.center,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_rounded, size: 18, color: Colors.grey),
                                    SizedBox(width: 6),
                                    Text('Gagal memuat media', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          : (comment.fullMediaUrl!.startsWith('http://') ||
                                  comment.fullMediaUrl!.startsWith('https://'))
                              ? Image.network(
                                  comment.fullMediaUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 600,
                                  cacheHeight: 600,
                                  gaplessPlayback: true,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      height: 120,
                                      alignment: Alignment.center,
                                      child: const CupertinoActivityIndicator(),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    alignment: Alignment.center,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.broken_image_rounded, size: 18, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text('Gagal memuat media', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(comment.fullMediaUrl!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 600,
                                  cacheHeight: 600,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    alignment: Alignment.center,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.broken_image_rounded, size: 18, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text('Gagal memuat media', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                    if (comment.mediaType == 'gif')
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'GIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),

          Row(
            children: [
              InkWell(
                onTap: () => _toggleLike(comment),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 15,
                        color: comment.isLiked ? Colors.redAccent : cardMutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likesCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: comment.isLiked ? Colors.redAccent : cardMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    _replyingToCommentId = comment.id;
                    _replyingToUsername = comment.user?.username ?? 'Pengguna';
                  });
                  _commentFocusNode.requestFocus();
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: cardMutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Balas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cardMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasReplies) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _toggleReplies(comment),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRepliesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: cardMutedColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isRepliesExpanded
                              ? 'Sembunyikan'
                              : 'Lihat ${comment.repliesCount > 0 ? comment.repliesCount : comment.replies.length} Balasan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cardMutedColor,
                          ),
                        ),
                        if (isLoadingReplies) ...[
                          const SizedBox(width: 6),
                          const CupertinoActivityIndicator(radius: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (isRepliesExpanded) ...[
            const SizedBox(height: 8),
            if (isLoadingReplies && comment.replies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator(radius: 8)),
              )
            else if (comment.replies.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: (cardIsDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: comment.replies.map((reply) {
                    final replyIsOwner = currentUserId != null &&
                        reply.user != null &&
                        (currentUserId.toString() == reply.user!.id.toString());
                    final replyResolved = UserDecorResolver.instance.get(reply.user?.username);
                    final replyDecorUrl = replyIsOwner
                        ? (authUser?.fullAvatarDecorationUrl ?? reply.user?.fullAvatarDecorationUrl)
                        : (reply.user?.fullAvatarDecorationUrl ?? replyResolved?.decorationUrl);
                    final replyDecorCode = replyIsOwner
                        ? (authUser?.avatarDecorationCode ?? reply.user?.avatarDecorationCode)
                        : (reply.user?.avatarDecorationCode ?? replyResolved?.decorationCode);
                    final replyFontModel = replyIsOwner
                        ? (authUser?.profileFontData ?? ProfileFontModel.fromKey(authUser?.profileFont))
                        : (reply.user?.profileFontData ?? replyResolved?.profileFontData ?? ProfileFontModel.fromKey(reply.user?.profileFont));

                    final isReplyVerified = reply.isAuthorVerified ||
                        reply.user?.verifiedBadge == true ||
                        (replyIsOwner && authUser?.verifiedBadge == true) ||
                        (authUser != null &&
                            authUser.verifiedBadge &&
                            (reply.user?.username == authUser.username ||
                                reply.user?.id.toString() == authUser.id.toString()));

                    final replyCardBg = hasMediaBg
                        ? Colors.black.withValues(alpha: 0.38)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF2F3F6));
                    final replyCardBorder = hasMediaBg
                        ? Colors.white.withValues(alpha: 0.16)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.07));
                    final replyTextColor = cardIsDark ? Colors.white : AppColors.lightTextPrimary;
                    final replySubtitleColor = cardIsDark ? Colors.white.withValues(alpha: 0.95) : AppColors.lightTextPrimary;
                    final replySubtleColor = cardIsDark ? Colors.white60 : Colors.black45;

                    return SwipeToReply(
                      threshold: 36.0,
                      onReply: () {
                        setState(() {
                          _replyingToCommentId = comment.id;
                          _replyingToUsername = reply.user?.username ?? comment.user?.username ?? 'Pengguna';
                        });
                        _commentFocusNode.requestFocus();
                      },
                      direction: SwipeToReplyDirection.startToEnd,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: replyCardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: replyCardBorder,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final targetU = reply.user?.username ?? '';
                                    if (targetU.isNotEmpty && targetU != 'Pengguna') {
                                      showUserProfileCard(context, username: targetU);
                                    }
                                  },
                                  child: _buildUserAvatar(
                                    reply.user?.fullAvatarUrl ?? replyResolved?.avatarUrl ?? reply.authorAvatarUrl,
                                    reply.user?.username ?? 'Pengguna',
                                    radius: 12,
                                    decorationUrl: replyDecorUrl,
                                    decorationCode: replyDecorCode,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: GestureDetector(
                                          onTap: () {
                                            final targetU = reply.user?.username ?? '';
                                            if (targetU.isNotEmpty && targetU != 'Pengguna') {
                                              showUserProfileCard(context, username: targetU);
                                            }
                                          },
                                          child: Text(
                                            reply.user?.username ?? 'Pengguna',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: (replyFontModel != null
                                                ? replyFontModel.textStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: replyTextColor,
                                                  )
                                                : TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: replyTextColor,
                                                  )),
                                          ),
                                        ),
                                      ),
                                      if (isReplyVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          CupertinoIcons.checkmark_seal_fill,
                                          size: 12,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ],
                                      if ((reply.user?.genreRole ?? replyResolved?.genreRole) != null) ...[
                                        const SizedBox(width: 4),
                                        GenreRoleBadge(
                                          role: (reply.user?.genreRole ?? replyResolved?.genreRole)!,
                                          compact: true,
                                          isDark: cardIsDark,
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTimeAgo(reply.createdAt),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: replySubtleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (replyIsOwner)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteComment(reply.id, isReply: true),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              reply.content,
                              style: (replyFontModel != null
                                  ? replyFontModel.textStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: replySubtitleColor,
                                    )
                                  : TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: replySubtitleColor,
                                    )),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );

    if (hasMediaBg) {
      return Container(
        decoration: cardDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.5),
          child: Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CalmGif(
                      source: mediaBgUrl,
                      fit: BoxFit.cover,
                      speed: themeService.animSpeed,
                    ),
                    Container(
                      color: Colors.black.withValues(
                        alpha: themeService.overlayOpacity,
                      ),
                    ),
                  ],
                ),
              ),
              cardContent,
            ],
          ),
        ),
      );
    }

    return cardContent;
  }
}
