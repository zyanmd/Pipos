import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/anime/data/anime_repository.dart';
import '../../features/anime/data/models/anime_model.dart';
import '../../features/avatar_decoration/data/avatar_decoration_repository.dart';
import '../../features/avatar_decoration/data/models/avatar_decoration_model.dart';
import '../../features/comic/data/comic_repository.dart';
import '../../features/comic/data/models/comic_model.dart';
import '../../features/novel/data/novel_repository.dart';
import '../../features/novel/data/models/novel_model.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../core/services/adult_content_service.dart';

enum AiResultType {
  anime,
  comic,
  novel,
  frame,
  name,
  profileAction,
  chat,
}

class AiProfileChanges {
  final String? username;
  final String? displayName;
  final String? bio;
  final String? frameCode;
  final String? frameName;
  final String? profileFont;
  final String? profileFontName;
  final String? theme; // 'dark', 'light', 'system'
  final bool? is18Enabled;

  const AiProfileChanges({
    this.username,
    this.displayName,
    this.bio,
    this.frameCode,
    this.frameName,
    this.profileFont,
    this.profileFontName,
    this.theme,
    this.is18Enabled,
  });

  bool get hasAnyChange =>
      (username != null && username!.isNotEmpty) ||
      (displayName != null && displayName!.isNotEmpty) ||
      (bio != null && bio!.isNotEmpty) ||
      (frameCode != null && frameCode!.isNotEmpty) ||
      (profileFont != null && profileFont!.isNotEmpty) ||
      (theme != null && theme!.isNotEmpty) ||
      (is18Enabled != null);
}

class AiNameSuggestion {
  final String name;
  final String bio;
  final String theme;
  final String reason;

  const AiNameSuggestion({
    required this.name,
    required this.bio,
    required this.theme,
    required this.reason,
  });
}

class AiFrameRecommendation {
  final AvatarDecorationModel decoration;
  final String reason;

  const AiFrameRecommendation({
    required this.decoration,
    required this.reason,
  });
}

class AiAnimeSearchResult {
  final String query;
  final String explanation;
  final List<AnimeModel> animeList;
  final List<String> suggestedTags;
  final String rawResponse;

  const AiAnimeSearchResult({
    required this.query,
    required this.explanation,
    required this.animeList,
    this.suggestedTags = const [],
    required this.rawResponse,
  });
}

class AiUniversalResult {
  final AiResultType type;
  final String query;
  final String explanation;
  final List<AnimeModel> animeList;
  final List<ComicModel> comicList;
  final List<NovelItemModel> novelList;
  final List<AiFrameRecommendation> frameList;
  final List<AiNameSuggestion> nameList;
  final AiProfileChanges? profileChanges;
  final List<String> suggestedTags;
  final String rawResponse;

  const AiUniversalResult({
    required this.type,
    required this.query,
    required this.explanation,
    this.animeList = const [],
    this.comicList = const [],
    this.novelList = const [],
    this.frameList = const [],
    this.nameList = const [],
    this.profileChanges,
    this.suggestedTags = const [],
    required this.rawResponse,
  });
}

class AiAnimeService {
  AiAnimeService._();
  static final AiAnimeService instance = AiAnimeService._();

  static const String defaultBaseUrl = 'https://my.vpsmurah.co.id/api/v1';
  static const String defaultApiKey = 'sk-vps-0zj85rm7hgbfha9w8z0pmhzc7ygfivjcm2l5n8vb';

  /// Model yang diwajibkan oleh pengguna: gemini-38
  static const String defaultModel = 'gemini-38';

  static const String _kAiApiKey = 'vps_ai_api_key';
  static const String _kAiBaseUrl = 'vps_ai_base_url';

  String? _cachedApiKey;
  String? _cachedBaseUrl;

