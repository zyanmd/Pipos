import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/leaderboard_user_model.dart';

class GamificationRepository {
  GamificationRepository._();
  static final GamificationRepository instance = GamificationRepository._();

  /// Mengambil data papan peringkat (Leaderboard)
  Future<LeaderboardResponse?> getLeaderboard({
    String period = 'all', // 'all', 'monthly', 'weekly'
    int limit = 50,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        ApiConfig.userLeaderboard,
        queryParameters: {
          'period': period,
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        return LeaderboardResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (_) {}
    return null;
  }

  /// Mengambil data XP, Level, Rank, dan riwayat XP pengguna saat ini
  Future<XpSummaryModel?> getXpSummary() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.userXpMe);
      if (response.statusCode == 200 && response.data is Map) {
        return XpSummaryModel.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (_) {}
    return null;
  }

  /// Mengklaim bonus check-in harian (XP + Streak)
  Future<Map<String, dynamic>?> claimDailyBonus() async {
    try {
      final response = await ApiClient.instance.post(ApiConfig.userXpClaimDaily);
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        return Map<String, dynamic>.from(e.response!.data as Map);
      }
    }
    return null;
  }
}
