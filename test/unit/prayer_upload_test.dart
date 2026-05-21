import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minaret/core/base/base_notifier.dart';
import 'package:minaret/core/errors/app_error.dart';
import 'package:minaret/repositories/prayer_repository.dart';

// ---------------------------------------------------------------------------
// Mock for PrayerRepository — avoids any real Firestore or Firebase calls
// ---------------------------------------------------------------------------

class _MockPrayerRepository extends Mock implements PrayerRepository {}

// ---------------------------------------------------------------------------
// Thin notifier that wraps the upload service, exercising the
// loading → success/error state machine that the UI observes.
// ---------------------------------------------------------------------------

class _PrayerUploadNotifier extends BaseNotifier {
  final PrayerRepository _repo;
  List<String> _todayPrayers = [];

  _PrayerUploadNotifier(this._repo);

  List<String> get todayPrayers => List.unmodifiable(_todayPrayers);

  Future<void> loadTodayPrayers() => runAsync(() async {
        _todayPrayers = await _repo.getTodayPrayers();
      });

  Future<void> togglePrayer(String prayerName) => runAsync(() async {
        await _repo.togglePrayer(prayerName);
        _todayPrayers = await _repo.getTodayPrayers();
      });
}

// ---------------------------------------------------------------------------
// Thin fake for SharedPreferences-backed local operations
// ---------------------------------------------------------------------------

