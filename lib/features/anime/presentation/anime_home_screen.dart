import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../anime/presentation/anime_search_screen.dart';
import '../../anime/presentation/anime_schedule_screen.dart';
import '../../anime/presentation/anime_completed_screen.dart';
import '../../anime/presentation/anime_list_screen.dart';
import '../../anime/presentation/anime_new_releases_screen.dart';
import '../../genre/presentation/unified_genre_screen.dart';
import '../../genre/presentation/genre_detail_screen.dart';
import '../../../shared/widgets/featured_content_slider.dart';
import '../../chat/presentation/widgets/chat_marquee_banner.dart';
import '../data/models/ylnime_extra_models.dart';
import 'anime_hyper_screen.dart';
import 'anime_episode_player.dart';
import '../../character_vote/presentation/character_vote_screen.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../notifications/presentation/widgets/universal_notification_button.dart';
import '../../announcement/presentation/widgets/announcement_banner.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/data/reels_repository.dart';
import '../../reels/presentation/anime_reels_screen.dart';
import '../../reels/presentation/widgets/anime_reels_tray.dart';
import '../../../core/services/adult_content_service.dart';
import '../../jav/presentation/jav_home_screen.dart';

class AnimeHomeScreen extends StatefulWidget {
  const AnimeHomeScreen({super.key});

  @override
  State<AnimeHomeScreen> createState() => _AnimeHomeScreenState();
}

class _AnimeHomeScreenState extends State<AnimeHomeScreen> {
  static const List<Map<String, String>> _popularAnimeGenres = [
    {'name': 'Action', 'slug': 'action'},
    {'name': 'Romance', 'slug': 'romance'},
    {'name': 'Fantasy', 'slug': 'fantasy'},
    {'name': 'Isekai', 'slug': 'isekai'},
    {'name': 'Comedy', 'slug': 'comedy'},
    {'name': 'Supernatural', 'slug': 'supernatural'},
    {'name': 'School', 'slug': 'school'},
    {'name': 'Sci-Fi', 'slug': 'sci-fi'},
    {'name': 'Sports', 'slug': 'sports'},
  ];

