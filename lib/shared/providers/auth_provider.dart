import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/services/adult_content_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/chat/services/chat_theme_service.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/services/comment_theme_service.dart';
import '../../core/services/onesignal_service.dart';

/// Holds the current authenticated user (or null when logged out).
/// Anything that needs to know "am I logged in?" subscribes to this.
class AuthProvider extends ChangeNotifier {
  AuthProvider._();
  static final AuthProvider instance = AuthProvider._();

  UserModel? _user;
  UserModel? get user => _user;
  UserModel? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  bool _loading = false;
  bool get loading => _loading;
  String? _error;
  String? get error => _error;

  void _notifyUserScope(UserModel? u) {
    final uidStr = u != null && u.id > 0 ? u.id.toString() : null;
    final uidInt = u != null && u.id > 0 ? u.id : null;
    CommentThemeService.instance.switchUser(uidStr);
    ChatThemeService.instance.switchUser(uidStr);
    AdultContentService.instance.switchUser(uidInt);
    if (uidStr != null) {
      OneSignalService.instance.login(uidStr);
      if (u != null) {
        OneSignalService.instance.syncFromServer(
          u.notifMode ?? 'all',
          animeMode: u.animeNotifMode,
          comicMode: u.comicNotifMode,
          birthdayEnabled: u.birthdayNotifEnabled,
        );
        OneSignalService.instance.syncUserTags(u);
      }
    } else {
      OneSignalService.instance.logout();
    }
  }

  /// Restore cached user state instantly (0ms) from local storage to avoid guest flicker
  void fastRestore() {
    final cached = TokenStore.savedUser;
    if (cached != null && cached.username.isNotEmpty) {
      _user = cached;
      _notifyUserScope(_user);
    }
  }

  /// Fetch fresh profile in background without blocking initial app render
  Future<void> refreshProfileInBackground() async {
    final access = await TokenStore.access;
    if (access == null || access.isEmpty) {
      if (_user != null) {
        _user = null;
        _notifyUserScope(null);
        notifyListeners();
      }
      return;
    }

    try {
      UserModel? fresh;
      try {
        fresh = await ProfileRepository.instance.me();
      } catch (_) {
        fresh = await AuthRepository.instance.me();
      }
      if (fresh.username.isNotEmpty) {
        _user = fresh;
        await TokenStore.saveUser(fresh);
        _notifyUserScope(_user);
        notifyListeners();
      }
    } catch (e) {
      // Only clear if server explicitly told us 401 Unauthorized (expired token)
      if (e is DioException && e.response?.statusCode == 401) {
        await TokenStore.clear();
        _user = null;
        _notifyUserScope(null);
        notifyListeners();
      }
    }
  }

  Future<void> bootstrap() async {
    fastRestore();
    await refreshProfileInBackground();
  }

  Future<bool> login({
    required String emailOrUsername,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await AuthRepository.instance.login(
        emailOrUsername: emailOrUsername,
        password: password,
      );
      await TokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      if (session.user.username.isNotEmpty) {
        await TokenStore.saveUser(session.user);
      }
      _user = session.user;
      _notifyUserScope(_user);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = AuthRepository.instance.errorMessage(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await AuthRepository.instance.loginWithGoogle();
      await TokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      if (session.user.username.isNotEmpty) {
        await TokenStore.saveUser(session.user);
      }
      _user = session.user;
      _notifyUserScope(_user);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[GoogleSignIn Error] $e');
      final msg = e.toString();
      if (msg.contains('dibatalkan') || msg.contains('canceled') || msg.contains('cancelled') || msg.contains('Sign in canceled by user')) {
        _loading = false;
        notifyListeners();
        return false;
      }
      _error = AuthRepository.instance.errorMessage(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await AuthRepository.instance.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );
      // Clear any tokens or user from previous session so nothing bleeds into the new account
      await TokenStore.clear();
      _user = null;
      _notifyUserScope(null);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = AuthRepository.instance.errorMessage(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void clearUser() {
    _user = null;
    _notifyUserScope(null);
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthRepository.instance.logout();
    await TokenStore.clear();
    _user = null;
    _notifyUserScope(null);
    notifyListeners();
  }

  void setUser(UserModel u) {
    _user = u;
    if (u.username.isNotEmpty) {
      TokenStore.saveUser(u);
    }
    _notifyUserScope(_user);
    notifyListeners();
  }

  Future<UserModel?> refreshUser() async {
    try {
      UserModel? fresh;
      try {
        fresh = await ProfileRepository.instance.me();
      } catch (_) {
        fresh = await AuthRepository.instance.me();
      }
      if (fresh.username.isNotEmpty) {
        _user = fresh;
        await TokenStore.saveUser(fresh);
        _notifyUserScope(_user);
        notifyListeners();
        return fresh;
      }
    } catch (_) {}
    return _user;
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
