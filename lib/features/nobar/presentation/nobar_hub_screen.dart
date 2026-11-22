import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/config/api_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/anime_watch_progress_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../../shared/widgets/ios_capsule_search_bar.dart';
import '../../../shared/widgets/ios_capsule_text_field.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../community/presentation/forum_feed_screen.dart';
import '../data/models/nobar_model.dart';
import '../data/nobar_repository.dart';
import 'nobar_room_screen.dart';

class NobarHubScreen extends StatefulWidget {
  final bool isEmbedded;
  final Widget? headerTitleWidget;

  const NobarHubScreen({
    super.key,
    this.isEmbedded = true,
    this.headerTitleWidget,
  });

  @override
  State<NobarHubScreen> createState() => _NobarHubScreenState();
}

class _NobarHubScreenState extends State<NobarHubScreen> {
  int _activeTab = 0; // 0: Room Publik, 1: Masuk Kode Privat, 2: Chat Komunitas
  List<NobarRoomModel> _publicRooms = [];
  bool _isLoading = true;
  String? _joiningRoomCode;
  Timer? _refreshTimer;

  // Private room code input
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();
  bool _isJoiningPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadPublicRooms();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_activeTab == 0 && mounted) {
        _loadPublicRooms(isBackground: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicRooms({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    final rooms = await NobarRepository.instance.getPublicRooms();
    if (mounted) {
      setState(() {
        _publicRooms = rooms;
        _isLoading = false;
      });
    }
  }

  void _onTabChanged(int index) {
    if (_activeTab == index) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTab = index);
    if (index == 0) {
      _loadPublicRooms();
    }
  }

  Future<void> _joinPublicRoom(NobarRoomModel room) async {
    if (_joiningRoomCode != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _joiningRoomCode = room.code);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    final joined = await NobarRepository.instance.joinRoom(
      room.code,
      username: user?.username ?? '',
      avatar: user?.avatarUrl ?? '',
    );

    if (!mounted) return;
    setState(() => _joiningRoomCode = null);

    if (joined != null) {
      final isHost = (user != null && user.id == joined.hostId) ||
          (user?.username == joined.hostUsername);

      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => NobarRoomScreen(
            initialRoom: joined,
            isHost: isHost,
          ),
        ),
      ).then((_) => _loadPublicRooms());
    } else {
      _showErrorDialog('Gagal bergabung ke room nobar. Room mungkin sudah selesai.');
    }
  }

  Future<void> _joinPrivateRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showErrorDialog('Masukkan 6 digit kode room nobar');
      return;
    }

    setState(() => _isJoiningPrivate = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final passcode = _passcodeController.text.trim();

    final joined = await NobarRepository.instance.joinRoom(
      code,
      passcode: passcode.isNotEmpty ? passcode : null,
      username: user?.username ?? '',
      avatar: user?.avatarUrl ?? '',
    );

    if (!mounted) return;
    setState(() => _isJoiningPrivate = false);

    if (joined != null) {
      _codeController.clear();
      _passcodeController.clear();
      final isHost = (user != null && user.id == joined.hostId) ||
          (user?.username == joined.hostUsername);

      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => NobarRoomScreen(
            initialRoom: joined,
            isHost: isHost,
          ),
        ),
      ).then((_) => _loadPublicRooms());
    } else {
      _showErrorDialog('Room tidak ditemukan atau kode sandi salah. Pastikan kode room sudah benar.');
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Info Nobar'),
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

  void _openCreateRoomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateNobarRoomSheet(),
    ).then((res) {
      if (res is NobarRoomModel && mounted) {
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (_) => NobarRoomScreen(
              initialRoom: res,
              isHost: true,
            ),
          ),
        ).then((_) => _loadPublicRooms());
      }
    });
  }

  Widget _buildSegmentedHeader(bool isDark) {
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: _activeTab,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.06),
      thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      padding: const EdgeInsets.all(3),
      children: {
        0: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.play_circle_fill,
                size: 13.5,
                color: _activeTab == 0
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 5),
              Text(
                'Nobar Publik',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeTab == 0 ? FontWeight.w700 : FontWeight.w500,
                  color: _activeTab == 0
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
        1: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.lock_fill,
                size: 13.5,
                color: _activeTab == 1
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 5),
              Text(
                'Kode Room',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                  color: _activeTab == 1
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
        2: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.square_list_fill,
                size: 13.5,
                color: _activeTab == 2
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 5),
              Text(
                'Forum',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeTab == 2 ? FontWeight.w700 : FontWeight.w500,
                  color: _activeTab == 2
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      },
      onValueChanged: (val) {
        if (val != null) _onTabChanged(val);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context)
                  ? Responsive.maxContentWidth
                  : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // iOS Large Title & Action Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _activeTab == 2 ? 'Forum' : 'Nobar',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                          color: isDark ? AppColors.iosTextPrimaryDark : AppColors.iosTextPrimaryLight,
                        ),
                      ),
                      if (_activeTab != 2)
                        BouncyTap(
                          onTap: _openCreateRoomSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.add, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Buat Room',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // iOS Full-width Segmented Control
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: widget.headerTitleWidget ?? _buildSegmentedHeader(isDark),
                  ),
                ),

                // Body content based on active tab
                Expanded(
                  child: IndexedStack(
                  index: _activeTab,
                  children: [
                    // Tab 0: Public Rooms
                    _buildPublicRoomsTab(isDark),

                    // Tab 1: Private Room / Room Code
                    _buildPrivateCodeTab(isDark),

                    // Tab 2: Forum & Thread Berbasis Genre / Judul
                    const ForumFeedScreen(
                      isEmbedded: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPublicRoomsTab(bool isDark) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_publicRooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadPublicRooms(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                ),
                child: const Icon(
                  CupertinoIcons.play_rectangle_fill,
                  size: 48,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Belum Ada Room Nobar Aktif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Jadilah yang pertama membuat room nonton bareng anime favoritmu dan ajak teman-teman nonton bareng live!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: BouncyTap(
                onTap: _openCreateRoomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.plus_circle_fill, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Buat Room Nobar Sekarang',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPublicRooms(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: _publicRooms.length,
        itemBuilder: (context, index) {
          final room = _publicRooms[index];
          return _buildRoomCard(room, isDark);
        },
      ),
    );
  }

  Widget _buildRoomCard(NobarRoomModel room, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _joinPublicRoom(room),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Anime Poster Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 100,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: room.animePoster.isNotEmpty
                        ? Image.network(
                            room.animePoster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.film, color: Colors.grey),
                          )
                        : const Icon(CupertinoIcons.film, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                // Room Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF3B30),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Participant Count
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.person_2_fill, size: 12, color: Color(0xFF007AFF)),
                                const SizedBox(width: 4),
                                Text(
                                  '${room.participantsCount} Nonton',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.animeTitle} • Eps ${room.episodeNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Host info & Join button
                      Row(
                        children: [
                          DecoratedAvatar(
                            avatarUrl: room.hostAvatar,
                            radius: 10,
                            fallbackName: room.hostUsername,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Host: ${room.hostUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _joiningRoomCode == room.code
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CupertinoActivityIndicator(color: Colors.white, radius: 7),
                                  )
                                : const Text(
                                    'Gabung',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateCodeTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
            ),
            child: const Icon(CupertinoIcons.lock_shield_fill, color: Color(0xFFFF9500), size: 40),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Masuk Room Nobar Teman',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Minta kode room 6 karakter (misal: MK8291) dari temanmu untuk langsung bergabung ke nobar privat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Room Code Input Box
        Text(
          'KODE ROOM NOBAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        IosCapsuleTextField(
          controller: _codeController,
          prefixIcon: CupertinoIcons.ticket_fill,
          hintText: 'MISAL: QQF5RG',
          textCapitalization: TextCapitalization.characters,
          height: 48,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),

        // Passcode Input (Optional)
        Text(
          'KODE SANDI / PASSCODE (OPSIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        IosCapsuleTextField(
          controller: _passcodeController,
          prefixIcon: CupertinoIcons.lock_fill,
          hintText: 'Kosongkan jika room tidak bersandi',
          obscureText: true,
          height: 48,
        ),
        const SizedBox(height: 24),

        // Join Button
        BouncyTap(
          onTap: _isJoiningPrivate ? () {} : _joinPrivateRoom,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isJoiningPrivate
                  ? const CupertinoActivityIndicator(color: Colors.white, radius: 11)
                  : const Text(
                      'Masuk ke Nobar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal Sheet to Create a Watch Party Room
class CreateNobarRoomSheet extends StatefulWidget {
  final AnimeModel? preselectedAnime;
  final String? initialAnimeId;
  final String? initialAnimeTitle;
  final String? initialAnimeThumb;
  final String? initialEpisodeId;
  final String? initialEpisodeLabel;
  final String? initialEpisodeUrl;

  const CreateNobarRoomSheet({
    super.key,
    this.preselectedAnime,
    this.initialAnimeId,
    this.initialAnimeTitle,
    this.initialAnimeThumb,
    this.initialEpisodeId,
    this.initialEpisodeLabel,
    this.initialEpisodeUrl,
  });

  @override
  State<CreateNobarRoomSheet> createState() => _CreateNobarRoomSheetState();
}

class _CreateNobarRoomSheetState extends State<CreateNobarRoomSheet> {
  final TextEditingController _titleController = TextEditingController(text: 'Nobar Santai Bareng');
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();

  bool _isPrivate = false;
  bool _isSearching = false;
  bool _isLoadingEpisodes = false;
  bool _isCreating = false;

  List<AnimeModel> _searchResults = [];
  AnimeModel? _selectedAnime;
  AnimeDetailModel? _animeDetail;
  EpisodeModel? _selectedEpisode;
  String? _resolvedStreamUrl;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedAnime != null) {
      _selectedAnime = widget.preselectedAnime;
      _titleController.text = 'Nobar ${widget.preselectedAnime!.title}';
      _loadDetailsForPreselected(widget.preselectedAnime!.id);
    } else if (widget.initialAnimeId != null && widget.initialAnimeId!.isNotEmpty) {
      _selectedAnime = AnimeModel(
        id: widget.initialAnimeId!,
        title: widget.initialAnimeTitle ?? 'Anime',
        thumb: widget.initialAnimeThumb,
      );
      _titleController.text = 'Nobar ${widget.initialAnimeTitle ?? 'Anime'}';
      _loadDetailsForPreselected(widget.initialAnimeId!);
    } else {
      _loadInitialAnime();
    }
  }

  Future<void> _loadDetailsForPreselected(String animeId) async {
    setState(() => _isLoadingEpisodes = true);
    try {
      final cleanId = AnimeWatchProgressService.cleanAnimeSlug(animeId);
      final detail = await AnimeRepository.instance.detail(cleanId.isNotEmpty ? cleanId : animeId);
      if (mounted) {
        setState(() {
          _animeDetail = detail;
          _isLoadingEpisodes = false;
          if (detail.episodes.isNotEmpty) {
            EpisodeModel? matched;
            if (widget.initialEpisodeId != null && widget.initialEpisodeId!.isNotEmpty) {
              matched = detail.episodes.cast<EpisodeModel?>().firstWhere(
                (ep) => ep?.id == widget.initialEpisodeId ||
                    ep?.url == widget.initialEpisodeUrl ||
                    ep?.label == widget.initialEpisodeLabel,
                orElse: () => null,
              );
            }
            _onSelectEpisode(matched ?? detail.episodes.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialAnime() async {
    setState(() => _isSearching = true);
    try {
      final homeData = await AnimeRepository.instance.home();
      final latest = homeData['latest_episode'] ?? homeData['latest_update'] ?? [];
      if (latest is List && latest.isNotEmpty) {
        setState(() {
          _searchResults = latest
              .whereType<AnimeModel>()
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _searchAnime(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadInitialAnime();
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await AnimeRepository.instance.search(q);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _onSelectAnime(AnimeModel anime) async {
    setState(() {
      _selectedAnime = anime;
      _animeDetail = null;
      _selectedEpisode = null;
      _resolvedStreamUrl = null;
      _isLoadingEpisodes = true;
      _titleController.text = 'Nobar ${anime.title}';
    });

    try {
      final detail = await AnimeRepository.instance.detail(anime.id);
      if (mounted) {
        setState(() {
          _animeDetail = detail;
          _isLoadingEpisodes = false;
          if (detail.episodes.isNotEmpty) {
            _onSelectEpisode(detail.episodes.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  Future<void> _onSelectEpisode(EpisodeModel ep) async {
    setState(() {
      _selectedEpisode = ep;
      _resolvedStreamUrl = null;
    });

    var epUrl = ep.url ?? '';
    if (epUrl.isEmpty || (!epUrl.contains('episode=') && !epUrl.contains('ylnime.com'))) {
      if (_selectedAnime != null && _selectedAnime!.id.isNotEmpty) {
        final slug = AnimeWatchProgressService.cleanAnimeSlug(_selectedAnime!.id);
        final epNum = AnimeWatchProgressService.extractEpisodeNumber(ep.episodeNumber) ??
            AnimeWatchProgressService.extractEpisodeNumber(ep.label) ??
            AnimeWatchProgressService.extractEpisodeNumber(ep.id) ?? '1';
        epUrl = 'https://ylnime.com/?series=$slug&episode=$epNum';
      }
    }

    if (epUrl.isNotEmpty) {
      try {
        final streams = await AnimeRepository.instance.ylnimeEpisode(epUrl);
        if (mounted && streams != null) {
          var stream = streams.bestPlayable?.proxyUrl ?? streams.bestPlayable?.url ?? '';
          if (stream.isNotEmpty) {
            if (stream.startsWith('/')) {
              stream = '${ApiConfig.ipv4BaseUrl}$stream';
            }
            stream = stream.replaceAll('103.119.237.37:2028', '31.59.119.142:2028');
            setState(() {
              _resolvedStreamUrl = stream;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _submitCreate() async {
    if (_selectedAnime == null) {
      _showError('Pilih anime yang ingin ditonton');
      return;
    }
    if (_selectedEpisode == null) {
      _showError('Pilih episode anime');
      return;
    }
    if (_resolvedStreamUrl == null || _resolvedStreamUrl!.isEmpty) {
      _showError('Menghubungkan stream video episode, coba pilih episode lagi');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Judul room tidak boleh kosong');
      return;
    }

    setState(() => _isCreating = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    final room = await NobarRepository.instance.createRoom(
      title: title,
      animeId: _selectedAnime!.id,
      animeTitle: _selectedAnime!.title,
      animePoster: _selectedAnime!.thumb ?? _animeDetail?.thumb ?? '',
      episodeKey: (_selectedEpisode!.url != null && _selectedEpisode!.url!.isNotEmpty)
          ? _selectedEpisode!.url!
          : _selectedEpisode!.id,
      episodeNumber: (_selectedEpisode!.episodeNumber != null && _selectedEpisode!.episodeNumber!.isNotEmpty)
          ? _selectedEpisode!.episodeNumber!
          : '1',
      streamUrl: _resolvedStreamUrl!,
      isPrivate: _isPrivate,
      passcode: _passcodeController.text.trim(),
      username: user?.username ?? 'Host',
      avatar: user?.avatarUrl ?? '',
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (room != null) {
      Navigator.of(context).pop(room);
    } else {
      _showError('Gagal membuat room nobar. Coba periksa koneksi internet.');
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Perhatian'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag bar & Header
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    '🎬 Buat Room Nobar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Room Title
                  const Text('Judul Room', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  IosCapsuleTextField(
                    controller: _titleController,
                    prefixIcon: CupertinoIcons.film_fill,
                    hintText: 'Misal: Nobar One Piece Bareng!',
                    height: 46,
                  ),
                  const SizedBox(height: 14),

                  // 2. Select Anime
                  const Text('Pilih Anime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  IosCapsuleSearchBar(
                    controller: _searchController,
                    showCancelButton: false,
                    hintText: 'Cari judul anime...',
                    onSubmitted: _searchAnime,
                    onChanged: (val) {
                      if (val.isEmpty) _loadInitialAnime();
                    },
                    onClear: _loadInitialAnime,
                  ),
                  const SizedBox(height: 8),

                  // Horizontal Anime List
                  if (_isSearching)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CupertinoActivityIndicator()))
                  else if (_searchResults.isNotEmpty)
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final a = _searchResults[index];
                          final isSelected = _selectedAnime?.id == a.id;
                          return BouncyTap(
                            onTap: () => _onSelectAnime(a),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        a.thumb ?? '',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.film),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),

                  // 3. Select Episode
                  if (_selectedAnime != null) ...[
                    Text(
                      'Pilih Episode ${_selectedAnime!.title}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingEpisodes)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator()))
                    else if (_animeDetail != null && _animeDetail!.episodes.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _animeDetail!.episodes.take(20).map((ep) {
                          final isSelected = _selectedEpisode?.url == ep.url;
                          return BouncyTap(
                            onTap: () => _onSelectEpisode(ep),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Eps ${(ep.episodeNumber != null && ep.episodeNumber!.isNotEmpty) ? ep.episodeNumber : ep.label}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Room Privacy Toggle
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Room Privat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              'Hanya teman yang memiliki kode / sandi yang bisa bergabung',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _isPrivate,
                        activeTrackColor: const Color(0xFF007AFF),
                        onChanged: (val) => setState(() => _isPrivate = val),
                      ),
                    ],
                  ),
                  if (_isPrivate) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _passcodeController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Kode Sandi Room (Opsional)',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submit Button
                  BouncyTap(
                    onTap: _isCreating ? () {} : _submitCreate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isCreating
                            ? const CupertinoActivityIndicator(color: Colors.white, radius: 11)
                            : const Text(
                                'Mulai Nonton Bareng 🎬',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
