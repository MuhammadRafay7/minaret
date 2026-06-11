import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/repositories/prayer_repository.dart';
import 'package:minaret/widgets/enhanced_prayer_tracker_card.dart';

import '../helpers/fake_repos.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

UserPrayerStats _makeStats({int streak = 0, int longest = 0}) =>
    UserPrayerStats(
      userId: 'test',
      totalPrayers: streak * 5,
      currentStreak: streak,
      longestStreak: longest,
      overallCompletionRate: 0.0,
      totalDaysPrayed: streak,
      lastPrayerDate: DateTime.now(),
      prayerCounts: {
        'Fajr': streak,
        'Dhuhr': streak,
        'Asr': streak,
        'Maghrib': streak,
        'Isha': streak,
      },
      prayerCompletionRates: {
        'Fajr': 0.0,
        'Dhuhr': 0.0,
        'Asr': 0.0,
        'Maghrib': 0.0,
        'Isha': 0.0,
      },
    );

Widget _wrapCard() => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: EnhancedPrayerTrackerCard(),
          ),
        ),
      ),
    );

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPrayerRepository mockRepo;

  setUp(() {
    mockRepo = MockPrayerRepository();

    // Default stubs — can be overridden per test.
    when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => []);
    when(() => mockRepo.getCurrentUserStats())
        .thenAnswer((_) async => _makeStats(streak: 3, longest: 5));
    when(() => mockRepo.togglePrayer(any(), queued: any(named: 'queued')))
        .thenAnswer((_) async {});

    ServiceContainer()
        .registerSingletonInstance<PrayerRepository>(mockRepo);
  });

  tearDown(() {
    ServiceContainer().dispose();
  });

  group('EnhancedPrayerTrackerCard', () {
    testWidgets('renders prayer buttons for all five prayers', (tester) async {
      await tester.pumpWidget(_wrapCard());
      await tester.pumpAndSettle();

      for (final label in ['Fajr', 'Dhuhr', 'Asr', 'Maghr', 'Isha']) {
        expect(find.text(label), findsOneWidget,
            reason: '$label prayer button should be visible');
      }
    });

    testWidgets('tapping a prayer button marks it complete', (tester) async {
      await tester.pumpWidget(_wrapCard());
      await tester.pumpAndSettle(); // initial load

      // Before tap — Fajr should show an outline circle icon (not checked).
      expect(
        find.byIcon(Icons.check_rounded).hitTestable(),
        findsNothing,
      );

      await tester.tap(find.text('Fajr'));
      await tester.pump(); // apply optimistic UI update

      // After tap — at least one prayer shows a check icon.
      expect(find.byIcon(Icons.check_rounded).hitTestable(), findsWidgets);
    });

    testWidgets('tapping a completed prayer unchecks it', (tester) async {
      // Seed Fajr as already completed.
      when(() => mockRepo.getTodayPrayers()).thenAnswer((_) async => ['Fajr']);

      await tester.pumpWidget(_wrapCard());
      await tester.pumpAndSettle();

      // Fajr should show a check icon initially.
      expect(find.byIcon(Icons.check_rounded).hitTestable(), findsWidgets);

      await tester.tap(find.text('Fajr'));
      await tester.pump();

      // Check icon should be gone after untapping.
      expect(
        find.byIcon(Icons.check_rounded).hitTestable(),
        findsNothing,
      );
    });

    testWidgets('streak counter updates in UI after sync', (tester) async {
      var callCount = 0;
      when(() => mockRepo.getCurrentUserStats()).thenAnswer((_) async {
        callCount++;
        // First call (initial load) → streak 3. Subsequent → streak 4.
        return callCount == 1
            ? _makeStats(streak: 3, longest: 5)
            : _makeStats(streak: 4, longest: 5);
      });

      await tester.pumpWidget(_wrapCard());
      await tester.pumpAndSettle();

      // Initial streak is 3.
      expect(find.text('3'), findsWidgets);

      await tester.tap(find.text('Fajr'));
      // Wait for the async sync + state update.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Streak should have updated to 4.
      expect(find.text('4'), findsWidgets);
    });
  });
}