  Future<String> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAiApiKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _cachedApiKey = saved.trim();
      return _cachedApiKey!;
    }
    _cachedApiKey = defaultApiKey;
    return defaultApiKey;
  }

  Future<void> setApiKey(String key) async {
    final clean = key.trim();
    _cachedApiKey = clean.isNotEmpty ? clean : defaultApiKey;
    final prefs = await SharedPreferences.getInstance();
    if (clean.isNotEmpty) {
      await prefs.setString(_kAiApiKey, clean);
    } else {
      await prefs.remove(_kAiApiKey);
    }
  }

  Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAiBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      var clean = saved.trim();
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      _cachedBaseUrl = clean;
      return clean;
    }
    _cachedBaseUrl = defaultBaseUrl;
    return defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _cachedBaseUrl = clean.isNotEmpty ? clean : defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    if (clean.isNotEmpty) {
      await prefs.setString(_kAiBaseUrl, clean);
    } else {
      await prefs.remove(_kAiBaseUrl);
    }
  }

  Future<Dio> _getDio() async {
    final apiKey = await getApiKey();
    final baseUrl = await getBaseUrl();

    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Verifikasi koneksi dan ketersediaan model gemini-38
  Future<bool> testConnection() async {
    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': 'Halo, jawab dalam 1 kata: OK.'},
          ],
          'temperature': 0.1,
          'stream': false,
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AiAnimeService] Test connection failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNIVERSAL AI COMMAND PROCESSOR (ANIME, KOMIK, NOVEL, BINGKAI, UBAH NAMA, FOTO, GANTI SEMUA)
  // ─────────────────────────────────────────────────────────────────────────

  /// Proses perintah kustomisasi komprehensif (Username, Nama, Bio, Bingkai, Font, Tema, 18+, Ganti Semuanya)
  Future<AiUniversalResult> processProfileAndCustomizationCommand(String prompt) async {
    final myUser = AuthProvider.instance.user;
    final currentUsername = myUser?.username ?? 'user';
    final currentDisplayName = myUser?.displayName ?? currentUsername;
    final currentBio = myUser?.bio ?? '';

    final sysPrompt = '''
Kamu adalah Moko AI, asisten personal super cerdas Animeverse.
Pengguna memberikan perintah untuk mengubah profil / username / nama / bio / bingkai avatar / font / tema aplikasi / pengaturan lainnya:
"$prompt"

Profil Pengguna Saat Ini:
- Username: @$currentUsername
- Display Name: $currentDisplayName
- Bio: "$currentBio"

Katalog Kode Bingkai Discord Animeverse:
ki_energy, dragon_balls, cyber_katana, neon_cat_hoodie, kitsune, spirit_blossom_springs, flaming_sword, malefic_crown, deaths_edge, ryu, oni_mask, sakura_warrior, hologram_dragon, port_of_soul, mirage_void, rumbling, mecha_break, black_hole, astro_helmet, omen_cowl, mokoko, infinite_swirl, shenron

Katalog Font Profil:
orbitron, cinzel, chakra_petch, press_start, japanese_style, bangers, medieval, monospace

Petunjuk Analisis:
1. "username": Jika pengguna meminta ganti username atau ganti semua, berikan usulan/pilihan username baru (huruf kecil semua, 3-20 karakter, tanpa spasi, hanya alfabet/angka/garis bawah, misal: kage_shadow, raihan_kun). Jika tidak diminta dan bukan ganti semua, kosongkan (null).
2. "display_name": Jika pengguna meminta ganti nama atau ganti semua, berikan nama tampilan keren. Jika tidak, kosongkan.
3. "bio": Jika pengguna meminta ganti bio atau ganti semua, buatkan bio bergaya wibu/anime/gamer estetis. Jika tidak, kosongkan.
4. "frame_code": Jika pengguna meminta bingkai atau ganti semua, pilih 1 kode bingkai paling pas dari katalog di atas. Jika tidak, kosongkan.
5. "profile_font": Jika pengguna meminta font atau ganti semua, pilih font dari katalog di atas. Jika tidak, kosongkan.
6. "theme": Jika pengguna meminta tema gelap ("dark") atau terang ("light") atau jika ganti semua pilih "dark". Jika tidak diminta, kosongkan.
7. "is_18_enabled": true/false hanya jika pengguna meminta aktifkan/nonaktifkan konten 18+. Jika tidak, kosongkan (null).
8. "explanation": Tulis pesan ramah dalam Bahasa Indonesia menjelaskan perubahan profil yang disiapkan Moko AI.

Format Respon WAJIB JSON:
```json
{
  "username": "kage_shadow",
  "display_name": "Kage Shadow",
  "bio": "Berjalan dalam bayang-bayang kegelapan 🗡️",
  "frame_code": "cyber_katana",
  "profile_font": "orbitron",
  "theme": "dark",
  "is_18_enabled": null,
  "explanation": "Moko AI telah menyiapkan kustomisasi profil lengkap sesuai permintaanmu!"
}
```
''';

    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': sysPrompt},
          ],
          'temperature': 0.7,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      String? username;
      String? displayName;
      String? bio;
      String? frameCode;
      String? profileFont;
      String? theme;
      bool? is18Enabled;
      String explanation = '';

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final parsed = jsonDecode(jsonMatch.group(1)!);
          if (parsed is Map) {
            username = parsed['username']?.toString().trim().replaceAll('@', '').toLowerCase();
            displayName = parsed['display_name']?.toString().trim();
            bio = parsed['bio']?.toString().trim();
            frameCode = parsed['frame_code']?.toString().trim();
            profileFont = parsed['profile_font']?.toString().trim();
            theme = parsed['theme']?.toString().trim();
            if (parsed['is_18_enabled'] != null) {
              is18Enabled = parsed['is_18_enabled'] == true;
            }
            explanation = parsed['explanation']?.toString() ?? '';
          }
        } catch (_) {}
      }

      var cleanExp = content.replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '').trim();
      if (cleanExp.isEmpty && explanation.isNotEmpty) cleanExp = explanation;

      final List<AiFrameRecommendation> frames = [];
      String? frameName;
      if (frameCode != null && frameCode.isNotEmpty) {
        frameName = AvatarDecorationRepository.formatName(frameCode);
        final url = 'https://discord-decoration.art/decorations/$frameCode.png';
        frames.add(
          AiFrameRecommendation(
            decoration: AvatarDecorationModel(
              id: 0,
              code: frameCode,
              name: frameName,
              category: 'anime',
              imageUrl: url,
              thumbnailUrl: url,
              isActive: true,
              isOwned: true,
            ),
            reason: 'Dipilihkan khusus oleh Moko AI untuk melengkapi tema profil barumu.',
          ),
        );
      }

      final List<AiNameSuggestion> names = [];
      if (displayName != null && displayName.isNotEmpty) {
        names.add(
          AiNameSuggestion(
            name: displayName,
            bio: bio ?? 'Pencinta anime sejati 🌸',
            theme: 'Pilihan AI',
            reason: 'Cocok dengan kustomisasi yang kamu minta.',
          ),
        );
      }

      final changes = AiProfileChanges(
        username: username,
        displayName: displayName,
        bio: bio,
        frameCode: frameCode,
        frameName: frameName,
        profileFont: profileFont,
        profileFontName: profileFont,
        theme: theme,
        is18Enabled: is18Enabled,
      );

      return AiUniversalResult(
        type: AiResultType.profileAction,
        query: prompt,
        explanation: cleanExp.isNotEmpty ? cleanExp : 'Berikut rincian kustomisasi yang disiapkan Moko AI:',
        profileChanges: changes,
        frameList: frames,
        nameList: names,
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] processProfileAndCustomizationCommand error: $e');
      return AiUniversalResult(
        type: AiResultType.profileAction,
        query: prompt,
        explanation: 'Moko AI siap mengubah profilmu. Silakan pilih elemen yang ingin kamu perbarui:',
        profileChanges: AiProfileChanges(
          username: prompt.toLowerCase().contains('user') ? 'kage_master' : null,
          displayName: 'Kage Master',
          bio: 'Penguasa bayangan Animeverse ⚔️',
          frameCode: 'cyber_katana',
          frameName: 'Cyber Katana',
          profileFont: 'orbitron',
          theme: 'dark',
        ),
        rawResponse: '',
      );
    }
  }

  Future<AiUniversalResult> processUniversalCommand(String prompt, {String? imageBase64}) async {
    // 0. Jika ada foto/gambar yang diunggah, proses dengan vision model
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      return processImageWithAi(imageBase64: imageBase64, prompt: prompt);
    }

    final q = prompt.trim();
    if (q.isEmpty) {
      return const AiUniversalResult(
        type: AiResultType.chat,
        query: '',
        explanation: 'Ada yang bisa Moko AI bantu? Kamu bisa minta saran bingkai avatar keren, ubah nama, unggah foto untuk dianalisis, atau cari anime, komik, dan novel.',
        rawResponse: '',
      );
    }

    final lower = q.toLowerCase();

    // 1. Deteksi Perintah Profil, Username, Ganti Semuanya, Bingkai, Nama, Font, Bio, Tema
    final isProfileOrCustomization = lower.contains('username') ||
        lower.contains('ganti semua') ||
        lower.contains('ubah semua') ||
        lower.contains('ganti semuanya') ||
        lower.contains('ubah semuanya') ||
        (lower.contains('semua') && (lower.contains('ganti') || lower.contains('ubah') || lower.contains('profil'))) ||
        lower.contains('profil') ||
        lower.contains('profile') ||
        lower.contains('tema') ||
        lower.contains('dark mode') ||
        lower.contains('mode gelap') ||
        lower.contains('mode terang') ||
        lower.contains('font') ||
        lower.contains('bio') ||
        lower.contains('18+') ||
        lower.contains('ubah nama') ||
        lower.contains('ganti nama') ||
        lower.contains('saran nama') ||
        lower.contains('nama keren') ||
        lower.contains('nama wibu') ||
        lower.contains('bingkai') ||
        lower.contains('frame') ||
        lower.contains('dekorasi');

    if (isProfileOrCustomization) {
      return processProfileAndCustomizationCommand(q);
    }

    // 3. Deteksi Perintah Cari Komik / Manga / Manhwa
    if (lower.contains('komik') ||
        lower.contains('manga') ||
        lower.contains('manhwa') ||
        lower.contains('manhua') ||
        lower.contains('baca chapter')) {
      final comics = await searchComicsWithAi(q);
      return AiUniversalResult(
        type: AiResultType.comic,
        query: q,
        explanation: comics.explanation,
        comicList: comics.comicList,
        suggestedTags: comics.suggestedTags,
        rawResponse: comics.rawResponse,
      );
    }

    // 4. Deteksi Perintah Cari Novel / Light Novel / Web Novel
    if (lower.contains('novel') ||
        lower.contains('light novel') ||
        lower.contains('web novel') ||
        lower.contains('webnovel') ||
        lower.contains('baca novel') ||
        lower.contains('cerita novel') ||
        lower.contains('rekomendasi ln') ||
        lower.contains('rekomendasi wn')) {
      final novels = await searchNovelsWithAi(q);
      return AiUniversalResult(
        type: AiResultType.novel,
        query: q,
        explanation: novels.explanation,
        novelList: novels.novelList,
        suggestedTags: novels.suggestedTags,
        rawResponse: novels.rawResponse,
      );
    }

    // 5. Default: Pencarian Anime Komprehensif
    final animeRes = await searchWithAi(q);
    return AiUniversalResult(
      type: AiResultType.anime,
      query: q,
      explanation: animeRes.explanation,
      animeList: animeRes.animeList,
      suggestedTags: animeRes.suggestedTags,
      rawResponse: animeRes.rawResponse,
    );
  }

  /// Fitur Analisis Gambar & Foto menggunakan Multimodal Vision
  Future<AiUniversalResult> processImageWithAi({
    required String imageBase64,
    String? prompt,
  }) async {
    final userPrompt = (prompt != null && prompt.trim().isNotEmpty)
        ? prompt.trim()
        : 'Analisis foto/gambar ini dengan teliti, kenali karakternya, anime/manga-nya, atau vibe-nya, lalu carikan konten yang ada di aplikasi.';

    const systemPrompt = '''
Kamu adalah Moko AI, asisten pintar Animeverse.
Tugasmu:
1. Analisis gambar dengan teliti:
   - Jika ini adalah anime/manga/manhwa/karakter: identifikasi judul anime, nama karakter, studio, atau kemiripannya.
   - Jika ini foto selfie/avatar/estetik: analisis warna dominan, tema, dan gaya anime yang cocok.
2. Tulis penjelasan ramah dan detail dalam Bahasa Indonesia (1-2 paragraf).
3. WAJIB di akhir respon sertakan blok JSON:
```json
{
  "explanation": "Penjelasan analisismu...",
  "detected_anime_titles": ["Judul Anime 1", "Judul Anime 2"],
  "detected_comic_titles": ["Judul Komik/Manga 1"],
  "detected_novel_titles": ["Judul Light Novel/Web Novel 1"],
  "recommended_frame_codes": ["ki_energy", "cyber_katana", "kitsune", "dragon_balls"],
  "suggested_names": ["Nama 1", "Nama 2"]
}
```
''';

    try {
      final dio = await _getDio();
      final imageUrl = imageBase64.startsWith('data:')
          ? imageBase64
          : 'data:image/jpeg;base64,$imageBase64';

      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': userPrompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': imageUrl},
                },
              ],
            },
          ],
          'temperature': 0.7,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      List<String> animeTitles = [];
      List<String> comicTitles = [];
      List<String> novelTitles = [];
      List<String> frameCodes = [];
      List<String> nameList = [];
      String explanation = '';

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final parsed = jsonDecode(jsonMatch.group(1)!);
          if (parsed is Map) {
            if (parsed['detected_anime_titles'] is List) {
              animeTitles = (parsed['detected_anime_titles'] as List).map((e) => e.toString().trim()).toList();
            }
            if (parsed['detected_comic_titles'] is List) {
              comicTitles = (parsed['detected_comic_titles'] as List).map((e) => e.toString().trim()).toList();
            }
            if (parsed['detected_novel_titles'] is List) {
              novelTitles = (parsed['detected_novel_titles'] as List).map((e) => e.toString().trim()).toList();
            }
            if (parsed['recommended_frame_codes'] is List) {
              frameCodes = (parsed['recommended_frame_codes'] as List).map((e) => e.toString().trim()).toList();
            }
            if (parsed['suggested_names'] is List) {
              nameList = (parsed['suggested_names'] as List).map((e) => e.toString().trim()).toList();
            }
            explanation = parsed['explanation']?.toString() ?? '';
          }
        } catch (_) {}
      }

      var cleanExp = content.replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '').trim();
      if (cleanExp.isEmpty && explanation.isNotEmpty) cleanExp = explanation;

      // Ambil data HANYA yang ada di database / scraper API
      final Map<String, AnimeModel> uniqueAnime = {};
      final animeRepo = AnimeRepository.instance;
      for (final t in animeTitles) {
        try {
          final list = await animeRepo.search(t);
          for (final a in list) {
            uniqueAnime[a.id] = a;
          }
        } catch (_) {}
      }

      final Map<String, ComicModel> uniqueComic = {};
      final comicRepo = ComicRepository.instance;
      for (final t in comicTitles) {
        try {
          final list = await comicRepo.search(t);
          for (final c in list) {
            uniqueComic[c.slug] = c;
          }
        } catch (_) {}
      }

      final Map<String, NovelItemModel> uniqueNovel = {};
      final novelRepo = NovelRepository.instance;
      for (final t in novelTitles) {
        try {
          final list = await novelRepo.searchNovels(t);
          for (final n in list) {
            uniqueNovel[n.slug] = n;
          }
        } catch (_) {}
      }

      final List<AiFrameRecommendation> frames = [];
      for (final code in frameCodes) {
        final name = AvatarDecorationRepository.formatName(code);
        final url = 'https://discord-decoration.art/decorations/$code.png';
        frames.add(
          AiFrameRecommendation(
            decoration: AvatarDecorationModel(
              id: 0,
              code: code,
              name: name,
              category: 'anime',
              imageUrl: url,
              thumbnailUrl: url,
              isActive: true,
              isOwned: true,
            ),
            reason: 'Cocok dengan vibe dan visual foto yang kamu unggah.',
          ),
        );
      }

      final List<AiNameSuggestion> names = nameList.map((n) => AiNameSuggestion(
        name: n,
        bio: 'Terinspirasi dari visual gambar 🌸',
        theme: 'Vision Match',
        reason: 'Sangat serasi dengan estetika foto/karakter.',
      ),).toList();

      AiResultType resultType = AiResultType.chat;
      if (uniqueAnime.isNotEmpty) {
        resultType = AiResultType.anime;
      } else if (uniqueComic.isNotEmpty) {
        resultType = AiResultType.comic;
      } else if (uniqueNovel.isNotEmpty) {
        resultType = AiResultType.novel;
      } else if (frames.isNotEmpty) {
        resultType = AiResultType.frame;
      }

      return AiUniversalResult(
        type: resultType,
        query: userPrompt,
        explanation: cleanExp.isNotEmpty ? cleanExp : 'Berikut hasil analisis gambar dari Moko AI.',
        animeList: uniqueAnime.values.toList(),
        comicList: uniqueComic.values.toList(),
        novelList: uniqueNovel.values.toList(),
        frameList: frames,
        nameList: names,
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] processImageWithAi error: $e');
      return AiUniversalResult(
        type: AiResultType.chat,
        query: userPrompt,
        explanation: 'Maaf, terjadi kendala saat menganalisis gambar: $e',
        rawResponse: '',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. FITUR BINGKAI AVATAR (AI AUTO-PICK & PASANG BINGKAI KEREN)
  // ─────────────────────────────────────────────────────────────────────────

  /// Moko AI memilihkan bingkai avatar terbaik dari katalog berdasarkan tema / preferensi pengguna
  Future<List<AiFrameRecommendation>> pickCoolDecorations({String? preference}) async {
    const candidateCodes = [
      'ki_energy', 'dragon_balls', 'cyber_katana', 'neon_cat_hoodie',
      'kitsune', 'spirit_blossom_springs', 'flaming_sword', 'malefic_crown',
      'deaths_edge', 'ryu', 'oni_mask', 'sakura_warrior', 'hologram_dragon',
      'port_of_soul', 'mirage_void', 'rumbling', 'arcane_sigil', 'beamchop',
      'phoenix', 'eldritch_ring', 'mecha_break', 'black_hole', 'astro_helmet',
      'shurikens_mask', 'valorant_champions_2024', 'omens_cowl', 'blade_storm',
      'mokoko', 'infinite_swirl', 'shenron', 'lightsabers_blue_and_red', 'chromawave',
    ];

    final prompt = '''
Kamu adalah asisten avatar Animeverse. Dari daftar kode bingkai avatar Discord keren berikut:
${candidateCodes.join(', ')}

Pilihlah 4 sampai 6 bingkai avatar PALING KEREN dan paling cocok untuk pengguna (Preferensi pengguna: "${preference ?? 'paling keren dan epik'}").
Berikan alasan singkat dan menarik untuk setiap pilihan.

WAJIB respon dalam format JSON saja:
```json
{
  "recommendations": [
    {
      "code": "cyber_katana",
      "reason": "Efek katana futuristik bercahaya neon, sangat cocok untuk wibu pecinta tema cyberpunk."
    },
    {
      "code": "ki_energy",
      "reason": "Aura energi petir biru-emas seperti Super Saiyan, bikin profil terlihat overpowered."
    }
  ]
}
```
''';

    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      List<dynamic> recs = [];

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(1)!);
        if (parsed is Map && parsed['recommendations'] is List) {
          recs = parsed['recommendations'] as List;
        }
      } else {
        final rawJson = RegExp(r'\{[\s\S]*"recommendations"[\s\S]*\}').firstMatch(content);
        if (rawJson != null) {
          final parsed = jsonDecode(rawJson.group(0)!);
          if (parsed is Map && parsed['recommendations'] is List) {
            recs = parsed['recommendations'] as List;
          }
        }
      }

      final List<AiFrameRecommendation> results = [];
      for (final r in recs) {
        if (r is Map && r['code'] != null) {
          final code = r['code'].toString().trim();
          final reason = r['reason']?.toString() ?? 'Pilihan keren dari Moko AI.';
          final name = AvatarDecorationRepository.formatName(code);
          final url = 'https://discord-decoration.art/decorations/$code.png';
          final dec = AvatarDecorationModel(
            id: 0,
            code: code,
            name: name,
            category: 'anime',
            imageUrl: url,
            thumbnailUrl: url,
            isActive: true,
            isOwned: true,
          );
          results.add(AiFrameRecommendation(decoration: dec, reason: reason));
        }
      }

      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[AiAnimeService] pickCoolDecorations error: $e');
    }

    // Fallback jika API gagal / format berbeda: pilihan top default
    const fallbackCodes = [
      ('cyber_katana', 'Efek katana futuristik bercahaya neon berputar di sekeliling avatarmu.'),
      ('ki_energy', 'Aura ki energi bertabur petir yang membuat avatarmu tampak overpowered.'),
      ('kitsune', 'Topeng kitsune roh mistis Jepang dengan nyala api spiritual.'),
      ('dragon_balls', 'Bola naga emas bersinar dengan aura mistis klasik anime shonen.'),
    ];

    return fallbackCodes.map((item) {
      final code = item.$1;
      final name = AvatarDecorationRepository.formatName(code);
      final url = 'https://discord-decoration.art/decorations/$code.png';
      return AiFrameRecommendation(
        decoration: AvatarDecorationModel(
          id: 0,
          code: code,
          name: name,
          category: 'anime',
          imageUrl: url,
          thumbnailUrl: url,
          isActive: true,
          isOwned: true,
        ),
        reason: item.$2,
      );
    }).toList();
  }

  /// Pasang bingkai yang dipilih langsung ke akun profil user
  Future<bool> equipFrame(String code, {String? name}) async {
    try {
      final url = 'https://discord-decoration.art/decorations/$code.png';
      final dispName = name ?? AvatarDecorationRepository.formatName(code);
      await AvatarDecorationRepository.instance.selectDecoration(
        code: code,
        name: dispName,
        imageUrl: url,
        scale: 1.0,
      );
      await AuthProvider.instance.refreshUser();
      return true;
    } catch (e) {
      debugPrint('[AiAnimeService] equipFrame error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. FITUR UBAH NAMA & BIO PROFIL (AI NAME GENERATOR & AUTO-UPDATE)
  // ─────────────────────────────────────────────────────────────────────────

  /// Moko AI menghasilkan pilihan nama & bio profil keren bergaya anime / wibu
  Future<List<AiNameSuggestion>> generateCoolNames({String? currentName, String? vibe}) async {
    final prompt = '''
Kamu adalah pembuat nama samaran (nickname / display name) kreatif di komunitas anime Animeverse.
Tugasmu adalah membuatkan 5 ide nama tampilan (Display Name) dan bio profil yang SANGAT KEREN, estetik, atau badass bergaya wibu/anime/gamer.
${currentName != null && currentName.isNotEmpty ? 'Nama pengguna saat ini: "$currentName".' : ''}
${vibe != null && vibe.isNotEmpty ? 'Gaya / Preferensi yang diminta: "$vibe".' : 'Buat beragam tema: Overpower / Shadow, Estetik Jepang / Sakura, Badass Hunter, Cute / Kawaii, dan Cyberpunk.'}

WAJIB respon dalam format JSON saja:
```json
{
  "names": [
    {
      "name": "Kage no Shiin",
      "bio": "Berjalan dalam bayang-bayang, hidup di antara cahaya dan kegelapan ⚔️",
      "theme": "Shadow Sovereign",
      "reason": "Nama terinspirasi dari karakter pengendali bayangan misterius."
    },
    {
      "name": "Aetherius",
      "bio": "Menjelajahi seribu dunia fantasi tanpa batas 🌌",
      "theme": "Astral Voyager",
      "reason": "Kesan elegan, futuristik, dan magis."
    }
  ]
}
```
''';

    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.8,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      List<dynamic> list = [];

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(1)!);
        if (parsed is Map && parsed['names'] is List) {
          list = parsed['names'] as List;
        }
      } else {
        final rawJson = RegExp(r'\{[\s\S]*"names"[\s\S]*\}').firstMatch(content);
        if (rawJson != null) {
          final parsed = jsonDecode(rawJson.group(0)!);
          if (parsed is Map && parsed['names'] is List) {
            list = parsed['names'] as List;
          }
        }
      }

      final List<AiNameSuggestion> suggestions = [];
      for (final item in list) {
        if (item is Map && item['name'] != null) {
          suggestions.add(
            AiNameSuggestion(
              name: item['name'].toString().trim(),
              bio: item['bio']?.toString().trim() ?? 'Pencinta anime sejati 🌸',
              theme: item['theme']?.toString().trim() ?? 'Anime Style',
              reason: item['reason']?.toString().trim() ?? 'Nama yang elegan dan berkarakter.',
            ),
          );
        }
      }

      if (suggestions.isNotEmpty) return suggestions;
    } catch (e) {
      debugPrint('[AiAnimeService] generateCoolNames error: $e');
    }

    // Fallback default suggestions
    return const [
      AiNameSuggestion(
        name: 'Kage Shiro',
        bio: 'Tersenyum di hadapan takdir, berkuasa dalam diam 🗡️',
        theme: 'Shadow King',
        reason: 'Sangat cocok untuk karakter tenang dan kuat.',
      ),
      AiNameSuggestion(
        name: 'Zenith Kuro',
        bio: 'Berpindah antar dimensi demi mencari kedamaian 🌌',
        theme: 'Dimension Walker',
        reason: 'Perpaduan modern dan misterius.',
      ),
      AiNameSuggestion(
        name: 'Sakura Fubuki',
        bio: 'Mekar bersama badai kelopak bunga musim semi 🌸',
        theme: 'Estetik Sakura',
        reason: 'Anggun dan penuh nuansa Jepang klasik.',
      ),
      AiNameSuggestion(
        name: 'Ignis Vesper',
        bio: 'Bara api abadi yang tak pernah padam 🔥',
        theme: 'Flames of Resolve',
        reason: 'Penuh semangat dan jiwa petarung.',
      ),
    ];
  }

  /// Terapkan nama tampilan (dan bio) baru langsung ke profil pengguna
  Future<UserModel?> updateProfileName({required String displayName, String? bio}) async {
    try {
      final updated = await ProfileRepository.instance.updateProfile(
        displayName: displayName,
        bio: bio,
      );
      AuthProvider.instance.setUser(updated);
      return updated;
    } catch (e) {
      debugPrint('[AiAnimeService] updateProfileName error: $e');
      return null;
    }
  }

  /// Terapkan username baru langsung ke profil pengguna
  Future<UserModel?> updateProfileUsername(String newUsername) async {
    try {
      final clean = newUsername.trim().replaceAll('@', '').toLowerCase().replaceAll(' ', '_');
      final updated = await ProfileRepository.instance.updateProfile(username: clean);
      AuthProvider.instance.setUser(updated);
      return updated;
    } catch (e) {
      debugPrint('[AiAnimeService] updateProfileUsername error: $e');
      return null;
    }
  }

  /// Terapkan SEMUA perubahan profil dan kustomisasi sekaligus ("Ganti Semuanya")
  Future<({bool success, String message, UserModel? updatedUser})> applyProfileChanges({
    String? username,
    String? displayName,
    String? bio,
    String? frameCode,
    String? frameName,
    String? profileFont,
    String? theme,
    bool? is18Enabled,
  }) async {
    try {
      final auth = AuthProvider.instance;
      UserModel? current = auth.user;
      final List<String> appliedItems = [];

      final hasTextUpdate = (username != null && username.isNotEmpty) ||
          (displayName != null && displayName.isNotEmpty) ||
          (bio != null && bio.isNotEmpty) ||
          (is18Enabled != null);

      if (hasTextUpdate) {
        final cleanUsername = username?.trim().replaceAll('@', '').toLowerCase().replaceAll(' ', '_');
        final textUpdated = await ProfileRepository.instance.updateProfile(
          username: cleanUsername,
          displayName: displayName?.trim(),
          bio: bio?.trim(),
          is18Enabled: is18Enabled,
        );
        current = textUpdated;
        auth.setUser(textUpdated);

        if (cleanUsername != null && cleanUsername.isNotEmpty) {
          appliedItems.add('Username: @$cleanUsername');
        }
        if (displayName != null && displayName.isNotEmpty) {
          appliedItems.add('Nama: "$displayName"');
        }
        if (bio != null && bio.isNotEmpty) {
          appliedItems.add('Bio');
        }
      }

      if (frameCode != null && frameCode.isNotEmpty) {
        final okFrame = await equipFrame(frameCode, name: frameName);
        if (okFrame) {
          appliedItems.add('Bingkai: ${frameName ?? frameCode}');
        }
      }

      if (profileFont != null && profileFont.isNotEmpty) {
        try {
          final fontUser = await ProfileRepository.instance.setProfileFont(font: profileFont);
          current = fontUser;
          auth.setUser(fontUser);
          appliedItems.add('Font: $profileFont');
        } catch (_) {}
      }

      if (theme != null && theme.isNotEmpty) {
        final lower = theme.toLowerCase();
        if (lower.contains('dark') || lower.contains('gelap') || lower.contains('hitam')) {
          await ThemeProvider.instance.setMode(ThemeModeOption.dark);
          appliedItems.add('Tema: Gelap');
        } else if (lower.contains('light') || lower.contains('terang') || lower.contains('putih')) {
          await ThemeProvider.instance.setMode(ThemeModeOption.light);
          appliedItems.add('Tema: Terang');
        } else if (lower.contains('system') || lower.contains('sistem')) {
          await ThemeProvider.instance.setMode(ThemeModeOption.system);
          appliedItems.add('Tema: Sistem');
        }
      }

      if (is18Enabled != null) {
        await AdultContentService.instance.setHiddenFeature(is18Enabled);
        appliedItems.add(is18Enabled ? '18+: Aktif' : '18+: Nonaktif');
      }

      await auth.refreshUser();

      return (
        success: true,
        message: appliedItems.isNotEmpty
            ? 'Moko AI berhasil menerapkan: ${appliedItems.join(', ')}'
            : 'Perubahan profil berhasil disimpan.',
        updatedUser: auth.user ?? current,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] applyProfileChanges error: $e');
      return (
        success: false,
        message: 'Gagal menerapkan perubahan profil: $e',
        updatedUser: null,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. FITUR PENCARIAN KOMIK & MANGA DENGAN GEMINI 3.8
  // ─────────────────────────────────────────────────────────────────────────

  Future<({String explanation, List<ComicModel> comicList, List<String> suggestedTags, String rawResponse})>
      searchComicsWithAi(String userQuery) async {
    final prompt = '''
Kamu adalah Moko AI, asisten Manga dan Manhwa di Animeverse.
Database katalog komik Animeverse (Komiku) menyimpan komik dengan judul bahasa Indonesia, Inggris, dan Romaji Jepang/Korea.
Bantu pengguna menemukan komik, manga, manhwa, atau manhua yang cocok dengan ceritanya: "$userQuery".

Tugasmu:
1. Terjemahkan dan petakan konsep cerita/alur ke dalam judul komik resmi serta kata kunci pencarian (Bahasa Indonesia & Bahasa Inggris).
2. Berikan 3 sampai 6 judul komik dan kata kunci pencarian.
3. Berikan penjelasan ramah (1-2 paragraf) dalam Bahasa Indonesia.
4. HANYA rekomendasikan komik yang benar-benar ada di API aplikasi.

WAJIB di akhir respon sertakan blok JSON:
```json
{
  "explanation": "Penjelasan rekomendasi komik...",
  "search_keywords": ["Solo Leveling", "Shadow Monarch", "Dungeon"],
  "comic_titles": ["Solo Leveling", "Omniscient Reader's Viewpoint", "The Beginning After the End"],
  "suggested_tags": ["Manhwa", "Action", "Dungeon"]
}
```
''';

    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      List<String> titles = [];
      List<String> keywords = [];
      List<String> tags = [];
      String explanation = '';

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final parsed = jsonDecode(jsonMatch.group(1)!);
          if (parsed is Map) {
            if (parsed['comic_titles'] is List) {
              titles = (parsed['comic_titles'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            if (parsed['search_keywords'] is List) {
              keywords = (parsed['search_keywords'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            if (parsed['suggested_tags'] is List) {
              tags = (parsed['suggested_tags'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            explanation = parsed['explanation']?.toString() ?? '';
          }
        } catch (_) {}
      }

      var cleanExp = content.replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '').trim();
      if (cleanExp.isEmpty && explanation.isNotEmpty) cleanExp = explanation;

      final Map<String, ComicModel> unique = {};
      final repo = ComicRepository.instance;

      if (titles.isNotEmpty) {
        final futures = titles.map((t) => repo.search(t).catchError((_) => <ComicModel>[]));
        final results = await Future.wait(futures);
        for (final list in results) {
          for (final c in list) {
            unique[c.slug] = c;
          }
        }
      }

      if (unique.length < 5 && keywords.isNotEmpty) {
        final kFutures = keywords.map((k) => repo.search(k).catchError((_) => <ComicModel>[]));
        final kResults = await Future.wait(kFutures);
        for (final list in kResults) {
          for (final c in list) {
            unique[c.slug] = c;
          }
        }
      }

      if (unique.isEmpty) {
        final fallback = await repo.search(userQuery).catchError((_) => <ComicModel>[]);
        for (final c in fallback) {
          unique[c.slug] = c;
        }
      }

      final finalComicList = unique.values.toList();
      String finalExplanation = cleanExp.isNotEmpty ? cleanExp : 'Berikut komik yang relevan.';
      if (finalComicList.isEmpty) {
        finalExplanation = 'Maaf, komik yang kamu cari belum tersedia di katalog API Animeverse saat ini. Coba kata kunci atau judul lainnya.';
      }

      return (
        explanation: finalExplanation,
        comicList: finalComicList,
        suggestedTags: tags,
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] searchComicsWithAi error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. FITUR PENCARIAN LIGHT NOVEL DENGAN GEMINI 3.8
  // ─────────────────────────────────────────────────────────────────────────

  Future<({String explanation, List<NovelItemModel> novelList, List<String> suggestedTags, String rawResponse})>
      searchNovelsWithAi(String userQuery) async {
    final prompt = '''
Kamu adalah Moko AI, asisten pencarian Light Novel dan Web Novel di Animeverse.
Database katalog novel yang digunakan aplikasi (Sakuranovel) menyimpan judul-judul novel dalam BAHASA INGGRIS dan Romaji resmi (contoh: "To Be a Power in the Shadows!", "Omniscient Reader's Viewpoint", "Star-Embracing Swordmaster", "Re:Zero", "Release That Witch", "A Regressor’s Tale of Cultivation", "Swordmaster's Youngest Son", "The Beginning After the End").

Pengguna bertanya / mencari: "$userQuery".

Tugasmu:
1. Terjemahkan dan petakan konsep cerita atau kata kunci pengguna ke dalam JUDUL RESMI BAHASA INGGRIS atau kata kunci Bahasa Inggris yang umum dipakai pada judul light novel/web novel.
   - Contoh: "bayangan / raja bayangan" -> "Shadow", "Power in the Shadows", "Shadow Monarch"
   - Contoh: "pedang / pendekar pedang" -> "Sword", "Swordmaster", "Swordsman"
   - Contoh: "penyihir / sihir" -> "Witch", "Mage", "Magic"
   - Contoh: "reinkarnasi / lahir kembali" -> "Reborn", "Reincarnated", "Regressor"
   - Contoh: "dungeon / monster" -> "Dungeon", "Monster", "Hunter"
   - Contoh: "naga" -> "Dragon"
2. Berikan 3 sampai 6 judul novel resmi berbahasa Inggris dan kata kunci pencarian dalam bahasa Inggris.
3. Berikan penjelasan ramah (1-2 paragraf) dalam Bahasa Indonesia.
4. HANYA rekomendasikan novel yang benar-benar nyata ada di database.

WAJIB di akhir respon sertakan blok JSON:
```json
{
  "explanation": "Penjelasan rekomendasi novel...",
  "english_search_keywords": ["Shadow", "Swordmaster", "Witch"],
  "novel_titles": ["To Be a Power in the Shadows!", "Omniscient Reader's Viewpoint", "Star-Embracing Swordmaster"],
  "suggested_tags": ["Fantasy", "Action", "Isekai", "Romance"]
}
```
''';

    try {
      final dio = await _getDio();
      final res = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
        },
      );

      final content = res.data['choices']?[0]?['message']?['content']?.toString() ?? '';
      List<String> titles = [];
      List<String> keywords = [];
      List<String> tags = [];
      String explanation = '';

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final parsed = jsonDecode(jsonMatch.group(1)!);
          if (parsed is Map) {
            if (parsed['novel_titles'] is List) {
              titles = (parsed['novel_titles'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            if (parsed['english_search_keywords'] is List) {
              keywords = (parsed['english_search_keywords'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            if (parsed['suggested_tags'] is List) {
              tags = (parsed['suggested_tags'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
            explanation = parsed['explanation']?.toString() ?? '';
          }
        } catch (_) {}
      }

      var cleanExp = content.replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '').trim();
      if (cleanExp.isEmpty && explanation.isNotEmpty) cleanExp = explanation;

      final Map<String, NovelItemModel> unique = {};
      final repo = NovelRepository.instance;

      // 1. Cari berdasarkan judul spesifik yang dihasilkan AI
      if (titles.isNotEmpty) {
        final futures = titles.map((t) => repo.searchNovels(t).catchError((_) => <NovelItemModel>[]));
        final results = await Future.wait(futures);
        for (final list in results) {
          for (final n in list) {
            unique[n.slug] = n;
          }
        }
      }

      // 2. Jika masih sedikit, cari berdasarkan kata kunci bahasa Inggris yang dipetakan AI
      if (unique.length < 5 && keywords.isNotEmpty) {
        final kFutures = keywords.map((k) => repo.searchNovels(k).catchError((_) => <NovelItemModel>[]));
        final kResults = await Future.wait(kFutures);
        for (final list in kResults) {
          for (final n in list) {
            unique[n.slug] = n;
          }
        }
      }

      // 3. Jika masih kosong, coba cari langsung user query
      if (unique.isEmpty) {
        final fallback = await repo.searchNovels(userQuery).catchError((_) => <NovelItemModel>[]);
        for (final n in fallback) {
          unique[n.slug] = n;
        }
      }

      // 4. Jika masih kosong, coba cari dari tag yang disarankan
      if (unique.isEmpty && tags.isNotEmpty) {
        final tagFutures = tags.map((t) => repo.searchNovels(t).catchError((_) => <NovelItemModel>[]));
        final tagResults = await Future.wait(tagFutures);
        for (final list in tagResults) {
          for (final n in list) {
            unique[n.slug] = n;
          }
        }
      }

      final finalNovelList = unique.values.toList();
      String finalExplanation = cleanExp.isNotEmpty ? cleanExp : 'Berikut novel yang relevan.';

      if (finalNovelList.isEmpty) {
        finalExplanation = 'Maaf, novel yang kamu cari belum tersedia di katalog API Animeverse saat ini. Coba kata kunci lain atau judul alternatif dalam bahasa Inggris.';
      }

      return (
        explanation: finalExplanation,
        novelList: finalNovelList,
        suggestedTags: tags,
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] searchNovelsWithAi error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. FITUR PENCARIAN ANIME BERBASIS GEMINI 3.8 & SCRAPER
  // ─────────────────────────────────────────────────────────────────────────

  Future<AiAnimeSearchResult> searchWithAi(String userQuery) async {
    final cleanQuery = userQuery.trim();
    if (cleanQuery.isEmpty) {
      return const AiAnimeSearchResult(
        query: '',
        explanation: 'Silakan masukkan deskripsi atau kata kunci anime yang ingin dicari.',
        animeList: [],
        rawResponse: '',
      );
    }

    const systemPrompt = '''
Kamu adalah Moko AI, asisten pencarian anime cerdas untuk aplikasi streaming Animeverse.
Tugas utamamu:
1. Membantu pengguna menemukan anime berdasarkan alur cerita, ciri-ciri karakter (misal: "mc overpower pura-pura lemah", "reinkarnasi jadi monster", "romance sekolah baper"), rekomendasi genre, perbandingan ("anime mirip Solo Leveling"), atau judul yang lupa.
2. Memberikan penjelasan ramah, antusias, dan informatif dalam Bahasa Indonesia (maksimal 2-3 paragraf singkat dan jelas).
3. Memberikan daftar rekomendasi anime nyata yang ada di database anime (gunakan judul romaji Jepang atau judul Inggris resmi populer).
4. WAJIB di akhir respon selalu sertakan blok format JSON seperti ini:
```json
{
  "explanation": "Ringkasan penjelasan untuk pengguna...",
  "anime_titles": [
    "Judul Anime 1",
    "Judul Anime 2",
    "Judul Anime 3",
    "Judul Anime 4"
  ],
  "suggested_tags": ["Isekai", "Overpower", "Action", "Comedy"]
}
```
Pastikan "anime_titles" berisi 3 sampai 6 judul anime yang paling relevan.
''';

    try {
      final dio = await _getDio();
      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': cleanQuery},
          ],
          'temperature': 0.7,
          'stream': false,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Gagal menghubungi AI Service (${response.statusCode})');
      }

      final data = response.data;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Respons AI kosong.');
      }

      final content = choices[0]['message']?['content']?.toString() ?? '';

      // Ekstraksi data rekomendasi dari jawaban Gemini 38
      List<String> recommendedTitles = [];
      List<String> suggestedTags = [];
      String explanationText = '';

      final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false).firstMatch(content);
      if (jsonMatch != null) {
        try {
          final jsonStr = jsonMatch.group(1);
          if (jsonStr != null) {
            final parsed = jsonDecode(jsonStr);
            if (parsed is Map) {
              if (parsed['anime_titles'] is List) {
                recommendedTitles = (parsed['anime_titles'] as List)
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              if (parsed['suggested_tags'] is List) {
                suggestedTags = (parsed['suggested_tags'] as List)
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              explanationText = parsed['explanation']?.toString() ?? '';
            }
          }
        } catch (e) {
          debugPrint('[AiAnimeService] Gagal parse JSON block: $e');
        }
      }

      if (recommendedTitles.isEmpty) {
        final directJsonMatch = RegExp(r'\{[\s\S]*"anime_titles"\s*:[\s\S]*\}').firstMatch(content);
        if (directJsonMatch != null) {
          try {
            final parsed = jsonDecode(directJsonMatch.group(0)!);
            if (parsed is Map && parsed['anime_titles'] is List) {
              recommendedTitles = (parsed['anime_titles'] as List)
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (parsed['suggested_tags'] is List) {
                suggestedTags = (parsed['suggested_tags'] as List)
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
            }
          } catch (_) {}
        }
      }

      if (recommendedTitles.isEmpty) {
        final boldMatches = RegExp(r'\*\*([^*]+)\*\*').allMatches(content);
        for (final m in boldMatches) {
          final title = m.group(1)?.trim();
          if (title != null &&
              title.length > 2 &&
              !title.toLowerCase().contains('penjelasan') &&
              !title.toLowerCase().contains('rekomendasi') &&
              !title.toLowerCase().contains('catatan')) {
            recommendedTitles.add(title);
            if (recommendedTitles.length >= 5) break;
          }
        }
      }

      var cleanUserExplanation = content
          .replaceAll(RegExp(r'```(?:json)?[\s\S]*?```', caseSensitive: false), '')
          .replaceAll(RegExp(r'\{[\s\S]*"anime_titles"[\s\S]*\}'), '')
          .trim();

      if (cleanUserExplanation.isEmpty && explanationText.isNotEmpty) {
        cleanUserExplanation = explanationText;
      }

      final Map<String, AnimeModel> uniqueResults = {};
      final repo = AnimeRepository.instance;

      if (recommendedTitles.isNotEmpty) {
        final searchFutures = recommendedTitles.map((title) async {
          try {
            final items = await repo.search(title);
            return items;
          } catch (e) {
            debugPrint('[AiAnimeService] Scraper search error for "$title": $e');
            return <AnimeModel>[];
          }
        });

        final resultsPerTitle = await Future.wait(searchFutures);
        for (final list in resultsPerTitle) {
          for (final item in list) {
            final key = item.id.isNotEmpty ? item.id : item.title.toLowerCase();
            if (!uniqueResults.containsKey(key)) {
              uniqueResults[key] = item;
            }
          }
        }
      }

      if (uniqueResults.isEmpty) {
        try {
          final fallbackItems = await repo.search(cleanQuery);
          for (final item in fallbackItems) {
            final key = item.id.isNotEmpty ? item.id : item.title.toLowerCase();
            uniqueResults[key] = item;
          }
        } catch (_) {}
      }

      if (uniqueResults.isEmpty && suggestedTags.isNotEmpty) {
        try {
          final tagItems = await repo.search(suggestedTags.first);
          for (final item in tagItems.take(6)) {
            final key = item.id.isNotEmpty ? item.id : item.title.toLowerCase();
            uniqueResults[key] = item;
          }
        } catch (_) {}
      }

      if (uniqueResults.isEmpty && cleanUserExplanation.isEmpty) {
        cleanUserExplanation = 'Maaf, anime yang kamu cari belum tersedia di katalog API scraper saat ini. Coba kata kunci atau judul lainnya.';
      } else if (uniqueResults.isEmpty) {
        cleanUserExplanation = '$cleanUserExplanation\n\n*(Catatan: Anime ini belum ditemukan di server streaming scraper saat ini)*';
      }

      return AiAnimeSearchResult(
        query: cleanQuery,
        explanation: cleanUserExplanation.isNotEmpty
            ? cleanUserExplanation
            : 'Berikut beberapa rekomendasi anime yang sesuai dengan pencarian Anda.',
        animeList: uniqueResults.values.toList(),
        suggestedTags: suggestedTags,
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('[AiAnimeService] Search error: $e');
      rethrow;
    }
  }

  /// Percakapan bebas dengan Moko AI (Gemini 3.8)
  Future<String> askAi(String question, {List<Map<String, String>>? history}) async {
    const systemPrompt = '''
Nama kamu adalah Moko AI, asisten kecerdasan buatan resmi Animeverse.
PANDUAN UTAMA:
1. Kamu hanya menjawab dan merekomendasikan konten serta fitur yang benar-benar ada di aplikasi dan API Animeverse (Anime streaming, Komik/Manga/Manhwa, Light Novel & Web Novel, Kustomisasi Profil, Bingkai Avatar Discord, Font, dan Tema).
2. Jika pengguna menanyakan anime, komik, atau novel, berikan informasi akurat sesuai judul resmi (judul anime Jepang/Inggris, judul novel dalam Bahasa Inggris sesuai katalog Sakuranovel).
3. Jika sesuatu tidak ada atau di luar aplikasi, katakan dengan jujur dan ramah bahwa hal tersebut belum tersedia di API Animeverse.
4. Jangan mengarang fitur atau tautan yang tidak ada di aplikasi.
5. Selalu jawab dalam Bahasa Indonesia dengan nada ramah, keren, dan membantu wibu serta pengguna Animeverse.
''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (history != null && history.isNotEmpty) {
      messages.addAll(history);
    }

    messages.add({'role': 'user', 'content': question});

    final dio = await _getDio();
    final response = await dio.post(
      '/chat/completions',
      data: {
        'model': defaultModel,
        'messages': messages,
        'temperature': 0.7,
        'stream': false,
      },
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Gagal menghubungi AI Service (${response.statusCode})');
    }

    final choices = response.data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Respons AI kosong.');
    }

    return choices[0]['message']?['content']?.toString() ?? '';
  }
}
