import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/character_vote_model.dart';

class CharacterVoteRepository {
  CharacterVoteRepository._();
  static final CharacterVoteRepository instance = CharacterVoteRepository._();

  final Dio _directDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {'User-Agent': 'Animeverse/1.2'},
    ),
  );

  /// Mengambil daftar karakter teratas berdasarkan kategori (terkuat, tercantik, terganteng)
  Future<List<CharacterVoteItem>> getLeaderboard(String category) async {
    try {
      final response = await ApiClient.instance.get(
        ApiConfig.characterVoteLeaderboard(category),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final raw = response.data['characters'] as List? ?? [];
        return raw
            .whereType<Map>()
            .map((item) => CharacterVoteItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Memberikan vote atau membatalkan vote pada suatu karakter
  Future<Map<String, dynamic>?> voteCharacter({
    required String category,
    required CharacterVoteItem character,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiConfig.characterVoteAction,
        data: {
          'category': category,
          'character_id': character.characterId,
          'character_name': character.name,
          'character_image': character.imageUrl,
          'character_about': character.about,
          'anime_title': character.animeTitle,
        },
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        return Map<String, dynamic>.from(e.response!.data as Map);
      }
    }
    return null;
  }

  /// Mencari karakter menggunakan API Jikan.moe (MyAnimeList) dengan proxy fallback
  Future<List<JikanCharacterItem>> searchJikanCharacters(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    // 1. Coba melalui backend proxy kita
    try {
      final response = await ApiClient.instance.get(
        ApiConfig.characterVoteSearch(clean),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final list = response.data['data'] as List? ?? [];
        if (list.isNotEmpty) {
          return list
              .whereType<Map>()
              .map((item) => JikanCharacterItem.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {}

    // 2. Direct fallback ke api.jikan.moe jika proxy backend offline
    try {
      final directResp = await _directDio.get(
        'https://api.jikan.moe/v4/characters',
        queryParameters: {
          'q': clean,
          'limit': 20,
        },
      );
      if (directResp.statusCode == 200 && directResp.data is Map) {
        final list = directResp.data['data'] as List? ?? [];
        return list
            .whereType<Map>()
            .map((item) => JikanCharacterItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}

    return [];
  }
}
