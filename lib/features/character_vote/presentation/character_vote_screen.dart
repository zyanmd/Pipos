import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../data/character_vote_repository.dart';
import '../data/models/character_vote_model.dart';

class CharacterVoteScreen extends StatefulWidget {
  final String initialCategory;

  const CharacterVoteScreen({
    super.key,
    this.initialCategory = 'terkuat',
  });

  @override
  State<CharacterVoteScreen> createState() => _CharacterVoteScreenState();
}

class _CharacterVoteScreenState extends State<CharacterVoteScreen> {
  late String _selectedCategory;
  bool _isLoading = true;
  String? _error;
  List<CharacterVoteItem> _characters = [];

  static const _categories = [
    {
      'key': 'terkuat',
      'label': 'Terkuat',
      'icon': '⚡',
      'title': 'Karakter Terkuat',
      'subtitle': 'Pahlawan, Dewa & Petarung Tak Tertandingi',
      'accent': Color(0xFFFF9500),
    },
    {
      'key': 'tercantik',
      'label': 'Tercantik',
      'icon': '🌸',
      'title': 'Karakter Tercantik',
      'subtitle': 'Waifu Idaman & Karisma Mempesona',
      'accent': Color(0xFFFF2D55),
    },
    {
      'key': 'terganteng',
      'label': 'Terganteng',
      'icon': '✨',
      'title': 'Karakter Terganteng',
      'subtitle': 'Husbando Berwibawa & Paling Memikat',
      'accent': Color(0xFF5856D6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadCharacters();
  }

  Map<String, dynamic> get _currentCatInfo {
    return _categories.firstWhere(
      (c) => c['key'] == _selectedCategory,
      orElse: () => _categories.first,
    );
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final list = await CharacterVoteRepository.instance.getLeaderboard(_selectedCategory);

    if (!mounted) return;
    setState(() {
      _characters = list;
      _isLoading = false;
    });
  }

  void _onCategoryChanged(String cat) {
    if (_selectedCategory == cat) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = cat);
    _loadCharacters();
  }

  Future<void> _toggleVote(CharacterVoteItem item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Login untuk memberikan vote pada karakter'),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();

    // Optimistic Update
    final newVoted = !item.userVoted;
    final newVotesCount = newVoted ? item.votesCount + 1 : (item.votesCount > 0 ? item.votesCount - 1 : 0);

    setState(() {
      final idx = _characters.indexWhere((c) => c.characterId == item.characterId);
      if (idx != -1) {
        _characters[idx] = _characters[idx].copyWith(
          userVoted: newVoted,
          votesCount: newVotesCount,
        );
        _recalculatePercentages();
      }
    });

    final res = await CharacterVoteRepository.instance.voteCharacter(
      category: _selectedCategory,
      character: item,
    );

    if (res != null && mounted) {
      if (res['success'] == true) {
        final msg = res['message']?.toString() ?? 'Vote berhasil!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
        // Refresh auth profile XP in background
        auth.refreshUser();
      } else {
        // Revert
        setState(() {
          final idx = _characters.indexWhere((c) => c.characterId == item.characterId);
          if (idx != -1) {
            _characters[idx] = _characters[idx].copyWith(
              userVoted: item.userVoted,
              votesCount: item.votesCount,
            );
            _recalculatePercentages();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(res['error']?.toString() ?? 'Gagal memproses vote'),
          ),
        );
      }
    }
  }

  void _recalculatePercentages() {
    int total = 0;
    for (final c in _characters) {
      total += c.votesCount;
    }
    for (int i = 0; i < _characters.length; i++) {
      final pct = total > 0 ? (_characters[i].votesCount / total * 100) : 0.0;
      _characters[i] = _characters[i].copyWith(percentage: pct);
    }
  }

  void _openNominateSearchSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NominateSearchSheet(
        category: _selectedCategory,
        accentColor: _currentCatInfo['accent'] as Color,
        onCharacterVoted: () {
          _loadCharacters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catInfo = _currentCatInfo;
    final Color catAccent = catInfo['accent'] as Color;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: (isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7)).withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'Vote Karakter Anime',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              catInfo['subtitle'] as String,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              CupertinoIcons.search,
              color: catAccent,
              size: 21,
            ),
            tooltip: 'Cari & Nominasikan (Jikan.moe)',
            onPressed: _openNominateSearchSheet,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. SEGMENTED CATEGORIES CAPSULE (Apple Pill) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildCategoryTabs(isDark),
            ),

            // ── 2. MAIN CONTENT ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _error != null
                      ? _buildErrorView(isDark)
                      : _characters.isEmpty
                          ? _buildEmptyView(isDark)
                          : RefreshIndicator(
                              onRefresh: _loadCharacters,
                              color: catAccent,
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: [
                                  // Top 3 Podium
                                  if (_characters.length >= 3)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                                        child: _buildPodium(isDark, catAccent),
                                      ),
                                    ),

                                  // Header List
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                      child: Row(
                                        children: [
                                          Text(
                                            _characters.length >= 3 ? 'Kandidat Lainnya' : 'Daftar Kandidat',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${_characters.length} Karakter Terdaftar',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Ranked List
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final offset = _characters.length >= 3 ? 3 : 0;
                                          final actualIndex = offset + index;
                                          if (actualIndex >= _characters.length) return null;

                                          final item = _characters[actualIndex];
                                          return _buildCharacterListItem(
                                            item: item,
                                            rank: actualIndex + 1,
                                            isDark: isDark,
                                            accent: catAccent,
                                          );
                                        },
                                        childCount: _characters.length >= 3 ? _characters.length - 3 : _characters.length,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: catAccent,
        elevation: 6,
        onPressed: _openNominateSearchSheet,
        icon: const Icon(CupertinoIcons.plus_circle_fill, size: 18, color: Colors.white),
        label: const Text(
          'Nominasikan Karakter',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    final containerBg = isDark ? const Color(0xFF18181C) : const Color(0xFFE5E5EA);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c['key'];

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onCategoryChanged(c['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  border: isSelected
                      ? Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
                          width: 0.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c['icon'] as String, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4.5),
                      Text(
                        c['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodium(bool isDark, Color catAccent) {
    final first = _characters[0];
    final second = _characters[1];
    final third = _characters[2];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 Silver (Left)
          Expanded(
            child: _buildPodiumColumn(
              item: second,
              rank: 2,
              height: 140,
              badgeColor: const Color(0xFF9E9E9E),
              gradientColors: [const Color(0xFFB0B0B8), const Color(0xFF8E8E93)],
              isDark: isDark,
              accent: catAccent,
            ),
          ),
          const SizedBox(width: 8),

          // #1 Gold (Center, Highest)
          Expanded(
            child: _buildPodiumColumn(
              item: first,
              rank: 1,
              height: 175,
              badgeColor: const Color(0xFFFF9500),
              gradientColors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
              isCenter: true,
              isDark: isDark,
              accent: catAccent,
            ),
          ),
          const SizedBox(width: 8),

          // #3 Bronze (Right)
          Expanded(
            child: _buildPodiumColumn(
              item: third,
              rank: 3,
              height: 125,
              badgeColor: const Color(0xFFCD7F32),
              gradientColors: [const Color(0xFFD78848), const Color(0xFFB86B28)],
              isDark: isDark,
              accent: catAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required CharacterVoteItem item,
    required int rank,
    required double height,
    required Color badgeColor,
    required List<Color> gradientColors,
    bool isCenter = false,
    required bool isDark,
    required Color accent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / Medal Icon
        if (isCenter)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            child: const Text('👑', style: TextStyle(fontSize: 22)),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Text(rank == 2 ? '🥈' : '🥉', style: const TextStyle(fontSize: 16)),
          ),

        // Character Portrait
        ClipRRect(
          borderRadius: BorderRadius.circular(isCenter ? 18 : 14),
          child: Container(
            width: isCenter ? 68 : 52,
            height: isCenter ? 68 : 52,
            decoration: BoxDecoration(
              border: Border.all(
                color: isCenter ? badgeColor : (isDark ? Colors.white24 : Colors.black12),
                width: isCenter ? 2.0 : 1.2,
              ),
              borderRadius: BorderRadius.circular(isCenter ? 18 : 14),
            ),
            child: AppNetworkImage(
              url: item.imageUrl,
              width: isCenter ? 68 : 52,
              height: isCenter ? 68 : 52,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isCenter ? 13 : 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 1),

        // Anime Title
        if (item.animeTitle != null && item.animeTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.animeTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Pedestal
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColors[0].withValues(alpha: isDark ? 0.35 : 0.20),
                gradientColors[1].withValues(alpha: isDark ? 0.15 : 0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rank badge circle
              Container(
                width: isCenter ? 30 : 24,
                height: isCenter ? 30 : 24,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: isCenter ? 14 : 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Votes count
              Text(
                '${item.votesCount} Vote',
                style: TextStyle(
                  fontSize: isCenter ? 12 : 10.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 1),

              // Percentage
              Text(
                '${item.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),

              // Quick Vote Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleVote(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.userVoted
                        ? const Color(0xFF34C759)
                        : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.userVoted ? CupertinoIcons.checkmark_alt : CupertinoIcons.heart_fill,
                        size: 11,
                        color: item.userVoted ? Colors.white : accent,
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        item.userVoted ? 'Dipilih' : 'Vote',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: item.userVoted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterListItem({
    required CharacterVoteItem item,
    required int rank,
    required bool isDark,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.userVoted
            ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
            : (isDark ? const Color(0xFF18181C) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.userVoted
              ? accent.withValues(alpha: 0.45)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          width: item.userVoted ? 1.0 : 0.6,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Character Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50,
              height: 50,
              color: isDark ? Colors.white12 : Colors.black12,
              child: AppNetworkImage(
                url: item.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details & Vote Bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    if (item.nameKanji != null && item.nameKanji!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.nameKanji!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.animeTitle != null && item.animeTitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.animeTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                      FractionallySizedBox(
                        widthFactor: (item.percentage / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Percentage and votes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.votesCount} Vote',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Vote Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleVote(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: item.userVoted
                    ? const Color(0xFF34C759)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item.userVoted ? const Color(0xFF34C759) : (isDark ? Colors.white12 : Colors.black12),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.userVoted ? CupertinoIcons.checkmark_alt : CupertinoIcons.heart_fill,
                    size: 15,
                    color: item.userVoted ? Colors.white : accent,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.userVoted ? 'Dipilih' : 'Vote',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: item.userVoted ? Colors.white : (isDark ? Colors.white : Colors.black87),
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

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.heart_slash, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'Belum ada karakter untuk kategori ini',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoButton(
            onPressed: _openNominateSearchSheet,
            child: const Text('Cari & Nominasikan Karakter Pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle, size: 40, color: Colors.amber[700]),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Terjadi kesalahan saat memuat data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFFFF9500),
            onPressed: _loadCharacters,
            child: const Text('Coba Lagi', style: TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet untuk mencari karakter anime via Jikan API & MyAnimeList
class _NominateSearchSheet extends StatefulWidget {
  final String category;
  final Color accentColor;
  final VoidCallback onCharacterVoted;

  const _NominateSearchSheet({
    required this.category,
    required this.accentColor,
    required this.onCharacterVoted,
  });

  @override
  State<_NominateSearchSheet> createState() => _NominateSearchSheetState();
}

class _NominateSearchSheetState extends State<_NominateSearchSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<JikanCharacterItem> _results = [];
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(text.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final items = await CharacterVoteRepository.instance.searchJikanCharacters(query);

    if (!mounted) return;
    setState(() {
      _results = items;
      _isSearching = false;
      if (items.isEmpty) {
        _searchError = 'Karakter "$query" tidak ditemukan di Jikan / MyAnimeList';
      }
    });
  }

  Future<void> _voteNominated(JikanCharacterItem item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Login untuk memberikan vote pada karakter'),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();

    final candidate = CharacterVoteItem(
      characterId: item.malId,
      category: widget.category,
      name: item.name,
      nameKanji: item.nameKanji,
      imageUrl: item.imageUrl,
      about: item.about,
    );

    final res = await CharacterVoteRepository.instance.voteCharacter(
      category: widget.category,
      character: candidate,
    );

    if (!mounted) return;

    if (res != null && res['success'] == true) {
      Navigator.pop(context);
      widget.onCharacterVoted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Berhasil vote ${item.name}! (+10 XP)'),
        ),
      );
      auth.refreshUser();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(res?['error']?.toString() ?? 'Gagal vote karakter'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cari & Nominasikan Karakter',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Database MyAnimeList via Jikan.moe API',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                  color: isDark ? Colors.white38 : Colors.black38,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: _searchCtrl,
              placeholder: 'Ketik nama karakter (e.g. Gojo, Zoro, Makima)...',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              onChanged: _onSearchChanged,
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CupertinoActivityIndicator())
                : _searchError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.sparkles,
                                  size: 40,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cari karakter anime favoritmu\nuntuk ditambahkan ke vote kategori ini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F6F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        color: isDark ? Colors.white12 : Colors.black12,
                                        child: AppNetworkImage(
                                          url: item.imageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (item.nameKanji != null && item.nameKanji!.isNotEmpty)
                                            Text(
                                              item.nameKanji!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white54 : Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      color: widget.accentColor,
                                      borderRadius: BorderRadius.circular(12),
                                      onPressed: () => _voteNominated(item),
                                      child: const Text(
                                        'Vote',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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
