import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/prayer_repository.dart';
import 'package:minaret/widgets/enhanced_prayer_tracker_card.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockPrayerRepository extends Mock implements PrayerRepository {}

// ---------------------------------------------------------------------------
// Test wrapper
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  late _MockPrayerRepository mockRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockRepo = _MockPrayerRepository();
    // Override the repo in the DI singleton so the card uses our mock.
    ServiceContainer().registerSingletonInstance<PrayerRepository>(mockRepo);
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  group('EnhancedPrayerTrackerCard — loading state', () {
    testWidgets('shows CircularProgressIndicator while fetching prayer data',
        (tester) async {
      // Arrange — slow responses keep loading state visible
      when(() => mockRepo.getTodayPrayers()).thenAnswer(
        (_) => Future<List<String>>.delayed(const Duration(seconds: 30), () => []),
      );
      when(() => mockRepo.getCurrentUserStats()).thenAnswer(
        (_) =>
            Future<UserPrayerStats?>.delayed(const Duration(seconds: 30), () => null),
      );

      // Act
      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pump(); // single frame — loading

      // Assert
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // _loadData awaits getTodayPrayers (30 s) then getCurrentUserStats (30 s)
      // sequentially — drain both timers so the widget tree is clean on teardown.
      await tester.pump(const Duration(seconds: 61));
    });
  });

  // ── Success state ──────────────────────────────────────────────────────────

  group('EnhancedPrayerTrackerCard — success state', () {
    testWidgets('renders all five prayer labels after data loads', (tester) async {
      // Arrange
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => ['Fajr']);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));

      // Act
      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Dhuhr'), findsOneWidget);
      expect(find.text('Asr'), findsOneWidget);
    });

    testWidgets('completed prayers show check icon; pending prayers show circle',
        (tester) async {
      // Arrange — only Fajr completed
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => ['Fajr']);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));

      // Act
      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
    });

    testWidgets('tapping a prayer button shows spinner during sync then resolves',
        (tester) async {
      // Arrange
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));
      when(() => mockRepo.togglePrayer('Fajr'))
          .thenAnswer((_) async => await Future.delayed(const Duration(milliseconds: 50)));

      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // Act — tap Fajr button
      await tester.tap(find.text('Fajr'));
      await tester.pump(); // render syncing spinner

      // Assert — spinner visible during sync
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  // ── Error state ────────────────────────────────────────────────────────────

  group('EnhancedPrayerTrackerCard — error state', () {
    testWidgets('shows SnackBar when prayer sync fails', (tester) async {
      // Arrange
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));
      when(() => mockRepo.togglePrayer(any()))
          .thenThrow(Exception('Firestore unavailable'));

      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // Act — tap Fajr
      await tester.tap(find.text('Fajr'));
      await tester.pumpAndSettle();

      // Assert — SnackBar appears
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('prayer state rolls back to unchecked when sync fails', (tester) async {
      // Arrange
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));
      when(() => mockRepo.togglePrayer(any()))
          .thenThrow(Exception('server error'));

      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // No check marks initially
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Act — tap Fajr; optimistic check appears then rolls back
      await tester.tap(find.text('Fajr'));
      await tester.pumpAndSettle();

      // Assert — state rolled back
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('second tap on same prayer while sync is in-flight is a no-op',
        (tester) async {
      // Arrange — very slow sync
      int toggleCalls = 0;
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);
      when(() => mockRepo.getCurrentUserStats())
          .thenAnswer((_) async => UserPrayerStats.empty('uid'));
      when(() => mockRepo.togglePrayer('Fajr')).thenAnswer((_) async {
        toggleCalls++;
        await Future.delayed(const Duration(seconds: 10));
      });

      await tester.pumpWidget(_wrap(const EnhancedPrayerTrackerCard()));
      await tester.pumpAndSettle();

      // First tap — starts sync (spinner replaces icon)
      await tester.tap(find.text('Fajr'));
      await tester.pump();

      // Second tap attempt (GestureDetector is null-tapped; spinner is shown)
      await tester.tap(find.text('Fajr'));
      await tester.pump();

      // Only one backend call should have been made
      expect(toggleCalls, 1);

      // Drain the in-flight 10 s sync timer so the widget tree is clean on teardown.
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
    });
  });
}