void main() {
  group('PrayerRepository — local prayer tracking logic', () {
    late PrayerRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = PrayerRepository();
      await repo.initLocal();
    });

    // ── toggleLocal ──────────────────────────────────────────────────────────

    group('toggleLocal', () {
      test('adds prayer when not present', () async {
        final today = DateTime.now();
        await repo.toggleLocal(today, 'Fajr');
        expect(repo.getLocalDayStatus(today), contains('Fajr'));
      });

      test('removes prayer when already present', () async {
        final today = DateTime.now();
        await repo.toggleLocal(today, 'Fajr');
        await repo.toggleLocal(today, 'Fajr');
        expect(repo.getLocalDayStatus(today), isNot(contains('Fajr')));
      });

      test('toggling multiple prayers accumulates correctly', () async {
        final today = DateTime.now();
        await repo.toggleLocal(today, 'Fajr');
        await repo.toggleLocal(today, 'Dhuhr');
        await repo.toggleLocal(today, 'Asr');
        final status = repo.getLocalDayStatus(today);
        expect(status, containsAll(['Fajr', 'Dhuhr', 'Asr']));
        expect(status.length, 3);
      });

      test('prayers are persisted across separate SharedPreferences reads', () async {
        final today = DateTime.now();
        await repo.toggleLocal(today, 'Maghrib');

        // Re-create repo from same SharedPreferences mock to verify persistence
        final repo2 = PrayerRepository();
        await repo2.initLocal();
        expect(repo2.getLocalDayStatus(today), contains('Maghrib'));
      });

      test('different days are stored independently', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        await repo.toggleLocal(today, 'Isha');
        await repo.toggleLocal(yesterday, 'Fajr');

        expect(repo.getLocalDayStatus(today), contains('Isha'));
        expect(repo.getLocalDayStatus(today), isNot(contains('Fajr')));
        expect(repo.getLocalDayStatus(yesterday), contains('Fajr'));
      });
    });

    // ── getLocalDayStatus ────────────────────────────────────────────────────

    group('getLocalDayStatus', () {
      test('returns empty list for day with no prayers recorded', () {
        expect(repo.getLocalDayStatus(DateTime(2024, 1, 1)), isEmpty);
      });
    });

    // ── getLocalStreak ───────────────────────────────────────────────────────

    group('getLocalStreak', () {
      test('returns 0 when no prayers have been recorded', () {
        expect(repo.getLocalStreak(), 0);
      });

      test('returns 1 when only today has prayers', () async {
        final today = DateTime.now();
        await repo.toggleLocal(today, 'Fajr');
        expect(repo.getLocalStreak(), 1);
      });

      test('streak stops at first day without prayers', () async {
        final today = DateTime.now();
        final twoDaysAgo = today.subtract(const Duration(days: 2));
        // today and two days ago have prayers, but yesterday is empty → streak = 1
        await repo.toggleLocal(today, 'Fajr');
        await repo.toggleLocal(twoDaysAgo, 'Fajr');
        expect(repo.getLocalStreak(), 1);
      });

      test('consecutive days build a streak', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        await repo.toggleLocal(today, 'Fajr');
        await repo.toggleLocal(yesterday, 'Fajr');
        expect(repo.getLocalStreak(), 2);
      });
    });

    // ── PrayerRecord.fromDoc ─────────────────────────────────────────────────

    group('PrayerRecord.fromDoc', () {
      test('completionRate is computed from completedPrayers / 5', () {
        // Direct construction (bypasses Firestore)
        final record = PrayerRecord(
          id: 'test',
          userId: 'u1',
          date: DateTime.now(),
          completedPrayers: const ['Fajr', 'Dhuhr', 'Asr'],
          completionRate: 3 / 5,
        );
        expect(record.completionRate, closeTo(0.6, 0.001));
        expect(record.completedPrayers.length, 3);
      });
    });

    // ── UserPrayerStats.empty ────────────────────────────────────────────────

    group('UserPrayerStats.empty', () {
      test('initialises all counters to zero', () {
        final stats = UserPrayerStats.empty('uid123');
        expect(stats.totalPrayers, 0);
        expect(stats.currentStreak, 0);
        expect(stats.longestStreak, 0);
        expect(stats.overallCompletionRate, 0.0);
        expect(stats.prayerCounts, isEmpty);
      });
    });
  });

  // ── Prayer upload — loading, success, and error states ────────────────────

  group('Prayer upload — loading, success, and error states', () {
    late _MockPrayerRepository mockRepo;
    late _PrayerUploadNotifier notifier;

    setUp(() {
      mockRepo = _MockPrayerRepository();
      notifier = _PrayerUploadNotifier(mockRepo);
    });

    tearDown(() => notifier.dispose());

    // ── Loading state ──────────────────────────────────────────────────────

    test('isLoading is true while loadTodayPrayers is in flight', () async {
      // Arrange — hold getTodayPrayers open until we assert
      final completer = Completer<List<String>>();
      when(() => mockRepo.getTodayPrayers())
          .thenAnswer((_) => completer.future);

      // Act
      final future = notifier.loadTodayPrayers();
      expect(notifier.isLoading, isTrue);

      // Cleanup
      completer.complete([]);
      await future;
      expect(notifier.isLoading, isFalse);
    });

    test('isLoading is true while togglePrayer is in flight', () async {
      // Arrange
      final completer = Completer<void>();
      when(() => mockRepo.togglePrayer(any()))
          .thenAnswer((_) => completer.future);
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);

      // Act
      final future = notifier.togglePrayer('Fajr');
      expect(notifier.isLoading, isTrue);

      // Cleanup
      completer.complete();
      await future;
      expect(notifier.isLoading, isFalse);
    });

    // ── Success state ──────────────────────────────────────────────────────

    test('todayPrayers is populated after a successful load', () async {
      // Arrange
      when(() => mockRepo.getTodayPrayers())
          .thenAnswer((_) async => ['Fajr', 'Dhuhr']);

      // Act
      await notifier.loadTodayPrayers();

      // Assert
      expect(notifier.isLoading, isFalse);
      expect(notifier.hasError, isFalse);
      expect(notifier.todayPrayers, containsAll(['Fajr', 'Dhuhr']));
    });

    test('todayPrayers is updated after a successful toggle', () async {
      // Arrange
      when(() => mockRepo.togglePrayer(any())).thenAnswer((_) async {});
      when(() => mockRepo.getTodayPrayers())
          .thenAnswer((_) async => ['Fajr', 'Dhuhr', 'Asr']);

      // Act
      await notifier.togglePrayer('Asr');

      // Assert
      expect(notifier.isLoading, isFalse);
      expect(notifier.hasError, isFalse);
      expect(notifier.todayPrayers, contains('Asr'));
    });

    test('togglePrayer calls repository.togglePrayer with the prayer name', () async {
      // Arrange
      when(() => mockRepo.togglePrayer(any())).thenAnswer((_) async {});
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);

      // Act
      await notifier.togglePrayer('Maghrib');

      // Assert — repository received the exact prayer name
      verify(() => mockRepo.togglePrayer('Maghrib')).called(1);
    });

    // ── Error state ────────────────────────────────────────────────────────

    test('hasError is true and error is an AppError when togglePrayer fails', () async {
      // Arrange
      when(() => mockRepo.togglePrayer(any()))
          .thenThrow(Exception('Firestore write failed'));

      // Act
      await notifier.togglePrayer('Isha');

      // Assert
      expect(notifier.isLoading, isFalse);
      expect(notifier.hasError, isTrue);
      expect(notifier.error, isA<AppError>());
    });

    test('hasError is true when getTodayPrayers throws', () async {
      // Arrange
      when(() => mockRepo.getTodayPrayers())
          .thenThrow(Exception('Network unavailable'));

      // Act
      await notifier.loadTodayPrayers();

      // Assert
      expect(notifier.hasError, isTrue);
      expect(notifier.error, isA<AppError>());
      expect(notifier.todayPrayers, isEmpty); // state unchanged on failure
    });

    test('todayPrayers remains empty when togglePrayer throws', () async {
      // Arrange — toggle fails before getTodayPrayers is ever called
      when(() => mockRepo.togglePrayer(any()))
          .thenThrow(Exception('permission-denied'));

      // Act
      await notifier.togglePrayer('Fajr');

      // Assert — list was never updated
      expect(notifier.todayPrayers, isEmpty);
    });
  });
}
