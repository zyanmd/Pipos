import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moko/core/config/api_config.dart';
import 'package:moko/features/anime/data/models/anime_model.dart';
import 'package:moko/features/anime/data/models/genre_role_model.dart';
import 'package:moko/features/profile/data/models/friendship_model.dart';

void main() {
  group('Genre Role Models', () {
    test('GenreRoleItem parses correctly and computes tier colors and labels', () {
      final json = {
        'id': 1,
        'genre': 'action',
        'genre_label': 'Action',
        'emoji': '⚔️',
        'color': '#FF5252',
        'role_name': 'Action Master',
        'role_key': 'action_gold',
        'role_tier': 'gold',
        'watch_count': 42,
        'unlocked_at': '2026-09-30T10:00:00.000000',
        'progress': {
          'next_tier': 'platinum',
          'next_name': 'Supreme Overlord',
          'next_min_count': 70,
          'current': 42,
          'needed': 28,
          'percent': 60.0,
        },
      };

      final role = GenreRoleItem.fromJson(json);

      expect(role.id, 1);
      expect(role.genre, 'action');
      expect(role.genreLabel, 'Action');
      expect(role.emoji, '⚔️');
      expect(role.roleName, 'Action Master');
      expect(role.roleTier, 'gold');
      expect(role.tierBadgeLabel, 'GOLD');
      expect(role.watchCount, 42);
      expect(role.progress?.nextName, 'Supreme Overlord');
      expect(role.progress?.needed, 28);
      expect(role.progress?.percent, 60.0);
    });

    test('UserGenreSummary parses summary data properly', () {
      final json = {
        'roles': [
          {
            'genre': 'isekai',
            'genre_label': 'Isekai',
            'emoji': '🌀',
            'color': '#29B6F6',
            'role_name': 'Isekai Overlord',
            'role_key': 'isekai_platinum',
            'role_tier': 'platinum',
            'watch_count': 85,
          }
        ],
        'stats': [
          {
            'genre': 'isekai',
            'genre_label': 'Isekai',
            'emoji': '🌀',
            'color': '#29B6F6',
            'watch_count': 85,
            'total_watch_time': 102000,
            'total_watch_time_minutes': 1700.0,
          }
        ],
        'top_genre': {
          'genre': 'isekai',
          'label': 'Isekai',
          'emoji': '🌀',
          'color': '#29B6F6',
          'watch_count': 85,
        },
        'total_genres_watched': 1,
        'has_roles': true,
      };

      final summary = UserGenreSummary.fromJson(json);

      expect(summary.hasRoles, true);
      expect(summary.roles.length, 1);
      expect(summary.roles.first.roleTier, 'platinum');
      expect(summary.roles.first.tierBadgeLabel, 'PLATINUM');
      expect(summary.topGenre?.label, 'Isekai');
      expect(summary.stats.length, 1);
      expect(summary.totalGenresWatched, 1);
    });

    test('GenreRoleCatalogItem parses tiers properly', () {
      final json = {
        'genre': 'comedy',
        'label': 'Comedy',
        'emoji': '😂',
        'color': '#FFD600',
        'tiers': [
          {'tier': 'platinum', 'min_count': 70, 'key': 'comedy_platinum', 'name': 'Laugh Emperor'},
          {'tier': 'gold', 'min_count': 35, 'key': 'comedy_gold', 'name': 'Gag Connoisseur'},
          {'tier': 'silver', 'min_count': 15, 'key': 'comedy_silver', 'name': 'Comedy Enthusiast'},
          {'tier': 'bronze', 'min_count': 5, 'key': 'comedy_bronze', 'name': 'Giggle Seeker'},
        ],
      };

      final item = GenreRoleCatalogItem.fromJson(json);

      expect(item.genre, 'comedy');
      expect(item.tiers.length, 4);
      expect(item.tiers.first.tier, 'platinum');
      expect(item.tiers.last.minCount, 5);
      expect(item.tiers.last.name, 'Giggle Seeker');
    });

    test('EpisodeCommentModel & EpisodeCommentUser correctly parses genre_role', () {
      final commentJson = {
        'id': 123,
        'content': 'Anime ini seru banget!',
        'user': {
          'id': 7,
          'username': 'zyann',
          'avatar': 'https://example.com/avatar.jpg',
          'genre_role': {
            'genre': 'action',
            'genre_label': 'Action',
            'emoji': '⚔️',
            'color': '#FF5252',
            'role_name': 'Action Master',
            'role_key': 'action_gold',
            'role_tier': 'gold',
            'watch_count': 42,
          },
        },
      };

      final comment = EpisodeCommentModel.fromJson(commentJson);

      expect(comment.id, 123);
      expect(comment.authorGenreRole, isNotNull);
      expect(comment.authorGenreRole?.genre, 'action');
      expect(comment.authorGenreRole?.roleName, 'Action Master');
      expect(comment.authorGenreRole?.roleTier, 'gold');
      expect(comment.authorGenreRole?.tierBadgeLabel, 'GOLD');
    });

    test('GenreUtils.sanitizeGenre cleans dirty genres from punctuation, commas, dots, and semicolons', () {
      expect(GenreUtils.sanitizeGenre('comedy,'), 'comedy');
      expect(GenreUtils.sanitizeGenre('Romance.'), 'romance');
      expect(GenreUtils.sanitizeGenre(' Action , '), 'action');
      expect(GenreUtils.sanitizeGenre('Sci-Fi,'), 'sci-fi');
      expect(GenreUtils.sanitizeGenre(',Action,'), 'action');
      expect(GenreUtils.sanitizeGenre('Comedy, '), 'comedy');
      expect(GenreUtils.sanitizeGenre('sci.fi'), 'sci-fi');
      expect(GenreUtils.sanitizeGenre('slice_of_life'), 'slice-of-life');
      expect(GenreUtils.sanitizeGenre('martial   arts'), 'martial-arts');
      expect(GenreUtils.sanitizeGenre(null), isNull);
      expect(GenreUtils.sanitizeGenre(''), isNull);
      expect(GenreUtils.sanitizeGenre(' ,;-- '), isNull);
    });

    test('AnimeDetailModel sanitizes dirty genre list properly', () {
      final detail = AnimeDetailModel.fromJson({
        'id': 'test-anime',
        'title': 'Test Anime',
        'genres': ['comedy,', 'Romance.', ' Action , '],
      });
      expect(detail.genres, ['comedy', 'romance', 'action']);
    });

    test('GenreRoleItem parses new fields: userId, tierWeight, isPrimary and typedef aliases work', () {
      final json = {
        'id': 10,
        'user_id': 99,
        'genre': 'action',
        'role_name': 'Action King',
        'role_key': 'action_gold',
        'role_tier': 'gold',
        'tier_weight': 3,
        'watch_count': 50,
        'is_primary': true,
        'color': '#FF0000',
        'progress': {
          'next_tier': 'platinum',
          'next_name': 'Action Overlord',
          'next_min_count': 70,
          'current': 50,
          'needed': 20,
          'percent': 71.4,
        },
      };

      final GenreRole role = GenreRole.fromJson(json);
      expect(role.id, 10);
      expect(role.userId, 99);
      expect(role.tierWeight, 3);
      expect(role.isPrimary, true);
      expect(role.progress, isA<RoleProgress>());
      expect(role.progress?.needed, 20);
    });

    test('UserGenreSummary primaryRole getter prioritizes isPrimary=true, falls back to first', () {
      final summaryWithPrimary = UserGenreSummary(
        roles: const [
          GenreRoleItem(
            id: 1,
            genre: 'romance',
            genreLabel: 'Romance',
            emoji: '💖',
            colorHex: '#FF69B4',
            roleName: 'Romance Fan',
            roleKey: 'romance_bronze',
            roleTier: 'bronze',
            isPrimary: false,
          ),
          GenreRoleItem(
            id: 2,
            genre: 'action',
            genreLabel: 'Action',
            emoji: '⚔️',
            colorHex: '#FF0000',
            roleName: 'Action Master',
            roleKey: 'action_gold',
            roleTier: 'gold',
            isPrimary: true,
          ),
        ],
      );
      expect(summaryWithPrimary.primaryRole?.genre, 'action');

      final summaryWithoutPrimary = UserGenreSummary(
        roles: const [
          GenreRoleItem(
            id: 1,
            genre: 'romance',
            genreLabel: 'Romance',
            emoji: '💖',
            colorHex: '#FF69B4',
            roleName: 'Romance Fan',
            roleKey: 'romance_bronze',
            roleTier: 'bronze',
            isPrimary: false,
          ),
        ],
      );
      expect(summaryWithoutPrimary.primaryRole?.genre, 'romance');

      const emptySummary = UserGenreSummary();
      expect(emptySummary.primaryRole, isNull);
    });

    test('GenreStatsItem formats watch time correctly with totalWatchTimeFormatted', () {
      const s1 = GenreStatsItem(
        genre: 'action',
        genreLabel: 'Action',
        emoji: '⚔️',
        colorHex: '#FF0000',
        totalWatchTime: 45,
      );
      expect(s1.totalWatchTimeFormatted, '45s');

      const s2 = GenreStatsItem(
        genre: 'comedy',
        genreLabel: 'Comedy',
        emoji: '😂',
        colorHex: '#FFD600',
        totalWatchTime: 150,
      );
      expect(s2.totalWatchTimeFormatted, '2m');

      const s3 = GenreStatsItem(
        genre: 'fantasy',
        genreLabel: 'Fantasy',
        emoji: '🧙',
        colorHex: '#9C27B0',
        totalWatchTime: 7320, // 2h 2m
      );
      expect(s3.totalWatchTimeFormatted, '2h 2m');
    });

    test('UserGenreSummary.empty() clears all roles and stats to reset state', () {
      final cleared = UserGenreSummary.empty();
      expect(cleared.roles, isEmpty);
      expect(cleared.stats, isEmpty);
      expect(cleared.hasRoles, false);
      expect(cleared.topGenre, isNull);
      expect(cleared.primaryRole, isNull);
      expect(cleared.totalGenresWatched, 0);
    });

    test('Public /ylnime/genre-roles/user/{username} response parses 1 primary role next to name', () {
      final publicResponseJson = {
        'has_roles': true,
        'roles': [
          {
            'color': '#eab308',
            'emoji': '😂',
            'genre': 'comedy',
            'genre_label': 'Comedy',
            'id': 1,
            'progress': {
              'current': 4,
              'needed': 6,
              'next_min_count': 10,
              'next_name': '😆 Geli Sedikit',
              'next_tier': 'silver',
              'percent': 40,
            },
            'role_key': 'comedy_newbie',
            'role_name': 'Comedy Newbie',
            'role_tier': 'bronze',
            'tier_weight': 1,
            'unlocked_at': '2026-09-30T14:07:58',
            'user_id': 3,
            'watch_count': 4,
          },
          {
            'color': '#ec4899',
            'emoji': '💕',
            'genre': 'romance',
            'genre_label': 'Romance',
            'id': 2,
            'progress': {
              'current': 4,
              'needed': 6,
              'next_min_count': 10,
              'next_name': '💖 Suka Ship Shipan',
              'next_tier': 'silver',
              'percent': 40,
            },
            'role_key': 'romance_newbie',
            'role_name': 'Romance Newbie',
            'role_tier': 'bronze',
            'tier_weight': 1,
            'unlocked_at': '2026-09-30T14:07:58',
            'user_id': 3,
            'watch_count': 4,
          }
        ],
        'stats': [
          {
            'created_at': '2026-09-30T14:07:57',
            'genre': 'comedy',
            'id': 3,
            'last_watched_at': '2026-09-30T08:41:02',
            'total_watch_time': 258,
            'total_watch_time_formatted': '4 menit 18 detik',
            'updated_at': '2026-09-30T14:07:57',
            'user_id': 3,
            'watch_count': 4,
          }
        ],
        'top_genre': {
          'color': '#eab308',
          'emoji': '😂',
          'genre': 'comedy',
          'label': 'Comedy',
          'watch_count': 4,
        },
        'total_genres_watched': 2,
        'user': {
          'avatar': 'avatars/A_20260916_233153_909047.jpg',
          'id': 3,
          'rank': 'Ronin II',
          'username': 'A',
        },
      };

      final summary = UserGenreSummary.fromJson(publicResponseJson);

      expect(summary.hasRoles, true);
      expect(summary.roles.length, 2);
      expect(summary.primaryRole, isNotNull);
      // Ensures ONLY 1 primary role is selected for display next to the username
      expect(summary.primaryRole?.roleName, 'Comedy Newbie');
      expect(summary.primaryRole?.emoji, '😂');
      expect(summary.primaryRole?.roleTier, 'bronze');
      expect(summary.primaryRole?.tierBadgeLabel, 'BRONZE');
      expect(summary.primaryRole?.watchCount, 4);

      // Verify formatted time from server
      expect(summary.stats.first.totalWatchTimeFormatted, '4 menit 18 detik');
    });

    test('ApiEndpoints ylnimeWatchHistoryProgress matches /ylnime/watch-history/progress', () {
      expect(ApiEndpoints.ylnimeWatchHistoryProgress, equals('/ylnime/watch-history/progress'));
    });

    test('6-tier system (wood, stone, bronze, silver, gold, platinum) calculates weights, colors, and badge labels', () {
      expect(GenreRoleItem.tierWeightFor('wood'), 1);
      expect(GenreRoleItem.tierWeightFor('stone'), 2);
      expect(GenreRoleItem.tierWeightFor('bronze'), 3);
      expect(GenreRoleItem.tierWeightFor('silver'), 4);
      expect(GenreRoleItem.tierWeightFor('gold'), 5);
      expect(GenreRoleItem.tierWeightFor('platinum'), 6);
      expect(GenreRoleItem.tierWeightFor('unknown'), 0);

      const woodRole = GenreRoleItem(
        genre: 'comedy',
        genreLabel: 'Comedy',
        emoji: '😂',
        colorHex: '#FFD600',
        roleName: 'Giggle Seeker',
        roleKey: 'comedy_wood',
        roleTier: 'wood',
      );
      expect(woodRole.tierBadgeLabel, 'WOOD');
      expect(woodRole.tierColor, const Color(0xFF8B5A2B));

      const stoneRole = GenreRoleItem(
        genre: 'action',
        genreLabel: 'Action',
        emoji: '⚔️',
        colorHex: '#FF5252',
        roleName: 'Brawler',
        roleKey: 'action_stone',
        roleTier: 'stone',
      );
      expect(stoneRole.tierBadgeLabel, 'STONE');
      expect(stoneRole.tierColor, const Color(0xFF78716C));

      const catalogWood = GenreRoleCatalogTier(
        tier: 'wood',
        minCount: 5,
        key: 'comedy_wood',
        name: 'Giggle Seeker',
      );
      expect(catalogWood.tierWeight, 1);
      expect(catalogWood.tierBadgeLabel, 'WOOD');
      expect(catalogWood.tierColor, const Color(0xFF8B5A2B));
    });

    test('defaultGenreRoleCatalog is populated with 38 genres and 6 tiers', () {
      expect(defaultGenreRoleCatalog.length, 38);
      final actionItem = defaultGenreRoleCatalog.firstWhere((e) => e.genre == 'action');
      expect(actionItem.tiers.length, 6);
      expect(
        actionItem.tiers.map((t) => t.tier).toList(),
        containsAll(['wood', 'stone', 'bronze', 'silver', 'gold', 'platinum']),
      );
    });

    test('GenreRoleCatalogItem parses live /ylnime/genre-roles/definitions response', () {
      final liveJson = {
        'color': '#ef4444',
        'emoji': '⚔️',
        'genre': 'action',
        'label': 'Action',
        'tiers': [
          {'key': 'action_platinum', 'min_count': 100, 'name': '🗿 Aura Infinite', 'tier': 'platinum'},
          {'key': 'action_gold', 'min_count': 75, 'name': '🔥 Crashout King', 'tier': 'gold'},
          {'key': 'action_silver', 'min_count': 50, 'name': '🥊 Hantam Kromo', 'tier': 'silver'},
          {'key': 'action_bronze', 'min_count': 30, 'name': '👀 Pengamat Tawuran', 'tier': 'bronze'},
          {'key': 'action_stone', 'min_count': 15, 'name': '🪨 Batu Beraksi', 'tier': 'stone'},
          {'key': 'action_wood', 'min_count': 5, 'name': '🪵 Kayu Bergetar', 'tier': 'wood'},
        ],
      };

      final parsed = GenreRoleCatalogItem.fromJson(liveJson);
      expect(parsed.genre, 'action');
      expect(parsed.label, 'Action');
      expect(parsed.emoji, '⚔️');
      expect(parsed.tiers.length, 6);
      expect(parsed.tiers.first.name, '🗿 Aura Infinite');
      expect(parsed.tiers.first.minCount, 100);
      expect(parsed.tiers.last.name, '🪵 Kayu Bergetar');
      expect(parsed.tiers.last.minCount, 5);
    });

    test('GenreRoleItem parses isPinned and copyWith updates correctly', () {
      final json = {
        'id': 10,
        'genre': 'comedy',
        'genre_label': 'Comedy',
        'emoji': '😂',
        'color': '#FFD600',
        'role_name': 'Laugh Emperor',
        'role_key': 'comedy_platinum',
        'role_tier': 'platinum',
        'is_pinned': true,
      };

      final item = GenreRoleItem.fromJson(json);
      expect(item.isPinned, true);
      expect(item.isPrimary, true);

      final unpinned = item.copyWith(isPinned: false);
      expect(unpinned.isPinned, false);
      expect(unpinned.id, 10);
    });

    test('UserGenreSummary prioritizes pinned role over higher tier unpinned role', () {
      final json = {
        'roles': [
          {
            'id': 1,
            'genre': 'action',
            'genre_label': 'Action',
            'emoji': '⚔️',
            'color': '#FF5252',
            'role_name': 'Action Platinum',
            'role_key': 'action_platinum',
            'role_tier': 'platinum',
            'watch_count': 100,
            'is_pinned': false,
          },
          {
            'id': 2,
            'genre': 'comedy',
            'genre_label': 'Comedy',
            'emoji': '😂',
            'color': '#FFD600',
            'role_name': 'Comedy Silver',
            'role_key': 'comedy_silver',
            'role_tier': 'silver',
            'watch_count': 50,
            'is_pinned': true,
          }
        ],
        'pinned_role': {
          'id': 2,
          'genre': 'comedy',
          'genre_label': 'Comedy',
          'emoji': '😂',
          'color': '#FFD600',
          'role_name': 'Comedy Silver',
          'role_key': 'comedy_silver',
          'role_tier': 'silver',
          'watch_count': 50,
          'is_pinned': true,
        },
        'has_roles': true,
      };

      final summary = UserGenreSummary.fromJson(json);
      expect(summary.pinnedRole, isNotNull);
      expect(summary.pinnedRole?.roleKey, 'comedy_silver');
      // Even though action is platinum, comedy_silver is pinned and therefore primary!
      expect(summary.primaryRole?.roleKey, 'comedy_silver');
    });

    test('ApiEndpoints includes genre-roles equip and unequip routes', () {
      expect(ApiEndpoints.ylnimeGenreRolePin, '/ylnime/genre-roles/pin');
      expect(ApiEndpoints.ylnimeGenreRolePinId(42), '/ylnime/genre-roles/pin/42');
      expect(ApiEndpoints.ylnimeGenreRoleEquip(42), '/ylnime/genre-roles/equip/42');
      expect(ApiEndpoints.ylnimeGenreRoleUnpin, '/ylnime/genre-roles/unpin');
      expect(ApiEndpoints.ylnimeGenreRoleUnequip, '/ylnime/genre-roles/unequip');
      expect(ApiEndpoints.ylnimeGenreRolePinned, '/ylnime/genre-roles/pinned');
    });
  });

  group('Friendship Model & Row Parsing', () {
    final rowGoergeAndA = {
      'id': 3,
      'sender_id': 3,
      'receiver_id': 263,
      'status': 'accepted',
      'sender': {
        'id': 3,
        'username': 'A',
        'avatar': 'avatars/A.webp',
        'verified_badge': 1,
        'bio': 'bio A',
      },
      'receiver': {
        'id': 263,
        'username': 'goerge',
        'avatar': 'default.jpg',
        'verified_badge': 0,
        'bio': 'bio goerge',
      },
    };

    final rowAAndRizx = {
      'id': 4,
      'sender_id': 3,
      'receiver_id': 208,
      'status': 'accepted',
      'sender': {
        'id': 3,
        'username': 'A',
        'avatar': 'avatars/A.webp',
        'verified_badge': 1,
      },
      'receiver': {
        'id': 208,
        'username': 'rizxwrld999',
        'avatar': 'avatars/rizx.jpg',
        'verified_badge': 0,
      },
    };

    test('resolves friend of target user correctly when target is receiver', () {
      final friend = FriendUserItem.fromFriendshipRow(
        rowGoergeAndA,
        targetUsername: 'goerge',
        currentUserId: 3,
      );
      expect(friend, isNotNull);
      expect(friend!.username, 'A');
      expect(friend.id, 3);
      expect(friend.verifiedBadge, isTrue);
    });

    test('resolves friend of target user correctly when target is sender', () {
      final friend = FriendUserItem.fromFriendshipRow(
        rowGoergeAndA,
        targetUsername: 'A',
        currentUserId: 3,
      );
      expect(friend, isNotNull);
      expect(friend!.username, 'goerge');
      expect(friend.id, 263);
    });

    test('does NOT leak unrelated friend when targetUser does not match row', () {
      // Row 4 is friendship between A and rizxwrld999. It does NOT involve goerge!
      final friend = FriendUserItem.fromFriendshipRow(
        rowAAndRizx,
        targetUsername: 'goerge',
        currentUserId: 3,
      );
      expect(friend, isNull);
    });

    test('resolves own friends when targetUsername is null (own profile)', () {
      final friend = FriendUserItem.fromFriendshipRow(
        rowGoergeAndA,
        currentUserId: 3,
      );
      expect(friend, isNotNull);
      expect(friend!.username, 'goerge');
    });

    test('parses other_user payload directly if provided', () {
      final directRow = {
        'id': 99,
        'other_user': {
          'id': 500,
          'username': 'random_friend',
          'avatar': 'avatar.jpg',
          'verified_badge': true,
        },
      };
      final friend = FriendUserItem.fromFriendshipRow(directRow);
      expect(friend, isNotNull);
      expect(friend!.username, 'random_friend');
      expect(friend.id, 500);
      expect(friend.verifiedBadge, isTrue);
    });
  });
}


