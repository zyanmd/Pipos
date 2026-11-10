import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_decor_resolver.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/calm_gif.dart';
import '../../../shared/widgets/decorated_avatar.dart';
import '../../auth/data/models/user_model.dart';
import '../../anime/presentation/widgets/genre_role_widgets.dart';
import '../../avatar_decoration/data/avatar_decoration_repository.dart';
import '../../profile/data/models/profile_font_model.dart';
import '../../../shared/widgets/user_profile_card_modal.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_model.dart';
import '../services/chat_theme_service.dart';
import 'chat_background_screen.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../../shared/widgets/swipe_to_reply.dart';
import '../../../core/services/admob_service.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../notifications/presentation/universal_notification_modal.dart';
import '../../notifications/presentation/widgets/universal_notification_button.dart';
import '../../notifications/services/universal_notification_service.dart';
import '../../anime/data/anime_repository.dart';
import '../../anime/data/models/anime_model.dart';
import '../../anime/presentation/anime_detail_screen.dart';
import '../../comic/data/comic_repository.dart';
import '../../comic/data/models/comic_model.dart';
import '../../comic/presentation/comic_detail_screen.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'widgets/giphy_picker_modal.dart';

class ChatScreen extends StatefulWidget {
  final String? initialText;
  final String? initialFilter;
  final int? targetMessageId;

  const ChatScreen({super.key, this.initialText, this.initialFilter, this.targetMessageId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo = ChatRepository.instance;
  final _themeService = ChatThemeService.instance;

  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _isSending = false;
  int _currentPage = 1;
  bool _hasNextPage = true;

  final Map<int, GlobalKey> _messageKeys = {};
  int? _highlightedMessageId;

  GlobalKey _getMessageKey(int msgId) {
    return _messageKeys.putIfAbsent(msgId, () => GlobalKey());
  }

  // Filters: 'all', 'media', 'bg', 'mentions', 'replies'
  late String _activeFilter;
  bool _isSearchOpen = false;

  ChatMessageModel? _replyingTo;
  File? _stagedMediaFile;
  String? _stagedMediaUrl;
  String _stagedMediaType = 'none';
  ChatTaggedContent? _stagedTaggedContent;

  // Mention autocomplete
  List<ChatUserSearchResult> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;

  Timer? _pollingTimer;

  // Cache for other & current users' avatar decorations and profile pictures
  static final Map<String, ({String? avatar, String? decorationUrl, String? decorationCode})> _userDecorCache = {};

  void _cacheUserDecoration({
    required String username,
    String? avatar,
    String? decorationUrl,
    String? decorationCode,
  }) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty || key == 'unknown' || key == 'pengguna') return;
    final existing = _userDecorCache[key];
    _userDecorCache[key] = (
      avatar: avatar ?? existing?.avatar,
      decorationUrl: decorationUrl ?? existing?.decorationUrl,
      decorationCode: decorationCode ?? existing?.decorationCode,
    );
  }

