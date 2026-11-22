import 'package:flutter/foundation.dart';
import '../../community/data/forum_repository.dart';
import '../../community/data/models/forum_thread_model.dart';
import 'models/reel_model.dart';

class ReelsRepository {
  ReelsRepository._();
  static final ReelsRepository instance = ReelsRepository._();

  /// Fetch list of reels from Forum community video threads
  Future<ReelPagination> getReels({int page = 1, int limit = 10}) async {
    try {
      final videoThreads = await ForumRepository.instance.getVideoThreads();
      final allReels = videoThreads.map((t) => t.toReel()).toList();

      final startIndex = (page - 1) * limit;
      if (startIndex >= allReels.length) {
        return const ReelPagination(items: [], hasMore: false);
      }
      final endIndex = (startIndex + limit).clamp(0, allReels.length);
      final pagedItems = allReels.sublist(startIndex, endIndex);
      final hasMore = endIndex < allReels.length;

      return ReelPagination(items: pagedItems, hasMore: hasMore);
    } catch (e) {
      debugPrint('[ReelsRepository] Error fetching forum reels: $e');
      return const ReelPagination(items: [], hasMore: false);
    }
  }

  /// Fetch a single random reel from Forum community video threads
  Future<ReelModel?> getRandomReel() async {
    try {
      final videoThreads = await ForumRepository.instance.getVideoThreads();
      if (videoThreads.isNotEmpty) {
        final shuffled = List<ForumThreadModel>.from(videoThreads)..shuffle();
        return shuffled.first.toReel();
      }
    } catch (e) {
      debugPrint('[ReelsRepository] Error getting random forum reel: $e');
    }
    return null;
  }

  /// Like/unlike a reel directly in Forum repository
  Future<({bool success, bool isLiked, int likes})> toggleLike(String reelId) async {
    try {
      await ForumRepository.instance.toggleVote(reelId, 1);
      final thread = await ForumRepository.instance.getThreadById(reelId);
      if (thread != null) {
        return (
          success: true,
          isLiked: thread.userVote == 1,
          likes: thread.upvotes,
        );
      }
    } catch (e) {
      debugPrint('[ReelsRepository] Error toggling like: $e');
    }
    return (success: true, isLiked: true, likes: 1);
  }
}

