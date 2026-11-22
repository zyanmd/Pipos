import 'dart:async';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/bouncy_tap.dart';
import '../../../../shared/widgets/ios_capsule_text_field.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../data/forum_repository.dart';
import '../data/models/forum_thread_model.dart';

class CreateThreadSheet extends StatefulWidget {
  final ValueChanged<ForumThreadModel>? onThreadCreated;
  final String? prefillCategory;
  final String? prefillAnimeTitle;

  const CreateThreadSheet({
    super.key,
    this.onThreadCreated,
    this.prefillCategory,
    this.prefillAnimeTitle,
  });

  @override
  State<CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends State<CreateThreadSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _animeSearchController = TextEditingController();

  late String _selectedCategory;
  bool _isSubmitting = false;

  // Image Upload State
  File? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  // Video Upload State (Reels)
  File? _pickedVideo;
  String? _uploadedVideoUrl;
  int? _videoDurationSeconds;
  int? _videoSizeBytes;
  bool _isUploadingVideo = false;

  // Anime & Komik Tagging State
  String _tagType = 'anime'; // 'anime' | 'comic'
  String? _taggedTitle;
  String? _taggedType; // 'anime' | 'comic'
  String? _taggedSlug;
  String? _taggedPoster;
  List<AnimeModel> _animeSearchResults = [];
  List<ComicModel> _comicSearchResults = [];
  bool _isSearchingTag = false;
  Timer? _tagDebounce;

