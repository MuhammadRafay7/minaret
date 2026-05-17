import '../core/dependency_injection.dart';
import '../repositories/prayer_repository.dart';

// Backward-compatible static facade — delegates to PrayerRepository.
class PrayerTrackerService {
  static PrayerRepository get _repo =>
      ServiceLocator.get<PrayerRepository>();

  /// Call once in main() before runApp() to load SharedPreferences.
  static Future<void> init() => _repo.initLocal();

  static List<String> getDayStatus(DateTime date) =>
      _repo.getLocalDayStatus(date);

  static Future<void> togglePrayer(
          DateTime date, String prayerKey) =>
      _repo.toggleLocal(date, prayerKey);

  static int getStreak() => _repo.getLocalStreak();
}
