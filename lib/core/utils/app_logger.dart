import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin logging wrapper.
///
/// Rules:
///   • [debug] emits only in debug mode — stripped entirely from release builds.
///   • [error] always records to Crashlytics; also prints in debug mode.
///   • Neither method accepts raw user identifiers, tokens, or credentials.
///     Callers must sanitise before calling (omit UIDs, use opaque IDs).
class AppLogger {
  AppLogger._();

  /// Log a debug-only message. No-ops in release builds.
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint(tag != null ? '[$tag] $message' : message);
    }
  }

  /// Log an error. Always sent to Crashlytics; printed to console in debug mode.
  static void error(
    String message, {
    String? tag,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('[ERROR]${tag != null ? '[$tag]' : ''} $message');
      if (exception != null) debugPrint('  exception: $exception');
    }
    FirebaseCrashlytics.instance.recordError(
      exception ?? message,
      stackTrace,
      reason: tag != null ? '[$tag] $message' : message,
      fatal: false,
    );
  }
}
