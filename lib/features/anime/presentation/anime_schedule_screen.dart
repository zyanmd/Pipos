import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../data/anime_repository.dart';
import '../data/models/anime_model.dart';
import 'anime_detail_screen.dart';

class AnimeScheduleScreen extends StatefulWidget {
  const AnimeScheduleScreen({super.key});

  @override
  State<AnimeScheduleScreen> createState() => _AnimeScheduleScreenState();
}

class _AnimeScheduleScreenState extends State<AnimeScheduleScreen> {
  final _repo = AnimeRepository.instance;
  final ScrollController _dayScrollController = ScrollController();
  List<ScheduleModel> _data = [];
  int _selectedDayIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  int? _dayNameToWeekday(String dayName) {
    final clean = dayName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.contains('senin') || clean.contains('monday')) return DateTime.monday;
    if (clean.contains('selasa') || clean.contains('tuesday')) return DateTime.tuesday;
    if (clean.contains('rabu') || clean.contains('wednesday')) return DateTime.wednesday;
    if (clean.contains('kamis') || clean.contains('thursday')) return DateTime.thursday;
    if (clean.contains('jumat') || clean.contains('friday')) return DateTime.friday;
    if (clean.contains('sabtu') || clean.contains('saturday')) return DateTime.saturday;
    if (clean.contains('minggu') || clean.contains('sunday')) return DateTime.sunday;
    return null;
  }

  DateTime? _getDateForDay(String dayName) {
    final targetWeekday = _dayNameToWeekday(dayName);
    if (targetWeekday == null) return null;
    final now = DateTime.now();
    final diff = targetWeekday - now.weekday;
    return now.add(Duration(days: diff));
  }

  bool _isToday(String dayName) {
    final targetWeekday = _dayNameToWeekday(dayName);
    if (targetWeekday == null) return false;
    return targetWeekday == DateTime.now().weekday;
  }

  String _formatShortDate(String dayName) {
    final dt = _getDateForDay(dayName);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final m = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    return '${dt.day} $m';
  }

  String _formatFullHeaderDate(String dayName) {
    final dt = _getDateForDay(dayName);
    if (dt == null) return dayName;
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final m = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    final isToday = _isToday(dayName);
    final dateStr = '$dayName, ${dt.day} $m ${dt.year}';
    return isToday ? '$dateStr • Hari Ini' : dateStr;
  }

  void _scrollToSelectedDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayScrollController.hasClients && _selectedDayIndex > 0) {
        final targetOffset = (_selectedDayIndex * 92.0) - 16.0;
        _dayScrollController.animateTo(
          targetOffset.clamp(0.0, _dayScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.schedule();
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
        
        // Auto-select today's day if present in schedule
        final todayWeekday = DateTime.now().weekday;
        int todayIndex = -1;
        for (int i = 0; i < _data.length; i++) {
          if (_dayNameToWeekday(_data[i].day) == todayWeekday) {
            todayIndex = i;
            break;
          }
        }
        if (todayIndex != -1) {
          _selectedDayIndex = todayIndex;
        } else if (_selectedDayIndex >= _data.length && _data.isNotEmpty) {
          _selectedDayIndex = 0;
        }
      });
      _scrollToSelectedDay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _repo.errorMessage(e);
        _loading = false;
      });
    }
  }

  Widget _buildIosActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentDaySchedule = _data.isNotEmpty && _selectedDayIndex < _data.length
        ? _data[_selectedDayIndex]
        : null;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // iOS Large Title SliverAppBar matching AnimeHomeScreen
              SliverAppBar(
                expandedHeight: 112,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? AppColors.iosBackgroundDark.withValues(alpha: 0.85)
                    : AppColors.iosBackgroundLight.withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                leading: Navigator.canPop(context)
                    ? CupertinoNavigationBarBackButton(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null,
                actions: [
                  _buildIosActionButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _load();
                    },
                    isDark: isDark,
                  ),
                ],
                flexibleSpace: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final currentHeight = constraints.maxHeight;
                    const minHeight = kToolbarHeight;
                    const maxHeight = 112.0;
                    final shrinkProgress = (1 - ((currentHeight - minHeight) / (maxHeight - minHeight))).clamp(0.0, 1.0);
                    final isShrunk = shrinkProgress > 0.6;

                    return FlexibleSpaceBar(
                      centerTitle: isShrunk,
                      titlePadding: EdgeInsets.only(
                        left: isShrunk ? 0 : 16,
                        right: isShrunk ? 0 : 16,
                        bottom: isShrunk ? 13 : 12,
                      ),
                      title: Text(
                        'Jadwal Rilis',
                        style: TextStyle(
                          fontSize: isShrunk ? 17 : 32,
                          fontWeight: isShrunk ? FontWeight.w600 : FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: isShrunk ? -0.4 : -1.0,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Day Selector Capsule Pills (Horizontal)
              if (_data.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                    child: SizedBox(
                      height: 52,
                      child: ListView.separated(
                        controller: _dayScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _data.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final day = _data[index];
                          final isSelected = _selectedDayIndex == index;
                          final isToday = _isToday(day.day);
                          final shortDate = _formatShortDate(day.day);

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDayIndex = index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isToday
                                          ? AppColors.success.withValues(alpha: 0.6)
                                          : (isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight)),
                                  width: isToday && !isSelected ? 1.0 : 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            day.day.isEmpty ? '-' : day.day,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              color: isSelected
                                                  ? (isDark ? Colors.black : Colors.white)
                                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                            ),
                                          ),
                                          if (isToday) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? (isDark ? Colors.black : Colors.white)
                                                    : AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (shortDate.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          isToday ? '$shortDate • Hari Ini' : shortDate,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected
                                                ? (isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.75))
                                                : (isToday
                                                    ? AppColors.success
                                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (day.items.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.25))
                                            : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${day.items.length}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? (isDark ? Colors.black : Colors.white)
                                              : (isDark ? Colors.white : Colors.black),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // Selected Date Summary Bar
              if (_data.isNotEmpty && currentDaySchedule != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 14,
                          color: _isToday(currentDaySchedule.day)
                              ? AppColors.success
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatFullHeaderDate(currentDaySchedule.day),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isToday(currentDaySchedule.day)
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                        Text(
                          '${currentDaySchedule.items.length} Anime',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Content Area
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const AnimeCardSkeleton(),
                      childCount: 6,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ErrorState(message: _error!, onRetry: _load),
                  ),
                )
              else if (_data.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.calendar,
                      title: 'Belum ada jadwal rilis',
                      subtitle: 'Tarik ke bawah untuk memuat ulang.',
                    ),
                  ),
                )
              else if (currentDaySchedule == null || currentDaySchedule.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: CupertinoIcons.calendar_badge_minus,
                      title: 'Tidak ada rilisan hari ini',
                      subtitle: 'Anime yang rilis pada hari ini tidak ditemukan.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final a = currentDaySchedule.items[i];
                        return PosterCard(
                          title: a.title,
                          imageUrl: a.thumb,
                          subtitle: a.episode != null ? 'Ep ${a.episode}' : a.status,
                          score: a.score,
                          width: double.infinity,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => AnimeDetailScreen(animeId: a.id, anime: a),
                              ),
                            );
                          },
                        );
                      },
                      childCount: currentDaySchedule.items.length,
                    ),
                  ),
                ),

              // Bottom clearance for floating navbar
              SliverToBoxAdapter(
                child: SizedBox(height: Responsive.bottomNavPadding(context)),
              ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}
