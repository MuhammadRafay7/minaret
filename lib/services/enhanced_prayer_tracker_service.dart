// Model classes re-exported from PrayerRepository for backward compatibility.
// Widgets/providers that import from here will continue to compile unchanged.
export '../repositories/prayer_repository.dart'
    show PrayerRecord, UserPrayerStats;

import '../core/dependency_injection.dart';
import '../repositories/prayer_repository.dart';

// Backward-compatible static facade — delegates all Firestore I/O to
// PrayerRepository which is registered in the DI container.
class EnhancedPrayerTrackerService {
  static PrayerRepository get _repo =>
      ServiceLocator.get<PrayerRepository>();

  static Future<UserPrayerStats?> togglePrayer(String prayerName) async {
    try {
      return await _repo.togglePrayer(prayerName);
    } catch (e) {
      throw Exception('Failed to toggle prayer: $e');
    }
  }

  static Future<List<String>> getTodayPrayers() =>
      _repo.getTodayPrayers();

  static Future<List<PrayerRecord>> getPrayerRecords({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _repo.getPrayerRecords(startDate: startDate, endDate: endDate);

  static Future<UserPrayerStats?> getUserStats(String userId) =>
      _repo.getUserStats(userId);

  static Future<UserPrayerStats?> getCurrentUserStats() =>
      _repo.getCurrentUserStats();

  static Future<List<UserPrayerStats>> getLeaderboard({
    String sortBy = 'currentStreak',
    int limit = 10,
  }) =>
      _repo.getLeaderboard(sortBy: sortBy, limit: limit);

  static Future<Map<String, dynamic>> getAnalyticsData() =>
      _repo.getAnalyticsData();
}