  void _syncDecorCache(List<ChatMessageModel> msgs) {
    final toResolve = <String>{};
    for (final m in msgs) {
      if (m.username.isNotEmpty) {
        toResolve.add(m.username);
      }
      if (m.avatar != null || m.avatarDecorationUrl != null || m.avatarDecorationCode != null) {
        _cacheUserDecoration(
          username: m.username,
          avatar: m.avatar,
          decorationUrl: m.fullAvatarDecorationUrl,
          decorationCode: m.avatarDecorationCode,
        );
      }
      if (m.replyTo != null) {
        if (m.replyTo!.username.isNotEmpty) {
          toResolve.add(m.replyTo!.username);
        }
        if (m.replyTo!.avatar != null || m.replyTo!.avatarDecorationUrl != null || m.replyTo!.avatarDecorationCode != null) {
          _cacheUserDecoration(
            username: m.replyTo!.username,
            avatar: m.replyTo!.avatar,
            decorationUrl: m.replyTo!.fullAvatarDecorationUrl,
            decorationCode: m.replyTo!.avatarDecorationCode,
          );
        }
      }
    }
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser != null && currentUser.username.isNotEmpty) {
      toResolve.add(currentUser.username);
    }
    if (toResolve.isNotEmpty) {
      UserDecorResolver.instance.resolveUsers(toResolve);
    }
  }

  Timer? _decorDebounceTimer;

  void _onDecorUpdated() {
    if (!mounted) return;
    if (_decorDebounceTimer?.isActive ?? false) return;
    _decorDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter ?? 'all';
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    _themeService.init();

    UserDecorResolver.instance.addListener(_onDecorUpdated);

    // Preload current user active decoration from local repository & auth
    AvatarDecorationRepository.instance.getLocalActiveDecoration().then((active) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _cacheUserDecoration(
          username: user.username,
          avatar: user.avatarUrl,
          decorationUrl: active?.imageUrl ?? user.fullAvatarDecorationUrl,
          decorationCode: active?.code ?? user.avatarDecorationCode,
        );
        UserDecorResolver.instance.registerUserModel(user);
        UserDecorResolver.instance.resolveUsers([user.username]);
        setState(() {});
      }
    });

    _loadInitial();

    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);

    // Poll for new messages every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollNewMessages();
    });
  }

  @override
  void dispose() {
    UserDecorResolver.instance.removeListener(_onDecorUpdated);
    _decorDebounceTimer?.cancel();
    _pollingTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 240 && !_loadingMore && _hasNextPage) {
      _loadMore();
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.baseOffset > 0) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final match = RegExp(r'@([A-Za-z0-9_.]*)$').firstMatch(textBeforeCursor);
      if (match != null) {
        final query = match.group(1) ?? '';
        _searchMentions(query);
        return;
      }
    }
    if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
        _mentionSuggestions = [];
      });
    }
  }

  Future<void> _searchMentions(String q) async {
    final currentUsername = context.read<AuthProvider>().user?.username.toLowerCase();

    // 1. Gather active participants in current chat room for instant fallback / fuzzy match
    final localMap = <String, ChatUserSearchResult>{};
    for (final msg in _messages) {
      final uName = msg.username.trim();
      final uLower = uName.toLowerCase();
      if (uLower.isEmpty || uLower == 'unknown' || uLower == 'pengguna' || uLower == currentUsername) continue;
      if (!localMap.containsKey(uLower)) {
        localMap[uLower] = ChatUserSearchResult(
          id: msg.userId,
          username: uName,
          avatar: msg.avatar,
          verifiedBadge: msg.verifiedBadge,
        );
      }
    }

    // 2. If q is empty (user just typed '@'), show recent participants
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _mentionSuggestions = localMap.values.take(8).toList();
        _showMentionSuggestions = _mentionSuggestions.isNotEmpty;
      });
      return;
    }

    // 3. If q has 1+ characters, query server and merge with local participants
    final remoteResults = await _repo.searchUsers(q);
    if (!mounted) return;

    final qLower = q.toLowerCase();
    final combinedMap = <String, ChatUserSearchResult>{};

    // Add server results first
    for (final u in remoteResults) {
      final uLower = u.username.toLowerCase();
      if (uLower != currentUsername) {
        combinedMap[uLower] = u;
      }
    }

    // Add local participants matching query (fuzzy/partial match)
    for (final entry in localMap.entries) {
      if (entry.key.contains(qLower) && !combinedMap.containsKey(entry.key)) {
        combinedMap[entry.key] = entry.value;
      }
    }

    final merged = combinedMap.values.toList();
    // Sort: priority to usernames that start with query, then length, then alphabetical
    merged.sort((a, b) {
      final aLower = a.username.toLowerCase();
      final bLower = b.username.toLowerCase();
      final aStarts = aLower.startsWith(qLower) ? 0 : 1;
      final bStarts = bLower.startsWith(qLower) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      if (aLower.length != bLower.length) return aLower.length.compareTo(bLower.length);
      return aLower.compareTo(bLower);
    });

    setState(() {
      _mentionSuggestions = merged.take(12).toList();
      _showMentionSuggestions = _mentionSuggestions.isNotEmpty;
    });
  }

  void _selectMention(ChatUserSearchResult user) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.baseOffset > 0) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final match = RegExp(r'@([A-Za-z0-9_.]*)$').firstMatch(textBeforeCursor);
      if (match != null) {
        final atIndex = match.start;
        final prefix = text.substring(0, atIndex);
        final suffix = text.substring(selection.baseOffset);
        final replacement = '@${user.username} ';
        _textController.text = '$prefix$replacement$suffix';
        _textController.selection = TextSelection.collapsed(
          offset: prefix.length + replacement.length,
        );
      }
    }
    setState(() {
      _showMentionSuggestions = false;
      _mentionSuggestions = [];
    });
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);

    UniversalNotificationService.instance.refreshUnreadCounts();

    final searchQuery = _isSearchOpen ? _searchController.text.trim() : null;

    final res = await _repo.getMessages(
      page: 1,
      perPage: 50,
      search: searchQuery?.isNotEmpty == true ? searchQuery : null,
      mediaOnly: _activeFilter == 'media',
      withBackground: _activeFilter == 'bg',
      mentionsMe: _activeFilter == 'mentions',
      repliesToMe: _activeFilter == 'replies',
    );

    if (!mounted) return;

    if (res != null) {
      final list = res['messages'] as List<ChatMessageModel>? ?? [];
      final pagination = res['pagination'] as Map<String, dynamic>?;
      _syncDecorCache(list);
      setState(() {
        _messages = list;
        _currentPage = 1;
        _hasNextPage = pagination?['has_next'] == true;
        _loading = false;
      });
      if (widget.targetMessageId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToMessage(widget.targetMessageId!);
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(msg),
      ),
    );
  }

  Future<void> _scrollToMessage(int targetId) async {
    if (targetId <= 0) return;

    var index = _messages.indexWhere((m) => m.id == targetId);

    // If message is not yet in the loaded window, auto-fetch previous pages
    if (index == -1 && _hasNextPage && !_loadingMore) {
      _showToast('Mencari pesan asli...');
      int attempts = 0;
      while (attempts < 6 && _hasNextPage && mounted) {
        await _loadMore();
        index = _messages.indexWhere((m) => m.id == targetId);
        if (index != -1) break;
        attempts++;
      }
    }

    if (!mounted) return;

    if (index == -1) {
      _showToast('Pesan asli tidak ditemukan atau sudah dihapus');
      return;
    }

    setState(() {
      _highlightedMessageId = targetId;
    });

    final key = _messageKeys[targetId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
    } else {
      if (_scrollController.hasClients) {
        final estimatedOffset = (index * 80.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        await _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final targetKey = _messageKeys[targetId];
          if (targetKey?.currentContext != null) {
            Scrollable.ensureVisible(
              targetKey!.currentContext!,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: 0.5,
            );
          }
        });
      }
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _highlightedMessageId == targetId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNextPage) return;
    setState(() => _loadingMore = true);

    final nextPage = _currentPage + 1;
    final searchQuery = _isSearchOpen ? _searchController.text.trim() : null;

    try {
      final oldestId = _messages.isNotEmpty ? _messages.last.id.toString() : null;
      final res = await _repo.getMessages(
        page: nextPage,
        perPage: 50,
        before: oldestId,
        search: searchQuery?.isNotEmpty == true ? searchQuery : null,
        mediaOnly: _activeFilter == 'media',
        withBackground: _activeFilter == 'bg',
        mentionsMe: _activeFilter == 'mentions',
        repliesToMe: _activeFilter == 'replies',
      );

      if (!mounted) return;

      if (res != null) {
        final list = res['messages'] as List<ChatMessageModel>? ?? [];
        final pagination = res['pagination'] as Map<String, dynamic>?;
        _syncDecorCache(list);
        setState(() {
          final existingIds = _messages.map((m) => m.id).toSet();
          final uniqueList = list.where((m) => !existingIds.contains(m.id)).toList();
          _messages.addAll(uniqueList);
          _currentPage = nextPage;
          _hasNextPage = (pagination?['has_next'] == true || pagination?['has_more'] == true) && uniqueList.isNotEmpty;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pollNewMessages() async {
    if (_activeFilter != 'all' || _isSearchOpen) return;

    final res = await _repo.getMessages(page: 1, perPage: 20);
    if (!mounted || res == null) return;
    final list = res['messages'] as List<ChatMessageModel>?;
    if (list != null && list.isNotEmpty) {
      _syncDecorCache(list);
      final existingIds = _messages.map((m) => m.id).toSet();
      final newItems = list.where((m) => !existingIds.contains(m.id)).toList();
      if (newItems.isNotEmpty) {
        setState(() {
          _messages.insertAll(0, newItems);
        });
      }
    }
    UniversalNotificationService.instance.refreshUnreadCounts();
  }

  Future<void> _pickMediaFromSource(ImageSource source) async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final x = source == ImageSource.camera
        ? await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85)
        : await picker.pickImage(source: source);
    if (x == null) return;

    File file = File(x.path);
    final isGif = file.path.toLowerCase().endsWith('.gif');
    final len = await file.length();
    if (len > 5 * 1024 * 1024) {
      if (isGif) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran animasi GIF maksimal 5MB!'),
          ),
        );
        return;
      }
      // Recompress high-resolution photo from gallery so it doesn't exceed 5MB
      try {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final tempFile = File('${Directory.systemTemp.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.png');
          await tempFile.writeAsBytes(byteData.buffer.asUint8List());
          if (await tempFile.length() <= 5 * 1024 * 1024) {
            file = tempFile;
          }
        }
      } catch (_) {}

      if (await file.length() > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Ukuran file maksimal 5MB! Silakan pilih foto dengan resolusi lebih kecil.'),
          ),
        );
        return;
      }
    }
    setState(() {
      _stagedMediaFile = file;
      _stagedMediaUrl = null;
      _stagedMediaType = isGif ? 'gif' : 'image';
    });
  }

  void _showAttachmentMenu(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'Lampirkan ke Obrolan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        message: Text(
          'Bagikan foto, animasi GIF, atau tag anime/komik favoritmu',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showTagContentModal(context, initialTab: 0);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.film, size: 20, color: Color(0xFFFF2D55)),
                SizedBox(width: 8),
                Text('Tag Anime 🎬', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showTagContentModal(context, initialTab: 1);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.book, size: 20, color: Color(0xFF8E44AD)),
                SizedBox(width: 8),
                Text('Tag Komik 📚', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showGifPickerModal(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.sparkles, size: 20, color: Color(0xFFFF9500)),
                SizedBox(width: 8),
                Text('GIPHY & Stiker GIF ✨', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickMediaFromSource(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: 20, color: Color(0xFF34C759)),
                SizedBox(width: 8),
                Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickMediaFromSource(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: 20, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Text('Ambil Foto Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _showGifPickerModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GiphyPickerModal(
        isDark: isDark,
        onSelected: (url) {
          setState(() {
            _stagedMediaFile = null;
            _stagedMediaUrl = url;
            _stagedMediaType = 'gif';
          });
          _focusNode.requestFocus();
        },
      ),
    );
  }

  void _showTagContentModal(BuildContext context, {int initialTab = 0}) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TagContentModal(
        isDark: isDark,
        initialTab: initialTab,
        onSelected: (tagged) {
          setState(() {
            _stagedTaggedContent = tagged;
          });
          _focusNode.requestFocus();
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty && _stagedMediaFile == null && _stagedMediaUrl == null && _stagedTaggedContent == null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk untuk mengirim pesan ke chat komunitas.')),
      );
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    String? mediaUrl;
    String mediaType = 'none';

    try {
      if (_stagedMediaFile != null) {
        final staged = _stagedMediaFile!;
        final ext = staged.path.split('.').last.toLowerCase();
        final isGif = ext == 'gif';
        final uploadRes = await _repo.uploadMedia(staged);
        final Map<String, dynamic>? dataMap = uploadRes != null
            ? (uploadRes['data'] is Map
                ? Map<String, dynamic>.from(uploadRes['data'] as Map)
                : uploadRes)
            : null;

        if (dataMap != null) {
          mediaUrl = dataMap['media_url']?.toString() ?? dataMap['url']?.toString();
          final serverType = dataMap['media_type']?.toString();
          mediaType = isGif ? 'gif' : (serverType ?? 'image');
        }

        if (mediaUrl == null || mediaUrl.isEmpty) {
          if (!mounted) return;
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Gagal mengunggah foto. Pastikan ukuran file maks 5MB dan jaringan stabil.'),
            ),
          );
          return;
        }
      } else if (_stagedMediaUrl != null && _stagedMediaUrl!.isNotEmpty) {
        mediaUrl = _stagedMediaUrl;
        mediaType = _stagedMediaType;
      }

      final bgUrl = _themeService.activeBackgroundUrl;
      final bgType = _themeService.activeBackgroundType;
      final textColor = _themeService.activeTextColor;

      final currentUser = auth.user;
      final activeDecor = await AvatarDecorationRepository.instance.getLocalActiveDecoration();
      final decorCode = activeDecor?.code ?? currentUser?.avatarDecorationCode;
      final decorUrl = activeDecor?.imageUrl ?? currentUser?.fullAvatarDecorationUrl;

      final fullMessage = _stagedTaggedContent != null
          ? (rawText.isEmpty ? _stagedTaggedContent!.toTagString() : '$rawText\n${_stagedTaggedContent!.toTagString()}')
          : rawText;

      final sentMessage = await _repo.sendMessage(
        message: fullMessage,
        replyToId: _replyingTo?.id,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        backgroundUrl: bgUrl,
        backgroundType: bgType,
        textColor: textColor,
        avatarDecorationCode: decorCode,
        avatarDecorationUrl: decorUrl,
      );

      if (!mounted) return;

      if (sentMessage == null) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal mengirim pesan ke chat. Silakan coba lagi.'),
          ),
        );
        return;
      }

      _textController.clear();
      setState(() {
        _isSending = false;
        _replyingTo = null;
        _stagedMediaFile = null;
        _stagedMediaUrl = null;
        _stagedMediaType = 'none';
        _stagedTaggedContent = null;
        final effectiveMsg = sentMessage.copyWith(
          avatar: sentMessage.avatar ?? currentUser?.avatarUrl,
          avatarDecorationCode: sentMessage.avatarDecorationCode ?? decorCode,
          avatarDecorationUrl: sentMessage.avatarDecorationUrl ?? decorUrl,
        );
        _messages.insert(0, effectiveMsg);
        if (currentUser != null) {
          UserDecorResolver.instance.registerUserModel(currentUser);
          if (decorCode != null || decorUrl != null || currentUser.avatarUrl != null) {
            _cacheUserDecoration(
              username: currentUser.username,
              avatar: currentUser.avatarUrl,
              decorationUrl: decorUrl,
              decorationCode: decorCode,
            );
          }
        }
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorFormatter.format(e, fallback: 'Gagal mengirim pesan. Silakan coba lagi.'))),
      );
    }
  }

  void _replyMessage(ChatMessageModel msg) {
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = msg);
    _focusNode.requestFocus();
  }

  void _editMessage(ChatMessageModel msg) {
    final editCtrl = TextEditingController(text: msg.message);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Pesan'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: editCtrl,
            maxLines: 4,
            minLines: 1,
            placeholder: 'Tulis pesan baru...',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isEmpty && !msg.hasMedia) return;
              Navigator.pop(ctx);
              final updated = await _repo.editMessage(
                messageId: msg.id,
                message: newText,
              );
              if (updated != null && mounted) {
                setState(() {
                  final idx = _messages.indexWhere((m) => m.id == msg.id);
                  if (idx != -1) _messages[idx] = updated;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesan berhasil diperbarui!')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteMediaOnly(ChatMessageModel msg) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Media'),
        content: const Text('Hapus lampiran media dari pesan ini?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Media'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _repo.deleteMessageMedia(msg.id);
    if (ok && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _messages[idx] = ChatMessageModel(
            id: msg.id,
            userId: msg.userId,
            username: msg.username,
            avatar: msg.avatar,
            message: msg.message,
            mediaUrl: null,
            mediaType: 'none',
            hasMedia: false,
            backgroundUrl: msg.backgroundUrl,
            backgroundType: msg.backgroundType,
            hasBackground: msg.hasBackground,
            textColor: msg.textColor,
            mentions: msg.mentions,
            mentionCount: msg.mentionCount,
            replyToId: msg.replyToId,
            replyTo: msg.replyTo,
            isEdited: true,
            createdAt: msg.createdAt,
            updatedAt: msg.updatedAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lampiran media telah dihapus.')),
      );
    }
  }

  void _deleteBackgroundOnly(ChatMessageModel msg) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Background'),
        content: const Text('Kembalikan latar bubble pesan ini ke warna standar?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Background'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _repo.deleteMessageBackground(msg.id);
    if (ok && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _messages[idx] = ChatMessageModel(
            id: msg.id,
            userId: msg.userId,
            username: msg.username,
            avatar: msg.avatar,
            message: msg.message,
            mediaUrl: msg.mediaUrl,
            mediaType: msg.mediaType,
            hasMedia: msg.hasMedia,
            backgroundUrl: null,
            backgroundType: 'none',
            hasBackground: false,
            textColor: null,
            mentions: msg.mentions,
            mentionCount: msg.mentionCount,
            replyToId: msg.replyToId,
            replyTo: msg.replyTo,
            isEdited: true,
            createdAt: msg.createdAt,
            updatedAt: msg.updatedAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background khusus telah dihapus.')),
      );
    }
  }

  void _deleteMessage(ChatMessageModel msg) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Pesan'),
        content: const Text('Apakah Anda yakin ingin menghapus pesan ini?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await _repo.deleteMessage(msg.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesan telah dihapus.')),
      );
    }
  }

  void _showBubbleActions(ChatMessageModel msg, bool isOwner) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(msg.username),
        message: Text(msg.message.isNotEmpty ? msg.message : '[Media]'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _replyMessage(msg);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.reply, size: 18),
                SizedBox(width: 8),
                Text('Balas'),
              ],
            ),
          ),
          if (msg.message.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teks disalin ke papan klip!')),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                  SizedBox(width: 8),
                  Text('Salin Teks'),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _textController.text = '${_textController.text}@${msg.username} ';
              _focusNode.requestFocus();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.at, size: 18),
                SizedBox(width: 8),
                Text('Sebut (@Pengguna)'),
              ],
            ),
          ),
          if (isOwner) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _editMessage(msg);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.pencil, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Pesan'),
                ],
              ),
            ),
            if (msg.hasMedia)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteMediaOnly(msg);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus Media Saja'),
                  ],
                ),
              ),
            if (msg.hasBackground)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteBackgroundOnly(msg);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.sparkles, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus Background Saja'),
                  ],
                ),
              ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _deleteMessage(msg);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.trash, size: 18, color: CupertinoColors.destructiveRed),
                  SizedBox(width: 8),
                  Text('Hapus Pesan'),
                ],
              ),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _showNotificationsSheet(bool isDark) {
    HapticFeedback.selectionClick();
    UniversalNotificationModal.show(context, initialTabIndex: 0).then((_) {
      UniversalNotificationService.instance.refreshUnreadCounts();
    });
  }

  void _viewFullPhoto(BuildContext context, String url) {
    HapticFeedback.selectionClick();
    final isHttp = url.startsWith('http://') || url.startsWith('https://');
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text('Media Chat', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: PhotoView(
            imageProvider: isHttp ? NetworkImage(url) as ImageProvider : FileImage(File(url)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.0,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, __) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    return ChatThemeService.parseHexColor(hex, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF16161A) : Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearchOpen
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Cari pesan...',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onSubmitted: (_) => _loadInitial(),
                  onSuffixTap: () {
                    _searchController.clear();
                    _loadInitial();
                  },
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chat Komunitas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'Cari Pesan',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _loadInitial();
                }
              });
            },
          ),
          UniversalNotificationButton(
            size: 34,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            customOnTap: () => _showNotificationsSheet(isDark),
          ),
          IconButton(
            icon: Icon(CupertinoIcons.sparkles, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Kustomisasi Background Chat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatBackgroundScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(isDark),
            const AdBannerWidget(
              adUnitId: AdMobService.chatBannerUnitId,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadInitial,
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            addRepaintBoundaries: true,
                            addAutomaticKeepAlives: true,
                            findChildIndexCallback: (Key key) {
                              if (key is GlobalKey) {
                                for (final entry in _messageKeys.entries) {
                                  if (entry.value == key) {
                                    final idx = _messages.indexWhere((m) => m.id == entry.key);
                                    if (idx != -1) return idx;
                                  }
                                }
                              }
                              if (key is ValueKey<String> && key.value.startsWith('msg_')) {
                                final idStr = key.value.substring(4);
                                final id = int.tryParse(idStr);
                                if (id != null) {
                                  final idx = _messages.indexWhere((m) => m.id == id);
                                  if (idx != -1) return idx;
                                }
                              }
                              return null;
                            },
                            itemCount: _messages.length + (_loadingMore ? 1 : (_hasNextPage ? 0 : (_messages.isNotEmpty ? 1 : 0))),
                            itemBuilder: (ctx, index) {
                              if (index == _messages.length) {
                                if (_loadingMore) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                      child: CupertinoActivityIndicator(),
                                    ),
                                  );
                                }
                                return Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.sparkles, size: 13, color: isDark ? Colors.white54 : Colors.black45),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Awal Percakapan Komunitas',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final msg = _messages[index];
                              final isOwner = currentUserId != null &&
                                  (currentUserId.toString() == msg.userId.toString());
                              final isLastOldest = index == _messages.length - 1;
                              final showDateHeader = isLastOldest ||
                                  (_getDateLabel(msg.createdAt) != _getDateLabel(_messages[index + 1].createdAt));

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDateHeader)
                                    _buildDateBubble(_getDateLabel(msg.createdAt), isDark),
                                  RepaintBoundary(
                                    key: _getMessageKey(msg.id),
                                    child: SwipeToReply(
                                      onReply: () => _replyMessage(msg),
                                      direction: isOwner
                                          ? SwipeToReplyDirection.endToStart
                                          : SwipeToReplyDirection.startToEnd,
                                      child: _buildMessageBubble(msg, isOwner, isDark, auth.user),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
            ),
            if (_showMentionSuggestions)
              _buildMentionSuggestionsPopup(isDark, auth.user),
            if (_replyingTo != null)
              _buildReplyingBanner(isDark, auth.user),
            _buildStagedAttachmentsPreview(isDark),
            _buildInputBar(isDark, auth.isAuthenticated),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'Semua', 'icon': CupertinoIcons.chat_bubble_2},
      {'id': 'media', 'label': 'Media', 'icon': CupertinoIcons.photo},
      {'id': 'bg', 'label': 'Background', 'icon': CupertinoIcons.sparkles},
      {'id': 'mentions', 'label': '@ Saya', 'icon': CupertinoIcons.at},
      {'id': 'replies', 'label': 'Balasan', 'icon': CupertinoIcons.reply},
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final isSelected = _activeFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_activeFilter == f['id']) return;
                HapticFeedback.selectionClick();
                setState(() => _activeFilter = f['id'] as String);
                _loadInitial();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 13,
                      color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            _activeFilter == 'all'
                ? 'Belum ada pesan di Chat Global'
                : 'Tidak ada pesan dengan filter ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kirim pesan pertama dan sapa teman-teman lainnya!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateLabel(dynamic createdAt) {
    final dt = AppDateUtils.parseToLocal(createdAt);
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari Ini';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Kemarin';
    }
    return AppDateUtils.formatDate(dt);
  }

  Widget _buildDateBubble(String dateStr, bool isDark) {
    if (dateStr.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.black87).withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          dateStr,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isOwner, bool isDark, UserModel? currentUser) {
    final hasBg = msg.hasBackground && msg.fullBackgroundUrl != null;
    final hasAttachedMedia = msg.hasMedia && msg.fullMediaUrl != null;

    final defaultTextColor = isOwner ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final effectiveTextColor = hasBg
        ? _parseHex(msg.textColor, Colors.white)
        : defaultTextColor;

    final isSenderVerified = msg.verifiedBadge ||
        (isOwner && currentUser?.verifiedBadge == true) ||
        (currentUser != null &&
            currentUser.verifiedBadge &&
            (msg.username.toLowerCase() == currentUser.username.toLowerCase() ||
                msg.userId == currentUser.id));

    final isReplyVerified = msg.replyTo != null &&
        (msg.replyTo!.verifiedBadge ||
            (currentUser != null &&
                currentUser.verifiedBadge &&
                (msg.replyTo!.username.toLowerCase() == currentUser.username.toLowerCase() ||
                    (msg.replyTo!.userId != null && msg.replyTo!.userId == currentUser.id))));

    final authorKey = msg.username.trim().toLowerCase();
    final cachedAuthor = _userDecorCache[authorKey];
    final resolvedAuthor = UserDecorResolver.instance.get(msg.username);

    // Effective avatar and decoration for other users
    final senderAvatar = (msg.avatar != null && msg.avatar!.isNotEmpty)
        ? msg.authorAvatarUrl
        : (resolvedAuthor?.avatarUrl != null && resolvedAuthor!.avatarUrl!.isNotEmpty)
            ? UserModel.normalizeAvatarUrl(resolvedAuthor.avatarUrl)
            : (cachedAuthor?.avatar != null
                ? UserModel.normalizeAvatarUrl(cachedAuthor!.avatar)
                : msg.authorAvatarUrl);

    final senderDecor = msg.fullAvatarDecorationUrl ??
        resolvedAuthor?.decorationUrl ??
        cachedAuthor?.decorationUrl;
    final senderDecorCode = msg.avatarDecorationCode ??
        resolvedAuthor?.decorationCode ??
        cachedAuthor?.decorationCode;
    final senderDecorScale = resolvedAuthor?.decorationScale ?? 1.05;

    // Effective avatar and decoration for message owner
    final ownerKey = (currentUser?.username ?? msg.username).trim().toLowerCase();
    final cachedOwner = _userDecorCache[ownerKey];
    final resolvedOwner = UserDecorResolver.instance.get(currentUser?.username ?? msg.username);
    final ownerAvatar = (currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty)
        ? currentUser.avatarUrl!
        : ((msg.avatar != null && msg.avatar!.isNotEmpty)
            ? msg.authorAvatarUrl
            : (resolvedOwner?.avatarUrl != null && resolvedOwner!.avatarUrl!.isNotEmpty)
                ? UserModel.normalizeAvatarUrl(resolvedOwner.avatarUrl)
                : (cachedOwner?.avatar != null
                    ? UserModel.normalizeAvatarUrl(cachedOwner!.avatar)
                    : msg.authorAvatarUrl));

    final ownerDecor = currentUser?.fullAvatarDecorationUrl ??
        msg.fullAvatarDecorationUrl ??
        resolvedOwner?.decorationUrl ??
        cachedOwner?.decorationUrl;
    final ownerDecorCode = currentUser?.avatarDecorationCode ??
        msg.avatarDecorationCode ??
        resolvedOwner?.decorationCode ??
        cachedOwner?.decorationCode;
    final ownerDecorScale = currentUser?.avatarDecorationScale ??
        resolvedOwner?.decorationScale ??
        1.05;

    final authorFont = isOwner
        ? (currentUser?.profileFontData ?? resolvedOwner?.profileFontData)
        : resolvedAuthor?.profileFontData;
    final resolvedReply = msg.replyTo != null
        ? UserDecorResolver.instance.get(msg.replyTo!.username)
        : null;

    final isHighlighted = _highlightedMessageId == msg.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isOwner ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwner) ...[
            GestureDetector(
              onTap: () {
                showUserProfileCard(context, username: msg.username);
              },
              child: DecoratedAvatar(
                radius: 16,
                avatarUrl: senderAvatar,
                decorationUrl: senderDecor,
                decorationCode: senderDecorCode,
                decorationScale: senderDecorScale,
                fallbackName: msg.username,
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: () => _showBubbleActions(msg, isOwner),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFFFF2D55).withValues(alpha: 0.22)
                      : (hasBg
                          ? Colors.transparent
                          : (isOwner
                              ? (isDark ? const Color(0xFF2C2C2E) : Colors.black)
                              : (isDark ? const Color(0xFF1E1E22) : Colors.white))),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isOwner ? 18 : 4),
                    bottomRight: Radius.circular(isOwner ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isHighlighted
                        ? const Color(0xFFFF2D55)
                        : (hasBg
                            ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)
                            : (isOwner
                                ? (isDark ? Colors.white24 : Colors.transparent)
                                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)))),
                    width: isHighlighted ? 2.0 : 0.8,
                  ),
                  boxShadow: [
                    if (isHighlighted)
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 1.5,
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17.5),
                    topRight: const Radius.circular(17.5),
                    bottomLeft: Radius.circular(isOwner ? 17.5 : 3.5),
                    bottomRight: Radius.circular(isOwner ? 3.5 : 17.5),
                  ),
                  child: Stack(
                    children: [
                      if (hasBg)
                        Positioned.fill(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CalmGif(
                                source: msg.fullBackgroundUrl!,
                                fit: BoxFit.cover,
                                speed: _themeService.animSpeed,
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: 0.38),
                              ),
                            ],
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isOwner) ...[
                              GestureDetector(
                                onTap: () {
                                  showUserProfileCard(context, username: msg.username);
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.username,
                                      style: (authorFont != null)
                                          ? authorFont.textStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: hasBg
                                                  ? effectiveTextColor.withValues(alpha: 0.85)
                                                  : (isDark ? Colors.white : Colors.black),
                                            )
                                          : TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: hasBg
                                                  ? effectiveTextColor.withValues(alpha: 0.85)
                                                  : (isDark ? Colors.white : Colors.black),
                                            ),
                                    ),
                                    if (isSenderVerified) ...[
                                      const SizedBox(width: 3.5),
                                      const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 11.5,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ],
                                    if (resolvedAuthor?.genreRole != null) ...[
                                      const SizedBox(width: 4),
                                      GenreRoleBadge(
                                        role: resolvedAuthor!.genreRole!,
                                        compact: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                            ] else if (isSenderVerified || resolvedOwner?.genreRole != null) ...[
                              GestureDetector(
                                onTap: () {
                                  showUserProfileCard(context, username: msg.username.isNotEmpty ? msg.username : (currentUser?.username ?? ''));
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.username.isNotEmpty ? msg.username : (currentUser?.username ?? 'Anda'),
                                      style: (authorFont != null)
                                          ? authorFont.textStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: hasBg
                                                  ? effectiveTextColor.withValues(alpha: 0.85)
                                                  : Colors.white.withValues(alpha: 0.95),
                                            )
                                          : TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: hasBg
                                                  ? effectiveTextColor.withValues(alpha: 0.85)
                                                  : Colors.white.withValues(alpha: 0.95),
                                            ),
                                    ),
                                    if (isSenderVerified) ...[
                                      const SizedBox(width: 3.5),
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(0.5),
                                        child: const Icon(
                                          CupertinoIcons.checkmark_seal_fill,
                                          size: 11.5,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ),
                                    ],
                                    if (resolvedOwner?.genreRole != null) ...[
                                      const SizedBox(width: 4),
                                      GenreRoleBadge(
                                        role: resolvedOwner!.genreRole!,
                                        compact: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],

                            if (msg.replyTo != null) ...[
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  final targetId = (msg.replyTo!.id != 0) ? msg.replyTo!.id : msg.replyToId;
                                  if (targetId != null && targetId != 0) {
                                    _scrollToMessage(targetId);
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border(
                                      left: BorderSide(
                                        color: isOwner ? Colors.white : (isDark ? Colors.white : Colors.black),
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.reply,
                                            size: 10,
                                            color: isOwner ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              msg.replyTo!.username,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isOwner ? Colors.white70 : (isDark ? Colors.white : Colors.black),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isReplyVerified) ...[
                                            const SizedBox(width: 3),
                                            const Icon(
                                              CupertinoIcons.checkmark_seal_fill,
                                              size: 10.5,
                                              color: Color(0xFF007AFF),
                                            ),
                                          ],
                                          if (resolvedReply?.genreRole != null) ...[
                                            const SizedBox(width: 3.5),
                                            GenreRoleBadge(
                                              role: resolvedReply!.genreRole!,
                                              compact: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 1.5),
                                      Text(
                                        msg.replyTo!.message.isNotEmpty
                                            ? msg.replyTo!.message
                                            : (msg.replyTo!.hasMedia ? '[Media lampiran]' : ''),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: effectiveTextColor.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            if (hasAttachedMedia) ...[
                              GestureDetector(
                                onTap: () => _viewFullPhoto(context, msg.fullMediaUrl!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
                                    child: (msg.mediaType == 'gif' || msg.fullMediaUrl!.toLowerCase().endsWith('.gif'))
                                        ? CalmGif(
                                            source: msg.fullMediaUrl!,
                                            fit: BoxFit.cover,
                                            speed: 0.75,
                                          )
                                        : AppNetworkImage(
                                            url: msg.fullMediaUrl!,
                                            width: 280,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            borderRadius: 16,
                                            memCacheWidth: 480,
                                            placeholder: Container(
                                              width: 260,
                                              height: 160,
                                              color: isDark ? Colors.white10 : Colors.black12,
                                              child: const Center(
                                                child: CupertinoActivityIndicator(radius: 10),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              if (msg.displayMessage.isNotEmpty) const SizedBox(height: 6),
                            ],

                            if (msg.displayMessage.isNotEmpty)
                              _buildMentionRichText(msg, effectiveTextColor, isDark, authorFont),

                            if (msg.taggedContent != null)
                              _buildTaggedContentCard(msg.taggedContent!, isDark, isOwner),

                            const SizedBox(height: 3),

                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (msg.isEdited) ...[
                                    Text(
                                      'diedit • ',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: effectiveTextColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: effectiveTextColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (isOwner) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      CupertinoIcons.checkmark_alt,
                                      size: 11,
                                      color: effectiveTextColor.withValues(alpha: 0.7),
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
                ),
              ),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showUserProfileCard(
                  context,
                  username: msg.username.isNotEmpty ? msg.username : (currentUser?.username ?? ''),
                );
              },
              child: DecoratedAvatar(
                radius: 16,
                avatarUrl: ownerAvatar,
                decorationUrl: ownerDecor,
                decorationCode: ownerDecorCode,
                decorationScale: ownerDecorScale,
                fallbackName: msg.username.isNotEmpty ? msg.username : (currentUser?.username ?? 'Anda'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMentionRichText(
    ChatMessageModel msg,
    Color textColor,
    bool isDark, [
    ProfileFontModel? fontModel,
  ]) {
    final text = msg.displayMessage;
    final spans = <InlineSpan>[];
    final regex = RegExp(r'@([A-Za-z0-9_.]+)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        final rawStyle = TextStyle(fontSize: 13.5, height: 1.35, color: textColor);
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: fontModel != null
                ? fontModel.textStyle(fontSize: 13.5, height: 1.35, color: textColor)
                : rawStyle,
          ),
        );
      }

      final fullMention = match.group(0)!;
      final rawUsername = match.group(1)!;
      final isValid = msg.isMentionValid(rawUsername);
      final mentionUser = msg.getMentionUser(rawUsername);

      if (isValid) {
        // Registered user in DB -> Blue pill, clickable to open UserProfileCardModal
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                showUserProfileCard(
                  context,
                  username: mentionUser?.username ?? rawUsername,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: textColor.withValues(alpha: 0.32),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    fullMention,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // Unregistered user (not in DB) -> Red highlight as requested, message still delivered!
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: '@$rawUsername belum terdaftar',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF2C2C2E),
                      content: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle, color: Color(0xFFFF453A), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '@$rawUsername belum terdaftar',
                            style: const TextStyle(fontSize: 12.5, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF453A).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFFF453A).withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      fullMention,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF453A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final rawStyle = TextStyle(fontSize: 13.5, height: 1.35, color: textColor);
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: fontModel != null
              ? fontModel.textStyle(fontSize: 13.5, height: 1.35, color: textColor)
              : rawStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: text.trim().length > 30 ? TextAlign.justify : TextAlign.start,
    );
  }

  Widget _buildMentionSuggestionsPopup(bool isDark, [UserModel? currentUser]) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _mentionSuggestions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        itemBuilder: (ctx, idx) {
          final u = _mentionSuggestions[idx];
          final isUserVerified = u.verifiedBadge ||
              (currentUser != null &&
                  currentUser.verifiedBadge &&
                  (u.username.toLowerCase() == currentUser.username.toLowerCase() ||
                      u.id == currentUser.id));
          return ListTile(
            dense: true,
            leading: DecoratedAvatar(
              radius: 14,
              avatarUrl: u.avatar != null && u.avatar!.isNotEmpty
                  ? UserModel.normalizeAvatarUrl(u.avatar)
                  : (UserDecorResolver.instance.get(u.username)?.avatarUrl ?? _userDecorCache[u.username.toLowerCase()]?.avatar),
              decorationUrl: UserDecorResolver.instance.get(u.username)?.decorationUrl ?? _userDecorCache[u.username.toLowerCase()]?.decorationUrl,
              decorationCode: UserDecorResolver.instance.get(u.username)?.decorationCode ?? _userDecorCache[u.username.toLowerCase()]?.decorationCode,
              decorationScale: UserDecorResolver.instance.get(u.username)?.decorationScale ?? 1.05,
              fallbackName: u.username,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${u.username}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (isUserVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    size: 13,
                    color: Color(0xFF007AFF),
                  ),
                ],
              ],
            ),
            onTap: () => _selectMention(u),
          );
        },
      ),
    );
  }

  Widget _buildReplyingBanner(bool isDark, [UserModel? currentUser]) {
    final rep = _replyingTo!;
    final isReplyingVerified = rep.verifiedBadge ||
        (currentUser != null &&
            currentUser.verifiedBadge &&
            (rep.username.toLowerCase() == currentUser.username.toLowerCase() ||
                rep.userId == currentUser.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE5E5EA),
      child: Row(
        children: [
          Icon(CupertinoIcons.reply, size: 16, color: isDark ? Colors.white : Colors.black),
          DecoratedAvatar(
            radius: 13,
            avatarUrl: rep.authorAvatarUrl,
            decorationUrl: rep.fullAvatarDecorationUrl ??
                UserDecorResolver.instance.get(rep.username)?.decorationUrl ??
                _userDecorCache[rep.username.toLowerCase()]?.decorationUrl,
            decorationCode: rep.avatarDecorationCode ??
                UserDecorResolver.instance.get(rep.username)?.decorationCode ??
                _userDecorCache[rep.username.toLowerCase()]?.decorationCode,
            decorationScale: UserDecorResolver.instance.get(rep.username)?.decorationScale ?? 1.05,
            fallbackName: rep.username,
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.reply, size: 14, color: isDark ? Colors.white : Colors.black),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Membalas ${rep.username}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (isReplyingVerified) ...[
                      const SizedBox(width: 3.5),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 12,
                        color: Color(0xFF007AFF),
                      ),
                    ],
                  ],
                ),
                Text(
                  rep.message.isNotEmpty
                      ? rep.message
                      : (rep.hasMedia ? '[Media lampiran]' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
            color: isDark ? Colors.white54 : Colors.black45,
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildTaggedContentCard(ChatTaggedContent tag, bool isDark, bool isOwner) {
    final isAnime = tag.type == 'anime';
    final badgeLabel = isAnime ? '🎬 ANIME' : '📚 KOMIK';
    final accentColor = isAnime
        ? (isDark || isOwner ? const Color(0xFFFF5277) : const Color(0xFFFF2D55))
        : (isDark || isOwner ? const Color(0xFFC778F4) : const Color(0xFFAF52DE));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (isAnime) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => AnimeDetailScreen(animeId: tag.id),
            ),
          );
        } else {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ComicDetailScreen(slug: tag.id),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isOwner
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.18))
              : (isDark ? AppColors.darkCardElevated : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwner
                ? Colors.white.withValues(alpha: 0.20)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Poster thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 60,
                color: isOwner
                    ? Colors.white.withValues(alpha: 0.10)
                    : (isDark ? AppColors.darkCard : const Color(0xFFE5E5EA)),
                child: (tag.thumb != null && tag.thumb!.isNotEmpty)
                    ? AppNetworkImage(
                        url: tag.thumb!,
                        width: 44,
                        height: 60,
                        fit: BoxFit.cover,
                        borderRadius: 12,
                        placeholder: Icon(
                          isAnime ? CupertinoIcons.film : CupertinoIcons.book,
                          size: 20,
                          color: isOwner ? Colors.white54 : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      )
                    : Icon(
                        isAnime ? CupertinoIcons.film : CupertinoIcons.book,
                        size: 20,
                        color: isOwner ? Colors.white54 : (isDark ? Colors.white38 : Colors.black38),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isOwner ? 0.26 : (isDark ? 0.20 : 0.12)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isOwner ? 0.50 : (isDark ? 0.40 : 0.28)),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tag.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isOwner
                          ? Colors.white
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      height: 1.2,
                    ),
                  ),
                  if (tag.extra != null && tag.extra!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tag.extra!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isOwner
                            ? Colors.white70
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: isOwner ? Colors.white60 : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagedAttachmentsPreview(bool isDark) {
    final hasMedia = _stagedMediaFile != null || (_stagedMediaUrl != null && _stagedMediaUrl!.isNotEmpty);
    final hasTag = _stagedTaggedContent != null;
    if (!hasMedia && !hasTag) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMedia) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _stagedMediaFile != null
                        ? (_stagedMediaFile!.path.toLowerCase().endsWith('.gif')
                            ? CalmGif(source: _stagedMediaFile!.path, fit: BoxFit.cover, speed: 0.75)
                            : Image.file(_stagedMediaFile!, fit: BoxFit.cover))
                        : CalmGif(source: _stagedMediaUrl!, fit: BoxFit.cover, speed: 0.75),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _stagedMediaType == 'gif' || (_stagedMediaFile?.path.toLowerCase().endsWith('.gif') ?? false)
                            ? 'Animasi GIF terlampir'
                            : 'Foto terlampir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        _stagedMediaFile != null
                            ? _stagedMediaFile!.path.split(Platform.pathSeparator).last
                            : 'GIF reaksi anime online',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  onPressed: () => setState(() {
                    _stagedMediaFile = null;
                    _stagedMediaUrl = null;
                    _stagedMediaType = 'none';
                  }),
                ),
              ],
            ),
          ],
          if (hasMedia && hasTag) const SizedBox(height: 6),
          if (hasTag) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _stagedTaggedContent!.type == 'anime'
                      ? const Color(0xFFFF2D55).withValues(alpha: isDark ? 0.45 : 0.35)
                      : const Color(0xFFAF52DE).withValues(alpha: isDark ? 0.45 : 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 42,
                      color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                      child: (_stagedTaggedContent!.thumb != null && _stagedTaggedContent!.thumb!.isNotEmpty)
                          ? AppNetworkImage(
                              url: _stagedTaggedContent!.thumb!,
                              width: 32,
                              height: 42,
                              fit: BoxFit.cover,
                              placeholder: Icon(
                                _stagedTaggedContent!.type == 'anime' ? CupertinoIcons.film : CupertinoIcons.book,
                                size: 16,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            )
                          : Icon(
                              _stagedTaggedContent!.type == 'anime' ? CupertinoIcons.film : CupertinoIcons.book,
                              size: 16,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _stagedTaggedContent!.type == 'anime' ? '🎬 Tag Anime' : '📚 Tag Komik',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _stagedTaggedContent!.type == 'anime'
                                ? (isDark ? const Color(0xFFFF5277) : const Color(0xFFFF2D55))
                                : (isDark ? const Color(0xFFC778F4) : const Color(0xFFAF52DE)),
                          ),
                        ),
                        Text(
                          _stagedTaggedContent!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _stagedTaggedContent = null),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, bool isAuthenticated) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.add_circled_solid, color: isDark ? Colors.white : Colors.black, size: 25),
            tooltip: 'Lampirkan & Tag',
            onPressed: isAuthenticated ? () => _showAttachmentMenu(context, isDark) : null,
          ),
          IconButton(
            icon: Icon(CupertinoIcons.photo, color: isDark ? Colors.white70 : Colors.black54, size: 22),
            tooltip: 'Galeri Foto / GIF',
            onPressed: isAuthenticated ? () => _pickMediaFromSource(ImageSource.gallery) : null,
          ),
          Expanded(
            child: CupertinoTextField(
              controller: _textController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              placeholder: isAuthenticated ? 'Tulis pesan (@ untuk sebut)...' : 'Masuk untuk mengirim pesan...',
              placeholderStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242428) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: (!isAuthenticated || _isSending) ? null : _sendMessage,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isSending
                  ? CupertinoActivityIndicator(color: isDark ? Colors.black : Colors.white, radius: 8)
                  : Icon(CupertinoIcons.arrow_up, color: isDark ? Colors.black : Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    return AppDateUtils.formatTime(dateStr);
  }
}

