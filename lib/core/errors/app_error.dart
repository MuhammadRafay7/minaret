import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------------------------
// AppError — single sealed hierarchy for the entire app.
//
// Design constraints:
//   • userMessage  — sanitised, safe to render in UI, never contains raw
//                    Firebase error codes or stack traces.
//   • debugMessage — full technical detail; logged to Crashlytics only,
//                    never shown to users.
//   • originalError — the raw caught object; nullable so const subtypes
//                     (e.g. a static "no network" constant) are possible.
//
// All direct subtypes live in this file (sealed class requirement).
// ---------------------------------------------------------------------------

sealed class AppError implements Exception {
  const AppError({
    required this.code,
    required this.userMessage,
    required this.debugMessage,
    this.originalError,
    this.stackTrace,
  });

  /// Machine-readable identifier — stable across releases (used in tests,
  /// analytics, and retry logic). Never surfaced raw to the user.
  final String code;

  /// Sanitised string safe for display in the UI.
  /// Rule: must not contain raw Firebase error codes, stack traces,
  /// internal identifiers, or any value that came directly from an
  /// external service without sanitisation.
  final String userMessage;

  /// Full technical detail for diagnostics. Logged to Crashlytics only.
  /// May contain exception messages, codes, plugin names, etc.
  final String debugMessage;

  /// The original caught object. Passed to Crashlytics for native grouping.
  final Object? originalError;

  final StackTrace? stackTrace;

  bool get isRecoverable;

  // -------------------------------------------------------------------------
  // Factory: FirebaseException → typed AppError subtype
  // -------------------------------------------------------------------------

  factory AppError.fromFirebaseException(FirebaseException e) {
    // FirebaseAuthException IS a FirebaseException — check it first.
    if (e is FirebaseAuthException) {
      return AuthError._fromFirebaseAuth(e);
    }
    return switch (e.plugin) {
      'cloud_firestore' => FirestoreError._fromFirebaseException(e),
      'firebase_storage' => StorageError._fromFirebaseException(e),
      _ => UnknownError(
          code: e.code,
          debugMessage:
              'FirebaseException [${e.plugin}/${e.code}]: ${e.message ?? 'no message'}',
          originalError: e,
        ),
    };
  }

  // -------------------------------------------------------------------------
  // Factory: any caught Object → AppError
  // -------------------------------------------------------------------------

