import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../errors/app_error.dart';
import '../errors/error_extensions.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// ErrorBoundary
//
// Wraps the entire widget tree and intercepts two error channels:
//
//   1. FlutterError.onError — synchronous Flutter framework errors
//      (assertion failures, layout exceptions, widget build errors).
//
//   2. PlatformDispatcher.instance.onError — asynchronous errors that
//      escape all Zone boundaries (uncaught Futures, Isolate errors).
//
// When an error is caught the full app tree is replaced with _ErrorScreen.
// The "Reload app" button increments _key, which triggers a KeyedSubtree
// rebuild — effectively re-mounting the whole app without process restart.
//
// Usage (main.dart):
//
//   runApp(
//     ErrorBoundary(
//       child: MinaretApp(),
//     ),
//   );
// ---------------------------------------------------------------------------

class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({super.key, required this.child});

  final Widget child;

  /// Triggers an app reload from anywhere in the tree.
  static void reloadApp(BuildContext context) {
    context.findAncestorStateOfType<_ErrorBoundaryState>()?._reload();
  }

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;
  int _key = 0;

  // Keep references to the previous handlers so we can restore them on dispose
  // in case ErrorBoundary is removed from the tree mid-session.
  FlutterExceptionHandler? _previousFlutterErrorHandler;
  ErrorCallback? _previousPlatformErrorHandler;

  @override
  void initState() {
    super.initState();

    _previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = _onFlutterError;

    _previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = _onPlatformError;
  }

  @override
  void dispose() {
    FlutterError.onError = _previousFlutterErrorHandler;
    PlatformDispatcher.instance.onError = _previousPlatformErrorHandler;
    super.dispose();
  }

  void _onFlutterError(FlutterErrorDetails details) {
    final appError = AppError.fromException(
      details.exception,
      details.stack,
    );
    appError.logToCrashlyticsSync();

    // In debug mode also forward to the default presenter so the red
    // error screen still appears in the IDE overlay.
    if (kDebugMode) {
      FlutterError.presentError(details);
    }

    if (mounted) setState(() => _error = appError);
  }

  bool _onPlatformError(Object error, StackTrace stack) {
    final appError = AppError.fromException(error, stack);
    appError.logToCrashlyticsSync();
    if (mounted) setState(() => _error = appError);
    return true; // return true = error was handled, don't crash the process
  }

  void _reload() {
    setState(() {
      _error = null;
      _key++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(error: _error!, onReload: _reload);
    }
    return KeyedSubtree(
      key: ValueKey(_key),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorScreen — full-screen fallback shown after an uncaught fatal error.
// ---------------------------------------------------------------------------

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onReload});

  final AppError error;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final fg = isDark ? Colors.white : MinaretTheme.onyx;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: MinaretTheme.gold,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Something went wrong',
                  style: MinaretTheme.heading.copyWith(color: fg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  error.userMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: fg.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload app'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MinaretTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MinaretTheme.buttonRadius,
                        ),
                      ),
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.shade700.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      // debugMessage shown only in debug builds — never in release.
                      'DEBUG: ${error.debugMessage}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade300,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
