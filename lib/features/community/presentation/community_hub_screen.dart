import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'forum_feed_screen.dart';

/// Community Hub Screen:
/// Dialihkan ke Forum Diskusi Komunitas (Reddit / MyAnimeList Style)
class CommunityHubScreen extends StatelessWidget {
  final int initialTab;

  const CommunityHubScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return const ForumFeedScreen();
  }
}
