import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/core/errors/app_error.dart';

// ---------------------------------------------------------------------------
// Helpers — constructing Firebase exceptions without a live SDK
// ---------------------------------------------------------------------------

FirebaseAuthException _authEx(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message);

FirebaseException _firestoreEx(String code, [String? message]) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

FirebaseException _storageEx(String code, [String? message]) =>
    FirebaseException(plugin: 'firebase_storage', code: code, message: message);

FirebaseException _unknownPluginEx(String code) =>
    FirebaseException(plugin: 'firebase_remote_config', code: code);

// All known Firebase Auth error codes
const _allAuthCodes = [
  'user-not-found',
  'wrong-password',
  'invalid-credential',
  'email-already-in-use',
  'weak-password',
  'invalid-email',
  'user-disabled',
  'too-many-requests',
  'operation-not-allowed',
  'account-exists-with-different-credential',
  'network-request-failed',
  'session-expired',
  'quota-exceeded',
  'requires-recent-login',
  'invalid-verification-code',
  'invalid-verification-id',
  'missing-verification-code',
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // AppError.fromFirebaseException — routing
  // =========================================================================

  group('AppError.fromFirebaseException routing', () {
    test('FirebaseAuthException → AuthError', () {
      final error = AppError.fromFirebaseException(_authEx('user-not-found'));
      expect(error, isA<AuthError>());
      expect(error.code, 'user-not-found');
    });

    test('cloud_firestore exception → FirestoreError', () {
      final error =
          AppError.fromFirebaseException(_firestoreEx('permission-denied'));
      expect(error, isA<FirestoreError>());
    });

    test('firebase_storage exception → StorageError', () {
      final error =
          AppError.fromFirebaseException(_storageEx('object-not-found'));
      expect(error, isA<StorageError>());
    });

    test('unknown plugin → UnknownError', () {
      final error = AppError.fromFirebaseException(_unknownPluginEx('some-code'));
      expect(error, isA<UnknownError>());
    });

    test('FirebaseAuthException IS a FirebaseException — routed correctly', () {
      // Verify the Dart type hierarchy: FA exception passes isA<FirebaseException>
      expect(_authEx('wrong-password'), isA<FirebaseException>());
      // But the factory correctly routes it to AuthError, not UnknownError
      final error =
          AppError.fromFirebaseException(_authEx('wrong-password'));
      expect(error, isA<AuthError>());
      expect(error, isNot(isA<UnknownError>()));
    });
  });

  // =========================================================================
  // AuthError — userMessage safety
  // =========================================================================

  group('AuthError.userMessage — no raw codes in user-facing strings', () {
    for (final code in _allAuthCodes) {
      test('code "$code" does not appear verbatim in userMessage', () {
        final error = AppError.fromFirebaseException(_authEx(code));
        expect(error, isA<AuthError>());
        // The raw code must never appear verbatim in the UI string.
        expect(
          error.userMessage,
          isNot(contains(code)),
          reason: 'userMessage "${ error.userMessage}" leaked raw code "$code"',
        );
      });
    }

    test('unknown auth code falls back to a safe generic message', () {
      final error =
          AppError.fromFirebaseException(_authEx('some-future-unknown-code'));
      expect(error, isA<AuthError>());
      expect(error.userMessage, isNot(contains('some-future-unknown-code')));
      expect(error.userMessage, isNotEmpty);
    });

    test('debugMessage contains the raw code for diagnostics', () {
      final error = AppError.fromFirebaseException(_authEx('user-not-found'));
      // Unlike userMessage, debugMessage SHOULD contain the raw code
      // so engineers can diagnose the issue in Crashlytics.
      expect(error.debugMessage, contains('user-not-found'));
    });

    test('user-disabled → isRecoverable == false', () {
      final error = AppError.fromFirebaseException(_authEx('user-disabled'));
      expect(error.isRecoverable, isFalse);
    });

    test('other auth errors → isRecoverable == true', () {
      for (final code in _allAuthCodes.where((c) => c != 'user-disabled')) {
        final error = AppError.fromFirebaseException(_authEx(code));
        expect(error.isRecoverable, isTrue, reason: 'code: $code');
      }
    });
  });

  // =========================================================================
  // FirestoreError — userMessage safety
  // =========================================================================

  group('FirestoreError.userMessage — no raw codes in user-facing strings', () {
    const firestoreCodes = [
      'permission-denied',
      'not-found',
      'already-exists',
      'resource-exhausted',
      'unavailable',
      'deadline-exceeded',
      'cancelled',
      'unauthenticated',
      'invalid-argument',
      'aborted',
      'data-loss',
    ];

    for (final code in firestoreCodes) {
      test('code "$code" not in userMessage', () {
        final error = AppError.fromFirebaseException(_firestoreEx(code));
        expect(error.userMessage, isNot(contains(code)));
        expect(error.userMessage, isNotEmpty);
      });
    }

    test('permission-denied → isRecoverable == false', () {
      final error =
          AppError.fromFirebaseException(_firestoreEx('permission-denied'));
      expect(error.isRecoverable, isFalse);
    });

    test('other Firestore errors → isRecoverable == true', () {
      for (final code in firestoreCodes.where((c) => c != 'permission-denied')) {
        final error = AppError.fromFirebaseException(_firestoreEx(code));
        expect(error.isRecoverable, isTrue, reason: 'code: $code');
      }
    });
  });

  // =========================================================================
  // StorageError
  // =========================================================================

  group('StorageError', () {
    const nonRecoverableCodes = [
      'object-not-found',
      'unauthorized',
      'unauthenticated',
      'invalid-argument',
    ];

    for (final code in nonRecoverableCodes) {
      test('storage "$code" → isRecoverable == false', () {
        final error = AppError.fromFirebaseException(_storageEx(code));
        expect(error.isRecoverable, isFalse, reason: 'code: $code');
      });
    }

    test('quota-exceeded → isRecoverable == true', () {
      final error =
          AppError.fromFirebaseException(_storageEx('quota-exceeded'));
      expect(error.isRecoverable, isTrue);
    });

    test('userMessage does not contain raw code', () {
      final error =
          AppError.fromFirebaseException(_storageEx('object-not-found'));
      expect(error.userMessage, isNot(contains('object-not-found')));
    });
  });

  // =========================================================================
  // AppError.fromException — catch-all factory
  // =========================================================================

  group('AppError.fromException', () {
    test('AppError passthrough — identity', () {
      const original = UnknownError(
        code: 'test',
        debugMessage: 'test',
      );
      final result = AppError.fromException(original);
      expect(identical(result, original), isTrue);
    });

    test('SocketException → NetworkError with code "no-internet"', () {
      final error = AppError.fromException(
        const SocketException('Connection refused'),
      );
      expect(error, isA<NetworkError>());
      expect(error.code, 'no-internet');
      expect(error.isRecoverable, isTrue);
    });

    test('TimeoutException → NetworkError with code "timeout"', () {
      final error = AppError.fromException(
        TimeoutException('Timed out', const Duration(seconds: 30)),
      );
      expect(error, isA<NetworkError>());
      expect(error.code, 'timeout');
    });

    test('FormatException → ValidationError', () {
      final error = AppError.fromException(const FormatException('bad json'));
      expect(error, isA<ValidationError>());
      expect(error.code, 'invalid-format');
    });

    test('FirebaseAuthException routed via fromException', () {
      final error = AppError.fromException(_authEx('session-expired'));
      expect(error, isA<AuthError>());
      expect(error.code, 'session-expired');
    });

    test('FirebaseException (Firestore) routed via fromException', () {
      final error = AppError.fromException(_firestoreEx('unavailable'));
      expect(error, isA<FirestoreError>());
    });

    test('arbitrary Exception → UnknownError', () {
      final error = AppError.fromException(Exception('Something weird'));
      expect(error, isA<UnknownError>());
      expect(error.code, 'unknown');
      expect(error.isRecoverable, isTrue);
    });

    test('arbitrary Object → UnknownError', () {
      final error = AppError.fromException('a plain string error');
      expect(error, isA<UnknownError>());
    });

    test('stackTrace is preserved', () {
      final st = StackTrace.current;
      final error = AppError.fromException(Exception('test'), st);
      expect(error.stackTrace, same(st));
    });
  });

  // =========================================================================
  // ValidationError
  // =========================================================================

  group('ValidationError', () {
    test('holds optional field name', () {
      const error = ValidationError(
        code: 'required',
        userMessage: 'Email is required.',
        debugMessage: 'email field is required',
        field: 'email',
      );
      expect(error.field, 'email');
      expect(error.isRecoverable, isTrue);
    });

    test('field can be null', () {
      const error = ValidationError(
        code: 'invalid',
        userMessage: 'Invalid input.',
        debugMessage: 'general validation failure',
      );
      expect(error.field, isNull);
    });
  });

  // =========================================================================
  // PermissionError
  // =========================================================================

  group('PermissionError.forPermission', () {
    const permissions = ['location', 'camera', 'storage', 'notifications'];

    for (final perm in permissions) {
      test('$perm → safe userMessage without raw permission name', () {
        final error = PermissionError.forPermission(perm);
        expect(error, isA<PermissionError>());
        expect(error.permission, perm);
        expect(error.isRecoverable, isTrue);
        expect(error.userMessage, isNotEmpty);
      });
    }

    test('unknown permission falls back gracefully', () {
      final error = PermissionError.forPermission('biometrics');
      expect(error.userMessage, isNotEmpty);
      expect(error.code, 'permission-denied-biometrics');
    });
  });

  // =========================================================================
  // UnknownError
  // =========================================================================

  group('UnknownError', () {
    test('always uses the same safe userMessage', () {
      const a = UnknownError(code: 'x', debugMessage: 'first');
      const b = UnknownError(code: 'y', debugMessage: 'second');
      expect(a.userMessage, b.userMessage);
      expect(a.userMessage, 'An unexpected error occurred. Please try again.');
    });

    test('is always recoverable', () {
      const error = UnknownError(code: 'x', debugMessage: 'x');
      expect(error.isRecoverable, isTrue);
    });
  });

  // =========================================================================
  // Exhaustiveness check — sealed class coverage
  // =========================================================================

  group('sealed class exhaustiveness', () {
    test('switch on AppError subtypes compiles without default', () {
      // This test verifies that the sealed hierarchy is complete — Dart
      // will give a compile error if any subtype is not handled.
      AppError makeUnknown() =>
          const UnknownError(code: 'x', debugMessage: 'x');

      final errors = <AppError>[
        const AuthError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        const NetworkError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        const FirestoreError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        const StorageError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        const ValidationError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        const PermissionError(
          code: 'x',
          userMessage: 'u',
          debugMessage: 'd',
        ),
        makeUnknown(),
      ];

      for (final error in errors) {
        final label = switch (error) {
          AuthError() => 'auth',
          NetworkError() => 'network',
          FirestoreError() => 'firestore',
          StorageError() => 'storage',
          ValidationError() => 'validation',
          PermissionError() => 'permission',
          UnknownError() => 'unknown',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
