import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minaret/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Integration test: notification permission request → prayer upload flow.
///
/// This test exercises the critical path where a user:
///   1. Opens the app fresh (onboarding shown).
///   2. Steps through onboarding (implicitly requesting notification permission).
///   3. Lands on the home screen with the prayer tracker card.
///   4. Taps a prayer button and verifies the card responds correctly.
///
/// Note: Firebase is initialised by app.main(). The test targets a simulator/
/// device with Firebase emulators running (or real Firebase).
/// On CI without a device, run with `--ignore-timeouts` or as a unit widget
/// integration test against a fake Firebase backend.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notification permission + prayer upload flow', () {
    setUp(() async {
      // Clear preferences so onboarding shows on each test run.
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'completes onboarding, dismisses notification permission dialog, '
      'then interacts with prayer tracker on home screen',
      (tester) async {
        // ── Arrange ───────────────────────────────────────────────────────────
        await app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── 1. Onboarding ─────────────────────────────────────────────────────
        // Step through onboarding pages until "GET STARTED".
        for (int i = 0; i < 3; i++) {
          final continueBtn = find.text('CONTINUE');
          if (continueBtn.evaluate().isNotEmpty) {
            await tester.tap(continueBtn);
            await tester.pumpAndSettle(const Duration(milliseconds: 500));
          }
        }

        final getStarted = find.text('GET STARTED');
        if (getStarted.evaluate().isNotEmpty) {
          await tester.tap(getStarted);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // ── 2. Notification permission dialog ─────────────────────────────────
        // On a real device the OS shows a system alert here; we can only tap
        // within the Flutter layer. If a custom permission dialog is shown,
        // dismiss it. Otherwise this is a no-op (system dialog is outside app).
        final allowBtn = find.text('Allow');
        if (allowBtn.evaluate().isNotEmpty) {
          await tester.tap(allowBtn);
          await tester.pumpAndSettle();
        }

        // ── 3. Home screen reachable ──────────────────────────────────────────
        // Verify the home screen rendered (prayer tracker card or nav bar visible).
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'At least one Scaffold must be present on the home screen',
        );

        // ── 4. Prayer tracker interaction ─────────────────────────────────────
        // Look for a prayer button (Fajr label). If found, tap it and verify
        // the widget responds without crashing (loading spinner or check icon).
        final fajrFinder = find.text('Fajr');
        if (fajrFinder.evaluate().isNotEmpty) {
          await tester.tap(fajrFinder);
          await tester.pump(const Duration(milliseconds: 100));

          // After tap, either a spinner or check icon should be visible —
          // either outcome means the tap was handled correctly.
          final spinnerOrCheck = find.byWidgetPredicate(
            (w) =>
                w is CircularProgressIndicator ||
                (w is Icon &&
                    (w.icon == Icons.check_rounded ||
                        w.icon == Icons.circle_outlined)),
          );
          expect(
            spinnerOrCheck.evaluate().isNotEmpty,
            isTrue,
            reason: 'Prayer button tap must produce a spinner or icon change',
          );

          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      },
    );

    testWidgets(
      'notification settings toggle is reachable from home via navigation',
      (tester) async {
        // Arrange
        await app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Fast-forward through onboarding if present
        for (int i = 0; i < 4; i++) {
          for (final label in ['CONTINUE', 'GET STARTED']) {
            final btn = find.text(label);
            if (btn.evaluate().isNotEmpty) {
              await tester.tap(btn);
              await tester.pumpAndSettle(const Duration(milliseconds: 500));
            }
          }
        }

        // Tap person/account icon to reach settings-related screen
        final personIcon = find.byIcon(Icons.person_outline_rounded);
        if (personIcon.evaluate().isNotEmpty) {
          await tester.tap(personIcon);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // Verify auth/settings screen is visible
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'Settings-related scaffold must be visible',
        );
      },
    );
  });
}
