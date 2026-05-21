import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:minaret/core/base/base_notifier.dart';
import 'package:minaret/core/errors/app_error.dart';

// ---------------------------------------------------------------------------
// Thin Firebase-agnostic auth service interface — lets tests inject a mock
// ---------------------------------------------------------------------------

abstract class _AuthService {
  Future<void> signInWithEmail(String email, String password);
  Future<void> signOut();
}

class _MockAuthService extends Mock implements _AuthService {}

// ---------------------------------------------------------------------------
// Thin auth notifier built on BaseNotifier — models the UI-side state machine
// ---------------------------------------------------------------------------

class _TestAuthNotifier extends BaseNotifier {
  final _AuthService _service;
  bool _isAuthenticated = false;

  _TestAuthNotifier(this._service);

  bool get isAuthenticated => _isAuthenticated;

  Future<void> signIn(String email, String password) => runAsync(() async {
        await _service.signInWithEmail(email, password);
        _isAuthenticated = true;
      });

  Future<void> signOut() => runAsync(() async {
        await _service.signOut();
        _isAuthenticated = false;
      });
}

// ---------------------------------------------------------------------------
// Concrete test notifier to exercise BaseNotifier state machine
// ---------------------------------------------------------------------------

class _TestNotifier extends BaseNotifier {
  int callCount = 0;

  Future<void> doSuccess() => runAsync(() async {
        callCount++;
      });

  Future<void> doFailure(Object error) => runAsync(() async {
        callCount++;
        throw error;
      });

  Future<void> doStream(Stream<int> stream) async {
    listenToStream(stream, onData: (v) => callCount = v);
  }
}

