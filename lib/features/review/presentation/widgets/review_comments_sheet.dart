import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/user_decor_resolver.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/decorated_avatar.dart';
import '../../../../shared/widgets/user_profile_card_modal.dart';
import '../../data/models/user_review_model.dart';
import '../../data/review_repository.dart';

/// Modal Bottom Sheet Komentar Ulasan berdesain Apple iOS Modern & Elegan
class ReviewCommentsSheet extends StatefulWidget {
  final int reviewId;
  final String reviewTitle;

  const ReviewCommentsSheet({
    super.key,
    required this.reviewId,
    required this.reviewTitle,
  });

  static Future<int?> show(
    BuildContext context, {
    required int reviewId,
    required String reviewTitle,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewCommentsSheet(
        reviewId: reviewId,
        reviewTitle: reviewTitle,
      ),
    );
  }

  @override
  State<ReviewCommentsSheet> createState() => _ReviewCommentsSheetState();
}

class _ReviewCommentsSheetState extends State<ReviewCommentsSheet> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<UserReviewCommentModel> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  bool _hasInputText = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentCtrl.addListener(() {
      final hasText = _commentCtrl.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final data = await ReviewRepository.instance.getComments(widget.reviewId);
    if (mounted) {
      setState(() {
        _comments = data;
        _isLoading = false;
      });
      UserDecorResolver.instance.resolveUsers(data.map((c) => c.username));
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isPosting) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login untuk menulis komentar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isPosting = true);
    final created = await ReviewRepository.instance.addComment(widget.reviewId, text);
    if (mounted) {
      setState(() => _isPosting = false);
      if (created != null) {
        _commentCtrl.clear();
        setState(() {
          _comments.add(created);
        });
        HapticFeedback.mediumImpact();
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent + 80,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim komentar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCommentOptions(UserReviewCommentModel comment, bool isMe) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          comment.username ?? 'Komentar',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        message: Text(
          comment.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: comment.content));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Komentar disalin ke papan klip'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_on_doc, size: 18),
                SizedBox(width: 8),
                Text('Salin Teks'),
              ],
            ),
          ),
          if (isMe)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _deleteComment(comment);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.trash, size: 18),
                  SizedBox(width: 8),
                  Text('Hapus Komentar'),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Future<void> _deleteComment(UserReviewCommentModel comment) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Komentar'),
        content: const Text('Yakin ingin menghapus komentar ini?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Hapus'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ReviewRepository.instance.deleteComment(comment.id);
      if (success && mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
      }
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    return AppDateUtils.formatTimeAgo(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    final sheetBg = isDark
        ? const Color(0xEB16161A)
        : const Color(0xF5FFFFFF);

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: sheetHeight,
            margin: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Apple iOS Grabber Pill
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 38,
                    height: 4.8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.4),
                    ),
                  ),
                ),

                // Apple-style Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Komentar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_comments.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.reviewTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // iOS Cupertino Circular Close Button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(_comments.length);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor, thickness: 0.6),

                // Comment list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _comments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF222228) : const Color(0xFFF2F2F7),
                                      border: Border.all(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        CupertinoIcons.bubble_left_bubble_right_fill,
                                        size: 26,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Belum Ada Komentar',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Jadilah yang pertama menulis tanggapan!',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : AnimatedBuilder(
                              animation: UserDecorResolver.instance,
                              builder: (context, _) {
                                return ListView.separated(
                                  controller: _scrollCtrl,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                                  itemCount: _comments.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final c = _comments[index];
                                    final isMe = currentUserId != null && currentUserId == c.userId;
                                    final decor = UserDecorResolver.instance.get(c.username);
                                    final avatarUrl = decor?.avatarUrl ?? c.userAvatar;
                                    final decorUrl = decor?.decorationUrl ?? c.userDecorationUrl;
                                    final decorCode = decor?.decorationCode ?? c.userDecorationCode;

                                    return GestureDetector(
                                      onLongPress: () => _showCommentOptions(c, isMe),
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // User Avatar (Clickable to profile)
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              if (c.username != null && c.username!.isNotEmpty) {
                                                showUserProfileCard(context, username: c.username);
                                              }
                                            },
                                            child: DecoratedAvatar(
                                              avatarUrl: avatarUrl,
                                              decorationUrl: decorUrl,
                                              decorationCode: decorCode,
                                              decorationScale: decor?.decorationScale ?? 1.0,
                                              offsetX: decor?.decorationOffsetX ?? 0,
                                              offsetY: decor?.decorationOffsetY ?? 0,
                                              fallbackName: c.username ?? 'Pengguna',
                                              radius: 17,
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // iOS Message Bubble
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? (isMe
                                                            ? const Color(0xFF232328)
                                                            : const Color(0xFF1E1E22))
                                                        : (isMe
                                                            ? const Color(0xFFEBEBF0)
                                                            : const Color(0xFFF4F4F6)),
                                                    borderRadius: const BorderRadius.only(
                                                      topLeft: Radius.circular(5),
                                                      topRight: Radius.circular(18),
                                                      bottomLeft: Radius.circular(18),
                                                      bottomRight: Radius.circular(18),
                                                    ),
                                                    border: Border.all(
                                                      color: isDark
                                                          ? Colors.white.withValues(alpha: 0.07)
                                                          : Colors.black.withValues(alpha: 0.05),
                                                      width: 0.7,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Flexible(
                                                            child: GestureDetector(
                                                              behavior: HitTestBehavior.opaque,
                                                              onTap: () {
                                                                if (c.username != null && c.username!.isNotEmpty) {
                                                                  showUserProfileCard(context, username: c.username);
                                                                }
                                                              },
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Flexible(
                                                                    child: Text(
                                                                      c.username ?? 'Pengguna',
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: TextStyle(
                                                                        fontSize: 12.5,
                                                                        fontWeight: FontWeight.w700,
                                                                        letterSpacing: -0.2,
                                                                        color: isDark ? Colors.white : Colors.black,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (isMe) ...[
                                                                    const SizedBox(width: 4),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                                      decoration: BoxDecoration(
                                                                        color: isDark ? Colors.white12 : Colors.black12,
                                                                        borderRadius: BorderRadius.circular(4),
                                                                      ),
                                                                      child: Text(
                                                                        'Anda',
                                                                        style: TextStyle(
                                                                          fontSize: 9,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: isDark ? Colors.white70 : Colors.black54,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            _timeAgo(c.createdAt),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: isDark ? Colors.white38 : Colors.black38,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 5),
                                                      SelectableText(
                                                        c.content,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          height: 1.35,
                                                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Quick action line
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 4, top: 4),
                                                  child: Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () {
                                                          _commentCtrl.text = '@${c.username ?? 'user'} ';
                                                          _commentCtrl.selection = TextSelection.fromPosition(
                                                            TextPosition(offset: _commentCtrl.text.length),
                                                          );
                                                        },
                                                        child: Text(
                                                          'Balas',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: isDark ? Colors.white54 : Colors.black54,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isMe) ...[
                                                        const SizedBox(width: 14),
                                                        GestureDetector(
                                                          onTap: () => _deleteComment(c),
                                                          child: const Text(
                                                            'Hapus',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.redAccent,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                ),

                // Apple Messages-Style Floating Input Bar
                Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141417) : const Color(0xFFF9F9FB),
                    border: Border(
                      top: BorderSide(
                        color: dividerColor,
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _commentCtrl,
                          placeholder: 'Tulis komentar...',
                          placeholderStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13.5,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 13.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222228) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                              width: 0.8,
                            ),
                          ),
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _postComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Animated Apple iOS Send Button (like iOS Messages)
                      GestureDetector(
                        onTap: (_hasInputText && !_isPosting) ? _postComment : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _hasInputText
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                            shape: BoxShape.circle,
                          ),
                          child: _isPosting
                              ? Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  CupertinoIcons.arrow_up,
                                  color: _hasInputText
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark ? Colors.white24 : Colors.black26),
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
