import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/poster_card.dart';
import '../data/anime_repository.dart';
import '../data/models/anime_model.dart';
import '../../genre/presentation/genre_detail_screen.dart';
import 'anime_episode_player.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../core/services/onesignal_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../review/presentation/widgets/review_input_dialog.dart';

/// Pure Apple iOS HIG Styled Anime Detail Screen.
/// Features:
/// - Apple TV+ style immersive blurred ambient backdrop
/// - Translucent frosted glass navigation bar with circular blur buttons
/// - Hero squircle poster with 3D elevation and ambient shadow
/// - Clean Apple typography hierarchy with squircle genre chips
/// - Prominent Sakura primary CTA button (Tonton / Lanjutkan with timestamp)
/// - Apple App Store inset grouped stats card with vertical hairline dividers
/// - Apple Books expandable synopsis card
/// - Apple Settings inset grouped detail information
/// - Apple Podcasts / Apple Music unified inset grouped episode list with
///   playback progress bars, watched checkmarks, and Cupertino interactions
class AnimeDetailScreen extends StatefulWidget {
  const AnimeDetailScreen({
    super.key,
    required this.animeId,
    this.anime,
  });

  final String animeId;
  final AnimeModel? anime;

  static final RegExp _epRegex1 = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false);
  static final RegExp _epRegex2 = RegExp(r'(?:episode|ep|eps)[-_](\d+(?:\.\d+)?)', caseSensitive: false);
  static final RegExp _epRegexDigits = RegExp(r'\b(\d+(?:\.\d+)?)\b');
  static final Map<String, double> _epNumParsedCache = {};

  static double parseEpisodeNumber(EpisodeModel ep, [int fallback = 0]) {
    final key = '${ep.id}#${ep.label}#${ep.episodeNumber}';
    final cached = _epNumParsedCache[key];
    if (cached != null) return cached;

    double result = fallback.toDouble();
    if (ep.episodeNumber != null && ep.episodeNumber!.trim().isNotEmpty) {
      final n = double.tryParse(ep.episodeNumber!.trim());
      if (n != null) {
        _epNumParsedCache[key] = n;
        return n;
      }
    }
    final m = _epRegex1.firstMatch(ep.label);
    if (m != null) {
      final n = double.tryParse(m.group(1)!);
      if (n != null) {
        _epNumParsedCache[key] = n;
        return n;
      }
    }
    final mId = _epRegex2.firstMatch(ep.id) ??
        (ep.url != null ? _epRegex2.firstMatch(ep.url!) : null);
    if (mId != null) {
      final n = double.tryParse(mId.group(1)!);
      if (n != null) {
        _epNumParsedCache[key] = n;
        return n;
      }
    }
    final anyDigits = _epRegexDigits.firstMatch(ep.label);
    if (anyDigits != null) {
      final n = double.tryParse(anyDigits.group(1)!);
      if (n != null) {
        _epNumParsedCache[key] = n;
        return n;
      }
    }
    _epNumParsedCache[key] = result;
    return result;
  }

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  final _repo = AnimeRepository.instance;
  late Future<AnimeDetailModel> _future;
  late final ScrollController _scrollController;
  bool? _isBookmarked;
  bool _bookmarkLoading = false;
  bool? _isProfileLiked;
  bool _profileLikedLoading = false;
  bool _sortNewestFirst = false;
  int _displayCount = 30;
  static const int _pageSize = 30;
  Set<String> _watchedEpisodeIdentifiers = {};
  AnimeWatchProgress? _lastWatchedProgress;

  String get _effectiveAnimeId {
    final raw = widget.animeId.trim();
    if (raw.isNotEmpty && raw != 'None') return raw;
    if (widget.anime != null) {
      if (widget.anime!.url != null && widget.anime!.url!.trim().isNotEmpty) {
        return widget.anime!.url!.trim();
      }
      if (widget.anime!.id.trim().isNotEmpty && widget.anime!.id.trim() != 'None') {
        return widget.anime!.id.trim();
      }
      if (widget.anime!.title.trim().isNotEmpty) {
        return widget.anime!.title.trim();
      }
    }
    return raw;
  }

  Future<AnimeDetailModel> _loadDetail() async {
    final id = _effectiveAnimeId;
    try {
      if (id.isNotEmpty && id != 'None') {
        return await _repo.detail(id);
      }
    } catch (_) {}

    // Fallback 1: search by title
    final title = widget.anime?.title.trim();
    if (title != null && title.isNotEmpty) {
      try {
        final searchResults = await _repo.search(title);
        if (searchResults.isNotEmpty) {
          final first = searchResults.first;
          final target = (first.url != null && first.url!.isNotEmpty) ? first.url! : first.id;
          if (target.isNotEmpty && target != 'None') {
            return await _repo.detail(target);
          }
        }
      } catch (_) {}
    }

    // Fallback 2: if anime object was passed, construct graceful fallback
    if (widget.anime != null) {
      return AnimeDetailModel(
        id: id.isNotEmpty ? id : (widget.anime!.id.isNotEmpty ? widget.anime!.id : 'anime'),
        title: widget.anime!.title,
        thumb: widget.anime!.thumb,
        synopsis: widget.anime!.synopsis,
        score: widget.anime!.score,
        status: widget.anime!.status,
        episodes: const [],
      );
    }

    return await _repo.detail(id);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _future = _loadDetail();
    _checkBookmark();
    _checkProfileLiked();
    _loadWatchedEpisodes();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  int _totalEpisodesCount = 0;
  List<EpisodeModel>? _cachedEpisodesRaw;
  bool? _cachedSortOrder;
  List<EpisodeModel> _cachedSortedList = const [];

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_totalEpisodesCount > 0 && _displayCount >= _totalEpisodesCount) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMoreEpisodes();
    }
  }

  void _loadMoreEpisodes() {
    if (mounted && (_totalEpisodesCount == 0 || _displayCount < _totalEpisodesCount)) {
      setState(() {
        _displayCount += _pageSize;
      });
    }
  }

  static double parseEpisodeNumber(EpisodeModel ep, [int fallback = 0]) =>
      AnimeDetailScreen.parseEpisodeNumber(ep, fallback);

  List<EpisodeModel> _getSortedEpisodes(List<EpisodeModel> raw) {
    if (raw.isEmpty) return raw;
    if (identical(_cachedEpisodesRaw, raw) && _cachedSortOrder == _sortNewestFirst) {
      return _cachedSortedList;
    }
    final list = List<EpisodeModel>.from(raw);
    
    list.sort((a, b) {
      final na = parseEpisodeNumber(a, -1);
      final nb = parseEpisodeNumber(b, -1);
      if (na != -1 && nb != -1 && na != nb) {
        return _sortNewestFirst ? nb.compareTo(na) : na.compareTo(nb);
      }
      return 0;
    });

    final hasDistinction = list.any((e) => parseEpisodeNumber(e, -1) != -1);
    final result = !hasDistinction ? (_sortNewestFirst ? raw.reversed.toList() : raw) : list;
    _cachedEpisodesRaw = raw;
    _cachedSortOrder = _sortNewestFirst;
    _cachedSortedList = result;
    return result;
  }

  Future<void> _loadWatchedEpisodes() async {
    try {
      final local = await AnimeWatchProgressService.instance.getLastWatchedAnime(widget.animeId);
      if (mounted) {
        setState(() => _lastWatchedProgress = local);
      }
    } catch (_) {}
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    try {
      final history = await _repo.watchHistory();
      final set = <String>{};
      for (final item in history) {
        final animeId = (item['anime_id'] ?? item['animeId'] ?? '').toString();
        final animeTitle = (item['anime_title'] ?? item['title'] ?? '').toString();
        final currentTitle = widget.anime?.title ?? '';

        final matchesId = animeId.isNotEmpty &&
            (animeId.toLowerCase() == widget.animeId.toLowerCase() ||
             widget.animeId.toLowerCase().contains(animeId.toLowerCase()) ||
             animeId.toLowerCase().contains(widget.animeId.toLowerCase()));
        final matchesTitle = currentTitle.isNotEmpty &&
            animeTitle.isNotEmpty &&
            (animeTitle.toLowerCase() == currentTitle.toLowerCase() ||
             animeTitle.toLowerCase().contains(currentTitle.toLowerCase()) ||
             currentTitle.toLowerCase().contains(animeTitle.toLowerCase()));

        if (matchesId || matchesTitle) {
          final epId = (item['episode_id'] ?? item['episode_key'])?.toString();
          if (epId != null && epId.isNotEmpty) {
            set.add(epId.toLowerCase());
          }
          final epNum = (item['episode_number'] ?? item['episode_num'])?.toString();
          if (epNum != null && epNum.isNotEmpty) {
            set.add('ep_$epNum');
          }
          final epTitle = (item['episode_title'] ?? item['episode_label'])?.toString();
          if (epTitle != null && epTitle.isNotEmpty) {
            set.add(epTitle.toLowerCase());
            final m = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false).firstMatch(epTitle);
            if (m != null) set.add('ep_${m.group(1)!}');
          }
        }
      }
      if (mounted) {
        _watchedCache.clear();
        setState(() => _watchedEpisodeIdentifiers = set);
      }
    } catch (_) {}
  }

  static final RegExp _watchedNumRegex = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false);
  static final RegExp _watchedIdNumRegex = RegExp(r'(?:episode|ep|eps)[-_]?(\d+)', caseSensitive: false);
  final Map<String, bool> _watchedCache = {};

  bool _isEpisodeWatched(EpisodeModel ep) {
    if (_watchedEpisodeIdentifiers.isEmpty) return false;
    final cached = _watchedCache[ep.id];
    if (cached != null) return cached;

    final epId = ep.id.toLowerCase();
    if (epId.isNotEmpty && _watchedEpisodeIdentifiers.contains(epId)) {
      _watchedCache[ep.id] = true;
      return true;
    }

    final numMatch = _watchedNumRegex.firstMatch(ep.label);
    if (numMatch != null && _watchedEpisodeIdentifiers.contains('ep_${numMatch.group(1)}')) {
      _watchedCache[ep.id] = true;
      return true;
    }
    final idNumMatch = _watchedIdNumRegex.firstMatch(ep.id);
    if (idNumMatch != null && _watchedEpisodeIdentifiers.contains('ep_${idNumMatch.group(1)}')) {
      _watchedCache[ep.id] = true;
      return true;
    }
    if (ep.label.isNotEmpty && _watchedEpisodeIdentifiers.contains(ep.label.toLowerCase())) {
      _watchedCache[ep.id] = true;
      return true;
    }
    _watchedCache[ep.id] = false;
    return false;
  }

  bool _isMatchingProgressEpisode(EpisodeModel ep, AnimeWatchProgress p) {
    // 1. Episode Number Comparison (Strict & definitive)
    final currentEpNum = AnimeDetailScreen.parseEpisodeNumber(ep, -1);

    double pEpNum = -1;
    final pNumStr = AnimeWatchProgressService.extractEpisodeNumber(p.episodeId) ??
        AnimeWatchProgressService.extractEpisodeNumber(p.episodeUrl) ??
        AnimeWatchProgressService.extractEpisodeNumber(p.episodeLabel);
    if (pNumStr != null) {
      pEpNum = double.tryParse(pNumStr) ?? -1;
    }

    // If both have valid episode numbers:
    if (currentEpNum != -1 && pEpNum != -1) {
      // Must match numerically! If current is ep 2 and p is ep 1, they NEVER match.
      return (currentEpNum - pEpNum).abs() < 0.01;
    }

    // 2. If episode numbers couldn't be resolved, fallback to EXACT URL match
    if (ep.url != null && ep.url!.isNotEmpty && p.episodeUrl != null && p.episodeUrl!.isNotEmpty) {
      final u1 = ep.url!.trim().toLowerCase();
      final u2 = p.episodeUrl!.trim().toLowerCase();
      if (u1 == u2) return true;
    }

    // 3. Exact non-generic Episode ID match (must NOT equal the anime/series ID)
    final cleanAnime = AnimeWatchProgressService.cleanAnimeSlug(widget.animeId);
    final epId = ep.id.trim().toLowerCase();
    final pEpId = p.episodeId.trim().toLowerCase();
    if (epId.isNotEmpty && pEpId.isNotEmpty && epId != cleanAnime && pEpId != cleanAnime) {
      if (epId == pEpId) return true;
      final cleanEp = AnimeWatchProgressService.cleanEpisodeSlug(epId);
      final cleanPEp = AnimeWatchProgressService.cleanEpisodeSlug(pEpId);
      if (cleanEp.isNotEmpty && cleanPEp.isNotEmpty && cleanEp == cleanPEp && cleanEp != cleanAnime) {
        return true;
      }
    }

    // 4. Exact non-generic label match
    final epLabel = ep.label.trim().toLowerCase();
    final pLabel = p.episodeLabel?.trim().toLowerCase() ?? '';
    if (epLabel.isNotEmpty && pLabel.isNotEmpty && epLabel == pLabel) {
      if (!epLabel.startsWith('episode') && !epLabel.startsWith('ep')) {
        return true;
      }
    }

    return false;
  }

  Future<void> _checkBookmark() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    final v = await _repo.isBookmarked(widget.animeId);
    if (mounted) setState(() => _isBookmarked = v);
  }

  Future<void> _toggleBookmark(AnimeDetailModel detail) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menyimpan bookmark'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _bookmarkLoading = true);
    try {
      if (_isBookmarked == true) {
        await _repo.removeBookmark(widget.animeId);
        OneSignalService.syncBookmarkCache(widget.animeId, false);
        setState(() => _isBookmarked = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dihapus dari bookmark'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await _repo.addBookmark(
          animeId: widget.animeId,
          title: detail.title,
          thumb: detail.thumb,
          status: detail.status,
          score: detail.score,
          url: detail.url ?? widget.anime?.url,
        );
        OneSignalService.syncBookmarkCache(widget.animeId, true);
        final seriesKey = detail.url != null ? detail.url!.split('series=').last.split('&').first : '';
        if (seriesKey.isNotEmpty) {
          OneSignalService.syncBookmarkCache(seriesKey, true);
        }
        setState(() => _isBookmarked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ditambahkan ke bookmark'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_repo.errorMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  Future<void> _checkProfileLiked() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    final liked = await ProfileRepository.instance.checkProfileLiked(
      itemType: 'anime',
      itemId: widget.animeId,
    );
    if (mounted) setState(() => _isProfileLiked = liked);
  }

  Future<void> _toggleProfileLiked(AnimeDetailModel detail) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menyukai anime ini di profil'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _profileLikedLoading = true);
    try {
      final res = await ProfileRepository.instance.toggleProfileLiked(
        itemType: 'anime',
        itemId: widget.animeId,
        title: detail.title,
        thumbnail: detail.thumb,
      );
      if (res['success'] == true) {
        final isLiked = res['is_liked'] == true;
        setState(() => _isProfileLiked = isLiked);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ??
                    (isLiked ? 'Disukai dan dipajang di profil!' : 'Dihapus dari favorit profil'),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: isLiked ? const Color(0xFFFF2E93) : null,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Gagal memproses favorit profil'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profileLikedLoading = false);
    }
  }

  void _shareAnime(AnimeDetailModel detail) {
    HapticFeedback.selectionClick();
    final link = DeepLinkService.buildAnimeLink(
      animeId: widget.animeId,
      title: detail.title,
    );
    final text = 'Tonton ${detail.title} di MOKO!\n$link';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: const Row(
          children: [
            Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Tautan anime berhasil disalin untuk dibagikan!')),
          ],
        ),
      ),
    );
  }

  void _playEpisode({
    required EpisodeModel episode,
    required int index,
    required List<EpisodeModel> episodes,
    required AnimeDetailModel detail,
    Duration? startAt,
  }) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AnimeEpisodePlayerScreen(
          episodeId: episode.id,
          episodeLabel: episode.label,
          episodeUrl: episode.url,
          animeId: widget.animeId,
          animeTitle: detail.title,
          animeThumb: detail.thumb,
          episodes: episodes,
          currentEpisodeIndex: index,
          startAt: startAt,
        ),
      ),
    );
    _loadWatchedEpisodes();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context) ? Responsive.maxContentWidth : double.infinity,
          ),
          child: FutureBuilder<AnimeDetailModel>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                if (widget.anime != null) {
                  final instantDetail = AnimeDetailModel(
                    id: _effectiveAnimeId,
                    title: widget.anime!.title,
                    thumb: widget.anime!.thumb,
                    synopsis: widget.anime!.synopsis,
                    score: widget.anime!.score,
                    status: widget.anime!.status,
                    episodes: const [],
                  );
                  return _buildContent(instantDetail, isDark, isLoadingEpisodes: true);
                }
                return _loadingView();
              }
              if (snap.hasError && (!snap.hasData || snap.data == null)) {
                if (widget.anime != null) {
                  final fallbackDetail = AnimeDetailModel(
                    id: _effectiveAnimeId,
                    title: widget.anime!.title,
                    thumb: widget.anime!.thumb,
                    synopsis: widget.anime!.synopsis,
                    score: widget.anime!.score,
                    status: widget.anime!.status,
                    episodes: const [],
                  );
                  return _buildContent(fallbackDetail, isDark, isLoadingEpisodes: false);
                }
                return ErrorState(
                  message: _repo.errorMessage(snap.error!),
                  onRetry: () => setState(() => _future = _loadDetail()),
                );
              }
              final d = snap.data!;
              return _buildContent(d, isDark);
            },
          ),
        ),
      ),
    );
  }

  List<EpisodeModel>? _cachedStoryOrderRaw;
  List<EpisodeModel> _cachedStoryOrderList = const [];

  List<EpisodeModel> _getStoryOrderEpisodes(List<EpisodeModel> raw) {
    if (raw.isEmpty) return raw;
    if (identical(_cachedStoryOrderRaw, raw)) {
      return _cachedStoryOrderList;
    }
    final list = List<EpisodeModel>.from(raw);
    list.sort((a, b) {
      final na = parseEpisodeNumber(a, -1);
      final nb = parseEpisodeNumber(b, -1);
      if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
      return 0;
    });
    _cachedStoryOrderRaw = raw;
    _cachedStoryOrderList = list;
    return list;
  }

  Widget _buildContent(AnimeDetailModel d, bool isDark, {bool isLoadingEpisodes = false}) {
    _totalEpisodesCount = d.episodes.length;
    final episodes = _getSortedEpisodes(d.episodes);
    final visibleEpisodes = episodes.take(_displayCount).toList();
    final thumb = d.thumb ?? widget.anime?.thumb;

    // Fast O(1) episode index map and watched map
    final epIndexMap = {for (int idx = 0; idx < episodes.length; idx++) episodes[idx].id: idx};
    final watchedMap = {for (final ep in visibleEpisodes) ep.id: _isEpisodeWatched(ep)};

    // Find resume or first episode
    int targetEpIndex = -1;
    EpisodeModel? targetEp;
    String? matchingProgressEpId;

    if (_lastWatchedProgress != null) {
      for (int i = 0; i < episodes.length; i++) {
        final ep = episodes[i];
        if (_isMatchingProgressEpisode(ep, _lastWatchedProgress!)) {
          targetEpIndex = i;
          targetEp = ep;
          matchingProgressEpId = ep.id;
          break;
        }
      }
    }

    if (targetEp == null && episodes.isNotEmpty) {
      // Find first unwatched episode in story order
      final storyOrder = _getStoryOrderEpisodes(d.episodes);
      for (final ep in storyOrder) {
        if (!_isEpisodeWatched(ep)) {
          targetEp = ep;
          targetEpIndex = epIndexMap[ep.id] ?? 0;
          break;
        }
      }
      if (targetEp == null) {
        targetEpIndex = 0;
        targetEp = episodes[0];
      }
    }

    final isResuming = targetEp != null &&
        (_lastWatchedProgress != null || _watchedEpisodeIdentifiers.isNotEmpty);

    final cleanThumb = thumb != null && thumb.isNotEmpty
        ? (thumb.startsWith('http') ? thumb : '${ApiConfig.baseUrl}$thumb')
        : null;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── 1. APPLE TV+ PARALLAX BLUR BACKDROP APP BAR ────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          automaticallyImplyLeading: false,
          backgroundColor: (isDark ? AppColors.darkBackground : AppColors.lightBackground)
              .withValues(alpha: 0.85),
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Center(
              child: _circleGlassIcon(
                icon: CupertinoIcons.chevron_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: _isProfileLiked == true
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                iconColor: _isProfileLiked == true ? const Color(0xFFFF2E93) : Colors.white70,
                loading: _profileLikedLoading,
                onTap: () => _toggleProfileLiked(d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: _isBookmarked == true
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                iconColor: _isBookmarked == true ? Colors.white : Colors.white70,
                loading: _bookmarkLoading,
                onTap: () => _toggleBookmark(d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _circleGlassIcon(
                icon: CupertinoIcons.square_pencil,
                iconColor: Colors.white,
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login untuk menulis ulasan')),
                    );
                    return;
                  }
                  final res = await ReviewInputDialog.show(
                    context,
                    itemType: 'anime',
                    targetId: widget.animeId,
                    targetTitle: d.title,
                    targetCover: d.thumb,
                  );
                  if (res != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ulasan berhasil disimpan!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _circleGlassIcon(
                icon: CupertinoIcons.share,
                onTap: () => _shareAnime(d),
              ),
            ),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (ctx, constraints) {
              final currentH = constraints.maxHeight;
              const minH = kToolbarHeight + 40;
              const maxH = 240.0;
              final t = (1 - ((currentH - minH) / (maxH - minH))).clamp(0.0, 1.0);
              final isCollapsed = t > 0.65;

              return FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                centerTitle: true,
                titlePadding: const EdgeInsets.only(left: 56, right: 96, bottom: 14),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Ambient backdrop image
                    if (cleanThumb != null)
                      Image.network(
                        cleanThumb,
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: AppColors.darkHeroGradient),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: AppColors.darkHeroGradient),
                        ),
                      ),

                    // Multi-layer frosted glass blur
                    RepaintBoundary(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.60),
                                  (isDark ? AppColors.darkBackground : AppColors.lightBackground)
                                      .withValues(alpha: 0.95),
                                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                                ],
                                stops: const [0.0, 0.45, 0.80, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ── 2. HERO POSTER & IDENTITY CARD (Apple Books Layout) ────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floating Squircle Poster
                    Hero(
                      tag: 'anime_${widget.animeId}',
                      child: Container(
                        width: 114,
                        height: 164,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.20)
                                : Colors.black.withValues(alpha: 0.10),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: cleanThumb != null
                              ? Image.network(
                                  cleanThumb,
                                  fit: BoxFit.cover,
                                  cacheWidth: 350,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? AppColors.darkCard : Colors.white12,
                                    child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  color: isDark ? AppColors.darkCard : Colors.white12,
                                  child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title & Essential Metadata Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),

                          // Genre Capsules
                          if (d.genres.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: d.genres.take(4).map((g) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final slug = g.toLowerCase().replaceAll(' ', '-');
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GenreDetailScreen(
                                          genre: GenreModel(slug: slug, name: g),
                                          isAnime: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 8),

                          // Large iOS Title - generous lines, no arbitrary cut-off
                          Text(
                            d.title,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              letterSpacing: -0.4,
                              height: 1.22,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Metadata Subtitle Dot-Separated
                          Text(
                            [
                              if (d.type != null && d.type!.isNotEmpty) d.type!,
                              if (d.totalEpisodes != null && d.totalEpisodes!.isNotEmpty)
                                '${d.totalEpisodes} Ep'
                              else if (d.episodes.isNotEmpty)
                                '${d.episodes.length} Ep',
                              if (d.status != null && d.status!.isNotEmpty) d.status!,
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Rating Pill with Star
                          if (d.score != null && d.score!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.star_fill, size: 12, color: Color(0xFFFF9500)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${d.score} / 10',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF9500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                  const SizedBox(height: 18),

                  // ── 3. PRIMARY PLAY CTA BUTTON (Welcome Screen Pill Style) ─────────
                  if (targetEp != null)
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Colors.white, Color(0xFFF2F2F7)]
                              : const [Color(0xFF000000), Color(0xFF1C1C1E)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _playEpisode(
                            episode: targetEp!,
                            index: targetEpIndex,
                            episodes: episodes,
                            detail: d,
                            startAt: Duration.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.play_fill,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isResuming
                                        ? 'Lanjutkan: ${targetEp.label.isNotEmpty ? targetEp.label : 'Episode ${targetEpIndex + 1}'}'
                                        : 'Tonton Sekarang (${targetEp.label.isNotEmpty ? targetEp.label : 'Episode 1'})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Secondary Quick Action Pills Row
                  Row(
                    children: [
                      // Profile Liked Action Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: _isProfileLiked == true
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          label: _isProfileLiked == true ? 'Disukai' : 'Suka',
                          isActive: _isProfileLiked == true,
                          activeColor: const Color(0xFFFF2E93),
                          activeTextColor: Colors.white,
                          iconColor: _isProfileLiked == true ? Colors.white : const Color(0xFFFF2E93),
                          isDark: isDark,
                          onTap: () => _toggleProfileLiked(d),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bookmark Action Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: _isBookmarked == true
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          label: _isBookmarked == true ? 'Tersimpan' : 'Simpan',
                          isActive: _isBookmarked == true,
                          isDark: isDark,
                          onTap: () => _toggleBookmark(d),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Episode Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: CupertinoIcons.arrow_up_arrow_down,
                          label: _sortNewestFirst ? 'Terbaru' : 'Terlama',
                          isActive: false,
                          isDark: isDark,
                          onTap: () => _showSortActionSheet(context),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Share Pill
                      Expanded(
                        child: _buildSecondaryActionPill(
                          icon: CupertinoIcons.share,
                          label: 'Bagikan',
                          isActive: false,
                          isDark: isDark,
                          onTap: () => _shareAnime(d),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── 4. APPLE APP STORE INSET GROUPED STATS CARD ──────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildStatsCol(
                          top: '★ ${d.score ?? '-'}',
                          label: 'SKOR',
                          topColor: const Color(0xFFFF9500),
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: d.totalEpisodes ?? '${d.episodes.length}',
                          label: 'EPISODE',
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: d.status ?? 'Ongoing',
                          label: 'STATUS',
                          topColor: (d.status?.toLowerCase().contains('selesai') == true ||
                                  d.status?.toLowerCase().contains('completed') == true)
                              ? const Color(0xFF34C759)
                              : (isDark ? Colors.white : Colors.black),
                          isDark: isDark,
                        ),
                        _buildVerticalHairline(isDark),
                        _buildStatsCol(
                          top: d.duration ?? d.type ?? '24m',
                          label: 'DURASI',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ── 5. SYNOPSIS SECTION (Apple Books Inset Grouped) ───────
                  if (d.synopsis != null && d.synopsis!.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _buildSectionHeader('Sinopsis', isDark),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _ExpandableText(text: d.synopsis!.trim()),
                    ),
                  ],


                  // ── 6. METADATA DETAILS (Apple Settings Inset Grouped) ───
                  if (d.studio != null || d.duration != null || d.releasedOn != null) ...[
                    const SizedBox(height: 22),
                    _buildSectionHeader('Informasi Detail', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (d.studio != null && d.studio!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.film,
                              label: 'Studio',
                              value: d.studio!,
                              isDark: isDark,
                              showDivider: d.releasedOn != null || d.duration != null,
                            ),
                          if (d.releasedOn != null && d.releasedOn!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.calendar,
                              label: 'Rilis',
                              value: d.releasedOn!,
                              isDark: isDark,
                              showDivider: d.duration != null,
                            ),
                          if (d.duration != null && d.duration!.isNotEmpty)
                            _buildInfoRow(
                              icon: CupertinoIcons.time,
                              label: 'Durasi',
                              value: d.duration!,
                              isDark: isDark,
                              showDivider: false,
                            ),
                        ],
                      ),
                    ),
                  ],


                  // ── 7. EPISODES LIST (Apple Podcasts Inset Grouped) ──────
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSectionHeader('Daftar Episode', isDark),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${d.episodes.length}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildSortFilterPill(isDark),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Unified Inset Grouped Card for all episodes
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: episodes.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Center(
                                child: isLoadingEpisodes
                                    ? const CupertinoActivityIndicator(radius: 12)
                                    : Text(
                                        'Belum ada episode tersedia',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                              ),
                            )
                          : Column(
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: visibleEpisodes.length,
                                  separatorBuilder: (ctx, i) => Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 68,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                  itemBuilder: (ctx, i) {
                                    final ep = visibleEpisodes[i];
                                    final epId = ep.id;
                                    final isWatched = watchedMap[epId] ?? false;
                                    final isMatching = matchingProgressEpId == epId;
                                    final realIndex = (epIndexMap[epId] ?? i) + 1;

                                    return RepaintBoundary(
                                      child: _AppleEpisodeTile(
                                        ep: ep,
                                        index: realIndex,
                                        isWatched: isWatched,
                                        savedPositionSeconds: isMatching
                                            ? _lastWatchedProgress?.positionSeconds
                                            : null,
                                        totalDurationSeconds: isMatching
                                            ? _lastWatchedProgress?.totalDurationSeconds
                                            : null,
                                        isDark: isDark,
                                        onTap: () => _playEpisode(
                                          episode: ep,
                                          index: epIndexMap[epId] ?? i,
                                          episodes: episodes,
                                          detail: d,
                                          startAt: Duration.zero,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (visibleEpisodes.length < episodes.length)
                                  _buildLazyLoadFooter(
                                    currentCount: visibleEpisodes.length,
                                    totalCount: episodes.length,
                                    itemLabel: 'episode',
                                    isDark: isDark,
                                    onLoadMore: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _displayCount += _pageSize;
                                      });
                                    },
                                    onShowAll: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _displayCount = episodes.length;
                                      });
                                    },
                                  ),
                              ],
                            ),
                    ),
                  ),

                  // ── 7. REKOMENDASI TERKAIT ──
                  if (d.recommended.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Rekomendasi Terkait', isDark),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 204,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: d.recommended.length,
                        itemBuilder: (ctx, idx) {
                          final rec = d.recommended[idx];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: idx == d.recommended.length - 1 ? 0 : 12,
                            ),
                            child: PosterCard(
                              title: rec.title,
                              imageUrl: rec.thumb,
                              subtitle: rec.status?.isNotEmpty == true ? rec.status : 'Sub Indo',
                              badge: rec.score?.isNotEmpty == true ? '★ ${rec.score}' : null,
                              width: 130,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => AnimeDetailScreen(
                                      animeId: rec.id.isNotEmpty ? rec.id : rec.title,
                                      anime: rec,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── BOTTOM BANNER AD ──
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: AdBannerWidget(
                      margin: EdgeInsets.zero,
                    ),
                  ),

                  SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ],
      );
    }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildSortFilterPill(bool isDark) {
    final label = _sortNewestFirst ? 'Terbaru ke Terlama' : 'Terlama ke Terbaru';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSortActionSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.arrow_up_arrow_down,
                size: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                CupertinoIcons.chevron_down,
                size: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return CupertinoActionSheet(
          title: const Text(
            'Urutkan Episode',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          message: const Text('Pilih urutan daftar episode'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              isDefaultAction: _sortNewestFirst,
              onPressed: () {
                Navigator.pop(ctx);
                if (!_sortNewestFirst) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _sortNewestFirst = true;
                    _displayCount = _pageSize;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sortNewestFirst) ...[
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Terbaru ke Terlama',
                    style: TextStyle(
                      fontWeight: _sortNewestFirst ? FontWeight.w700 : FontWeight.w500,
                      color: _sortNewestFirst ? (isDark ? Colors.white : Colors.black) : null,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              isDefaultAction: !_sortNewestFirst,
              onPressed: () {
                Navigator.pop(ctx);
                if (_sortNewestFirst) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _sortNewestFirst = false;
                    _displayCount = _pageSize;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_sortNewestFirst) ...[
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Terlama ke Terbaru',
                    style: TextStyle(
                      fontWeight: !_sortNewestFirst ? FontWeight.w700 : FontWeight.w500,
                      color: !_sortNewestFirst ? (isDark ? Colors.white : Colors.black) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        );
      },
    );
  }

  Widget _buildLazyLoadFooter({
    required int currentCount,
    required int totalCount,
    required String itemLabel,
    required bool isDark,
    required VoidCallback onLoadMore,
    required VoidCallback onShowAll,
  }) {
    final remaining = totalCount - currentCount;
    final nextBatch = remaining > _pageSize ? _pageSize : remaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.015),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Menampilkan $currentCount dari $totalCount $itemLabel (sisa $remaining)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onLoadMore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_down_circle_fill, size: 14, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(width: 6),
                        Text(
                          'Muat $nextBatch Lagi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onShowAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Tampilkan Semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
    Color? activeColor,
    Color? activeTextColor,
    Color? iconColor,
  }) {
    final effectiveActiveBg = activeColor ?? (isDark ? Colors.white : Colors.black);
    final effectiveActiveFg = activeTextColor ?? (isDark ? Colors.black : Colors.white);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? effectiveActiveBg
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? effectiveActiveBg
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06)),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? effectiveActiveFg
                    : (iconColor ?? (isDark ? Colors.white70 : const Color(0xFF1C1C1E))),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? effectiveActiveFg
                      : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCol({
    required String top,
    required String label,
    Color? topColor,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: topColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E)),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalHairline(bool isDark) {
    return Container(
      width: 0.5,
      height: 30,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 44,
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _circleGlassIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool loading = false,
  }) {
    return RepaintBoundary(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.7,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(icon, color: iconColor ?? Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _loadingView() {
    return const Center(
      child: CupertinoActivityIndicator(radius: 16),
    );
  }
}

/// Inset Apple Podcasts styled Episode Tile
class _AppleEpisodeTile extends StatelessWidget {
  const _AppleEpisodeTile({
    required this.ep,
    required this.index,
    required this.onTap,
    required this.isWatched,
    this.savedPositionSeconds,
    this.totalDurationSeconds,
    required this.isDark,
  });

  final EpisodeModel ep;
  final int index;
  final VoidCallback onTap;
  final bool isWatched;
  final int? savedPositionSeconds;
  final int? totalDurationSeconds;
  final bool isDark;

  static final RegExp _epRegex1 = RegExp(r'(?:Episode|Ep|Eps)\.?\s*(\d+)', caseSensitive: false);
  static final RegExp _epRegex2 = RegExp(r'(?:episode|ep|eps)[-_](\d+)', caseSensitive: false);
  static final RegExp _epRegex3 = RegExp(r'[-_](\d+)$');
  static final RegExp _epRegexDigits = RegExp(r'\b(\d+)\b');
  static final RegExp _titlePrefixRegex = RegExp(r'^(?:Episode|Ep|Eps)\.?\s*\d+', caseSensitive: false);

  static final Map<String, String> _epNumCache = {};
  static final Map<String, String> _titleCache = {};

  String get _episodeNumber {
    final key = '${ep.id}_${ep.label}_$index';
    final cached = _epNumCache[key];
    if (cached != null) return cached;

    String res = '$index';
    if (ep.episodeNumber != null && ep.episodeNumber!.trim().isNotEmpty) {
      res = ep.episodeNumber!.trim();
    } else {
      final m = _epRegex1.firstMatch(ep.label);
      if (m != null) {
        res = m.group(1)!;
      } else {
        final mId = _epRegex2.firstMatch(ep.id) ??
            (ep.url != null ? _epRegex2.firstMatch(ep.url!) : null);
        if (mId != null) {
          res = mId.group(1)!;
        } else {
          final endDigits = _epRegex3.firstMatch(ep.id);
          if (endDigits != null) {
            res = endDigits.group(1)!;
          } else {
            final anyDigits = _epRegexDigits.firstMatch(ep.label);
            if (anyDigits != null) {
              res = anyDigits.group(1)!;
            }
          }
        }
      }
    }
    _epNumCache[key] = res;
    return res;
  }

  String get _displayTitle {
    final numStr = _episodeNumber;
    final key = '${ep.id}_${ep.label}_$numStr';
    final cached = _titleCache[key];
    if (cached != null) return cached;

    final labelTrimmed = ep.label.trim();
    String res;
    if (labelTrimmed.isEmpty) {
      res = 'Episode $numStr';
    } else if (_titlePrefixRegex.hasMatch(labelTrimmed)) {
      res = labelTrimmed;
    } else {
      res = 'Episode $numStr: $labelTrimmed';
    }
    _titleCache[key] = res;
    return res;
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const greenAccent = Color(0xFF34C759);
    final epNum = _episodeNumber;
    final hasProgress = savedPositionSeconds != null && savedPositionSeconds! > 5;
    final double progressRatio = (hasProgress && totalDurationSeconds != null && totalDurationSeconds! > 0)
        ? (savedPositionSeconds! / totalDurationSeconds!).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Episode Squircle Badge - Clean & Minimalist
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isWatched
                      ? greenAccent.withValues(alpha: isDark ? 0.12 : 0.08)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWatched
                        ? greenAccent.withValues(alpha: isDark ? 0.40 : 0.30)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.10)),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    epNum,
                    maxLines: 1,
                    style: TextStyle(
                      color: isWatched
                          ? (isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745))
                          : (isDark ? Colors.white : Colors.black),
                      fontSize: epNum.length >= 4 ? 11 : (epNum.length >= 3 ? 13 : 16),
                      fontWeight: isWatched ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, & Progress Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isWatched
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : (isDark ? Colors.white : AppColors.lightTextPrimary),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isWatched) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: greenAccent.withValues(alpha: isDark ? 0.12 : 0.09),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: greenAccent.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 9.5,
                                  color: isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745),
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  'Ditonton',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF4CD964) : const Color(0xFF28A745),
                                    letterSpacing: -0.1,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Subtitle / Date or Progress Info
                    Row(
                      children: [
                        if (hasProgress) ...[
                          Flexible(
                            child: Text(
                              'Tersimpan di ${_formatTime(savedPositionSeconds!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (ep.releasedOn != null && ep.releasedOn!.isNotEmpty)
                            Flexible(
                              child: Text(
                                ' • ${ep.releasedOn!}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                        ] else if (ep.releasedOn != null && ep.releasedOn!.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              ep.releasedOn!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              'Episode $epNum',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Playback progress bar
                    if (hasProgress && progressRatio > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 3,
                          width: double.infinity,
                          color: isDark ? Colors.white12 : Colors.black12,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressRatio,
                            child: Container(color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing Play Icon in Circular Glass
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isWatched
                      ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
                      : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.play_fill,
                  size: 12.5,
                  color: isWatched
                      ? (isDark ? Colors.white38 : Colors.black26)
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable text with animated crossfade and Cupertino chevron
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          secondChild: Text(
            widget.text,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _expanded ? 'Sembunyikan' : 'Selengkapnya',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                size: 12,
                color: isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
