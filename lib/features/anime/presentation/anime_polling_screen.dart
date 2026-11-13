import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../character_vote/presentation/character_vote_screen.dart';

/// Polling & Vote Karakter Screen
/// Integrates Jikan.moe API & Apple HIG Leaderboard
class AnimePollingScreen extends StatelessWidget {
  final String? initialCategory;
  const AnimePollingScreen({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context) {
    String cat = 'tercantik';
    final raw = (initialCategory ?? '').toLowerCase();
    if (raw == 'kuat' || raw == 'terkuat') {
      cat = 'terkuat';
    } else if (raw == 'tampan' || raw == 'ganteng' || raw == 'terganteng') {
      cat = 'terganteng';
    }
    return CharacterVoteScreen(initialCategory: cat);
  }
}
