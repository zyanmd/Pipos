import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/models/user_model.dart';

class AdultContentService extends ChangeNotifier {
  AdultContentService._();
  static final AdultContentService instance = AdultContentService._();

  static const String _kAdultModeKey = 'adult_mode_18_unlocked';
  bool _is18Unlocked = false;

  bool get is18Unlocked => _is18Unlocked;
  bool get isHiddenFeatureOn => _is18Unlocked;

  Future<void> init({int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = userId != null ? '${_kAdultModeKey}_$userId' : _kAdultModeKey;
      _is18Unlocked = prefs.getBool(key) ?? prefs.getBool(_kAdultModeKey) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> switchUser(int? userId) async {
    await init(userId: userId);
  }

  Future<void> set18Unlocked(bool enabled, {int? userId}) async {
    _is18Unlocked = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAdultModeKey, enabled);
      if (userId != null) {
        await prefs.setBool('${_kAdultModeKey}_$userId', enabled);
      }
    } catch (_) {}
  }

  Future<void> setHiddenFeature(bool enabled, {int? userId}) async {
    await set18Unlocked(enabled, userId: userId);
  }

  bool is18Active(UserModel? user) => _is18Unlocked;
}