  factory AppError.fromException(Object e, [StackTrace? st]) {
    if (e is AppError) return e;
    if (e is FirebaseException) return AppError.fromFirebaseException(e);
    if (e is DioException) return NetworkError._fromDio(e, st);
    if (e is SocketException) {
      return NetworkError(
        code: 'no-internet',
        userMessage:
            'No internet connection. Please check your network settings.',
        debugMessage: 'SocketException: ${e.message} (osError: ${e.osError})',
        originalError: e,
        stackTrace: st,
      );
    }
    if (e is TimeoutException) {
      return NetworkError(
        code: 'timeout',
        userMessage: 'Request timed out. Please try again.',
        debugMessage: 'TimeoutException: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
    if (e is FormatException) {
      return ValidationError(
        code: 'invalid-format',
        userMessage: 'Received unexpected data. Please try again.',
        debugMessage: 'FormatException: ${e.message} (source: ${e.source})',
        originalError: e,
        stackTrace: st,
      );
    }
    return UnknownError(
      code: 'unknown',
      debugMessage: '${e.runtimeType}: $e',
      originalError: e,
      stackTrace: st,
    );
  }

  @override
  String toString() => 'AppError($runtimeType, code: $code)';
}

// ---------------------------------------------------------------------------
// AuthError
// ---------------------------------------------------------------------------

final class AuthError extends AppError {
  const AuthError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get isRecoverable => code != 'user-disabled';

  factory AuthError._fromFirebaseAuth(FirebaseAuthException e) {
    final userMessage = switch (e.code) {
      'user-not-found' =>
        'No account found with this email address. Please check your credentials.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' =>
        'Invalid credentials. Please check your email and password.',
      'email-already-in-use' =>
        'An account already exists with this email address.',
      'weak-password' =>
        'Please choose a stronger password (at least 8 characters, '
            'mixed case and numbers).',
      'invalid-email' => 'Please enter a valid email address.',
      'user-disabled' =>
        'This account has been disabled. Please contact support.',
      'too-many-requests' =>
        'Too many failed attempts. Please wait a few minutes and try again.',
      'operation-not-allowed' =>
        'This sign-in method is not available. Please contact support.',
      'account-exists-with-different-credential' =>
        'An account already exists with different sign-in credentials. '
            'Try signing in another way.',
      'network-request-failed' =>
        'Network error during authentication. Please check your connection.',
      'session-expired' =>
        'Your session has expired. Please sign in again.',
      'quota-exceeded' =>
        'Service is temporarily unavailable. Please try again later.',
      'requires-recent-login' =>
        'Please sign in again to complete this action.',
      'invalid-verification-code' =>
        'Invalid verification code. Please check and try again.',
      'invalid-verification-id' =>
        'Verification session expired. Please request a new code.',
      'missing-verification-code' => 'Please enter the verification code.',
      _ => 'Authentication failed. Please try again.',
    };
    return AuthError(
      code: e.code,
      userMessage: userMessage,
      debugMessage:
          'FirebaseAuthException [${e.code}]: ${e.message ?? 'no message'}',
      originalError: e,
    );
  }
}

// ---------------------------------------------------------------------------
// NetworkError
// ---------------------------------------------------------------------------

final class NetworkError extends AppError {
  const NetworkError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get isRecoverable => true;

  factory NetworkError._fromDio(DioException e, [StackTrace? st]) {
    final (code, userMessage) = switch (e.type) {
      DioExceptionType.connectionTimeout => (
          'connection-timeout',
          'Connection timed out. Please check your network and try again.'
        ),
      DioExceptionType.sendTimeout => (
          'send-timeout',
          'Request timed out. Please try again.'
        ),
      DioExceptionType.receiveTimeout => (
          'receive-timeout',
          'Server took too long to respond. Please try again.'
        ),
      DioExceptionType.connectionError => (
          'no-internet',
          'No internet connection. Please check your network settings.'
        ),
      DioExceptionType.cancel => (
          'cancelled',
          'Request was cancelled. Please try again.'
        ),
      DioExceptionType.badCertificate => (
          'bad-certificate',
          'Secure connection failed. Please update the app.'
        ),
      DioExceptionType.badResponse => _httpCodeTuple(
          e.response?.statusCode ?? 0,
        ),
      _ => (
          'network-error',
          'A network error occurred. Please check your connection.'
        ),
    };
    return NetworkError(
      code: code,
      userMessage: userMessage,
      debugMessage: 'DioException [${e.type.name}]: ${e.message} '
          '(status: ${e.response?.statusCode})',
      originalError: e,
      stackTrace: st,
    );
  }

  static (String, String) _httpCodeTuple(int statusCode) => switch (statusCode) {
        400 => ('bad-request', 'Invalid request. Please check your input.'),
        401 => (
            'unauthorized',
            'Authentication required. Please sign in again.'
          ),
        403 => (
            'forbidden',
            "You don't have permission to perform this action."
          ),
        404 => ('not-found', 'The requested resource was not found.'),
        408 => ('request-timeout', 'Request timed out. Please try again.'),
        429 => (
            'rate-limited',
            'Too many requests. Please wait a moment and try again.'
          ),
        int s when s >= 500 => (
            'server-error',
            'Server error. Please try again later.'
          ),
        _ => ('http-error', 'A network error occurred. Please try again.'),
      };
}

// ---------------------------------------------------------------------------
// FirestoreError
// ---------------------------------------------------------------------------

final class FirestoreError extends AppError {
  const FirestoreError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get isRecoverable => code != 'permission-denied';

  factory FirestoreError._fromFirebaseException(FirebaseException e) {
    final userMessage = switch (e.code) {
      'permission-denied' =>
        "You don't have permission to access this data.",
      'not-found' => 'The requested data was not found.',
      'already-exists' =>
        'This record already exists. Please refresh and try again.',
      'resource-exhausted' =>
        'Server is busy. Please try again in a moment.',
      'unavailable' =>
        'Service is temporarily offline. Please try again later.',
      'deadline-exceeded' =>
        'The request took too long. Please try again.',
      'cancelled' => 'The operation was interrupted. Please try again.',
      'unauthenticated' => 'Please sign in to continue.',
      'invalid-argument' =>
        'Invalid data submitted. Please check your input.',
      'aborted' =>
        'Operation could not be completed. Please try again.',
      'data-loss' =>
        'Data could not be loaded. Please try refreshing.',
      _ => 'A database error occurred. Please try again.',
    };
    return FirestoreError(
      code: e.code,
      userMessage: userMessage,
      debugMessage:
          'FirebaseException [cloud_firestore/${e.code}]: ${e.message ?? 'no message'}',
      originalError: e,
    );
  }
}

// ---------------------------------------------------------------------------
// StorageError
// ---------------------------------------------------------------------------

final class StorageError extends AppError {
  const StorageError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
  });