/// Sheet for Mentions & Reply Notifications
class _NotificationsSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onRefreshSummary;

  const _NotificationsSheet({
    required this.isDark,
    required this.onRefreshSummary,
  });

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _repo = ChatRepository.instance;

  List<ChatMentionItemModel> _mentions = [];
  List<ChatReplyNotificationItemModel> _replies = [];
  bool _loadingMentions = true;
  bool _loadingReplies = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchMentions();
    _fetchReplies();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMentions() async {
    final list = await _repo.getMentions(page: 1, perPage: 30);
    if (!mounted) return;
    setState(() {
      _mentions = list;
      _loadingMentions = false;
    });
  }

  Future<void> _fetchReplies() async {
    final list = await _repo.getReplyNotifications(page: 1, perPage: 30);
    if (!mounted) return;
    setState(() {
      _replies = list;
      _loadingReplies = false;
    });
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    widget.onRefreshSummary();
    if (!mounted) return;
    setState(() {
      _mentions = _mentions.map((m) => ChatMentionItemModel(
        id: m.id,
        messageId: m.messageId,
        messagePreview: m.messagePreview,
        fullMessage: m.fullMessage,
        mediaUrl: m.mediaUrl,
        mediaType: m.mediaType,
        hasMedia: m.hasMedia,
        mentionedBy: m.mentionedBy,
        mentionedByUsername: m.mentionedByUsername,
        mentionedByAvatar: m.mentionedByAvatar,
        isRead: true,
        verifiedBadge: m.verifiedBadge,
        createdAt: m.createdAt,
      ),).toList();

      _replies = _replies.map((r) => ChatReplyNotificationItemModel(
        id: r.id,
        messageId: r.messageId,
        originalMessage: r.originalMessage,
        originalMessageId: r.originalMessageId,
        replyMessage: r.replyMessage,
        mediaUrl: r.mediaUrl,
        mediaType: r.mediaType,
        hasMedia: r.hasMedia,
        repliedBy: r.repliedBy,
        repliedByUsername: r.repliedByUsername,
        repliedByAvatar: r.repliedByAvatar,
        isRead: true,
        verifiedBadge: r.verifiedBadge,
        createdAt: r.createdAt,
      ),).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifikasi Chat',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _markAllRead,
                child: Text(
                  'Tandai Semua Dibaca',
                  style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: widget.isDark ? Colors.white : Colors.black,
            unselectedLabelColor: widget.isDark ? Colors.white54 : Colors.black54,
            indicatorColor: widget.isDark ? Colors.white : Colors.black,
            tabs: const [
              Tab(text: 'Mention (@)'),
              Tab(text: 'Balasan Pesan'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _loadingMentions
                    ? const Center(child: CupertinoActivityIndicator())
                    : _mentions.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada sebutan mention',
                              style: TextStyle(
                                color: widget.isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _mentions.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (ctx, i) {
                              final m = _mentions[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                  child: Text(
                                    m.mentionedByUsername?.isNotEmpty == true
                                        ? m.mentionedByUsername![0].toUpperCase()
                                        : '?',
                                    style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '@${m.mentionedByUsername ?? "Seseorang"} menyebut Anda',
                                        style: TextStyle(
                                          fontWeight: m.isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 13,
                                          color: widget.isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (m.verifiedBadge) ...[
                                      const SizedBox(width: 3.5),
                                      const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 12,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.messagePreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                    if (m.createdAt != null && m.createdAt!.isNotEmpty)
                                      Text(
                                        AppDateUtils.formatTimeAgo(m.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: widget.isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: !m.isRead
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: widget.isDark ? Colors.white : Colors.black,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  _repo.markMentionRead(m.id);
                                  widget.onRefreshSummary();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                _loadingReplies
                    ? const Center(child: CupertinoActivityIndicator())
                    : _replies.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada balasan pesan',
                              style: TextStyle(
                                color: widget.isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _replies.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (ctx, i) {
                              final r = _replies[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                  child: Text(
                                    r.repliedByUsername?.isNotEmpty == true
                                        ? r.repliedByUsername![0].toUpperCase()
                                        : '?',
                                    style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${r.repliedByUsername ?? "Seseorang"} membalas pesan Anda',
                                        style: TextStyle(
                                          fontWeight: r.isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 13,
                                          color: widget.isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (r.verifiedBadge) ...[
                                      const SizedBox(width: 3.5),
                                      const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 12,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.replyMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                    if (r.createdAt != null && r.createdAt!.isNotEmpty)
                                      Text(
                                        AppDateUtils.formatTimeAgo(r.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: widget.isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: !r.isRead
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: widget.isDark ? Colors.white : Colors.black,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  _repo.markReplyNotificationRead(r.id);
                                  widget.onRefreshSummary();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal picker for searching and tagging Anime or Comic into chat discussions
class _TagContentModal extends StatefulWidget {
  final bool isDark;
  final int initialTab;
  final ValueChanged<ChatTaggedContent> onSelected;

  const _TagContentModal({
    required this.isDark,
    required this.initialTab,
    required this.onSelected,
  });

  @override
  State<_TagContentModal> createState() => _TagContentModalState();
}

class _TagContentModalState extends State<_TagContentModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<AnimeModel> _animeResults = [];
  List<ComicModel> _comicResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Trigger rebuild for active tab UI
      }
      if (!_tabController.indexIsChanging) {
        _performSearch(_searchController.text.trim());
      }
    });
    // Load initial recommendations/ongoing/popular
    _loadInitialItems();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialItems() async {
    setState(() => _isLoading = true);
    try {
      if (_tabController.index == 0) {
        final ongoing = await AnimeRepository.instance.ongoing();
        if (mounted) {
          setState(() {
            _animeResults = ongoing.take(20).toList();
            _isLoading = false;
          });
        }
      } else {
        // Coba daftar komik (A-Z) terlebih dahulu karena sangat stabil dan cepat
        List<ComicModel> items = [];
        try {
          final res = await ComicRepository.instance.daftarKomik(halaman: 1);
          items = res.items;
        } catch (_) {}

        if (items.isEmpty) {
          try {
            items = await ComicRepository.instance.terbaru();
          } catch (_) {}
        }
        if (items.isEmpty) {
          try {
            items = await ComicRepository.instance.populer();
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _comicResults = items.take(30).toList();
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _loadInitialItems();
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_tabController.index == 0) {
        final results = await AnimeRepository.instance.search(query);
        if (mounted) {
          setState(() {
            _animeResults = results;
            _isLoading = false;
          });
        }
      } else {
        List<ComicModel> results = [];
        try {
          results = await ComicRepository.instance.search(query);
        } catch (_) {}

        // Fallback filter lokal jika backend search sedang lambat/timeout
        if (results.isEmpty) {
          try {
            final res = await ComicRepository.instance.daftarKomik(halaman: 1);
            final qLower = query.toLowerCase();
            results = res.items.where((c) => c.title.toLowerCase().contains(qLower)).toList();
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _comicResults = results;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtext = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Title and close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _tabController.index == 0 ? CupertinoIcons.film : CupertinoIcons.book,
                      color: _tabController.index == 0
                          ? (isDark ? const Color(0xFFFF5277) : const Color(0xFFFF2D55))
                          : (isDark ? const Color(0xFFC778F4) : const Color(0xFFAF52DE)),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tag untuk Obrolan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(CupertinoIcons.clear_thick_circled, size: 20),
                      color: subtext,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab Bar (Anime & Comic)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: text,
                  unselectedLabelColor: subtext,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.play_circle, size: 16),
                          SizedBox(width: 6),
                          Text('🎬 Anime'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.book, size: 16),
                          SizedBox(width: 6),
                          Text('📚 Komik / Manga'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: _tabController.index == 0 ? 'Cari judul anime...' : 'Cari judul komik / manga...',
                  style: TextStyle(color: text),
                  placeholderStyle: TextStyle(color: subtext),
                  backgroundColor: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: _onSearchChanged,
                ),
              ),

              // Content List
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _tabController.index == 0
                        ? _buildAnimeList(scrollCtrl, isDark)
                        : _buildComicList(scrollCtrl, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimeList(ScrollController scrollCtrl, bool isDark) {
    if (_animeResults.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada anime ditemukan',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        ),
      );
    }

    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _animeResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 12,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      itemBuilder: (context, i) {
        final item = _animeResults[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 56,
              color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
              child: (item.thumb != null && item.thumb!.isNotEmpty)
                  ? AppNetworkImage(
                      url: item.thumb!,
                      width: 44,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: const Icon(CupertinoIcons.film, size: 20),
                    )
                  : const Icon(CupertinoIcons.film, size: 20),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          subtitle: Row(
            children: [
              if (item.episode != null && item.episode!.isNotEmpty) ...[
                Text(
                  item.episode!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFFF5277) : const Color(0xFFFF2D55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (item.score != null && item.score!.isNotEmpty) ...[
                const Icon(CupertinoIcons.star_fill, size: 10, color: Color(0xFFFFB300)),
                const SizedBox(width: 3),
                Text(
                  item.score!,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
                ),
              ],
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF2D55).withValues(alpha: isDark ? 0.45 : 0.30),
                width: 0.6,
              ),
            ),
            child: Text(
              'Tag',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFFF6482) : const Color(0xFFFF2D55),
              ),
            ),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onSelected(
              ChatTaggedContent(
                type: 'anime',
                id: item.id,
                title: item.title,
                thumb: item.thumb,
                extra: item.episode ?? (item.score != null ? 'Skor: ${item.score}' : null),
              ),
            );
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildComicList(ScrollController scrollCtrl, bool isDark) {
    if (_comicResults.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada komik ditemukan',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        ),
      );
    }

    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _comicResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 12,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      itemBuilder: (context, i) {
        final item = _comicResults[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 56,
              color: isDark ? AppColors.darkCardElevated : const Color(0xFFE5E5EA),
              child: (item.thumb != null && item.thumb!.isNotEmpty)
                  ? AppNetworkImage(
                      url: item.thumb!,
                      width: 44,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: const Icon(CupertinoIcons.book, size: 20),
                    )
                  : const Icon(CupertinoIcons.book, size: 20),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          subtitle: Row(
            children: [
              if (item.latestChapter != null && item.latestChapter!.isNotEmpty) ...[
                Text(
                  item.latestChapter!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFC778F4) : const Color(0xFFAF52DE),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (item.type != null && item.type!.isNotEmpty)
                Text(
                  item.type!,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
                ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFAF52DE).withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFAF52DE).withValues(alpha: isDark ? 0.45 : 0.30),
                width: 0.6,
              ),
            ),
            child: Text(
              'Tag',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFD084F7) : const Color(0xFFAF52DE),
              ),
            ),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onSelected(
              ChatTaggedContent(
                type: 'comic',
                id: item.slug,
                title: item.title,
                thumb: item.thumb,
                extra: item.latestChapter ?? item.type,
              ),
            );
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

