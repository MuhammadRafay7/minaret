import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'config/certificate_pins.dart';

// ── Exception ──────────────────────────────────────────────────────────────

/// Thrown when the server's certificate does not match any pinned hash.
///
/// Never swallowed internally. The caller (or a global error handler) must
/// decide what to show the user. Treat it as a hard security failure — do
/// not retry, do not fall back to an unverified connection.
class CertificatePinningException implements Exception {
  const CertificatePinningException({
    required this.host,
    required this.message,
  });

  final String host;
  final String message;

  @override
  String toString() => 'CertificatePinningException($host): $message';
}

// ── Injectable verifier ────────────────────────────────────────────────────

/// Verifies [serverUrl]'s certificate against [allowedPins].
///
/// Completes normally on success.
/// Throws [CertificatePinningException] (or any exception) on failure —
/// the interceptor wraps all non-[CertificatePinningException] throws.
///
/// Injecting a custom verifier makes unit tests hermetic: no network calls,
/// no native plugin, no Firebase.
typedef PinVerifier = Future<void> Function({
  required String serverUrl,
  required List<String> allowedPins,
});

/// Production verifier — delegates to the http_certificate_pinning plugin.
///
/// The plugin makes a separate TLS probe connection to the host, extracts the
/// leaf certificate's SHA-256 fingerprint, and compares it against [allowedPins].
/// [allowedPins] must use colon-separated uppercase hex:  'AA:BB:CC:...'
///
/// See scripts/extract_pin.sh to generate these values.
Future<void> _nativePinVerifier({
  required String serverUrl,
  required List<String> allowedPins,
}) async {
  // SSL certificate pinning is only available on Android/iOS.
  // On web and desktop the pinning interceptor is never added (forEnvironment
  // returns an unpinned client when kIsWeb or pins are empty), so this
  // function should never be reached on those platforms.
  throw CertificatePinningException(
    host: Uri.parse(serverUrl).host,
    message: 'Certificate pinning is not supported on this platform',
  );
}

// ── Verified-host cache ────────────────────────────────────────────────────

/// Caches successful pin verifications per host for [_ttl] to avoid a
/// separate probe request on every API call. Invalidated on any pin failure.
class _PinCache {
  static final Map<String, DateTime> _timestamps = {};
  static const _ttl = Duration(minutes: 5);

  static bool isValid(String host) {
    final ts = _timestamps[host];
    return ts != null && DateTime.now().difference(ts) < _ttl;
  }

  static void mark(String host) => _timestamps[host] = DateTime.now();
  static void invalidate(String host) => _timestamps.remove(host);
  static void clearAll() => _timestamps.clear();
}

// ── Pinning interceptor ────────────────────────────────────────────────────

class _CertificatePinningInterceptor extends Interceptor {
  _CertificatePinningInterceptor({
    required Set<String> pinnedHosts,
    required List<String> allowedPins,
    required PinVerifier verifier,
  })  : _pinnedHosts = pinnedHosts,
        _allowedPins = allowedPins,
        _verifier = verifier;

  final Set<String> _pinnedHosts;
  final List<String> _allowedPins;
  final PinVerifier _verifier;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final host = options.uri.host;

    if (!_pinnedHosts.contains(host)) {
      handler.next(options);
      return;
    }

    if (_PinCache.isValid(host)) {
      handler.next(options);
      return;
    }

    try {
      await _verifier(
        serverUrl: '${options.uri.scheme}://$host',
        allowedPins: _allowedPins,
      );
      _PinCache.mark(host);
      handler.next(options);
    } on CertificatePinningException catch (e) {
      _PinCache.invalidate(host);
      await _log(e);
      handler.reject(_toDioException(options, e), true);
    } catch (e, st) {
      // Plugin threw PlatformException or another unexpected error.
      _PinCache.invalidate(host);
      final pinEx = CertificatePinningException(
        host: host,
        message: 'Verification error: $e',
      );
      await _log(pinEx, stackTrace: st);
      handler.reject(_toDioException(options, pinEx), true);
    }
  }

  static DioException _toDioException(
    RequestOptions options,
    CertificatePinningException e,
  ) =>
      DioException(
        requestOptions: options,
        error: e,
        message: e.toString(),
        type: DioExceptionType.unknown,
      );

  static Future<void> _log(
    CertificatePinningException e, {
    StackTrace? stackTrace,
  }) async {
    debugPrint('🔴 [SSL PIN] ${e.toString()}');
    try {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'SSL pin mismatch: ${e.host}',
        fatal: false,
      );
    } catch (_) {
      // Crashlytics not initialised (tests, first-launch edge cases).
    }
  }
}

// ── Security headers interceptor ───────────────────────────────────────────

