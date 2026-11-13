class CharacterVoteItem {
  final int characterId;
  final String category;
  final String name;
  final String? nameKanji;
  final String imageUrl;
  final String? about;
  final String? animeTitle;
  final int votesCount;
  final bool userVoted;
  final int rankPosition;
  final double percentage;

  CharacterVoteItem({
    required this.characterId,
    required this.category,
    required this.name,
    this.nameKanji,
    required this.imageUrl,
    this.about,
    this.animeTitle,
    this.votesCount = 0,
    this.userVoted = false,
    this.rankPosition = 0,
    this.percentage = 0.0,
  });

  CharacterVoteItem copyWith({
    int? characterId,
    String? category,
    String? name,
    String? nameKanji,
    String? imageUrl,
    String? about,
    String? animeTitle,
    int? votesCount,
    bool? userVoted,
    int? rankPosition,
    double? percentage,
  }) {
    return CharacterVoteItem(
      characterId: characterId ?? this.characterId,
      category: category ?? this.category,
      name: name ?? this.name,
      nameKanji: nameKanji ?? this.nameKanji,
      imageUrl: imageUrl ?? this.imageUrl,
      about: about ?? this.about,
      animeTitle: animeTitle ?? this.animeTitle,
      votesCount: votesCount ?? this.votesCount,
      userVoted: userVoted ?? this.userVoted,
      rankPosition: rankPosition ?? this.rankPosition,
      percentage: percentage ?? this.percentage,
    );
  }

  factory CharacterVoteItem.fromJson(Map<String, dynamic> j) {
    return CharacterVoteItem(
      characterId: (j['character_id'] as num?)?.toInt() ?? 0,
      category: j['category']?.toString() ?? 'terkuat',
      name: j['name']?.toString() ?? 'Karakter',
      nameKanji: j['name_kanji']?.toString(),
      imageUrl: j['image_url']?.toString() ?? '',
      about: j['about']?.toString(),
      animeTitle: j['anime_title']?.toString(),
      votesCount: (j['votes_count'] as num?)?.toInt() ?? 0,
      userVoted: j['user_voted'] == true,
      rankPosition: (j['rank_position'] as num?)?.toInt() ?? 0,
      percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'category': category,
        'character_name': name,
        'character_image': imageUrl,
        'character_about': about,
        'anime_title': animeTitle,
      };
}

class JikanCharacterItem {
  final int malId;
  final String name;
  final String? nameKanji;
  final String imageUrl;
  final String? about;

  JikanCharacterItem({
    required this.malId,
    required this.name,
    this.nameKanji,
    required this.imageUrl,
    this.about,
  });

  factory JikanCharacterItem.fromJson(Map<String, dynamic> j) {
    String img = '';
    if (j['images'] is Map) {
      final images = j['images'] as Map;
      if (images['jpg'] is Map) {
        img = images['jpg']['image_url']?.toString() ?? '';
      } else if (images['webp'] is Map) {
        img = images['webp']['image_url']?.toString() ?? '';
      }
    }

    return JikanCharacterItem(
      malId: (j['mal_id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      nameKanji: j['name_kanji']?.toString(),
      imageUrl: img,
      about: j['about']?.toString(),
    );
  }
}
