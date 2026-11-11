import 'package:flutter/material.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/desktop_sidebar.dart';
import '../../../shared/widgets/ios_bottom_nav_bar.dart';
import '../../anime/presentation/anime_home_screen.dart';
import '../../comic/presentation/comic_home_screen.dart';
import '../../review/presentation/review_home_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../update/services/app_update_service.dart';

/// Main shell with floating floating bubble bottom navigation.
/// Four tabs: Anime, Komik, Ulas, Profil — each with its own nested navigator.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  bool _isAtRoot = true;
  final Set<int> _loadedTabs = {0};

  // Each tab keeps its own navigator stack.
  final _animeKey = GlobalKey<NavigatorState>(debugLabel: 'anime_nav');
  final _comicKey = GlobalKey<NavigatorState>(debugLabel: 'comic_nav');
  final _reviewKey = GlobalKey<NavigatorState>(debugLabel: 'review_nav');
  final _profileKey = GlobalKey<NavigatorState>(debugLabel: 'profile_nav');

  late final List<_TabSpec> _tabs;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _tabs = [
      _TabSpec(
        navigatorKey: _animeKey,
        builder: (_) => const AnimeHomeScreen(),
      ),
      _TabSpec(
        navigatorKey: _comicKey,
        builder: (_) => const ComicHomeScreen(),
      ),
      _TabSpec(
        navigatorKey: _reviewKey,
        builder: (_) => const ReviewHomeScreen(),
      ),
      _TabSpec(
        navigatorKey: _profileKey,
        builder: (_) => const ProfileScreen(),
      ),
    ];

    // Background update check on startup
    AppUpdateService.instance.checkAndShowUpdate(context, isManual: false);

    // Flush any queued incoming deep link once RootShell is mounted
    DeepLinkService.instance.markAppReady();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTab(int index) {
    if (index == _currentIndex) {
      // Re-tapping active tab: pop to its root
      _tabs[index].navigatorKey.currentState?.popUntil((r) => r.isFirst);
      _checkNavState();
    } else {
      // 🔥 Pastikan tidak ada anime/video yang terus terputar saat berpindah tab!
      PipService.instance.pauseAllPlayers();
      PipService.instance.disablePipNow();
      setState(() {
        _currentIndex = index;
        _loadedTabs.add(index);
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      _checkNavState();
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      PipService.instance.pauseAllPlayers();
      PipService.instance.disablePipNow();
      setState(() {
        _currentIndex = index;
        _loadedTabs.add(index);
      });
      _checkNavState();
    }
  }

  void _checkNavState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = _tabs[_currentIndex].navigatorKey.currentState;
      final canPop = nav?.canPop() ?? false;
      final atRoot = !canPop;
      if (atRoot != _isAtRoot) {
        setState(() => _isAtRoot = atRoot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0 && !(_tabs[_currentIndex].navigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Pop nested navigator first
        final nav = _tabs[_currentIndex].navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          _checkNavState();
          return;
        }
        // Otherwise switch to tab 0
        if (_currentIndex != 0) {
          _onTab(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Responsive.isDesktop(context);

          if (isDesktop) {
            return Scaffold(
              body: Row(
                children: [
                  DesktopSidebar(
                    currentIndex: _currentIndex,
                    onTap: _onTab,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildPagesStack(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            extendBody: true,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _buildPagesStack(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: PipService.instance.isFullscreen,
                    builder: (context, isFullscreen, _) => ValueListenableBuilder<bool>(
                      valueListenable: PipService.instance.isInPip,
                      builder: (context, isInPip, _) {
                        final hideNavbars = isFullscreen || isInPip;
                        return AnimatedSlide(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          offset: (!hideNavbars && _isAtRoot) ? Offset.zero : const Offset(0, 1.4),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: (!hideNavbars && _isAtRoot) ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: hideNavbars || !_isAtRoot,
                              child: MokoBottomNavBar(
                                currentIndex: _currentIndex,
                                onTap: _onTab,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagesStack() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _tabs.length,
      physics: _isAtRoot
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) {
        final tab = _tabs[i];
        return _KeepAliveTab(
          child: NotificationListener<NavigationNotification>(
            onNotification: (_) {
              _checkNavState();
              return false;
            },
            child: Navigator(
              key: tab.navigatorKey,
              observers: [
                _TabNavObserver(onChanged: _checkNavState),
              ],
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: tab.builder,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TabSpec {
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;
  const _TabSpec({required this.navigatorKey, required this.builder});
}

class _TabNavObserver extends NavigatorObserver {
  final VoidCallback onChanged;
  _TabNavObserver({required this.onChanged});

  @override
  void didPush(Route route, Route? previousRoute) => onChanged();

  @override
  void didPop(Route route, Route? previousRoute) => onChanged();

  @override
  void didRemove(Route route, Route? previousRoute) => onChanged();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onChanged();
}