import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/ylnime_extra_models.dart';
import '../anime_search_screen.dart';

/// Interactive, Esports-style 3D Stepped Podium for Duel Karakter Top 3.
/// Features Gold (1st), Silver (2nd), and Bronze (3rd) pedestals with avatars,
/// metallic borders, crowns, and animated rank badges.
class DuelPodiumWidget extends StatelessWidget {
  final List<PollingLeaderboardRow> leaderboard;
  final bool isDark;
  final bool isCompact;
  final ValueChanged<PollingLeaderboardRow>? onSelect;

  const DuelPodiumWidget({
    super.key,
    required this.leaderboard,
    required this.isDark,
    this.isCompact = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) return const SizedBox.shrink();

    final rank1 = leaderboard.isNotEmpty ? leaderboard[0] : null;
    final rank2 = leaderboard.length > 1 ? leaderboard[1] : null;
    final rank3 = leaderboard.length > 2 ? leaderboard[2] : null;

    if (rank1 == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 16, vertical: 8),
      padding: EdgeInsets.fromLTRB(12, isCompact ? 12 : 18, 12, 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.iosCardDark
            : AppColors.iosCardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.iosHairlineDark : AppColors.iosHairlineLight,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Trophy Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: isDark ? 0.22 : 0.18),
                      const Color(0xFFFF9500).withValues(alpha: isDark ? 0.15 : 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.45 : 0.55),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      'PODIUM JUARA DUEL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFFFFE082) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 16),

          // Podium Arena (Columns in order: 2nd (Silver), 1st (Gold), 3rd (Bronze))
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Subtle golden ambient spotlight behind the champion
              Positioned(
                bottom: 20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD700).withValues(alpha: isDark ? 0.18 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // The 3 Pedestals & Characters
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd Place (Silver) - Left
                  Expanded(
                    flex: 10,
                    child: rank2 != null
                        ? _buildPodiumSlot(
                            context: context,
                            row: rank2,
                            rank: 2,
                            avatarSize: isCompact ? 56 : 68,
                            pedestalHeight: isCompact ? 68 : 90,
                            pedestalColor: const Color(0xFF94A3B8),
                            gradientColors: [
                              const Color(0xFFE2E8F0),
                              const Color(0xFF94A3B8),
                              const Color(0xFF64748B),
                            ],
                            badgeIcon: '🥈',
                            badgeLabel: '#2',
                            badgeColor: const Color(0xFF94A3B8),
                            isChampion: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 6),

                  // 1st Place (Gold Champion) - Center
                  Expanded(
                    flex: 12,
                    child: _buildPodiumSlot(
                      context: context,
                      row: rank1,
                      rank: 1,
                      avatarSize: isCompact ? 72 : 86,
                      pedestalHeight: isCompact ? 96 : 124,
                      pedestalColor: const Color(0xFFFFD700),
                      gradientColors: [
                        const Color(0xFFFFE082),
                        const Color(0xFFFFB300),
                        const Color(0xFFFF8F00),
                      ],
                      badgeIcon: '👑',
                      badgeLabel: 'JUARA 1',
                      badgeColor: const Color(0xFFFFB300),
                      isChampion: true,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3rd Place (Bronze) - Right
                  Expanded(
                    flex: 10,
                    child: rank3 != null
                        ? _buildPodiumSlot(
                            context: context,
                            row: rank3,
                            rank: 3,
                            avatarSize: isCompact ? 52 : 62,
                            pedestalHeight: isCompact ? 48 : 66,
                            pedestalColor: const Color(0xFFCD7F32),
                            gradientColors: [
                              const Color(0xFFFDBA74),
                              const Color(0xFFD97706),
                              const Color(0xFF9A3412),
                            ],
                            badgeIcon: '🥉',
                            badgeLabel: '#3',
                            badgeColor: const Color(0xFFCD7F32),
                            isChampion: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),

          // Ground Base Bar tying pedestals together
          Container(
            height: 6,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  const Color(0xFFFFD700).withValues(alpha: 0.35),
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSlot({
    required BuildContext context,
    required PollingLeaderboardRow row,
    required int rank,
    required double avatarSize,
    required double pedestalHeight,
    required Color pedestalColor,
    required List<Color> gradientColors,
    required String badgeIcon,
    required String badgeLabel,
    required Color badgeColor,
    required bool isChampion,
  }) {
    final effectiveName = row.name.isNotEmpty ? row.name : 'Karakter';
    final hasScore = row.score != null && row.score!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        if (onSelect != null) {
          onSelect!(row);
        } else if (row.subtitle != null && row.subtitle!.isNotEmpty) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => AnimeSearchScreen(initialQuery: row.subtitle!),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating Crown / Badge above avatar
          if (isChampion) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDF00), Color(0xFFFF9500)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('👑', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 3),
                  Text(
                    'CHAMPION',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
              child: Text(
                '$badgeIcon $badgeLabel',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Avatar Frame with Metallic Glow
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: avatarSize + 6,
                height: avatarSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: pedestalColor.withValues(alpha: isChampion ? 0.45 : 0.25),
                      blurRadius: isChampion ? 14 : 8,
                      spreadRadius: isChampion ? 2 : 0,
                    ),
                  ],
                ),
              ),

              // Gradient Border Ring
              Container(
                width: avatarSize,
                height: avatarSize,
                padding: EdgeInsets.all(isChampion ? 3.0 : 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
                child: ClipOval(
                  child: row.img != null && row.img!.isNotEmpty
                      ? AppNetworkImage(
                          url: row.img!,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                        )
                      : Container(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: avatarSize * 0.5,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Character Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              effectiveName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isChampion ? 12.5 : 11.5,
                fontWeight: isChampion ? FontWeight.w800 : FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Origin anime / Subtitle
          if (row.subtitle != null && row.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 1.5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                row.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.iosTextTertiaryDark : AppColors.iosTextTertiaryLight,
                ),
              ),
            ),
          ],

          // Vote / Score micro-pill
          if (hasScore) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: pedestalColor.withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
              child: Text(
                '★ ${row.score}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706),
                ),
              ),
            ),
          ],

          SizedBox(height: isCompact ? 6 : 8),

          // 3D Stepped Pedestal Block
          Container(
            height: pedestalHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientColors[0].withValues(alpha: isDark ? 0.38 : 0.28),
                  gradientColors[1].withValues(alpha: isDark ? 0.20 : 0.14),
                  gradientColors[2].withValues(alpha: isDark ? 0.08 : 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                top: BorderSide(
                  color: gradientColors[0].withValues(alpha: isDark ? 0.85 : 0.95),
                  width: isChampion ? 2.5 : 1.8,
                ),
                left: BorderSide(
                  color: gradientColors[1].withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 0.5,
                ),
                right: BorderSide(
                  color: gradientColors[1].withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Stepped Rank Numeral
                Container(
                  width: isChampion ? 34 : 28,
                  height: isChampion ? 34 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pedestalColor.withValues(alpha: isChampion ? 0.45 : 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: isChampion ? 18 : 14,
                        fontWeight: FontWeight.w900,
                        color: rank == 2 ? const Color(0xFF1E293B) : (rank == 1 ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom reflective line
                Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        gradientColors[0].withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
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
}
