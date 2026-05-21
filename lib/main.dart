import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase Core Services
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// UI and Framework
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local Imports
import 'package:minaret/core/config/certificate_pins.dart';
import 'package:minaret/core/app_repositories.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/firebase_options.dart';
import 'package:minaret/main_navigation.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/language_provider.dart';
import 'package:minaret/core/theme_provider.dart';
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
      if (!kIsWeb) CertificatePins.assertConfigured();
      final appConfig = await _initializeApp();
      runApp(appConfig);
    },
    (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Uncaught async error: $error\n$stackTrace');
      }
      // Firebase.apps is non-empty once initializeApp() has completed, so
      // Crashlytics is guaranteed to be ready when errors reach here in
      // production. Early startup errors (before Firebase init) are only
      // visible in debug logs; they will be replayed on next launch by
      // Crashlytics's on-device buffering.
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance
            .recordError(error, stackTrace, fatal: true);
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

      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Catches errors on the platform's event loop that escape Flutter's
      // widget layer (e.g. errors in isolate callbacks, platform channels).
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          debugPrint('PlatformDispatcher error: $error\n$stack');
        }
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true; // returning true marks the error as handled
      };
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
              // child is null only during the brief MaterialApp init window
              // before any route is mounted; SizedBox.shrink() is a safe
              // transparent placeholder for that instant.
              assert(child != null, 'MaterialApp builder received a null child');
              return Gatekeeper(child: child ?? const SizedBox.shrink());
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
