import '../repositories/progress_repository.dart';

const List<String> _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class CoinService {
  CoinService._();
  static final CoinService instance = CoinService._();

  final _repo = ProgressRepository();

  // Called after a prayer is toggled ON. completedToday is the NEW state.
  Future<void> onPrayerToggled(
    String prayerName,
    List<String> completedToday,
    int currentStreak,
  ) async {
    final progress = await _repo.getProgress();
    final multiplier = progress.multiplier;

    // Base prayer coins (× multiplier)
    int coins = (10 * multiplier).round();
    if (prayerName == 'Fajr') coins += 5;
    await _repo.awardCoins(
      coins,
      type: 'prayer',
      description: 'Prayed $prayerName',
    );

    // Full-day bonus when all 5 are done
    if (completedToday.length == _prayers.length) {
      final fullDayBonus = (50 * multiplier).round();
      await _repo.awardCoins(
        fullDayBonus,
        type: 'full_day',
        description: 'Completed all 5 prayers',
      );

      await _repo.checkAndAwardMilestone(
        'first_full_day',
        75,
        'First full prayer day',
      );
    }

    // Streak milestones
    if (currentStreak >= 100) {
      await _repo.checkAndAwardMilestone('streak_100', 1000, '100-day streak');
    } else if (currentStreak >= 40) {
      await _repo.checkAndAwardMilestone('streak_40', 500, '40-day Arba\'een streak');
    } else if (currentStreak >= 7) {
      await _repo.checkAndAwardMilestone('streak_7', 100, '7-day streak');
    }
  }

  // Called when a Qada prayer is made up.
  Future<void> onQadaMakeUp(bool isFirstEver) async {
    await _repo.awardCoins(15, type: 'qada', description: 'Qada prayer made up');
    if (isFirstEver) {
      await _repo.checkAndAwardMilestone('first_qada', 50, 'First Qada makeup');
    }
  }

  // Called when a day's fast is logged as kept. Rewards the fast and the
  // 10/20/30-day Ramadan milestones.
  Future<void> onFastLogged({int daysFastedTotal = 0}) async {
    final progress = await _repo.getProgress();
    final coins = (30 * progress.multiplier).round();
    await _repo.awardCoins(coins, type: 'fasting', description: 'Fast kept');

    if (daysFastedTotal >= 30) {
      await _repo.checkAndAwardMilestone(
          'ramadan_full_month', 1000, 'Fasted the whole month');
    } else if (daysFastedTotal >= 20) {
      await _repo.checkAndAwardMilestone('ramadan_20', 400, '20 fasts kept');
    } else if (daysFastedTotal >= 10) {
      await _repo.checkAndAwardMilestone('ramadan_10', 150, '10 fasts kept');
    }
  }

  // Called when a Taraweeh night is logged.
  Future<void> onTaraweehLogged({int taraweehNightsTotal = 0}) async {
    final progress = await _repo.getProgress();
    final coins = (20 * progress.multiplier).round();
    await _repo.awardCoins(coins, type: 'taraweeh', description: 'Taraweeh prayed');

    if (taraweehNightsTotal >= 27) {
      await _repo.checkAndAwardMilestone(
          'taraweeh_27', 500, '27 nights of Taraweeh');
    } else if (taraweehNightsTotal >= 10) {
      await _repo.checkAndAwardMilestone(
          'taraweeh_10', 150, '10 nights of Taraweeh');
    }
  }

  // Called when the daily Hadith is viewed. Returns true if coins were awarded.
  Future<bool> onHadithViewed() async {
    final today = _dateKey(DateTime.now());
    final progress = await _repo.getProgress();
    if (progress.lastHadithDate == today) return false;

    await _repo.setLastHadithDate(today);
    await _repo.awardCoins(5, type: 'hadith', description: 'Read daily Hadith');
    return true;
  }

  // Called on app launch. Returns true if coins were awarded.
  // The check-and-award is atomic to prevent concurrent launches double-awarding.
  Future<bool> onDailyLogin() async {
    final today = _dateKey(DateTime.now());
    return _repo.recordDailyLogin(today, 2);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
