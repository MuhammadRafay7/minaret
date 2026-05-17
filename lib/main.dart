import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase Core Services
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

// UI and Framework
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local Imports
import 'package:minaret/core/app_repositories.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/firebase_options.dart';
import 'package:minaret/main_navigation.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/language_provider.dart';
import 'package:minaret/core/theme_provider.dart';
import 'package:minaret/core/secure_config.dart';
import 'package:minaret/services/notification_service.dart';
import 'package:minaret/services/quran_download_service.dart';
import 'package:minaret/services/prayer_tracker_service.dart';
import 'package:minaret/services/offline_cache_service.dart';
import 'package:minaret/services/system_config_service.dart';
import 'package:minaret/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase background handler error: $e');
  }
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final appConfig = await _initializeApp();
      runApp(appConfig);
    },
    (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Global error: $error');
      }
    },
  );
}

Future<Widget> _initializeApp() async {
  try {
    await dotenv.load(fileName: '.env');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    if (!Hive.isAdapterRegistered(0)) {
      await Hive.initFlutter();
    }
    await OfflineCacheService.init();

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    configureRepositories();
    await PrayerTrackerService.init();

    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    final languageProvider = LanguageProvider();
    final themeProvider = ThemeProvider();
    await Future.wait([
      languageProvider.loadSavedLocale(),
      themeProvider.loadSavedTheme(),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final bool showOnboarding = prefs.getBool('seen_onboarding') != true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => QuranDownloadService()),
        StreamProvider<SystemConfig?>(
          create: (_) => SystemConfigService.systemConfigStream(),
          initialData: null,
        ),
        StreamProvider<GlobalSettings?>(
          create: (_) => SystemConfigService.globalSettingsStream(),
          initialData: null,
        ),
      ],
      child: MinaretApp(
        firebaseReady: true,
        showOnboarding: showOnboarding,
      ),
    );
  } catch (e, st) {
    debugPrint('_initializeApp error: $e\n$st');
    return const _ErrorScreen();
  }
}

class MinaretApp extends StatelessWidget {
  final bool firebaseReady;
  final bool showOnboarding;
  const MinaretApp({super.key, required this.firebaseReady, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, lang, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: lang.currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: MinaretTheme.lightTheme,
            darkTheme: MinaretTheme.darkTheme,
            themeMode: theme.themeMode,
            builder: (context, child) {
              return Gatekeeper(child: child!);
            },
            home: showOnboarding 
                ? OnboardingPage(firebaseReady: firebaseReady) 
                : MainNavigation(firebaseReady: firebaseReady),
          );
        },
      ),
    );
  }
}

class Gatekeeper extends StatelessWidget {
  final Widget child;
  const Gatekeeper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<SystemConfig?>(context);
    
    if (config == null) return child;

    if (config.maintenanceMode) {
      return const _MaintenanceScreen();
    }

    // Version check could go here if package_info_plus is added
    
    return child;
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE3),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_rounded, size: 80, color: Color(0xFFD4AF37)),
              const SizedBox(height: 24),
              Text(
                'SYSTEM MAINTENANCE',
                style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'We are currently performing scheduled improvements to our infrastructure. Please check back shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();
  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold(body: Center(child: Text('Initialization Error'))));
}