  static const _nonRecoverable = {
    'object-not-found',
    'unauthorized',
    'unauthenticated',
    'invalid-argument',
  };

  @override
  bool get isRecoverable => !_nonRecoverable.contains(code);

  factory StorageError._fromFirebaseException(FirebaseException e) {
    final userMessage = switch (e.code) {
      'object-not-found' => 'File not found. It may have been deleted.',
      'bucket-not-found' ||
      'project-not-found' =>
        'Storage service is unavailable. Please contact support.',
      'quota-exceeded' =>
        'Storage quota exceeded. Please contact support.',
      'unauthenticated' => 'Please sign in to access this file.',
      'unauthorized' =>
        "You don't have permission to access this file.",
      'retry-limit-exceeded' =>
        'Upload failed after multiple attempts. Please try again.',
      'canceled' => 'Upload was cancelled.',
      'invalid-checksum' =>
        'File upload was corrupted. Please try again.',
      'cannot-slice-blob' =>
        'Could not process this file. Please try a different file.',
      'server-file-wrong-size' =>
        'File upload failed. Please check your connection and try again.',
      _ => 'A file operation error occurred. Please try again.',
    };
    return StorageError(
      code: e.code,
      userMessage: userMessage,
      debugMessage:
          'FirebaseException [firebase_storage/${e.code}]: ${e.message ?? 'no message'}',
      originalError: e,
    );
  }
}

// ---------------------------------------------------------------------------
// ValidationError
// ---------------------------------------------------------------------------

final class ValidationError extends AppError {
  const ValidationError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
    this.field,
  });

  /// The specific field that failed validation, if applicable.
  /// Used by form widgets to highlight the correct input.
  final String? field;

  @override
  bool get isRecoverable => true;
}

// ---------------------------------------------------------------------------
// PermissionError
// ---------------------------------------------------------------------------

final class PermissionError extends AppError {
  const PermissionError({
    required super.code,
    required super.userMessage,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
    this.permission,
  });

  /// The device permission name: 'location', 'camera', 'storage', 'notifications'.
  final String? permission;

  @override
  bool get isRecoverable => true;

  factory PermissionError.forPermission(String permission) {
    final userMessage = switch (permission) {
      'location' =>
        'Location access is required to find nearby mosques. '
            'Please enable it in your device settings.',
      'camera' =>
        'Camera access is required to take photos. '
            'Please enable it in your device settings.',
      'storage' =>
        'Storage access is required to save files. '
            'Please enable it in your device settings.',
      'notifications' =>
        'Notification permission is required for prayer time alerts. '
            'Please enable it in your device settings.',
      _ =>
        'A permission is required for this feature. '
            'Please check your device settings.',
    };
    return PermissionError(
      code: 'permission-denied-$permission',
      userMessage: userMessage,
      debugMessage: 'Device permission denied: $permission',
      permission: permission,
    );
  }
}

// ---------------------------------------------------------------------------
// UnknownError
// ---------------------------------------------------------------------------

final class UnknownError extends AppError {
  const UnknownError({
    required super.code,
    required super.debugMessage,
    super.originalError,
    super.stackTrace,
  }) : super(
          userMessage: 'An unexpected error occurred. Please try again.',
        );

  @override
  bool get isRecoverable => true;
}
