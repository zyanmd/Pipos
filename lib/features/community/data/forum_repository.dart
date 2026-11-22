import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/forum_thread_model.dart';

class ForumRepository {
  ForumRepository._();
  static final ForumRepository instance = ForumRepository._();

  static const String _kForumThreadsKey = 'forum_threads_cache_v2';
  List<ForumThreadModel> _threads = [];
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kForumThreadsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _threads = decoded
              .map((e) => ForumThreadModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ForumRepository] Error loading threads: $e');
    }

    if (_threads.isEmpty) {
      _threads = _generateInitialThreads();
      await _persist();
    }
    _initialized = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_threads.map((t) => t.toJson()).toList());
      await prefs.setString(_kForumThreadsKey, data);
    } catch (e) {
      debugPrint('[ForumRepository] Error persisting threads: $e');
    }
  }

  Future<List<ForumThreadModel>> getThreads({
    String? category,
    String? query,
    String? sort, // 'trending', 'latest', 'top'
  }) async {
    await _init();
    var list = List<ForumThreadModel>.from(_threads);

    if (category != null && category.isNotEmpty && category != 'Semua') {
      list = list.where((t) => t.category.toLowerCase() == category.toLowerCase()).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((t) {
        final titleMatch = t.title.toLowerCase().contains(q);
        final contentMatch = t.content.toLowerCase().contains(q);
        final animeMatch = t.relatedTitle?.toLowerCase().contains(q) ?? false;
        final authorMatch = t.authorName.toLowerCase().contains(q);
        return titleMatch || contentMatch || animeMatch || authorMatch;
      }).toList();
    }

    if (sort == 'top') {
      list.sort((a, b) => b.upvotes.compareTo(a.upvotes));
    } else if (sort == 'latest') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      // Default: Trending (upvotes + comment weight + recency)
      list.sort((a, b) {
        final scoreA = a.upvotes * 2 + a.commentCount * 3;
        final scoreB = b.upvotes * 2 + b.commentCount * 3;
        return scoreB.compareTo(scoreA);
      });
    }

    return list;
  }

  Future<ForumThreadModel?> getThreadById(String id) async {
    await _init();
    try {
      return _threads.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<ForumThreadModel>> getVideoThreads() async {
    await _init();
    final vids = _threads.where((t) => t.hasVideo).toList();
    if (vids.isEmpty) {
      final initial = _generateInitialThreads().where((t) => t.hasVideo).toList();
      _threads.insertAll(0, initial);
      await _persist();
      return initial;
    }
    return vids;
  }

  Future<ForumThreadModel> createThread({
    required String title,
    required String content,
    required String category,
    String? relatedTitle,
    String? relatedType,
    String? relatedSlug,
    String? relatedPoster,
    String? imageUrl,
    String? videoUrl,
    int? videoDuration,
    required String authorName,
    String? authorAvatar,
    int authorLevel = 1,
  }) async {
    await _init();
    final newThread = ForumThreadModel(
      id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      content: content.trim(),
      authorId: 'user_local',
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorLevel: authorLevel,
      category: category,
      relatedTitle: relatedTitle?.trim().isNotEmpty == true ? relatedTitle!.trim() : null,
      relatedType: relatedType?.trim().isNotEmpty == true ? relatedType!.trim() : null,
      relatedSlug: relatedSlug?.trim().isNotEmpty == true ? relatedSlug!.trim() : null,
      relatedPoster: relatedPoster?.trim().isNotEmpty == true ? relatedPoster!.trim() : null,
      imageUrl: imageUrl?.trim().isNotEmpty == true ? imageUrl!.trim() : null,
      videoUrl: videoUrl?.trim().isNotEmpty == true ? videoUrl!.trim() : null,
      videoDuration: videoDuration,
      upvotes: 1,
      userVote: 1,
      commentCount: 0,
      createdAt: DateTime.now(),
      comments: [],
    );

    _threads.insert(0, newThread);
    await _persist();
    return newThread;
  }

  Future<ForumCommentModel> addComment({
    required String threadId,
    required String content,
    required String authorName,
    String? authorAvatar,
    int authorLevel = 1,
    String? imageUrl,
  }) async {
    await _init();
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) {
      throw Exception('Thread tidak ditemukan');
    }

    final newComment = ForumCommentModel(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      threadId: threadId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorLevel: authorLevel,
      content: content.trim(),
      imageUrl: imageUrl,
      likes: 0,
      userLiked: false,
      createdAt: DateTime.now(),
    );

    final thread = _threads[index];
    final updatedComments = List<ForumCommentModel>.from(thread.comments)..add(newComment);
    _threads[index] = thread.copyWith(
      comments: updatedComments,
      commentCount: updatedComments.length,
    );

    await _persist();
    return newComment;
  }

  Future<void> toggleVote(String threadId, int direction) async {
    await _init();
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;

    final thread = _threads[index];
    int currentVote = thread.userVote;
    int upvotes = thread.upvotes;

    if (currentVote == direction) {
      // Batal vote
      upvotes -= direction;
      currentVote = 0;
    } else {
      // Ganti vote (misal dari downvote ke upvote atau netral ke upvote)
      upvotes = upvotes - currentVote + direction;
      currentVote = direction;
    }

    _threads[index] = thread.copyWith(
      upvotes: upvotes < 0 ? 0 : upvotes,
      userVote: currentVote,
    );
    await _persist();
  }

  Future<void> toggleCommentLike(String threadId, String commentId) async {
    await _init();
    final threadIndex = _threads.indexWhere((t) => t.id == threadId);
    if (threadIndex == -1) return;

    final thread = _threads[threadIndex];
    final commentIndex = thread.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = thread.comments[commentIndex];
    final newLiked = !comment.userLiked;
    final newLikes = newLiked ? comment.likes + 1 : (comment.likes > 0 ? comment.likes - 1 : 0);

    final updatedComments = List<ForumCommentModel>.from(thread.comments);
    updatedComments[commentIndex] = ForumCommentModel(
      id: comment.id,
      threadId: comment.threadId,
      authorName: comment.authorName,
      authorAvatar: comment.authorAvatar,
      authorLevel: comment.authorLevel,
      content: comment.content,
      likes: newLikes,
      userLiked: newLiked,
      createdAt: comment.createdAt,
    );

    _threads[threadIndex] = thread.copyWith(comments: updatedComments);
    await _persist();
  }

  List<ForumThreadModel> _generateInitialThreads() {
    return [
      ForumThreadModel(
        id: 't_reel_frieren_magic',
        title: 'Momen Sihir Zoltraak Fern - Kecepatan Animasi Madhouse Luar Biasa!',
        content: 'Animasi pertarungan Frieren vs Clone di dungeon terdalam adalah salah satu animasi terbaik tahun ini!',
        authorId: 'u_frieren',
        authorName: 'FernStaff',
        authorAvatar: null,
        authorLevel: 6,
        category: 'Reels / Video',
        relatedTitle: 'Sousou no Frieren',
        relatedType: 'anime',
        relatedSlug: 'sousou-no-frieren',
        relatedPoster: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600',
        imageUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        videoDuration: 15,
        upvotes: 142,
        userVote: 1,
        commentCount: 18,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        comments: [],
      ),
      ForumThreadModel(
        id: 't_reel_action_clip',
        title: 'Kompilasi Sakuga Pertarungan Anime Terbaik',
        content: 'Kombinasi efek suara dan pergerakan kamera dinamis yang memanjakan mata.',
        authorId: 'u_sakuga',
        authorName: 'SakugaLover',
        authorAvatar: null,
        authorLevel: 8,
        category: 'Reels / Video',
        relatedTitle: 'Jujutsu Kaisen',
        relatedType: 'anime',
        relatedSlug: 'jujutsu-kaisen',
        relatedPoster: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
        imageUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        videoDuration: 15,
        upvotes: 98,
        userVote: 0,
        commentCount: 9,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        comments: [],
      ),
      ForumThreadModel(
        id: 't_onepiece_elbaf',
        title: 'Teori Joy Boy & Abad Kekosongan di Arc Elbaf: Hubungan Robot Kuno dengan Pohon Hawa',
        content:
            'Melihat chapter terbaru, sangat jelas bahwa raksasa Elbaf memiliki hubungan mendalam dengan peradaban 800 tahun lalu. Apakah sumber energi robot kuno yang digerakkan Gear 5 Luffy sebenarnya berasal dari getaran detak jantung Nika yang beresonansi dengan Pohon Hawa? Bagaimana menurut kalian?',
        authorId: 'u_nakama',
        authorName: 'RoronoaFan',
        authorAvatar: null,
        authorLevel: 6,
        category: 'Teori Manga',
        relatedTitle: 'One Piece',
        relatedType: 'anime',
        relatedSlug: 'one-piece',
        relatedPoster: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600',
        upvotes: 42,
        userVote: 0,
        commentCount: 4,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        comments: [
          ForumCommentModel(
            id: 'c_1',
            threadId: 't_onepiece_elbaf',
            authorName: 'LawKuning',
            authorLevel: 4,
            content: 'Setuju banget! Emeth di Egghead juga sempat bilang dia minta maaf ke Joy Boy. Berarti dulu Elbaf adalah tempat pertemuan sekutu Joy Boy.',
            likes: 12,
            userLiked: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          ForumCommentModel(
            id: 'c_2',
            threadId: 't_onepiece_elbaf',
            authorName: 'SanjiCook',
            authorLevel: 5,
            content: 'Apalagi senjata kuno Pluton dan Poseidon sudah mulai terkuak. Uranus kemungkinan besar ada di tangan Imu.',
            likes: 8,
            userLiked: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      ),
      ForumThreadModel(
        id: 't_frieren_rekomendasi',
        title: 'Rekomendasi Anime Serupa Sousou no Frieren: Perjalanan Tenang yang Menguras Emosi',
        content:
            'Bagi yang sedang hampa setelah tamat nonton Frieren, berikut beberapa judul dengan atmosfer serupa:\n1. Mushishi: Suasana alam mistis dan tenang.\n2. Kino no Tabi: Filosofi perjalanan antar negeri.\n3. Natsume Yuujinchou: Hubungan hangat antara manusia dan roh.\n4. Violet Evergarden: Memahami arti kata cinta dan penyesalan masa lalu.',
        authorId: 'u_frieren',
        authorName: 'HimmelTheHero',
        authorAvatar: null,
        authorLevel: 7,
        category: 'Rekomendasi',
        relatedTitle: 'Sousou no Frieren',
        upvotes: 68,
        userVote: 1,
        commentCount: 5,
        createdAt: DateTime.now().subtract(const Duration(hours: 7)),
        comments: [
          ForumCommentModel(
            id: 'c_3',
            threadId: 't_frieren_rekomendasi',
            authorName: 'FernStaff',
            authorLevel: 3,
            content: 'Mushishi salah satu mahakarya yang wajib ditonton minimal sekali seumur hidup!',
            likes: 15,
            userLiked: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ],
      ),
      ForumThreadModel(
        id: 't_jjk_discussion',
        title: 'Analisis Domain Expansion & Binding Vow Terakhir di Manga Jujutsu Kaisen',
        content:
            'Penggunaan Binding Vow di babak akhir pertarungan Sukuna sempat menuai perdebatan. Menurut kalian apakah konsekuensi kehilangan lengan dan teknik kutukan Sukuna sudah sepadan dengan World Cutting Slash yang dilepaskan?',
        authorId: 'u_jjk',
        authorName: 'GojoHonored',
        authorAvatar: null,
        authorLevel: 5,
        category: 'Teori Manga',
        relatedTitle: 'Jujutsu Kaisen',
        upvotes: 35,
        userVote: 0,
        commentCount: 6,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        comments: [],
      ),
      ForumThreadModel(
        id: 't_fanart_demon_slayer',
        title: 'Fan Art Zenitsu Thunderclap and Flash Rokuren - Digital Canvas 4K',
        content:
            'Menghabiskan waktu sekitar 14 jam membuat ilustrasi Zenitsu saat bertarung di Infinity Castle. Fokus pencahayaan ada pada petir emas yang membelah kegelapan ruangan. Silakan berikan masukan atau kritik untuk komposisi warnanya!',
        authorId: 'u_artist',
        authorName: 'ZenithArt',
        authorAvatar: null,
        authorLevel: 4,
        category: 'Fan Art',
        relatedTitle: 'Kimetsu no Yaiba',
        upvotes: 51,
        userVote: 0,
        commentCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        comments: [],
      ),
      ForumThreadModel(
        id: 't_sololeveling_ragnarok',
        title: 'Solo Leveling: Ragnarok Chapter Terbaru - Potensi Sung Suho Melampaui Bayangan Jin-Woo',
        content:
            'Perkembangan kekuatan Suho di sekuel ini terasa sangat dinamis karena dia memadukan kekuatan Shadow Monarch dengan berkah dari para Monarch lainnya. Apakah Suho nantinya akan menciptakan pasukan bayangan jenis baru?',
        authorId: 'u_hunter',
        authorName: 'ShadowLord',
        authorAvatar: null,
        authorLevel: 5,
        category: 'Review',
        relatedTitle: 'Solo Leveling',
        relatedType: 'comic',
        relatedSlug: 'solo-leveling',
        relatedPoster: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
        upvotes: 29,
        userVote: 0,
        commentCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        comments: [],
      ),
    ];
  }
}