  final List<String> _categories = [
    'Reels / Video',
    'Teori Manga',
    'Fan Art',
    'Rekomendasi',
    'Review',
    'Spoiler',
    'Diskusi Umum',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.prefillCategory ?? _categories.first;
    if (widget.prefillAnimeTitle != null && widget.prefillAnimeTitle!.isNotEmpty) {
      _taggedTitle = widget.prefillAnimeTitle;
      _taggedType = 'anime';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _animeSearchController.dispose();
    _tagDebounce?.cancel();
    super.dispose();
  }

  void _onTagSearchChanged(String query) {
    _tagDebounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      if (_animeSearchResults.isNotEmpty || _comicSearchResults.isNotEmpty || _isSearchingTag) {
        setState(() {
          _animeSearchResults = [];
          _comicSearchResults = [];
          _isSearchingTag = false;
        });
      }
      return;
    }

    setState(() => _isSearchingTag = true);
    _tagDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        if (_tagType == 'anime') {
          final results = await AnimeRepository.instance.search(q);
          if (mounted) {
            setState(() {
              _animeSearchResults = results.take(6).toList();
              _comicSearchResults = [];
              _isSearchingTag = false;
            });
          }
        } else {
          final results = await ComicRepository.instance.search(q);
          if (mounted) {
            setState(() {
              _comicSearchResults = results.take(6).toList();
              _animeSearchResults = [];
              _isSearchingTag = false;
            });
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _animeSearchResults = [];
            _comicSearchResults = [];
            _isSearchingTag = false;
          });
        }
      }
    });
  }

  void _selectAnime(AnimeModel anime) {
    HapticFeedback.selectionClick();
    setState(() {
      _taggedTitle = anime.title;
      _taggedType = 'anime';
      _taggedSlug = anime.id;
      _taggedPoster = anime.thumb;
      _animeSearchResults = [];
      _animeSearchController.clear();
      _isSearchingTag = false;
    });
  }

  void _selectComic(ComicModel comic) {
    HapticFeedback.selectionClick();
    setState(() {
      _taggedTitle = comic.title;
      _taggedType = 'comic';
      _taggedSlug = comic.slug;
      _taggedPoster = comic.thumb;
      _comicSearchResults = [];
      _animeSearchController.clear();
      _isSearchingTag = false;
    });
  }

  void _removeTaggedItem() {
    HapticFeedback.selectionClick();
    setState(() {
      _taggedTitle = null;
      _taggedType = null;
      _taggedSlug = null;
      _taggedPoster = null;
      _animeSearchResults = [];
      _comicSearchResults = [];
      _animeSearchController.clear();
    });
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final sizeInBytes = await file.length();
    if (sizeInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      _showError('Ukuran gambar maksimal 5MB.');
      return;
    }

    setState(() {
      _pickedImage = file;
      _isUploadingImage = true;
    });

    try {
      final uploadRes = await AnimeRepository.instance.uploadCommentMedia(file);
      if (!mounted) return;
      if (uploadRes != null && (uploadRes['media_url'] != null || uploadRes['url'] != null)) {
        setState(() {
          _uploadedImageUrl = (uploadRes['media_url'] ?? uploadRes['url']).toString();
          _isUploadingImage = false;
        });
      } else {
        setState(() => _isUploadingImage = false);
        _showError('Gagal mengunggah gambar ke server.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showError('Error saat unggah gambar: $e');
      }
    }
  }

  void _removeImage() {
    HapticFeedback.selectionClick();
    setState(() {
      _pickedImage = null;
      _uploadedImageUrl = null;
      _isUploadingImage = false;
    });
  }

  Future<void> _pickVideo() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final sizeInBytes = await file.length();
    // 500MB = 500 * 1024 * 1024 bytes
    if (sizeInBytes > 500 * 1024 * 1024) {
      if (!mounted) return;
      _showError('Ukuran video melebihi batas 500MB.');
      return;
    }

    int durationSec = 0;
    try {
      final vController = VideoPlayerController.file(file);
      await vController.initialize();
      durationSec = vController.value.duration.inSeconds;
      await vController.dispose();
      if (durationSec > 60) {
        if (!mounted) return;
        _showError('Durasi video maksimal 1 menit (60 detik).');
        return;
      }
    } catch (e) {
      debugPrint('[CreateThreadSheet] Video duration check: $e');
    }

    setState(() {
      _pickedVideo = file;
      _videoDurationSeconds = durationSec > 0 ? durationSec : null;
      _videoSizeBytes = sizeInBytes;
      _isUploadingVideo = true;
      _selectedCategory = 'Reels / Video';
    });

    try {
      final uploadRes = await AnimeRepository.instance.uploadCommentMedia(file);
      if (!mounted) return;
      if (uploadRes != null && (uploadRes['media_url'] != null || uploadRes['url'] != null)) {
        setState(() {
          _uploadedVideoUrl = (uploadRes['media_url'] ?? uploadRes['url']).toString();
          _isUploadingVideo = false;
        });
      } else {
        setState(() => _isUploadingVideo = false);
        _showError('Gagal mengunggah video ke server.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingVideo = false);
        _showError('Error saat unggah video: $e');
      }
    }
  }

  void _removeVideo() {
    HapticFeedback.selectionClick();
    setState(() {
      _pickedVideo = null;
      _uploadedVideoUrl = null;
      _videoDurationSeconds = null;
      _videoSizeBytes = null;
      _isUploadingVideo = false;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      _showError('Judul thread tidak boleh kosong');
      return;
    }
    if (content.isEmpty) {
      _showError('Isi pembahasan tidak boleh kosong');
      return;
    }
    if (_isUploadingImage) {
      _showError('Mohon tunggu gambar selesai diunggah.');
      return;
    }
    if (_isUploadingVideo) {
      _showError('Mohon tunggu video selesai diunggah.');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      final authorName = user?.displayName ?? user?.username ?? 'Komunitas Moko';
      final authorAvatar = user?.avatarUrl;
      final authorLevel = user?.level ?? 1;

      final thread = await ForumRepository.instance.createThread(
        title: title,
        content: content,
        category: _selectedCategory,
        relatedTitle: _taggedTitle,
        relatedType: _taggedType,
        relatedSlug: _taggedSlug,
        relatedPoster: _taggedPoster,
        imageUrl: _uploadedImageUrl,
        videoUrl: _uploadedVideoUrl,
        videoDuration: _videoDurationSeconds,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorLevel: authorLevel,
      );

      if (!mounted) return;
      widget.onThreadCreated?.call(thread);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Gagal membuat thread: $e');
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Perhatian'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textMuted = isDark ? Colors.white54 : Colors.black45;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.square_pencil, size: 20, color: textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Buat Thread Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.xmark, size: 16, color: textMuted),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Body Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // 1. Kategori Tag
                Text(
                  'Kategori Pembahasan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF007AFF)
                              : (isDark ? const Color(0xFF222230) : const Color(0xFFF2F2F7)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF007AFF)
                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // 2. Tag Anime / Komik
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tag Anime / Komik Terkait',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (_taggedTitle == null)
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF20202C) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _tagType = 'anime';
                                  _animeSearchResults = [];
                                  _comicSearchResults = [];
                                });
                                if (_animeSearchController.text.trim().length >= 2) {
                                  _onTagSearchChanged(_animeSearchController.text);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _tagType == 'anime'
                                      ? (isDark ? const Color(0xFF007AFF) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _tagType == 'anime'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                      : null,
                                ),
                                child: Text(
                                  'Anime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _tagType == 'anime' ? FontWeight.w700 : FontWeight.w500,
                                    color: _tagType == 'anime'
                                        ? (_tagType == 'anime' && isDark ? Colors.white : const Color(0xFF007AFF))
                                        : textMuted,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _tagType = 'comic';
                                  _animeSearchResults = [];
                                  _comicSearchResults = [];
                                });
                                if (_animeSearchController.text.trim().length >= 2) {
                                  _onTagSearchChanged(_animeSearchController.text);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _tagType == 'comic'
                                      ? (isDark ? const Color(0xFF8B5CF6) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _tagType == 'comic'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                      : null,
                                ),
                                child: Text(
                                  'Komik',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _tagType == 'comic' ? FontWeight.w700 : FontWeight.w500,
                                    color: _tagType == 'comic'
                                        ? (_tagType == 'comic' && isDark ? Colors.white : const Color(0xFF8B5CF6))
                                        : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_taggedTitle != null) ...[
                  // Tagged Item Chip Card (Anime / Komik)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_taggedType == 'comic' ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (_taggedType == 'comic' ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_taggedPoster != null && _taggedPoster!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AppNetworkImage(
                              url: _taggedPoster!,
                              width: 32,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (_taggedType == 'comic' ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _taggedType == 'comic' ? CupertinoIcons.book : CupertinoIcons.film,
                              size: 16,
                              color: _taggedType == 'comic' ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _taggedType == 'comic'
                                          ? const Color(0xFF8B5CF6)
                                          : const Color(0xFF007AFF),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      _taggedType == 'comic' ? 'Komik' : 'Anime',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _taggedTitle!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ditandai dalam pembahasan thread',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (_taggedType == 'comic' ? const Color(0xFF8B5CF6) : const Color(0xFF007AFF))
                                      .withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _removeTaggedItem,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.black12,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.xmark, size: 13, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Search & Tag Field
                  IosCapsuleTextField(
                    controller: _animeSearchController,
                    hintText: _tagType == 'anime'
                        ? 'Cari anime untuk ditag (cth: One Piece)...'
                        : 'Cari komik untuk ditag (cth: Solo Leveling)...',
                    prefixIcon: CupertinoIcons.search,
                    onChanged: _onTagSearchChanged,
                  ),

                  // Suggestions Dropdown (Anime)
                  if (_animeSearchResults.isNotEmpty && _tagType == 'anime') ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24242A) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: _animeSearchResults.map((anime) {
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: AppNetworkImage(
                                url: anime.thumb ?? '',
                                width: 28,
                                height: 38,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              anime.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              anime.status ?? 'Anime',
                              style: TextStyle(fontSize: 11, color: textMuted),
                            ),
                            trailing: const Icon(CupertinoIcons.plus_circle, size: 18, color: Color(0xFF007AFF)),
                            onTap: () => _selectAnime(anime),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Suggestions Dropdown (Komik)
                  if (_comicSearchResults.isNotEmpty && _tagType == 'comic') ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24242A) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: _comicSearchResults.map((comic) {
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: AppNetworkImage(
                                url: comic.thumb ?? '',
                                width: 28,
                                height: 38,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              comic.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              comic.type ?? 'Komik',
                              style: TextStyle(fontSize: 11, color: const Color(0xFF8B5CF6)),
                            ),
                            trailing: const Icon(CupertinoIcons.plus_circle, size: 18, color: Color(0xFF8B5CF6)),
                            onTap: () => _selectComic(comic),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 18),

                // 3. Judul Thread
                Text(
                  'Judul Diskusi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                IosCapsuleTextField(
                  controller: _titleController,
                  hintText: 'Tulis judul yang menarik dan jelas...',
                  prefixIcon: CupertinoIcons.pencil,
                ),

                const SizedBox(height: 18),

                // 4. Isi Thread
                Text(
                  'Isi Pembahasan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                IosCapsuleTextField(
                  controller: _contentController,
                  hintText: 'Bagikan teori, analisis, karya seni, atau pertanyaanmu untuk komunitas...',
                  prefixIcon: CupertinoIcons.text_quote,
                  maxLines: 6,
                ),

                const SizedBox(height: 18),

                // 5. Unggah Gambar / Fan Art (Langsung Upload dari Perangkat)
                Text(
                  'Gambar / Fan Art (Unggah dari Galeri)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                if (_pickedVideo != null) ...[
                  // Video (Reels) Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _uploadedVideoUrl != null
                            ? const Color(0xFF34C759).withValues(alpha: 0.6)
                            : const Color(0xFF007AFF).withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.videocam_fill, size: 22, color: Color(0xFF007AFF)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedVideo!.path.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (_videoDurationSeconds != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${_videoDurationSeconds}s / 60s',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                                          ),
                                        ),
                                      if (_videoSizeBytes != null)
                                        Text(
                                          '${((_videoSizeBytes!) / (1024 * 1024)).toStringAsFixed(1)} MB',
                                          style: TextStyle(fontSize: 11, color: textMuted),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _removeVideo,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(CupertinoIcons.xmark, size: 14, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUploadingVideo) ...[
                                const CupertinoActivityIndicator(radius: 7, color: Color(0xFF34C759)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Mengunggah video ke server...',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF34C759)),
                                ),
                              ] else ...[
                                const Icon(CupertinoIcons.play_circle_fill, size: 14, color: Color(0xFF34C759)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Video Siap • Otomatis Ditayangkan di Reels',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF34C759)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_pickedImage != null) ...[
                  // Image Preview Card
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _uploadedImageUrl != null
                            ? const Color(0xFF34C759).withValues(alpha: 0.6)
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _pickedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Dark overlay at bottom for status
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isUploadingImage) ...[
                                  const CupertinoActivityIndicator(radius: 8, color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Mengunggah ke server...',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ] else if (_uploadedImageUrl != null) ...[
                                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 15, color: Color(0xFF34C759)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Gambar berhasil diunggah',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Pick Buttons Row (Photo & Video Reels)
                  Row(
                    children: [
                      // Button 1: Image
                      Expanded(
                        child: BouncyTap(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(CupertinoIcons.photo_on_rectangle, size: 20, color: Color(0xFF007AFF)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Foto',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Maksimal 5MB',
                                  style: TextStyle(fontSize: 10.5, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Button 2: Video Reels
                      Expanded(
                        child: BouncyTap(
                          onTap: _pickVideo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(CupertinoIcons.videocam_fill, size: 20, color: Color(0xFF34C759)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Video (Reels)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Maks 1 Min & 500MB',
                                  style: TextStyle(fontSize: 10.5, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // Submit Button
                BouncyTap(
                  onTap: _isSubmitting ? () {} : _submit,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.paperplane_fill, size: 17, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Posting Thread Diskusi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
