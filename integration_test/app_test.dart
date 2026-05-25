import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minaret/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('Full app flow: Onboarding to Main Navigation', (tester) async {
      // Clear preferences to ensure onboarding shows
      SharedPreferences.setMockInitialValues({});
      
      // Start the app
      await app.main();
      await tester.pumpAndSettle();

      // --- 1. Onboarding Flow ---
      // Check if we are on the first onboarding page
      expect(find.text('PRECISION PRAYER'), findsOneWidget);

      // Click "CONTINUE" 3 times
      for (int i = 0; i < 3; i++) {
        final continueBtn = find.text('CONTINUE');
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();
      }

      // Final onboarding page
      expect(find.text('GET STARTED'), findsOneWidget);
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      // --- 2. Main Navigation Flow ---
      // We should now be on the Home Page
      expect(find.byIcon(Icons.roofing_rounded), findsOneWidget);

      // Navigate to Quran
      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pumpAndSettle();

      // Navigate to Hadith
      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();

      // Navigate to Global Registry
      await tester.tap(find.byIcon(Icons.public_rounded));
      await tester.pumpAndSettle();

      // Navigate to Account/Auth
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      
      // We should see login related text - using RegExp for case-insensitive search
      expect(find.textContaining(RegExp('LOGIN', caseSensitive: false)), findsWidgets);
    });
  });
}
