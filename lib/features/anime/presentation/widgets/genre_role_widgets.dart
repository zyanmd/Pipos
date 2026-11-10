library;

import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/user_decor_resolver.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/anime_repository.dart';
import '../../data/models/genre_role_model.dart';

/// Badge role genre berukuran ringkas (cocok untuk profile header & kartu user)
class GenreRoleBadge extends StatelessWidget {
  final GenreRoleItem role;
  final bool showTier;
  final bool compact;
  final VoidCallback? onTap;
  final bool? isDark;

  const GenreRoleBadge({
    super.key,
    required this.role,
    this.showTier = true,
    this.compact = false,
    this.onTap,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final tierColor = role.tierColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap!();
        } else {
          showGenreRoleDetailModal(context, role, isDark: effectiveIsDark);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: effectiveIsDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(
            color: tierColor.withValues(alpha: effectiveIsDark ? 0.35 : 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (role.isPinned) ...[
              const Icon(
                CupertinoIcons.pin_fill,
                size: 9.5,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              role.emoji,
              style: TextStyle(fontSize: compact ? 11 : 13),
            ),
            const SizedBox(width: 4),
            Text(
              role.roleName,
              style: TextStyle(
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w700,
                color: effectiveIsDark ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.2,
              ),
            ),
            if (showTier) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.tierBadgeLabel,
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w800,
                    color: tierColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu Genre Mastery di layar Profil
class GenreMasteryCard extends StatelessWidget {
  final UserGenreSummary summary;
  final bool isDark;
  final VoidCallback? onOpenCatalog;
  final VoidCallback? onRecalculate;
  final VoidCallback? onResetRoles;

  const GenreMasteryCard({
    super.key,
    required this.summary,
    required this.isDark,
    this.onOpenCatalog,
    this.onRecalculate,
    this.onResetRoles,
  });

  @override
  Widget build(BuildContext context) {
    final roles = summary.roles;
    final topGenre = summary.topGenre;
    final hasRoles = summary.hasRoles && roles.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.flame_fill,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GENRE MASTERY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    Text(
                      hasRoles ? 'Gelar & Koleksi Role' : 'Spesialisasi Nonton',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
              if (onResetRoles != null && hasRoles) ...[
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.08),
                  onPressed: onResetRoles,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.trash,
                        size: 13,
                        color: Colors.redAccent.shade200,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent.shade200,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (onRecalculate != null) ...[
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  onPressed: onRecalculate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_2_circlepath,
                        size: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sync',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                borderRadius: BorderRadius.circular(14),
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (onOpenCatalog != null) {
                    onOpenCatalog!();
                  } else {
                    showGenreRoleCatalogModal(context, isDark: isDark);
                  }
                },
                child: Text(
                  'Katalog',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (hasRoles) ...[
            // Top Primary Role Card
            if (roles.isNotEmpty) _buildPrimaryRoleBanner(context, summary.primaryRole ?? roles.first),

            // Other Unlocked Roles
            if (roles.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                'Role Genre Lainnya (${roles.length - 1})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: roles
                    .where((r) => r != (summary.primaryRole ?? roles.first))
                    .map((r) => GenreRoleBadge(role: r))
                    .toList(),
              ),
            ],
          ] else ...[
            // Empty State
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        topGenre != null ? topGenre.emoji : '🎯',
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topGenre != null
                                  ? 'Genre Terbanyak: ${topGenre.label} (${topGenre.watchCount} ep)'
                                  : 'Buka Role Berdasarkan Tontonan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tonton 5 episode dari genre apa pun untuk membuka gelar & role pertama!',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (onRecalculate != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: onRecalculate,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.arrow_2_circlepath, size: 14, color: Color(0xFF6366F1)),
                            SizedBox(width: 6),
                            Text(
                              'Sync Genre Role',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
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
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryRoleBanner(BuildContext context, GenreRoleItem primaryRole) {
    final prog = primaryRole.progress;
    final tierColor = primaryRole.tierColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showGenreRoleDetailModal(
          context,
          primaryRole,
          allRoles: summary.roles,
          isDark: isDark,
          onEquipChanged: onRecalculate,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tierColor.withValues(alpha: isDark ? 0.16 : 0.10),
              isDark ? const Color(0xFF1E1E24) : Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tierColor.withValues(alpha: isDark ? 0.4 : 0.3),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  primaryRole.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              primaryRole.roleName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              primaryRole.tierBadgeLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: tierColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Spesialis ${primaryRole.genreLabel} • ${primaryRole.watchCount} episode ditonton',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),

            if (prog != null && prog.needed > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menuju ${prog.nextName ?? prog.nextTier?.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    '${prog.needed} ep lagi (${prog.percent.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: tierColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (prog.percent / 100.0).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal detail role genre saat diklik
/// Modal detail role genre saat diklik dengan fitur pasang/lepas gelar
void showGenreRoleDetailModal(
  BuildContext context,
  GenreRoleItem role, {
  List<GenreRoleItem>? allRoles,
  bool isDark = true,
  VoidCallback? onEquipChanged,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      GenreRoleItem currentRole = role;
      List<GenreRoleItem> currentAllRoles = List<GenreRoleItem>.from(allRoles ?? [role]);
      bool isActionLoading = false;

      return StatefulBuilder(
        builder: (context, setModalState) {
          final tierColor = currentRole.tierColor;
          final prog = currentRole.progress;
          final isPinned = currentRole.isPinned;

          return RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.5,
                  ),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag handle
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Large Emoji Avatar with tier glow
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPinned ? const Color(0xFFFFB300) : tierColor.withValues(alpha: 0.5),
                        width: isPinned ? 2.5 : 1.5,
                      ),
                      boxShadow: isPinned
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(
                          currentRole.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                        if (isPinned)
                          Positioned(
                            right: -6,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB300),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.pin_fill,
                                size: 10,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Role Title & Badges
                  Text(
                    currentRole.roleName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${currentRole.tierBadgeLabel} TIER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: tierColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        'Genre: ${currentRole.genreLabel}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      if (isPinned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.pin_fill,
                                size: 10,
                                color: Color(0xFFFFB300),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'DIPASANG',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFB300),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Stat Counter Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${currentRole.watchCount}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: tierColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Episode Ditonton',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 0.8,
                          height: 26,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        Column(
                          children: [
                            Text(
                              currentRole.unlockedAt != null
                                  ? '${currentRole.unlockedAt!.day}/${currentRole.unlockedAt!.month}/${currentRole.unlockedAt!.year}'
                                  : 'Aktif',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Terbuka Sejak',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Progression Box
                  if (prog != null && prog.needed > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tier Selanjutnya: ${prog.nextName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                '${prog.current} / ${prog.nextMinCount} ep',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tierColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (prog.percent / 100.0).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tonton ${prog.needed} episode ${currentRole.genreLabel} lagi untuk naik ke ${prog.nextName}!',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Other Unlocked Roles in Collection
                  if (currentAllRoles.length > 1) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Koleksi Role Anda (${currentAllRoles.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: currentAllRoles.map((r) {
                        final isCurrent = r.roleKey == currentRole.roleKey;
                        return GenreRoleBadge(
                          role: r,
                          compact: true,
                          onTap: isCurrent
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() {
                                    currentRole = r;
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 🔥 EQUIP / UNEQUIP BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: isPinned
                          ? const Color(0xFFFFB300).withValues(alpha: isDark ? 0.20 : 0.14)
                          : tierColor.withValues(alpha: isDark ? 0.24 : 0.16),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: isActionLoading
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              setModalState(() => isActionLoading = true);

                              if (isPinned) {
                                // UNEQUIP / LEPAS GELAR
                                final ok = await AnimeRepository.instance.unequipGenreRole();
                                if (!ctx.mounted) return;
                                setModalState(() {
                                  isActionLoading = false;
                                  if (ok) {
                                    currentRole = currentRole.copyWith(isPinned: false);
                                    currentAllRoles = currentAllRoles
                                        .map((item) => item.copyWith(isPinned: false))
                                        .toList();
                                  }
                                });
                                if (ok) {
                                  try {
                                    final authUser = Provider.of<AuthProvider>(context, listen: false).user;
                                    if (authUser != null && authUser.username.isNotEmpty) {
                                      UserDecorResolver.instance.register(
                                        username: authUser.username,
                                        clearGenreRole: true,
                                      );
                                    }
                                  } catch (_) {}
                                  HapticFeedback.mediumImpact();
                                  onEquipChanged?.call();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Gelar dilepas. Profil otomatis memakai tier tertinggi.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  HapticFeedback.heavyImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Gagal melepas gelar. Periksa koneksi internet atau server.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } else {
                                // EQUIP / PASANG GELAR
                                final ok = await AnimeRepository.instance.equipGenreRole(
                                  currentRole.id ?? 0,
                                  genre: currentRole.genre,
                                  roleItem: currentRole,
                                );
                                if (!ctx.mounted) return;
                                setModalState(() {
                                  isActionLoading = false;
                                  if (ok) {
                                    currentRole = currentRole.copyWith(isPinned: true);
                                    currentAllRoles = currentAllRoles
                                        .map((item) => item.copyWith(
                                              isPinned: item.roleKey == currentRole.roleKey,
                                            ),)
                                        .toList();
                                  }
                                });
                                if (ok) {
                                  try {
                                    final authUser = Provider.of<AuthProvider>(context, listen: false).user;
                                    if (authUser != null && authUser.username.isNotEmpty) {
                                      UserDecorResolver.instance.register(
                                        username: authUser.username,
                                        genreRole: currentRole,
                                      );
                                    }
                                  } catch (_) {}
                                  HapticFeedback.mediumImpact();
                                  onEquipChanged?.call();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gelar "${currentRole.roleName}" berhasil dipasang di profil!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  HapticFeedback.heavyImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal memasang gelar "${currentRole.roleName}". Coba sesaat lagi.'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isActionLoading)
                            const CupertinoActivityIndicator(radius: 8)
                          else ...[
                            Icon(
                              isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
                              size: 15,
                              color: isPinned ? const Color(0xFFFFB300) : tierColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPinned ? 'Lepas Gelar Ini (Gunakan Otomatis)' : 'Pasang Gelar Ini di Profil',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isPinned ? const Color(0xFFFFB300) : tierColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Bottom Action Buttons: Katalog Gelar & Tutup
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showGenreRoleCatalogModal(context, isDark: isDark);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.square_grid_2x2, size: 14, color: Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Text(
                                'Katalog Gelar',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      );
    },
  );
}

/// Modal Katalog Semua Role Genre & Tier
void showGenreRoleCatalogModal(BuildContext context, {bool isDark = true}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RepaintBoundary(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              // Header & Drag handle
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.sparkles,
                      size: 20,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Katalog Role Genre',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            'Daftar role dan batas episode tiap tier',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
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

              // Content FutureBuilder
              Expanded(
                child: FutureBuilder<List<GenreRoleCatalogItem>>(
                  future: AnimeRepository.instance.getGenreRolesCatalog(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final bool isFallback = snapshot.hasError ||
                        snapshot.data == null ||
                        snapshot.data!.isEmpty ||
                        identical(snapshot.data, defaultGenreRoleCatalog);
                    final catalog = (snapshot.data != null && snapshot.data!.isNotEmpty)
                        ? snapshot.data!
                        : defaultGenreRoleCatalog;

                    return ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.paddingOf(context).bottom),
                      itemCount: catalog.length + (isFallback ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) {
                        if (isFallback && i == 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.info_circle_fill,
                                  size: 16,
                                  color: Color(0xFFFF9500),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Katalog Cadangan Aktif: Menampilkan daftar gelar bawaan aplikasi.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final item = catalog[isFallback ? i - 1 : i];
                        return _buildCatalogGenreCard(item, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

Widget _buildCatalogGenreCard(GenreRoleCatalogItem item, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white12 : Colors.black12,
        width: 0.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: item.tiers.map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.tierColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t.tier.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: t.tierColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '${t.minCount} ep',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}