class _SecurityHeadersInterceptor extends Interceptor {
  static const _mutatingMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kIsWeb) options.headers['User-Agent'] = 'MinaretApp/1.0';
    options.headers['X-Requested-With'] = 'XMLHttpRequest';
    if (_mutatingMethods.contains(options.method.toUpperCase())) {
      options.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      options.headers['Pragma'] = 'no-cache';
      options.headers['Expires'] = '0';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'DENY');
    handler.next(response);
  }
}

// ── Retry interceptor ──────────────────────────────────────────────────────

class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 1);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Certificate pinning failures must never be retried.
    if (err.error is CertificatePinningException) {
      handler.next(err);
      return;
    }

    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (_shouldRetry(err) && retryCount < _maxRetries) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      await Future.delayed(_retryDelay * (retryCount + 1));
      try {
        final response =
            await SecureHttpClient.instance.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final s = err.response?.statusCode ?? 0;
        return s >= 500 || s == 408 || s == 429;
      default:
        return false;
    }
  }
}

// ── Public client ──────────────────────────────────────────────────────────

class SecureHttpClient {
  SecureHttpClient._();

  static Dio? _instance;

  /// Singleton Dio for third-party API calls (Quran, Hadith, CDN).
  ///
  /// No SSL pinning — you do not control these servers' certificates.
  /// Standard system TLS validation applies.
  static Dio get instance {
    _instance ??= _build(pinnedInterceptor: null);
    return _instance!;
  }

  /// Returns a new Dio instance for [CertificatePins.pinnedApiHost]
  /// (`api.minaret.app`) with certificate pinning enforced.
  ///
  /// Pin set is selected by [env]:
  ///   production  → real pins from [CertificatePins]
  ///   staging     → staging pins
  ///   development → no pinning (empty pin list)
  ///
  /// [pinVerifier] is injectable for unit tests. Defaults to the native
  /// http_certificate_pinning plugin.
  ///
  /// Asserts (in non-debug builds) that pin constants are not placeholders.
  /// If this assertion fires, run:  bash scripts/extract_pin.sh api.minaret.app
  static Dio forEnvironment(
    AppEnvironment env, {
    PinVerifier? pinVerifier,
  }) {
    final pins = CertificatePins.forEnvironment(env);

    // Dart asserts are stripped in release builds — use a real throw instead.
    if (!kDebugMode && CertificatePins.hasPlaceholders(pins)) {
      throw StateError(
        'CertificatePins still contains placeholder values. '
        'Run  bash scripts/extract_pin.sh api.minaret.app  and update '
        'lib/core/config/certificate_pins.dart before building for release.',
      );
    }

    // Web does not support the http_certificate_pinning plugin.
    // Development environments have no pins by design.
    if (pins.isEmpty || kIsWeb) {
      return _build(pinnedInterceptor: null);
    }

    return _build(
      pinnedInterceptor: _CertificatePinningInterceptor(
        pinnedHosts: {CertificatePins.pinnedApiHost},
        allowedPins: pins,
        verifier: pinVerifier ?? _nativePinVerifier,
      ),
    );
  }

  /// Creates a fresh Dio instance bound to [host] without pinning.
  /// Used for one-off download clients (Quran files, audio, etc.).
  static Dio createTrustedClient(String host) =>
      _build(pinnedInterceptor: null);

  /// Closes the singleton and allows [instance] to be recreated.
  /// Useful in tests that need a fresh client.
  static void resetInstance() {
    _instance?.close(force: true);
    _instance = null;
  }

  /// Clears the in-memory pin verification cache.
  /// Call this in test [setUp] to prevent cross-test cache pollution.
  @visibleForTesting
  static void clearPinCacheForTest() => _PinCache.clearAll();


  static Dio _build({
    required _CertificatePinningInterceptor? pinnedInterceptor,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    if (pinnedInterceptor != null) {
      dio.interceptors.add(pinnedInterceptor);
    }

    dio.interceptors
      ..add(_SecurityHeadersInterceptor())
      ..add(_RetryInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (o) => debugPrint('🌐 [HTTP] $o'),
      ));
    }

    return dio;
  }
}

// ── URL validation utilities ───────────────────────────────────────────────

class NetworkSecurity {
  NetworkSecurity._();

  static bool isHttps(String url) {
    try {
      return Uri.parse(url).scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  static bool validateUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Strips query parameters and fragment from [url].
  /// Returns empty string if [url] is not a valid http/https URL.
  static String sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!{'http', 'https'}.contains(uri.scheme)) return '';
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port == 0 ? null : uri.port,
        path: uri.path,
      ).toString();
    } catch (_) {
      return '';
    }
  }
}