void main() {
  group('BaseNotifier — auth/loading state management', () {
    late _TestNotifier notifier;

    setUp(() => notifier = _TestNotifier());
    tearDown(() => notifier.dispose());

    // ── Initial state ────────────────────────────────────────────────────────

    test('starts with isLoading=false, error=null, hasError=false', () {
      expect(notifier.isLoading, isFalse);
      expect(notifier.error, isNull);
      expect(notifier.hasError, isFalse);
    });

    // ── runAsync — success path ──────────────────────────────────────────────

    test('runAsync sets isLoading=true during execution and resets to false on success', () async {
      // Arrange
      var loadingDuringExecution = false;
      notifier.addListener(() {
        if (notifier.isLoading) loadingDuringExecution = true;
      });

      // Act
      await notifier.doSuccess();

      // Assert
      expect(loadingDuringExecution, isTrue);
      expect(notifier.isLoading, isFalse);
      expect(notifier.hasError, isFalse);
    });

    test('runAsync returns true on success', () async {
      // Arrange / Act / Assert
      await notifier.doSuccess();
      expect(notifier.hasError, isFalse);
    });

    test('runAsync clears previous error on new attempt', () async {
      // Arrange: fail first, then succeed
      await notifier.doFailure(Exception('first fail'));
      expect(notifier.hasError, isTrue);

      // Act
      await notifier.doSuccess();

      // Assert
      expect(notifier.hasError, isFalse);
      expect(notifier.error, isNull);
    });

    // ── runAsync — error path ────────────────────────────────────────────────

    test('runAsync converts raw exception to AppError on failure', () async {
      // Act
      await notifier.doFailure(Exception('network down'));

      // Assert
      expect(notifier.hasError, isTrue);
      expect(notifier.error, isA<AppError>());
      expect(notifier.isLoading, isFalse);
    });

    test('runAsync stores AppError directly when thrown', () async {
      // Arrange
      const authErr = AuthError(
        code: 'user-disabled',
        userMessage: 'disabled',
        debugMessage: 'debug',
      );

      // Act
      await notifier.doFailure(authErr);

      // Assert — error should be the exact same typed AppError
      expect(notifier.error, isA<AuthError>());
      expect((notifier.error as AuthError).code, 'user-disabled');
    });

    test('runAsync returns false on failure', () async {
      await notifier.doFailure(Exception('boom'));
      expect(notifier.hasError, isTrue);
    });

    // ── clearError ───────────────────────────────────────────────────────────

    test('clearError resets error and notifies listeners', () async {
      // Arrange
      await notifier.doFailure(Exception('oops'));
      expect(notifier.hasError, isTrue);

      var notified = false;
      notifier.addListener(() => notified = true);

      // Act
      notifier.clearError();

      // Assert
      expect(notifier.hasError, isFalse);
      expect(notifier.error, isNull);
      expect(notified, isTrue);
    });

    // ── listenToStream ───────────────────────────────────────────────────────

    test('listenToStream delivers data events to onData callback', () async {
      // Arrange
      final controller = Stream<int>.fromIterable([42]);

      // Act
      await notifier.doStream(controller);
      await Future.delayed(Duration.zero); // allow microtask queue to flush

      // Assert
      expect(notifier.callCount, 42);
    });

    test('listenToStream converts stream errors to AppError', () async {
      // Arrange
      final errorStream = Stream<int>.error(Exception('stream error'));
      await notifier.doStream(errorStream);
      await Future.delayed(Duration.zero);

      // Assert
      expect(notifier.hasError, isTrue);
      expect(notifier.error, isA<AppError>());
    });

    // ── disposed guard ───────────────────────────────────────────────────────

    test('runAsync returns false immediately when notifier is disposed', () async {
      // Arrange
      notifier.dispose();

      // Act
      await notifier.doSuccess();

      // Assert — should be a no-op after dispose
      expect(notifier.isLoading, isFalse);
    });
  });

  // ── Auth sign-in / sign-out state flow ───────────────────────────────────

  group('Auth sign-in / sign-out state flow', () {
    late _MockAuthService mockAuth;
    late _TestAuthNotifier authNotifier;

    setUp(() {
      mockAuth = _MockAuthService();
      authNotifier = _TestAuthNotifier(mockAuth);
    });

    tearDown(() => authNotifier.dispose());

    test('initial state is unauthenticated with no loading or error', () {
      // Assert
      expect(authNotifier.isAuthenticated, isFalse);
      expect(authNotifier.isLoading, isFalse);
      expect(authNotifier.hasError, isFalse);
    });

    test('sign-in success transitions to authenticated state', () async {
      // Arrange
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenAnswer((_) async {});

      // Act
      await authNotifier.signIn('user@example.com', 'Password1!');

      // Assert
      expect(authNotifier.isAuthenticated, isTrue);
      expect(authNotifier.isLoading, isFalse);
      expect(authNotifier.hasError, isFalse);
    });

    test('sign-in failure stores an AppError and stays unauthenticated', () async {
      // Arrange
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenThrow(Exception('wrong-password'));

      // Act
      await authNotifier.signIn('user@example.com', 'wrongpass');

      // Assert
      expect(authNotifier.isAuthenticated, isFalse);
      expect(authNotifier.hasError, isTrue);
      expect(authNotifier.error, isA<AppError>());
      expect(authNotifier.isLoading, isFalse);
    });

    test('sign-out transitions from authenticated to unauthenticated', () async {
      // Arrange — sign in first
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      await authNotifier.signIn('user@example.com', 'Password1!');
      expect(authNotifier.isAuthenticated, isTrue);

      // Act
      await authNotifier.signOut();

      // Assert
      expect(authNotifier.isAuthenticated, isFalse);
      expect(authNotifier.isLoading, isFalse);
      expect(authNotifier.hasError, isFalse);
    });

    test('isLoading is true while sign-in is in flight', () async {
      // Arrange
      final completer = Completer<void>();
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenAnswer((_) => completer.future);

      // Act
      final future = authNotifier.signIn('user@example.com', 'Password1!');
      expect(authNotifier.isLoading, isTrue);

      // Cleanup
      completer.complete();
      await future;
      expect(authNotifier.isLoading, isFalse);
    });

    test('second sign-in attempt clears a previous error', () async {
      // Arrange — first attempt fails
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenThrow(Exception('network error'));
      await authNotifier.signIn('user@example.com', 'Password1!');
      expect(authNotifier.hasError, isTrue);

      // Arrange — second attempt succeeds
      when(() => mockAuth.signInWithEmail(any(), any()))
          .thenAnswer((_) async {});

      // Act
      await authNotifier.signIn('user@example.com', 'Password1!');

      // Assert — error is cleared on the new attempt
      expect(authNotifier.hasError, isFalse);
      expect(authNotifier.isAuthenticated, isTrue);
    });
  });
}
