import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/chat_repository.dart';
import '../../data/models/chat_model.dart';
import '../chat_screen.dart';

/// A sleek Apple HIG running text (marquee ticker) banner for displaying the latest
/// community chat message and announcements on Home, Comic, NekoPoi, and 18+ screens.
/// Tapping opens the ChatScreen.
class ChatMarqueeBanner extends StatefulWidget {
  final EdgeInsetsGeometry? margin;

  const ChatMarqueeBanner({
    super.key,
    this.margin,
  });

  @override
  State<ChatMarqueeBanner> createState() => _ChatMarqueeBannerState();
}

class _ChatMarqueeBannerState extends State<ChatMarqueeBanner> {
  final _repo = ChatRepository.instance;
  ChatMessageModel? _latestMessage;
  Timer? _pollingTimer;
  late final ScrollController _scrollController;
  bool _isScrolling = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _loadLatest();
    // Poll for new messages every 20 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadLatest();
    });

    // Schedule running marquee loop once view is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarquee();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLatest() async {
    final msg = await _repo.getLatestMessage();
    if (!mounted || _disposed) return;
    if (msg != null && (_latestMessage == null || _latestMessage!.id != msg.id)) {
      setState(() => _latestMessage = msg);
      if (!_isScrolling) {
        _startMarquee();
      }
    }
  }

  void _startMarquee() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _disposed || !_scrollController.hasClients) return;
      if (_isScrolling) return;
      _isScrolling = true;

      // Smooth continuous marquee loop
      while (mounted && !_disposed && _scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (max <= 0) {
          // If content fits or layout is pending, wait and re-check
          await Future.delayed(const Duration(milliseconds: 1000));
          continue;
        }

        // Brief pause at the starting point
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted || _disposed || !_scrollController.hasClients) break;

        final currentMax = _scrollController.position.maxScrollExtent;
        if (currentMax <= 0) break;

        // Smooth scrolling speed (~32 px/sec for comfortable reading)
        final durationSeconds = (currentMax / 32).clamp(10.0, 45.0).toInt();
        await _scrollController.animateTo(
          currentMax,
          duration: Duration(seconds: durationSeconds),
          curve: Curves.linear,
        );

        // Pause briefly at the end of the line
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted || _disposed || !_scrollController.hasClients) break;

        // Quick smooth rewind to start
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
      _isScrolling = false;
    });
  }

  void _openChat() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(),
      ),
    ).then((_) => _loadLatest());
  }

  String _buildMarqueeSegment() {
    if (_latestMessage != null) {
      final user = _latestMessage!.username;
      final text = _latestMessage!.message.trim();
      final hasMedia = _latestMessage!.hasMedia;
      final mediaLabel = _latestMessage!.mediaType == 'gif' ? '🎞️ [GIF]' : '📷 [Foto]';

      final String chatContent;
      if (text.isNotEmpty && hasMedia) {
        chatContent = '$user: "$text" $mediaLabel';
      } else if (text.isNotEmpty) {
        chatContent = '$user: "$text"';
      } else if (hasMedia) {
        chatContent = '$user mengirim $mediaLabel';
      } else {
        chatContent = '$user mengirim pesan';
      }

      return '💬 $chatContent   •   🔥 Ketuk di sini untuk gabung obrolan komunitas!   •   ❤️ Dukung server MOKO via Sociabuzz @zanegg   •   ⚡ Update harian anime & komik';
    }

    return '🔥 Selamat datang di MOKO! Streaming Anime & Baca Komik terlengkap   •   💬 Gabung obrolan wibu di Chat Global!   •   ❤️ Dukung server MOKO via Sociabuzz @zanegg   •   ⚡ Update episode & chapter tiap hari tanpa batas';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segment = _buildMarqueeSegment();

    return Padding(
      padding: widget.margin ?? const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openChat,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                  : const Color(0xFFF2F2F7).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Live Chat Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF000000), Color(0xFF262626)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Running Marquee Ticker Text (Repeated segments guarantee scroll on all screens)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          segment,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.92)
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 40),
                        Text(
                          segment,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.92)
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
