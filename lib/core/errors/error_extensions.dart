import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'app_error.dart';

// ---------------------------------------------------------------------------
// Object → AppError
// ---------------------------------------------------------------------------

extension ExceptionToAppError on Object {
  /// Converts any caught exception to an [AppError].
  /// Idempotent: if `this` is already an [AppError] it is returned unchanged.
  ///
  /// Usage:
  ///   ```dart
  ///   try {
  ///     ...
  ///   } catch (e, st) {
  ///     final error = e.toAppError(st);
  ///     error.logToCrashlytics();
  ///     state = AsyncError(error, st);
  ///   }
  ///   ```
  AppError toAppError([StackTrace? stackTrace]) =>
      AppError.fromException(this, stackTrace);
}

// ---------------------------------------------------------------------------
// AppError → Crashlytics
// ---------------------------------------------------------------------------

extension AppErrorCrashlytics on AppError {
  /// Logs this error to Firebase Crashlytics.
  ///
  /// What IS logged (safe for diagnostics):
  ///   • [debugMessage] — technical detail, set by our own factories
  ///   • [code] — machine-readable identifier
  ///   • [runtimeType] — subtype name
  ///   • [originalError] — raw exception for native Crashlytics grouping
  ///   • [stackTrace] — full stack trace
  ///
  /// What is NEVER logged:
  ///   • [userMessage] — may be displayed near user-entered data and could
  ///     therefore transitively contain PII (e.g. email in a validation msg).
  ///
  /// Failures to reach Crashlytics are swallowed — a logging failure must
  /// never crash the app.
  Future<void> logToCrashlytics() async {
    if (kDebugMode) {
      debugPrint(
        '[AppError] ${runtimeType} | code: $code\n'
        '  debug: $debugMessage\n'
        '  recoverable: $isRecoverable\n'
        '  original: $originalError',
      );
      if (stackTrace != null) debugPrint('  stack: $stackTrace');
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        // Pass originalError when available so Crashlytics can group by the
        // native exception type. Fall back to debugMessage as a String error.
        originalError ?? debugMessage,
        stackTrace,
        reason: '$runtimeType/$code: $debugMessage',
        fatal: !isRecoverable,
        printDetails: kDebugMode,
      );
    } catch (crashlyticsError) {
      // Crashlytics itself threw — log locally and move on.
      debugPrint(
        '[AppError] Crashlytics.recordError failed: $crashlyticsError\n'
        '  Suppressed error was: $debugMessage',
      );
    }
  }

  /// Synchronous variant — schedules the Crashlytics call without awaiting.
  /// Use when the call site is not async and you don't need backpressure.
  void logToCrashlyticsSync() => logToCrashlytics();
}
