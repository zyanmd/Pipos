import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../data/gamification_repository.dart';
import '../../data/models/leaderboard_user_model.dart';
import '../leaderboard_screen.dart';

class DailyXpStreakBanner extends StatefulWidget {
  final VoidCallback? onClaimSuccess;
  final bool compact;

  const DailyXpStreakBanner({
    super.key,
    this.onClaimSuccess,
    this.compact = false,
  });

  @override
  State<DailyXpStreakBanner> createState() => _DailyXpStreakBannerState();
}

class _DailyXpStreakBannerState extends State<DailyXpStreakBanner>
    with SingleTickerProviderStateMixin {
  XpSummaryModel? _summary;
  bool _isClaiming = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<int> _defaultRewards = [15, 20, 25, 30, 35, 40, 150];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSummary();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    final summary = await GamificationRepository.instance.getXpSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
      });
      if (summary != null && auth.user != null && summary.xp != auth.user!.xp) {
        auth.refreshUser();
      }
    }
  }

  Future<void> _claim() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    HapticFeedback.mediumImpact();

    final res = await GamificationRepository.instance.claimDailyBonus();
    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (res != null && res['success'] == true) {
      HapticFeedback.heavyImpact();
      final bonus = (res['bonus_amount'] as num?)?.toInt() ?? 25;
      final streak = (res['streak'] as num?)?.toInt() ?? 1;
      final isGrand = res['is_grand_bonus'] == true || streak % 7 == 0;

      // Refresh auth profile & summary
      await auth.refreshUser();
      await _loadSummary();
      widget.onClaimSuccess?.call();

      if (!mounted) return;
      _showSuccessDialog(bonus: bonus, streak: streak, isGrand: isGrand);
    } else {
      HapticFeedback.lightImpact();
      final msg = res?['error']?.toString() ??
          'Bonus harian sudah diklaim hari ini. Kembali lagi besok!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSuccessDialog({
    required int bonus,
    required int streak,
    required bool isGrand,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGrand ? CupertinoIcons.gift_fill : CupertinoIcons.sparkles,
              color: isGrand ? const Color(0xFFFFD60A) : const Color(0xFFFF9500),
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(isGrand ? '🎉 HADIAH BESAR STREAK!' : 'Check-in Berhasil!'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isGrand
                      ? const LinearGradient(
                          colors: [Color(0xFFFF9500), Color(0xFFFF2D55)],
                        )
                      : null,
                  color: isGrand ? null : const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '+$bonus XP',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isGrand ? Colors.white : const Color(0xFFFF9500),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isGrand
                    ? 'Luar biasa! Kamu berhasil mempertahankan streak selama 7 hari berturut-turut! Hadiah jackpot +$bonus XP telah masuk ke akunmu 🔥'
                    : 'Streak aktif: $streak Hari berturut-turut 🔥\nJaga streak-mu setiap hari agar mendapatkan Hadiah Besar +150 XP di Hari ke-7!',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mantap!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final user = auth.user;

    // Hitung streak & cycle
    final streak = _summary?.streak ?? user?.streak ?? 0;
    final canClaim = !isLoggedIn || (_summary?.canClaimDaily ?? true);
    final rewards = _summary?.streakRewards.isNotEmpty == true
        ? _summary!.streakRewards
        : _defaultRewards;

    // Hari ke-berapa di dalam siklus 7 hari (1..7)
    int cycleDay = _summary?.streakCycleDay ?? 1;
    if (cycleDay < 1) cycleDay = 1;
    if (cycleDay > 7) cycleDay = 7;

    final nextBonus = rewards[(cycleDay - 1).clamp(0, rewards.length - 1)];
    final isGrandDay = cycleDay == 7;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(14),
      blur: 10,
      border: Border.all(
        color: isGrandDay && canClaim
            ? const Color(0xFFFF9500).withValues(alpha: 0.6)
            : (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.08)),
        width: isGrandDay && canClaim ? 1.5 : 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // ── Header: Streak & Level / Papan Peringkat ──
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🔥', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Klaim XP Harian',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: streak > 0
                                          ? const Color(0xFFFF9500).withValues(alpha: 0.2)
                                          : (isDark ? Colors.white12 : Colors.black12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      streak > 0 ? '$streak Hari' : 'Mulai',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: streak > 0
                                            ? const Color(0xFFFF9500)
                                            : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Bonus streak 7 hari (+150 XP)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLoggedIn
                                ? 'Lv. ${_summary?.level ?? user?.level ?? 1} • ${(_summary?.xp ?? user?.xp ?? 0)} XP'
                                : 'Peringkat',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF9500),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            CupertinoIcons.chevron_forward,
                            size: 11,
                            color: Color(0xFFFF9500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── 7-Day Numbers Row ("angka-angka gitu") ──
              Row(
                children: List.generate(7, (index) {
                  final dayNum = index + 1;
                  final reward = rewards[index.clamp(0, rewards.length - 1)];
                  final isGrand = dayNum == 7;

                  // Status hari
                  final isClaimed = !canClaim
                      ? dayNum <= cycleDay
                      : dayNum < cycleDay;
                  final isCurrentTarget = canClaim && dayNum == cycleDay;
                  final isFuture = dayNum > cycleDay;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 6 ? 4.0 : 0.0),
                      child: _buildDayChip(
                        isDark: isDark,
                        dayNum: dayNum,
                        reward: reward,
                        isGrand: isGrand,
                        isClaimed: isClaimed,
                        isCurrentTarget: isCurrentTarget,
                        isFuture: isFuture,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // ── Action CTA Button ──
              if (!isLoggedIn)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          CupertinoIcons.person_crop_circle_badge_plus,
                          size: 16,
                          color: Color(0xFFFF9500),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Masuk Akun untuk Mulai Klaim XP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!canClaim)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF34C759).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 15,
                        color: Color(0xFF34C759),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          cycleDay == 7
                              ? 'Selamat! Hadiah Besar 7 Hari sudah diklaim 🎉'
                              : 'Sudah check-in hari ini! Besok: Hari $cycleDay (+${rewards[(cycleDay).clamp(0, rewards.length - 1)]} XP)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF34C759),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ScaleTransition(
                  scale: isGrandDay ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: _isClaiming ? null : _claim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isGrandDay
                            ? const LinearGradient(
                                colors: [Color(0xFFFF9500), Color(0xFFFF2D55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isClaiming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isGrandDay
                                        ? CupertinoIcons.gift_fill
                                        : CupertinoIcons.sparkles,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isGrandDay
                                          ? '🎁 Klaim Hadiah Hari ke-7 (+150 XP)!'
                                          : 'Klaim Bonus Hari ke-$cycleDay (+$nextBonus XP)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildDayChip({
    required bool isDark,
    required int dayNum,
    required int reward,
    required bool isGrand,
    required bool isClaimed,
    required bool isCurrentTarget,
    required bool isFuture,
  }) {
    Color borderColor;
    Color bgColor;

    if (isClaimed) {
      borderColor = const Color(0xFF34C759).withValues(alpha: 0.6);
      bgColor = const Color(0xFF34C759).withValues(alpha: 0.12);
    } else if (isCurrentTarget) {
      borderColor = const Color(0xFFFF9500);
      bgColor = const Color(0xFFFF9500).withValues(alpha: 0.20);
    } else if (isGrand) {
      borderColor = const Color(0xFFFFD60A).withValues(alpha: 0.5);
      bgColor = const Color(0xFFFFD60A).withValues(alpha: 0.08);
    } else {
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02);
    }

    Widget centerIcon;
    if (isClaimed) {
      centerIcon = const Icon(
        CupertinoIcons.checkmark_alt,
        size: 13,
        color: Color(0xFF34C759),
      );
    } else if (isGrand) {
      centerIcon = const Text('🎁', style: TextStyle(fontSize: 12));
    } else if (isCurrentTarget) {
      centerIcon = const Text('🔥', style: TextStyle(fontSize: 12));
    } else {
      centerIcon = Icon(
        CupertinoIcons.lock_fill,
        size: 11,
        color: isDark ? Colors.white30 : Colors.black26,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: isCurrentTarget ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hari ke-X
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'H$dayNum',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCurrentTarget
                    ? const Color(0xFFFF9500)
                    : isGrand
                        ? const Color(0xFFFFD60A)
                        : isDark
                            ? Colors.white60
                            : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Icon
          centerIcon,
          const SizedBox(height: 3),
          // XP
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+$reward',
              style: TextStyle(
                fontSize: isGrand ? 9.5 : 9.0,
                fontWeight: isGrand || isCurrentTarget
                    ? FontWeight.w900
                    : FontWeight.w600,
                color: isGrand
                    ? const Color(0xFFFFD60A)
                    : isCurrentTarget
                        ? const Color(0xFFFF9500)
                        : isClaimed
                            ? const Color(0xFF34C759)
                            : isDark
                                ? Colors.white54
                                : Colors.black45,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