  final _repo = AnimeRepository.instance;
  List<AnimeModel> _carouselAnime = [];
  List<AnimeModel> _newReleases = [];
  List<AnimeModel> _topAnime = [];
  List<AnimeModel> _todayAnime = [];
  String _todayDay = '';
  List<AnimeModel> _ongoing = [];
  List<AnimeModel> _completed = [];
  List<AnimeModel> _allAnime = [];
  List<ContinueWatchingItem> _continueWatching = [];
  List<AnimeModel> _movieAnime = [];
  List<AnimeModel> _hypeAnime = [];
  List<ReelModel> _reels = [];
  bool _loading = true;
  String? _error;
  late final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    if (_repo.hasCachedHome) {
      _applyPrimaryData(
        _repo.cachedHome!,
        _repo.cachedScheduleToday ?? const TodayScheduleModel(),
      );
      _loading = false;
    }
    _load();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            AnnouncementBanner.checkAndShowNewAnnouncementPopup(context);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _translateDay(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'monday':
        return 'Senin';
      case 'tuesday':
        return 'Selasa';
      case 'wednesday':
        return 'Rabu';
      case 'thursday':
        return 'Kamis';
      case 'friday':
        return 'Jumat';
      case 'saturday':
        return 'Sabtu';
      case 'sunday':
        return 'Minggu';
      default:
        return raw;
    }
  }

  void _applyPrimaryData(
    Map<String, dynamic> rawHomeData,
    TodayScheduleModel todayData, {
    List<AnimeModel> newReleasesFallback = const [],
  }) {
    final homeData = (rawHomeData['data'] is Map)
        ? Map<String, dynamic>.from(rawHomeData['data'] as Map)
        : rawHomeData;

    var continueList = <ContinueWatchingItem>[];
    final continueRaw = homeData['continue_watching'] ?? rawHomeData['continue_watching'];
    if (continueRaw is List) {
      continueList = continueRaw
          .map((e) => ContinueWatchingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final carouselList = _extractList(homeData, 'carousel');
    final newReleasesList = _extractList(homeData, 'new_releases');
    final topAnimeList = _extractTopAnime(homeData);

    final ongoing = _extractList(homeData, 'ongoing_anime').isNotEmpty
        ? _extractList(homeData, 'ongoing_anime')
        : _extractList(homeData, 'ongoing');

    final completed = _extractList(homeData, 'completed_anime').isNotEmpty
        ? _extractList(homeData, 'completed_anime')
        : _extractList(homeData, 'completed');

    final todayList = todayData.animeList;
    final todayDay = _translateDay(todayData.today);

    List<AnimeModel> dedupe(List<AnimeModel> list) {
      final seen = <String>{};
      return list.where((a) {
        final key = a.id.isNotEmpty ? a.id : a.title.trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();
    }

    final carouselAnime = dedupe(carouselList);
    final newReleasesRaw = newReleasesList.isNotEmpty ? newReleasesList : newReleasesFallback;
    final newReleases = dedupe(newReleasesRaw);
    final topAnime = dedupe(topAnimeList);
    final todayAnime = dedupe(todayList);
    final distinctOngoing = dedupe(ongoing);
    final distinctCompleted = dedupe(completed);

    final allMap = <String, AnimeModel>{};
    for (final a in [
      ...carouselList,
      ...newReleasesRaw,
      ...topAnimeList,
      ...todayList,
      ...ongoing,
      ...completed,
    ]) {
      if (a.id.isNotEmpty) {
        allMap[a.id] = a;
      } else if (a.title.isNotEmpty) {
        allMap[a.title] = a;
      }
    }

    _carouselAnime = carouselAnime;
    _newReleases = newReleases;
    if (_newReleases.isNotEmpty) {
      HomeWidgetService.instance.updateLatestAnimeList(_newReleases).ignore();
    }
    _topAnime = topAnime;
    _todayAnime = todayAnime;
    _todayDay = todayDay;
    _ongoing = distinctOngoing;
    if (_completed.isEmpty) {
      _completed = distinctCompleted;
    }
    _allAnime = allMap.values.toList();
    // Gabungkan history lokal terbaru dan cache backend
    AnimeWatchProgressService.instance.getRecentContinueWatching().then((localList) {
      if (!mounted) return;
      final Map<String, ContinueWatchingItem> m = {};
      for (final item in continueList) {
        final k = AnimeWatchProgressService.cleanAnimeSlug(item.animeId ?? item.title);
        if (k.isNotEmpty) m[k] = item;
      }
      for (final item in localList) {
        final k = AnimeWatchProgressService.cleanAnimeSlug(item.animeId ?? item.title);
        if (k.isNotEmpty) m[k] = item;
      }
      if (m.isNotEmpty) {
        final mergedList = m.values.toList();
        setState(() => _continueWatching = mergedList);
        if (mergedList.isNotEmpty) {
          HomeWidgetService.instance.updateContinueWatchingList(mergedList).ignore();
        }
      }
    });
    if (_hypeAnime.isEmpty && topAnimeList.isNotEmpty) {
      _hypeAnime = topAnimeList;
    }
  }

  Future<void> _load() async {
    final hasData = _carouselAnime.isNotEmpty || _ongoing.isNotEmpty;
    if (!hasData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // 1. Tahap 1: Tampilkan konten utama secepat kilat (home & schedule telah di-prefetch saat splash)
      final primaryResults = await Future.wait<dynamic>([
        _repo.home(forceRefresh: !hasData).catchError((_) => <String, dynamic>{}),
        _repo.scheduleToday().catchError((_) => const TodayScheduleModel()),
      ]);
      if (!mounted) return;

      final homeData = primaryResults[0] as Map<String, dynamic>;
      final todayData = primaryResults[1] as TodayScheduleModel;

      setState(() {
        _applyPrimaryData(
          homeData,
          todayData,
        );
        _loading = false;
      });

      // Muat Anime Reels dari backend Golang secara asinkron
      ReelsRepository.instance.getReels(page: 1).then((res) {
        if (mounted && res.items.isNotEmpty) {
          setState(() => _reels = res.items);
        }
      }).catchError((_) {});

      // 2. Tahap 2: Muat data sekunder (movies, hyper) secara efisien & ter-cache
      final secondaryResults = await Future.wait<dynamic>([
        _repo.getMovies(page: 1).catchError((_) => <AnimeModel>[]),
        _repo.getContinueWatching().catchError((_) => <ContinueWatchingItem>[]),
        _repo.getHyper().catchError((_) => null),
      ]);
      if (!mounted) return;

      final movieP1 = secondaryResults[0] as List<AnimeModel>;
      final continueList = secondaryResults[1] as List<ContinueWatchingItem>;
      final hyperData = secondaryResults[2] as HyperPageData?;

      final rawMovies = movieP1;
      final movieSeen = <String>{};
      final distinctMovies = rawMovies.where((m) {
        final k = m.id.isNotEmpty ? m.id : m.title.trim().toLowerCase();
        if (k.isEmpty || movieSeen.contains(k)) return false;
        movieSeen.add(k);
        return true;
      }).toList();

      final hypeList = <AnimeModel>[];
      if (hyperData != null) {
        if (hyperData.champion != null) {
          final c = hyperData.champion!;
          hypeList.add(AnimeModel(
            id: c.seriesKey ?? c.url ?? c.title,
            title: c.title,
            thumb: c.cover ?? c.backdrop,
            status: c.views != null ? '${c.views} views' : 'TerHype',
          ),);
        }
        for (final r in hyperData.rankings) {
          hypeList.add(AnimeModel(
            id: r.seriesKey ?? r.url ?? r.title,
            title: r.title,
            thumb: r.cover,
            status: r.views != null ? '${r.views} views' : 'TerHype',
          ),);
        }
      }
      if (hypeList.isEmpty && _topAnime.isNotEmpty) {
        hypeList.addAll(_topAnime);
      }

      // Prioritaskan history lokal terbaru terlebih dahulu, lalu gabungkan dari backend
      final localContinue = await AnimeWatchProgressService.instance.getRecentContinueWatching();
      final Map<String, ContinueWatchingItem> mergedMap = {};

      // 1. Masukkan item dari backend terlebih dahulu
      for (final item in continueList) {
        final key = AnimeWatchProgressService.cleanAnimeSlug(item.animeId ?? item.title);
        if (key.isNotEmpty) {
          mergedMap[key] = item;
        }
      }

      // 2. Timpa dengan item lokal (paling update di perangkat ini)
      for (final item in localContinue) {
        final key = AnimeWatchProgressService.cleanAnimeSlug(item.animeId ?? item.title);
        if (key.isNotEmpty) {
          mergedMap[key] = item;
        }
      }

      final List<ContinueWatchingItem> finalContinue = mergedMap.values.toList();

      setState(() {
        _continueWatching = finalContinue;
        _movieAnime = distinctMovies;
        if (hypeList.isNotEmpty) {
          _hypeAnime = hypeList;
        }
      });
      if (finalContinue.isNotEmpty) {
        HomeWidgetService.instance.updateContinueWatchingList(finalContinue).ignore();
      }
    } catch (e) {
      if (!mounted) return;
      if (_carouselAnime.isEmpty && _ongoing.isEmpty) {
        setState(() {
          _error = _repo.errorMessage(e);
          _loading = false;
        });
      }
    }
  }

  List<AnimeModel> _extractTopAnime(Map<String, dynamic> data) {
    final top = data['top_anime'];
    if (top is Map) {
      for (final period in ['today', 'seven_days', 'yesterday', 'thirty_days']) {
        if (top[period] is List && (top[period] as List).isNotEmpty) {
          return (top[period] as List)
              .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } else if (top is List) {
      return top
          .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  List<AnimeModel> _extractList(Map<String, dynamic> data, String key) {
    var v = data[key];
    if (v == null) {
      if (key == 'ongoing' || key == 'ongoing_anime') {
        v = data['ongoing'] ?? data['ongoing_anime'] ?? (data['data'] is List ? data['data'] : null);
      } else if (key == 'completed' || key == 'completed_anime') {
        v = data['completed'] ?? data['completed_anime'];
      } else if (key == 'latest' || key == 'latest_anime') {
        v = data['latest'] ?? data['latest_anime'] ?? data['latest_episode'] ?? data['latest_update'] ?? (data['data'] is List ? data['data'] : null);
      } else if (key == 'new_releases') {
        v = data['new_releases'] ?? data['latest_episode'] ?? data['latest_update'] ?? data['latest'] ?? (data['data'] is List ? data['data'] : null);
      } else if (key == 'carousel') {
        v = data['carousel'] ?? (data['data'] is List ? (data['data'] as List).take(8).toList() : null);
      }
    }
    if (v is List) {
      return v
          .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (v is Map) {
      for (final k in ['items', 'data', 'list', 'results', 'anime_list']) {
        if (v[k] is List) {
          return (v[k] as List)
              .map((e) => AnimeModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      if (v['title'] != null && !v.containsKey('carousel') && !v.containsKey('ongoing')) {
        return [AnimeModel.fromJson(Map<String, dynamic>.from(v))];
      }
    }
    return [];
  }

  void _resumeWatching(ContinueWatchingItem item) {
    HapticFeedback.selectionClick();
    String? seriesSlug;
    if (item.animeId != null && item.animeId!.isNotEmpty && !item.animeId!.contains(' ')) {
      seriesSlug = item.animeId;
    } else if (item.url != null && item.url!.contains('series=')) {
      seriesSlug = AnimeWatchProgressService.cleanAnimeSlug(item.url!);
    } else if (item.episodeUrl != null && item.episodeUrl!.contains('series=')) {
      seriesSlug = AnimeWatchProgressService.cleanAnimeSlug(item.episodeUrl!);
    }

    final rawEpId = item.episodeId ?? item.url;
    final epId = (rawEpId != null && rawEpId != seriesSlug) ? rawEpId : '';

    if (epId.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => AnimeEpisodePlayerScreen(
            episodeId: epId,
            episodeLabel: item.episode ?? 'Episode',
            episodeUrl: item.episodeUrl ?? item.url,
            animeId: seriesSlug,
            animeTitle: item.title,
            animeThumb: item.cover,
            startAt: item.currentTime > 0 ? Duration(seconds: item.currentTime) : Duration.zero,
          ),
        ),
      ).then((_) => _load());
    } else {
      final detailId = seriesSlug ?? (item.animeId != null && item.animeId!.isNotEmpty ? item.animeId! : item.title);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimeDetailScreen(
            animeId: detailId,
            anime: AnimeModel(
              id: detailId,
              title: item.title,
              thumb: item.cover,
              episode: item.episode,
            ),
          ),
        ),
      ).then((_) => _load());
    }
  }

  Widget _buildNetflixTopShelf(bool isDark) {
    final list = _hypeAnime.isNotEmpty ? _hypeAnime : _topAnime;
    if (list.isEmpty) return const SizedBox.shrink();

    final top10 = list.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Top 10 Anime Populer',
          subtitle: 'Paling banyak ditonton minggu ini',
          seeAllLabel: 'Lihat Semua',
          onSeeAll: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => const AnimeHyperScreen(),
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: top10.length,
            itemBuilder: (ctx, i) {
              final a = top10[i];
              final rank = i + 1;
              return _buildNetflixTopCard(a, rank, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNetflixTopCard(AnimeModel a, int rank, bool isDark) {
    return RepaintBoundary(
      child: Container(
        width: 175,
        margin: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnimeDetailScreen(
                  animeId: a.id,
                  anime: a,
                ),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Netflix Iconic Giant Rank Number (Bottom Left)
              Positioned(
                left: -4,
                bottom: -10,
                child: Stack(
                  children: [
                    // Outline Stroke
                    Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: rank == 10 ? 92 : 106,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -7,
                        height: 0.88,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3.5
                          ..color = isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    // Inner Fill
                    Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: rank == 10 ? 92 : 106,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -7,
                        height: 0.88,
                        color: isDark
                            ? const Color(0xFF181818)
                            : const Color(0xFFECECEC),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Poster Card (Overlapping to the right)
              Positioned(
                left: 48,
                top: 4,
                right: 0,
                bottom: 8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                        blurRadius: 10,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Poster Image
                        a.thumb != null && a.thumb!.isNotEmpty
                            ? AppNetworkImage(
                                url: a.thumb!,
                                fit: BoxFit.cover,
                                memCacheWidth: 350,
                                memCacheHeight: 500,
                              )
                            : Container(
                                color: Colors.grey.shade900,
                                child: const Icon(CupertinoIcons.film, color: Colors.white30),
                              ),

                      // Gradient Overlay for Title Legibility
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.88),
                              ],
                              stops: const [0.4, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Netflix "TOP 10" Badge (Top Left Corner)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF000000), Color(0xFF262626)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TOP',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$rank',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Title & Subtitle at Bottom
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                            if (a.views != null || a.status != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                a.views != null
                                    ? '${a.views} penonton'
                                    : (a.status ?? 'Populer'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMovieShelf(bool isDark) {
    if (_movieAnime.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Film & Anime Movie',
          subtitle: 'Koleksi layar lebar berkualitas tinggi',
          seeAllLabel: 'Lihat Semua',
          onSeeAll: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => const AnimeSearchScreen(initialQuery: 'movie'),
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _movieAnime.length,
            itemBuilder: (ctx, i) {
              final a = _movieAnime[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AnimeCard(
                  anime: a,
                  badge: 'Movie',
                  subtitle: a.score != null && a.score!.isNotEmpty ? '★ ${a.score}' : (a.status ?? 'Movie'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? backgroundColor,
    Color? borderColor,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ??
                  (isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7)),
              border: Border.all(
                color: borderColor ??
                    (isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB)),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? (isDark ? Colors.white : Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanNavPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final featuredAnime = _carouselAnime.isNotEmpty
        ? _carouselAnime
        : (_todayAnime.isNotEmpty ? _todayAnime : _ongoing);
    final sliderItems = featuredAnime.take(8).map((a) {
      final isToday = _todayAnime.contains(a);
      final isCarousel = _carouselAnime.contains(a);
      final tag = isCarousel
          ? (a.status != null && a.status!.isNotEmpty ? a.status!.toUpperCase() : 'UNGGULAN')
          : (isToday
              ? (_todayDay.isNotEmpty ? 'TAYANG HARI INI • $_todayDay' : 'TAYANG HARI INI')
              : 'SEDANG TAYANG');

      Color tagAccent;
      final tagUpper = tag.toUpperCase();
      if (tagUpper.contains('SEDANG TAYANG') || tagUpper.contains('ONGOING')) {
        tagAccent = const Color(0xFF30D158); // Apple iOS vibrant emerald green
      } else if (tagUpper.contains('TAYANG HARI INI')) {
        tagAccent = const Color(0xFF0A84FF); // Apple iOS vibrant electric blue
      } else if (tagUpper.contains('UNGGULAN')) {
        tagAccent = const Color(0xFFFFD60A); // Apple iOS vivid gold
      } else {
        tagAccent = const Color(0xFF30D158);
      }

      String effectiveId = a.id;
      if (effectiveId.isEmpty || effectiveId == 'None') {
        if (a.url != null && a.url!.isNotEmpty) {
          final m = RegExp(r'series=([^&]+)').firstMatch(a.url!);
          if (m != null) effectiveId = m.group(1)!;
        }
      }
      if (effectiveId.isEmpty || effectiveId == 'None') {
        final match = _ongoing.firstWhere(
          (o) => o.title.toLowerCase().trim() == a.title.toLowerCase().trim(),
          orElse: () => _todayAnime.firstWhere(
            (t) => t.title.toLowerCase().trim() == a.title.toLowerCase().trim(),
            orElse: () => a,
          ),
        );
        if (match.id.isNotEmpty && match.id != 'None') {
          effectiveId = match.id;
        } else if (match.url != null && match.url!.isNotEmpty) {
          effectiveId = match.url!;
        }
      }

      return FeaturedContentItem(
        title: a.title,
        imageUrl: a.thumb,
        posterUrl: a.thumb,
        eyebrowTag: tag,
        subtitle: a.synopsis != null && a.synopsis!.isNotEmpty
            ? a.synopsis!
            : (a.episode != null ? '${AnimeModel.formatEpisode(a.episode)} • Sub Indo' : (a.status ?? 'Rilis Baru')),
        badge: a.score != null && a.score!.isNotEmpty ? '★ ${a.score}' : null,
        actionIcon: CupertinoIcons.play_fill,
        actionLabel: 'Watch',
        secondaryActionLabel: 'More',
        accentColor: tagAccent,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => AnimeDetailScreen(animeId: effectiveId, anime: a),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: RefreshIndicator(
              color: isDark ? Colors.white : Colors.black,
              edgeOffset: 112,
              onRefresh: _load,
              child: CustomScrollView(
                controller: _scrollCtrl,
                scrollCacheExtent: const ScrollCacheExtent.pixels(350.0),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Apple iOS Large Title App Bar (Matches Ulas & Komik)
                  SliverAppBar(
                    expandedHeight: 112,
                    pinned: true,
                    stretch: true,
                    backgroundColor: isDark
                        ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                        : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    flexibleSpace: LayoutBuilder(
                      builder: (ctx, c) {
                        final shrink = 1 -
                            ((c.maxHeight - kToolbarHeight) / (112 - kToolbarHeight))
                                .clamp(0.0, 1.0);
                        final isShrunk = shrink > 0.6;
                        return FlexibleSpaceBar(
                          centerTitle: isShrunk,
                          titlePadding: EdgeInsets.only(
                            left: isShrunk ? 0 : 16,
                            right: isShrunk ? 0 : 16,
                            bottom: isShrunk ? 13 : 12,
                          ),
                          title: Text(
                            'Anime',
                            style: TextStyle(
                                fontSize: isShrunk ? 17 : 32,
                                fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                                color: isDark
                                    ? AppColors.iosTextPrimaryDark
                                    : AppColors.iosTextPrimaryLight,
                                letterSpacing: isShrunk ? -0.4 : -1.0,
                              ),
                            ),
                        );
                      },
                    ),
                    actions: [
                      const UniversalNotificationButton(),
                      _buildIosActionButton(
                        icon: CupertinoIcons.search,
                        tooltip: 'Cari Anime',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const AnimeSearchScreen(),
                          ),
                        ),
                      ),
                      _buildIosActionButton(
                        icon: CupertinoIcons.calendar,
                        tooltip: 'Jadwal Hari Ini',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const AnimeScheduleScreen(),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: AdultContentService.instance,
                        builder: (context, _) {
                          if (!AdultContentService.instance.is18Unlocked) {
                            return const SizedBox.shrink();
                          }
                          return _buildIosActionButton(
                            icon: CupertinoIcons.film_fill,
                            tooltip: 'Javtiful (JAV)',
                            iconColor: const Color(0xFFFF2D55),
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const JavHomeScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  // Featured Today Anime Hero Slider
                  SliverToBoxAdapter(
                    child: FeaturedContentSlider(
                      items: sliderItems,
                      isLoading: _loading,
                    ),
                  ),

              // Pemberitahuan / Announcement Banner (Push Alert jika ada)
              const SliverToBoxAdapter(
                child: AnnouncementBanner(),
              ),

              // Chat Komunitas Running Text Banner
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: ChatMarqueeBanner(),
                ),
              ),

              // Quick Nav Discovery Bar (Clean matching bottom buttons)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCleanNavPill(
                          icon: CupertinoIcons.flame_fill,
                          label: 'Top Hype',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnimeHyperScreen()),
                          ),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.play_rectangle_fill,
                          label: 'Reels',
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                              builder: (_) => AnimeReelsScreen(initialReels: _reels),
                            ),
                          ),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.sparkles,
                          label: 'Baru Diupload',
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const AnimeNewReleasesScreen()),
                          ),
                          isDark: isDark,
                        ),

                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.heart_fill,
                          label: 'Vote Karakter',
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const CharacterVoteScreen()),
                          ),
                          isDark: isDark,
                        ),

                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.calendar,
                          label: 'Jadwal Rilis',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnimeScheduleScreen()),
                          ),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.square_grid_2x2,
                          label: 'Genre',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UnifiedGenreScreen(initialType: GenreType.anime)),
                          ),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildCleanNavPill(
                          icon: CupertinoIcons.textformat_abc,
                          label: 'Daftar A-Z',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnimeListScreen()),
                          ),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Lanjut Nonton (Continue Watching Tray with real % progress)
              if (_continueWatching.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Lanjut Nonton',
                    subtitle: 'Lanjutkan episode terakhir yang kamu tonton',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 125,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _continueWatching.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _continueWatching[index];
                        final progressVal = (item.progress / 100.0).clamp(0.0, 1.0);
                        return GestureDetector(
                          onTap: () => _resumeWatching(item),
                          child: Container(
                            width: 220,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 85,
                                      height: 125,
                                      child: item.cover != null && item.cover!.isNotEmpty
                                          ? AppNetworkImage(
                                              url: item.cover!,
                                              fit: BoxFit.cover,
                                              borderRadius: 0,
                                              memCacheWidth: 170,
                                              memCacheHeight: 250,
                                            )
                                          : Container(
                                              color: Colors.grey.shade900,
                                              child: const Icon(Icons.play_arrow, color: Colors.white54),
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            if (item.episode != null && item.episode!.isNotEmpty)
                                              Text(
                                                item.episode!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Text(
                                                  item.currentTime > 0
                                                      ? '${AnimeWatchProgressService.formatDuration(item.currentTime)}${item.progress > 0 ? ' • ${item.progress.toStringAsFixed(0)}%' : ''}'
                                                      : (item.progress > 0 ? '${item.progress.toStringAsFixed(0)}%' : 'Lanjut'),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white60 : Colors.black54,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  CupertinoIcons.play_circle_fill,
                                                  size: 19,
                                                  color: isDark ? Colors.white : Colors.black,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(
                                    value: progressVal,
                                    minHeight: 3.5,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Anime Reels Section (Go Backend API: /api/ylnime/reels)
              SliverToBoxAdapter(
                child: AnimeReelsTray(
                  reels: _reels,
                  isLoading: _loading && _reels.isEmpty,
                ),
              ),

              // Quick Genre Discovery (iOS HIG Horizontal Pills)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jelajahi Genre',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isDark
                                  ? AppColors.iosTextPrimaryDark
                                  : AppColors.iosTextPrimaryLight,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UnifiedGenreScreen(initialType: GenreType.anime),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lihat Semua',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 12,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularAnimeGenres.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final g = _popularAnimeGenres[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GenreDetailScreen(
                                    genre: GenreModel(slug: g['slug']!, name: g['name']!),
                                    isAnime: true,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.iosCardDark
                                      : AppColors.iosCardLight,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.iosHairlineDark
                                        : AppColors.iosHairlineLight,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    g['name']!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                      color: isDark
                                          ? AppColors.iosTextPrimaryDark
                                          : AppColors.iosTextPrimaryLight,
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
                ),
              ),

              // A-Z Anime Directory Quick Card (iOS Inset Grouped Cell)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnimeListScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.iosCardDark : AppColors.iosCardLight,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              CupertinoIcons.textformat_abc,
                              color: isDark ? Colors.white : Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Anime A-Z',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                    color: isDark
                                        ? AppColors.iosTextPrimaryDark
                                        : AppColors.iosTextPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Jelajahi seluruh katalog anime berdasarkan alfabet',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.iosTextSecondaryDark
                                        : AppColors.iosTextSecondaryLight,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: isDark
                                ? AppColors.iosTextTertiaryDark
                                : AppColors.iosTextTertiaryLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),



              if (_loading) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Tayang Hari Ini',
                    subtitle: 'Memuat jadwal anime hari ini...',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (c, i) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: AnimeCardSkeleton(),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Sedang Tayang',
                    subtitle: 'Memuat episode ongoing...',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (c, i) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: AnimeCardSkeleton(),
                      ),
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                SliverToBoxAdapter(
                  child: ErrorState(message: _error!, onRetry: _load),
                ),
              ] else ...[
                // 1. Tayang Hari Ini (GET /ylnime/schedule/today)
                // 1. Rilis Terbaru (New Releases)
                if (_newReleases.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Baru Diupload',
                          subtitle: 'Episode & anime paling gres yang baru masuk',
                          onSeeAll: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const AnimeNewReleasesScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: _newReleases.length,
                            itemBuilder: (ctx, i) {
                              final a = _newReleases[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: AnimeCard(
                                  anime: a,
                                  badge: a.episode != null ? AnimeModel.formatEpisode(a.episode) : 'Baru',
                                  subtitle: a.status ?? 'Rilis Baru',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),


                // 2. Top 20 Anime TerHype (Trending / Most Viewed)
                if (_hypeAnime.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildNetflixTopShelf(isDark),
                  )
                else if (_topAnime.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Top Anime Populer',
                          subtitle: 'Paling banyak ditonton',
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: _topAnime.length,
                            itemBuilder: (ctx, i) {
                              final a = _topAnime[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: AnimeCard(
                                  anime: a,
                                  badge: '#${i + 1}',
                                  subtitle: a.score != null ? 'Skor: ${a.score}' : (a.status ?? 'Populer'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. Tayang Hari Ini (GET /ylnime/schedule/today)
                if (_todayAnime.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: _todayDay.isNotEmpty
                              ? 'Tayang Hari Ini ($_todayDay)'
                              : 'Tayang Hari Ini',
                          subtitle: 'Jadwal rilis episode baru hari ini',
                          seeAllLabel: 'Lihat Jadwal',
                          onSeeAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AnimeScheduleScreen(),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: _todayAnime.length,
                            itemBuilder: (ctx, i) {
                              final a = _todayAnime[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: AnimeCard(
                                  anime: a,
                                  badge: _todayDay.isNotEmpty ? _todayDay : 'Hari Ini',
                                  subtitle: a.episode != null ? AnimeModel.formatEpisode(a.episode) : 'Hari Ini',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // 4. Sedang Tayang (Ongoing)
                if (_ongoing.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Sedang Tayang',
                          subtitle: 'Update anime ongoing terbaru',
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: _ongoing.length,
                            itemBuilder: (ctx, i) {
                              final a = _ongoing[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: AnimeCard(
                                  anime: a,
                                  badge: a.episode != null ? AnimeModel.formatEpisode(a.episode) : 'Ongoing',
                                  subtitle: a.status ?? 'Ongoing',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Film & Anime Movie (SEBELUM Anime Tamat)
                if (_movieAnime.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildMovieShelf(isDark),
                  ),

                // 5. Anime Tamat (GET /ylnime/completed)
                if (_completed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Anime Tamat',
                          subtitle: 'Enak buat maraton tanpa nunggu episode',
                          seeAllLabel: 'Lihat Semua',
                          onSeeAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AnimeCompletedScreen(),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: _completed.length,
                            itemBuilder: (ctx, i) {
                              final a = _completed[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: AnimeCard(
                                  anime: a,
                                  badge: 'Tamat',
                                  subtitle: a.status ?? 'Tamat',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_allAnime.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Semua Anime',
                          subtitle: 'Daftar rilis terbaru',
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.gridColumns(context),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.7,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final a = _allAnime[i];
                          return AnimeCard(
                            anime: a,
                            width: double.infinity,
                          );
                        },
                        childCount: _allAnime.length,
                      ),
                    ),
                  ),
                ],
              ],

              const SliverToBoxAdapter(
                child: AdBannerWidget(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: Responsive.bottomNavPadding(context))),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

/// Compact anime card matching ComicCard
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    this.subtitle,
    this.badge,
    this.width = 140,
  });

  final AnimeModel anime;
  final String? subtitle;
  final String? badge;
  final double width;

  @override
  Widget build(BuildContext context) {
    final epText = AnimeModel.formatEpisode(anime.episode);
    final effectiveBadge = badge != null
        ? AnimeModel.formatEpisode(badge)
        : (anime.score != null && anime.score!.isNotEmpty
            ? '★ ${anime.score}'
            : (epText.isNotEmpty ? epText : null));

    String? effectiveSubtitle = subtitle != null ? AnimeModel.formatEpisode(subtitle) : null;
    if (effectiveSubtitle == null) {
      if (effectiveBadge == epText && epText.isNotEmpty) {
        effectiveSubtitle = (anime.status != null && anime.status!.isNotEmpty)
            ? anime.status
            : (anime.type != null && anime.type!.isNotEmpty ? anime.type : 'Sub Indo');
      } else if (epText.isNotEmpty) {
        effectiveSubtitle = epText;
      } else {
        effectiveSubtitle = anime.status;
      }
    } else if (effectiveBadge != null && effectiveBadge == effectiveSubtitle) {
      effectiveSubtitle = (anime.status != null && anime.status!.isNotEmpty)
          ? anime.status
          : 'Sub Indo';
    }

    return PosterCard(
      title: anime.title,
      imageUrl: anime.thumb,
      subtitle: effectiveSubtitle,
      badge: effectiveBadge,
      width: width,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimeDetailScreen(animeId: anime.id, anime: anime),
        ),
      ),
    );
  }
}

