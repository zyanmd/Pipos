import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/bouncy_tap.dart';
import '../../../anime/data/models/anime_model.dart';
import '../../../anime/presentation/anime_episode_player.dart';
import '../../data/models/nobar_model.dart';
import '../nobar_hub_screen.dart';
import '../nobar_room_screen.dart';

/// Shows an iOS-style modal allowing user to choose between "Nonton Sendiri" or "Nobar Bersama"
Future<void> showWatchModeSheet({
  required BuildContext context,
  required String animeId,
  required String animeTitle,
  required String animeThumb,
  required String episodeId,
  required String episodeLabel,
  String? episodeUrl,
  Duration? startAt,
  List<EpisodeModel>? episodes,
  int? currentEpisodeIndex,
}) async {
  HapticFeedback.lightImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  final surfaceBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  final textColor = isDark ? Colors.white : Colors.black;
  final subtextColor = isDark ? Colors.white60 : Colors.black54;

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS Drag Handle
              Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header
              Row(
                children: [
                  if (animeThumb.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        animeThumb,
                        width: 44,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 56,
                          color: surfaceBg,
                          child: const Icon(CupertinoIcons.film, size: 20),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Mode Menonton',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$animeTitle • $episodeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Option 1: Nonton Sendiri
              BouncyTap(
                onTap: () => Navigator.pop(ctx, 'solo'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.play_circle_fill,
                          color: Color(0xFF007AFF),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nonton Sendiri',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Putar di pemutar anime pribadi dengan kontrol penuh',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        color: subtextColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: Nobar Bersama (Watch Party)
              BouncyTap(
                onTap: () => Navigator.pop(ctx, 'nobar'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF2E93).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2E93), Color(0xFFFF8E3C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_2_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Nobar Bersama Teman',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2E93).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Color(0xFFFF2E93),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Buat room nobar & nonton bareng realtime via chat & emoji',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        color: subtextColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Batal Button
              BouncyTap(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: subtextColor,
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

  if (choice == null || !context.mounted) return;

  if (choice == 'solo') {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AnimeEpisodePlayerScreen(
          episodeId: episodeId,
          episodeLabel: episodeLabel,
          episodeUrl: episodeUrl,
          animeId: animeId,
          animeTitle: animeTitle,
          animeThumb: animeThumb,
          startAt: startAt,
          episodes: episodes,
          currentEpisodeIndex: currentEpisodeIndex,
        ),
      ),
    );
  } else if (choice == 'nobar') {
    final room = await showModalBottomSheet<NobarRoomModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateNobarRoomSheet(
        initialAnimeId: animeId,
        initialAnimeTitle: animeTitle,
        initialAnimeThumb: animeThumb,
        initialEpisodeId: episodeId,
        initialEpisodeLabel: episodeLabel,
        initialEpisodeUrl: episodeUrl,
      ),
    );

    if (room != null && context.mounted) {
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => NobarRoomScreen(
            initialRoom: room,
            isHost: true,
          ),
        ),
      );
    }
  }
}
