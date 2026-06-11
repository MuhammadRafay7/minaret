import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:minaret/features/auth/auth_page.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/user_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_repos.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

Widget _wrapAuthPage(AuthPage page) {
  return Provider<GlobalSettings?>.value(
    value: null,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserRepository mockUserRepo;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUserRepo = MockUserRepository();

    // Auth stream emits no user → login form is shown.
    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(null));

    // Register mock UserRepository so _handleAuth can resolve it.
    ServiceContainer()
        .registerSingletonInstance<UserRepository>(mockUserRepo);
  });

  tearDown(() {
    ServiceContainer().dispose();
  });

  group('AuthPage', () {
    testWidgets('renders the login form', (tester) async {
      await tester.pumpWidget(_wrapAuthPage(
        AuthPage(auth: mockAuth, onLoginSuccess: () {}),
      ));
      await tester.pump(); // let the StreamBuilder settle

      // The auth-form widget tree contains text fields and a sign-in button.
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('SIGN IN'), findsOneWidget);
    });

    testWidgets('shows error snackbar when email is empty', (tester) async {
      await tester.pumpWidget(_wrapAuthPage(
        AuthPage(auth: mockAuth, onLoginSuccess: () {}),
      ));
      await tester.pump();

      // Tap sign-in with no email entered.
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows error snackbar on invalid email format', (tester) async {
      await tester.pumpWidget(_wrapAuthPage(
        AuthPage(auth: mockAuth, onLoginSuccess: () {}),
      ));
      await tester.pump();

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'not-an-email');
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
      // The error should NOT have triggered any Firebase call.
      verifyNever(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });

    testWidgets('shows error snackbar on wrong credentials', (tester) async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await tester.pumpWidget(_wrapAuthPage(
        AuthPage(auth: mockAuth, onLoginSuccess: () {}),
      ));
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'wrongpass');
      await tester.tap(find.text('SIGN IN'));
      await tester.pump(); // start async
      await tester.pump(const Duration(milliseconds: 500)); // let auth complete

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('invokes onLoginSuccess callback on valid credentials',
        (tester) async {
      final mockUser = MockUser();
      final mockCred = MockUserCredential();
      when(() => mockUser.uid).thenReturn('uid-001');
      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockCred.user).thenReturn(mockUser);
      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockCred);

      when(() => mockUserRepo.getUser(any()))
          .thenAnswer((_) async => const UserProfile(
                uid: 'uid-001',
                role: 'common',
              ));

      var loginCalled = false;
      await tester.pumpWidget(_wrapAuthPage(
        AuthPage(
          auth: mockAuth,
          onLoginSuccess: () => loginCalled = true,
        ),
      ));
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'imam@example.com');
      await tester.enterText(fields.at(1), 'ValidPass1!');
      await tester.tap(find.text('SIGN IN'));
      await tester.pump(); // start async
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(loginCalled, isTrue);
    });
  });
}
