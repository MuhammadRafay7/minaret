import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:minaret/repositories/prayer_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/firestore_seeds.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late PrayerRepository repo;

  const userId = 'test-user-001';

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn(userId);
    repo = PrayerRepository(db: fakeDb, auth: mockAuth);
  });

  group('PrayerRepository', () {
    test('marks a prayer complete', () async {
      await repo.togglePrayer('Fajr');

      final prayers = await repo.getTodayPrayers();
      expect(prayers, contains('Fajr'));
    });

    test('toggles prayer back off when already marked complete', () async {
      await repo.togglePrayer('Fajr');
      await repo.togglePrayer('Fajr');

      final prayers = await repo.getTodayPrayers();
      expect(prayers, isNot(contains('Fajr')));
    });

    test('streak increments when completing all prayers on consecutive days',
        () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await seedFullDay(fakeDb, userId, yesterday);

      for (final p in kAllPrayers) {
        await repo.togglePrayer(p);
      }

      final stats = await repo.getCurrentUserStats();
      expect(stats, isNotNull);
      expect(stats!.currentStreak, 2);
    });

    test('streak resets to 1 when a day is missed', () async {
      // Seed a full day two days ago — yesterday is intentionally missing.
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      await seedFullDay(fakeDb, userId, twoDaysAgo);

      for (final p in kAllPrayers) {
        await repo.togglePrayer(p);
      }

      final stats = await repo.getCurrentUserStats();
      expect(stats, isNotNull);
      expect(stats!.currentStreak, 1);
    });

    test('longest streak is preserved after a break', () async {
      // Build a 3-day run (days 5, 4, 3 ago), then a gap, then resume yesterday.
      for (final offset in [5, 4, 3]) {
        await seedFullDay(
          fakeDb,
          userId,
          DateTime.now().subtract(Duration(days: offset)),
        );
      }
      // Day 2 ago: missed (no seed).
      await seedFullDay(
        fakeDb,
        userId,
        DateTime.now().subtract(const Duration(days: 1)),
      );

      // Complete all prayers today, triggering a stats recalculation.
      for (final p in kAllPrayers) {
        await repo.togglePrayer(p);
      }

      final stats = await repo.getCurrentUserStats();
      expect(stats, isNotNull);
      expect(stats!.longestStreak, 3); // the earlier 3-day run
      expect(stats.currentStreak, 2); // yesterday + today
    });
  });
}
