import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/calm_gif.dart';
import '../../../../shared/widgets/ios_capsule_text_field.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../chat/services/chat_theme_service.dart';
import '../data/forum_repository.dart';
import '../data/models/forum_thread_model.dart';
import 'widgets/forum_video_player_widget.dart';

class ThreadDetailScreen extends StatefulWidget {
  final ForumThreadModel thread;

  const ThreadDetailScreen({
    super.key,
    required this.thread,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  late ForumThreadModel _thread;
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  bool _isSending = false;

  // Comment Image Attachment
  File? _stagedCommentImage;
  String? _stagedCommentImageUrl;
  bool _isUploadingCommentImage = false;

  @override
  void initState() {
    super.initState();
    _thread = widget.thread;
    _refreshThread();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshThread() async {
    final fresh = await ForumRepository.instance.getThreadById(_thread.id);
    if (fresh != null && mounted) {
      setState(() => _thread = fresh);
    }
  }

  Future<void> _handleVote(int direction) async {
    HapticFeedback.selectionClick();
    await ForumRepository.instance.toggleVote(_thread.id, direction);
    await _refreshThread();
  }

  Future<void> _handleLikeComment(String commentId) async {
    HapticFeedback.selectionClick();
    await ForumRepository.instance.toggleCommentLike(_thread.id, commentId);
    await _refreshThread();
  }

  Future<void> _pickCommentImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final sizeInBytes = await file.length();
    if (sizeInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran gambar maksimal 5MB')),
      );
      return;
    }

    setState(() {
      _stagedCommentImage = file;
      _isUploadingCommentImage = true;
    });

    try {
      final res = await AnimeRepository.instance.uploadCommentMedia(file);
      if (!mounted) return;
      if (res != null && (res['media_url'] != null || res['url'] != null)) {
        setState(() {
          _stagedCommentImageUrl = (res['media_url'] ?? res['url']).toString();
          _isUploadingCommentImage = false;
        });
      } else {
        setState(() => _isUploadingCommentImage = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingCommentImage = false);
    }
  }

  void _removeCommentImage() {
    HapticFeedback.selectionClick();
    setState(() {
      _stagedCommentImage = null;
      _stagedCommentImageUrl = null;
      _isUploadingCommentImage = false;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _stagedCommentImageUrl == null) return;
    if (_isUploadingCommentImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon tunggu gambar selesai diunggah')),
      );
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      final authorName = user?.displayName ?? user?.username ?? 'Komunitas Moko';
      final authorAvatar = user?.avatarUrl;
      final authorLevel = user?.level ?? 1;

      await ForumRepository.instance.addComment(
        threadId: _thread.id,
        content: text.isNotEmpty ? text : 'Mengunggah gambar',
        imageUrl: _stagedCommentImageUrl,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorLevel: authorLevel,
      );

      _commentController.clear();
      _commentFocus.unfocus();
      _removeCommentImage();
      await _refreshThread();
    } catch (e) {
      debugPrint('[ThreadDetail] Gagal mengirim komentar: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Teori Manga':
        return const Color(0xFF8B5CF6);
      case 'Fan Art':
        return const Color(0xFFEC4899);
      case 'Rekomendasi':
        return const Color(0xFF10B981);
      case 'Review':
        return const Color(0xFFF59E0B);
      case 'Spoiler':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF007AFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textMuted = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final activeBgUrl = ChatThemeService.instance.activeBackgroundUrl;

    return Scaffold(
      backgroundColor: bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? AppColors.darkBackground : AppColors.lightCard).withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: 0.5,
          ),
        ),
        middle: Text(
          _thread.category,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        trailing: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(ClipboardData(text: '${_thread.title}\n\nDiskusi Moko Forum'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tautan thread berhasil disalin'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Icon(CupertinoIcons.share, size: 20, color: const Color(0xFF007AFF)),
        ),
      ),
      body: Stack(
        children: [
          // Forum Custom Wallpaper Background
          if (activeBgUrl != null && activeBgUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.16 : 0.08,
                child: CalmGif(
                  source: activeBgUrl,
                  fit: BoxFit.cover,
                  speed: ChatThemeService.instance.animSpeed,
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                  // ── 1. MAIN THREAD POST ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author Row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                              backgroundImage: _thread.authorAvatar != null
                                  ? NetworkImage(_thread.authorAvatar!)
                                  : null,
                              child: _thread.authorAvatar == null
                                  ? Text(
                                      _thread.authorName.isNotEmpty
                                          ? _thread.authorName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF007AFF),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _thread.authorName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Lv. ${_thread.authorLevel}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _formatTime(_thread.createdAt),
                                    style: TextStyle(fontSize: 11.5, color: textMuted),
                                  ),
                                ],
                              ),
                            ),
                            // Category Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _categoryColor(_thread.category).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _thread.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _categoryColor(_thread.category),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Related Anime / Komik Card (if any)
                        if (_thread.relatedTitle != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (_thread.isComicTag) {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => ComicDetailScreen(
                                      slug: _thread.relatedSlug ?? _thread.relatedTitle!,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => AnimeDetailScreen(
                                      animeId: _thread.relatedSlug ?? _thread.relatedTitle!,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (_thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (_thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                                      .withValues(alpha: 0.28),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (_thread.relatedPoster != null && _thread.relatedPoster!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: AppNetworkImage(
                                        url: _thread.relatedPoster!,
                                        width: 28,
                                        height: 38,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Icon(
                                      _thread.isComicTag ? CupertinoIcons.book : CupertinoIcons.film,
                                      size: 16,
                                      color: _thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: _thread.isComicTag
                                                    ? const Color(0xFF8B5CF6)
                                                    : const Color(0xFF007AFF),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _thread.isComicTag ? 'Komik' : 'Anime',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _thread.relatedTitle!,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Ketuk untuk melihat detail ${_thread.isComicTag ? 'komik' : 'anime'}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 14,
                                    color: _thread.isComicTag ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Thread Title
                        Text(
                          _thread.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            height: 1.35,
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Thread Content
                        Text(
                          _thread.content,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: textPrimary.withValues(alpha: 0.9),
                            height: 1.55,
                          ),
                        ),

                        // Thread Video (Reels) if any
                        if (_thread.hasVideo) ...[
                          const SizedBox(height: 14),
                          ForumVideoPlayerWidget(
                            videoUrl: _thread.videoUrl!,
                            coverUrl: _thread.imageUrl ?? _thread.relatedPoster,
                            autoPlay: true,
                          ),
                        ] else if (_thread.imageUrl != null && _thread.imageUrl!.isNotEmpty) ...[
                          // Thread Image (if any)
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AppNetworkImage(
                              url: _thread.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 220,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 12),

                        // Bottom Action Row (Reddit Style Upvote / Downvote)
                        Row(
                          children: [
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCardElevated : AppColors.lightSurfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _handleVote(1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Icon(
                                        CupertinoIcons.arrow_up,
                                        size: 16,
                                        color: _thread.userVote == 1
                                            ? const Color(0xFFFF4500)
                                            : textMuted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_thread.upvotes}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _thread.userVote == 1
                                          ? const Color(0xFFFF4500)
                                          : textPrimary,
                                    ),
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _handleVote(-1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Icon(
                                        CupertinoIcons.arrow_down,
                                        size: 16,
                                        color: _thread.userVote == -1
                                            ? const Color(0xFF7193FF)
                                            : textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCardElevated : AppColors.lightSurfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.chat_bubble_2, size: 15, color: textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_thread.comments.length} Komentar',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 2. COMMENTS HEADER ──
                  Row(
                    children: [
                      Icon(CupertinoIcons.bubble_left_bubble_right, size: 18, color: textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Diskusi & Komentar (${_thread.comments.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_thread.comments.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.chat_bubble, size: 36, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada tanggapan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jadilah yang pertama menyampaikan opini atau teori di thread ini!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Comment Cards
                    ..._thread.comments.map((comment) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                  child: Text(
                                    comment.authorName.isNotEmpty
                                        ? comment.authorName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  comment.authorName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Lv. ${comment.authorLevel}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTime(comment.createdAt),
                                  style: TextStyle(fontSize: 11, color: textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              comment.content,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: textPrimary,
                                height: 1.45,
                              ),
                            ),
                            if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AppNetworkImage(
                                  url: comment.imageUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Like Comment Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _handleLikeComment(comment.id),
                                  child: Row(
                                    children: [
                                      Icon(
                                        comment.userLiked
                                            ? CupertinoIcons.heart_fill
                                            : CupertinoIcons.heart,
                                        size: 14,
                                        color: comment.userLiked
                                            ? const Color(0xFFFF2D55)
                                            : textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${comment.likes}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: comment.userLiked
                                              ? const Color(0xFFFF2D55)
                                              : textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // ── 3. BOTTOM COMMENT INPUT BAR ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Staged Image Preview
                  if (_stagedCommentImage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24242A) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              _stagedCommentImage!,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _isUploadingCommentImage
                                ? const Row(
                                    children: [
                                      CupertinoActivityIndicator(radius: 7),
                                      SizedBox(width: 8),
                                      Text(
                                        'Mengunggah gambar...',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Gambar terlampir',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF34C759)),
                                  ),
                          ),
                          GestureDetector(
                            onTap: _removeCommentImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black12,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(CupertinoIcons.xmark, size: 12, color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      // Photo Attachment Button
                      GestureDetector(
                        onTap: _pickCommentImage,
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF24242A) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.photo,
                            size: 19,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                      Expanded(
                        child: IosCapsuleTextField(
                          controller: _commentController,
                          focusNode: _commentFocus,
                          hintText: 'Tulis tanggapan atau teorimu...',
                          prefixIcon: CupertinoIcons.chat_bubble_fill,
                          height: 40,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isSending ? null : _submitComment,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFF007AFF),
                            shape: BoxShape.circle,
                          ),
                          child: _isSending
                              ? const CupertinoActivityIndicator(color: Colors.white, radius: 9)
                              : const Icon(
                                  CupertinoIcons.arrow_up,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }
}
