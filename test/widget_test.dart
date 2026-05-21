import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/main.dart';
import 'package:provider/provider.dart';
import 'package:minaret/core/language_provider.dart';
import 'package:minaret/core/theme_provider.dart';
import 'package:minaret/services/quran_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads with MaterialApp', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final languageProvider = LanguageProvider();
    final themeProvider = ThemeProvider();
    final quranDownloadService = QuranDownloadService();

    // Set screen size for testing
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => languageProvider),
          ChangeNotifierProvider(create: (_) => themeProvider),
          ChangeNotifierProvider(create: (_) => quranDownloadService),
        ],
        child: const MinaretApp(
          firebaseReady: true,
          showOnboarding: true,
        ),
      ),
    );

    // Pump a few frames instead of pumpAndSettle to avoid timeout
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Basic check to see if the app starts
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
