import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/core/errors/app_error.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuthException extends Mock
    implements FirebaseAuthException {
  final String _code;
  final String? _message;
  _MockFirebaseAuthException(this._code, [this._message]);

  @override
  String get code => _code;
  @override
  String? get message => _message;
  @override
  String get plugin => 'firebase_auth';
}

class _MockFirebaseException extends Mock implements FirebaseException {
  final String _plugin;
  final String _code;
  _MockFirebaseException(this._plugin, this._code);

  @override
  String get plugin => _plugin;
  @override
  String get code => _code;
  @override
  String? get message => null;
}

void main() {
  group('AppError hierarchy — userMessage and isRecoverable', () {
    // ── AuthError ────────────────────────────────────────────────────────────

    group('AuthError', () {
      test('user-not-found maps to descriptive userMessage', () {
        final e = _MockFirebaseAuthException('user-not-found');
        final err = AppError.fromFirebaseException(e);
        expect(err, isA<AuthError>());
        expect(err.userMessage, contains('No account found'));
        expect(err.isRecoverable, isTrue);
      });

      test('wrong-password is recoverable', () {
        final e = _MockFirebaseAuthException('wrong-password');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.isRecoverable, isTrue);
        expect(err.userMessage, contains('Incorrect password'));
      });

      test('user-disabled is NOT recoverable', () {
        final e = _MockFirebaseAuthException('user-disabled');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.isRecoverable, isFalse);
        expect(err.userMessage, contains('disabled'));
      });

      test('invalid-credential maps to descriptive message', () {
        final e = _MockFirebaseAuthException('invalid-credential');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('Invalid credentials'));
      });

      test('unknown auth code maps to generic fallback message', () {
        final e = _MockFirebaseAuthException('some-unknown-code');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('Authentication failed'));
      });

      test('userMessage never contains raw Firebase error code', () {
        for (final code in [
          'user-not-found',
          'wrong-password',
          'email-already-in-use',
          'weak-password',
          'too-many-requests',
        ]) {
          final e = _MockFirebaseAuthException(code);
          final err = AppError.fromFirebaseException(e);
          expect(
            err.userMessage.contains(code),
            isFalse,
            reason: 'userMessage must not expose raw code "$code"',
          );
        }
      });
    });

    // ── NetworkError ─────────────────────────────────────────────────────────

    group('NetworkError', () {
      test('SocketException maps to NetworkError', () {
        // Generic exception → UnknownError; SocketException → NetworkError.
        // We test the no-internet factory directly:
        const noInternet = NetworkError(
          code: 'no-internet',
          userMessage: 'No internet connection. Please check your network settings.',
          debugMessage: 'SocketException test',
        );
        expect(noInternet.isRecoverable, isTrue);
        expect(noInternet.code, 'no-internet');
      });

      test('timeout NetworkError is always recoverable', () {
        const timeout = NetworkError(
          code: 'timeout',
          userMessage: 'Request timed out. Please try again.',
          debugMessage: 'timeout test',
        );
        expect(timeout.isRecoverable, isTrue);
      });
    });

    // ── FirestoreError ───────────────────────────────────────────────────────

    group('FirestoreError', () {
      test('permission-denied is NOT recoverable', () {
        final e =
            _MockFirebaseException('cloud_firestore', 'permission-denied');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.isRecoverable, isFalse);
        expect(err.userMessage, contains('permission'));
      });

      test('unavailable is recoverable', () {
        final e = _MockFirebaseException('cloud_firestore', 'unavailable');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.isRecoverable, isTrue);
      });

      test('unknown firestore code maps to generic message', () {
        final e =
            _MockFirebaseException('cloud_firestore', 'mysterious-error');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.userMessage, contains('database error'));
      });
    });

    // ── StorageError ─────────────────────────────────────────────────────────

    group('StorageError', () {
      test('object-not-found is NOT recoverable', () {
        final e =
            _MockFirebaseException('firebase_storage', 'object-not-found');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isFalse);
      });

      test('retry-limit-exceeded IS recoverable', () {
        final e = _MockFirebaseException(
            'firebase_storage', 'retry-limit-exceeded');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isTrue);
      });

      test('canceled IS recoverable', () {
        final e = _MockFirebaseException('firebase_storage', 'canceled');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isTrue);
      });
    });

    // ── ValidationError ──────────────────────────────────────────────────────

    group('ValidationError', () {
      test('is always recoverable', () {
        const err = ValidationError(
          code: 'required',
          userMessage: 'Field is required.',
          debugMessage: 'test',
          field: 'email',
        );
        expect(err.isRecoverable, isTrue);
        expect(err.field, 'email');
      });

      test('FormatException maps to ValidationError', () {
        final err = AppError.fromException(const FormatException('bad json'));
        expect(err, isA<ValidationError>());
        expect(err.isRecoverable, isTrue);
      });
    });

    // ── PermissionError ──────────────────────────────────────────────────────

    group('PermissionError', () {
      for (final perm in ['location', 'camera', 'storage', 'notifications']) {
        test('$perm permission has descriptive userMessage and is recoverable',
            () {
          final err = PermissionError.forPermission(perm);
          expect(err.isRecoverable, isTrue);
          expect(err.permission, perm);
          expect(err.userMessage, isNotEmpty);
          expect(err.userMessage.length, greaterThan(10));
        });
      }
    });

    // ── UnknownError ─────────────────────────────────────────────────────────

    group('UnknownError', () {
      test('is always recoverable with generic message', () {
        final err = AppError.fromException(Exception('surprise'));
        expect(err, isA<UnknownError>());
        expect(err.isRecoverable, isTrue);
        expect(err.userMessage, contains('unexpected error'));
      });

      test('AppError.fromException returns the same error when passed an AppError',
          () {
        const existing = NetworkError(
          code: 'no-internet',
          userMessage: 'msg',
          debugMessage: 'debug',
        );
        final result = AppError.fromException(existing);
        expect(identical(result, existing), isTrue);
      });
    });

    // ── debugMessage / userMessage contract ─────────────────────────────────

    group('debugMessage vs userMessage contract', () {
      test('debugMessage contains technical detail that userMessage omits', () {
        final e = _MockFirebaseAuthException(
            'unknown-reason', 'raw firebase internal detail');
        final err = AppError.fromFirebaseException(e);
        expect(err.debugMessage, contains('FirebaseAuthException'));
        // userMessage must not leak the raw Firebase message
        expect(err.userMessage, isNot(contains('raw firebase internal detail')));
      });
    });

    // ── AuthError — additional code mappings ─────────────────────────────────

    group('AuthError — additional code mappings', () {
      test('email-already-in-use maps to "already exists" message and is recoverable', () {
        final e = _MockFirebaseAuthException('email-already-in-use');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('already exists'));
        expect(err.isRecoverable, isTrue);
      });

      test('weak-password maps to stronger-password message', () {
        final e = _MockFirebaseAuthException('weak-password');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('stronger password'));
        expect(err.isRecoverable, isTrue);
      });

      test('too-many-requests maps to wait message and is recoverable', () {
        final e = _MockFirebaseAuthException('too-many-requests');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('many'));
        expect(err.isRecoverable, isTrue);
      });

      test('network-request-failed maps to network message', () {
        final e = _MockFirebaseAuthException('network-request-failed');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('Network'));
      });

      test('requires-recent-login maps to sign-in-again message', () {
        final e = _MockFirebaseAuthException('requires-recent-login');
        final err = AppError.fromFirebaseException(e) as AuthError;
        expect(err.userMessage, contains('sign in again'));
      });
    });

    // ── FirestoreError — additional code mappings ────────────────────────────

    group('FirestoreError — additional code mappings', () {
      test('not-found maps to descriptive message and is recoverable', () {
        final e = _MockFirebaseException('cloud_firestore', 'not-found');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.userMessage, contains('not found'));
        expect(err.isRecoverable, isTrue);
      });

      test('unauthenticated prompts the user to sign in', () {
        final e = _MockFirebaseException('cloud_firestore', 'unauthenticated');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.userMessage, contains('sign in'));
        expect(err.isRecoverable, isTrue);
      });

      test('resource-exhausted is recoverable', () {
        final e = _MockFirebaseException('cloud_firestore', 'resource-exhausted');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.isRecoverable, isTrue);
      });

      test('deadline-exceeded is recoverable', () {
        final e = _MockFirebaseException('cloud_firestore', 'deadline-exceeded');
        final err = AppError.fromFirebaseException(e) as FirestoreError;
        expect(err.isRecoverable, isTrue);
      });
    });

    // ── StorageError — non-recoverable codes ─────────────────────────────────

    group('StorageError — non-recoverable codes', () {
      test('unauthenticated is NOT recoverable', () {
        final e = _MockFirebaseException('firebase_storage', 'unauthenticated');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isFalse);
        expect(err.userMessage, contains('sign in'));
      });

      test('unauthorized is NOT recoverable', () {
        final e = _MockFirebaseException('firebase_storage', 'unauthorized');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isFalse);
        expect(err.userMessage, contains('permission'));
      });

      test('quota-exceeded is recoverable', () {
        final e = _MockFirebaseException('firebase_storage', 'quota-exceeded');
        final err = AppError.fromFirebaseException(e) as StorageError;
        expect(err.isRecoverable, isTrue);
      });
    });

    // ── NetworkError — stdlib exception mapping ──────────────────────────────

    group('NetworkError — stdlib exception mapping', () {
      test('TimeoutException maps to NetworkError with timeout code', () {
        final err = AppError.fromException(
          TimeoutException('Connection timed out'),
        );
        expect(err, isA<NetworkError>());
        expect(err.code, 'timeout');
        expect(err.isRecoverable, isTrue);
        expect(err.userMessage, contains('timed out'));
      });

      test('SocketException maps to NetworkError with no-internet code', () {
        final err = AppError.fromException(
          const SocketException('Network unreachable'),
        );
        expect(err, isA<NetworkError>());
        expect(err.code, 'no-internet');
        expect(err.isRecoverable, isTrue);
        expect(err.userMessage, contains('internet'));
      });
    });
  });
}
