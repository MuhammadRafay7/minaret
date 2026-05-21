import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'config/app_environment.dart';
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

// ── Pinning interceptor ────────────────────────────────────────────────────

/// Wires SHA-256 SPKI certificate pinning into a [Dio] instance at the
/// TLS layer via [HttpClient.badCertificateCallback].
///
/// Pin verification delegates to [CertificatePins.containsPin], which
/// looks up the computed SPKI hash in [pinnedDomains].  A mismatch causes
/// [badCertificateCallback] to return false, which Dart's TLS stack converts
/// into a [HandshakeException] — the connection is never established.
///
/// Not a [Dio] [Interceptor] subclass: all enforcement happens at the
/// TLS level, so there is nothing to hook in Dio's request/response chain.
class _CertificatePinningInterceptor {
  _CertificatePinningInterceptor({required Set<String> pinnedHosts})
      : _pinnedHosts = pinnedHosts;

  final Set<String> _pinnedHosts;

  /// Hooks TLS-level pin checking into [dio]. Must be called once, immediately
  /// after the [Dio] instance is created and before any requests are made.
  ///
  /// Calls [CertificatePins.debugAssertNoPinPlaceholders] in debug builds.
  void configureDio(Dio dio) {
    CertificatePins.debugAssertNoPinPlaceholders();
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
        _buildPinnedClient;
  }

  HttpClient _buildPinnedClient() {
    // Disable the OS trust store so badCertificateCallback fires for every
    // certificate — including valid CA-signed ones.  The SPKI pin is our
    // sole trust anchor; no system roots are consulted.
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
    client.badCertificateCallback = _verifyPin;
    return client;
  }

  // Returns true to accept the TLS connection, false to reject it.
  // Called synchronously during the TLS handshake — must not await.
  bool _verifyPin(X509Certificate cert, String host, int port) {
    // Hard-fail in every build mode until real pins are in place.
    // Returning true here with placeholder pins would silently accept any cert,
    // defeating the entire purpose of pinning.
    if (!CertificatePins.isConfigured()) {
      throw StateError(
        'Certificate pins are not configured. '
        'Run the following command against your server and paste the output '
        'into certificate_pins.dart:\n'
        'openssl s_client -connect YOUR_DOMAIN:443 </dev/null 2>/dev/null '
        '| openssl x509 -pubkey -noout '
        '| openssl pkey -pubin -outform der '
        '| openssl dgst -sha256 -binary '
        '| base64',
      );
    }
    // Assert-level crash for profile/release builds compiled with asserts
    // enabled (e.g. flutter run --release --enable-asserts).
    // The if/throw above is the primary guard; this is belt-and-suspenders.
    assert(
      CertificatePins.isConfigured(),
      'Certificate pins are not configured — replace sentinel pin values in '
      'lib/core/config/certificate_pins.dart before building for release.',
    );

    if (!_pinnedHosts.contains(host)) return true; // not a pinned host

    final computedPin = CertificatePins.computeSpkiPin(cert);
    if (computedPin == null) {
      if (kDebugMode) {
        debugPrint('🔴 [SSL PIN] $host: could not extract SPKI — rejecting.');
      }
      return false;
    }

    final accepted = CertificatePins.containsPin(host, computedPin);

    if (!accepted) {
      if (kDebugMode) {
        debugPrint(
          '🔴 [SSL PIN] $host: pin mismatch.\n'
          '  computed : $computedPin\n'
          '  expected : ${CertificatePins.pinsFor(host).join(' | ')}',
        );
      }
      // Fire-and-forget: badCertificateCallback is synchronous, so we cannot
      // await Crashlytics.  The rejection is still enforced by returning false.
      _logRejection(
        CertificatePinningException(
          host: host,
          message: 'Pin mismatch — computed: $computedPin',
        ),
      );
    }

    return accepted;
  }

  static void _logRejection(CertificatePinningException e) {
    FirebaseCrashlytics.instance
        .recordError(e, null, reason: 'SSL pin mismatch: ${e.host}', fatal: false)
        .catchError((_) {}); // Crashlytics may not be initialised yet.
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

    // TLS-level pin failures surface as HandshakeException (a TlsException
    // subclass).  Never retry these — a bad pin is a security signal, not
    // a transient network hiccup.
    if (err.error is TlsException) {
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
  /// (`api.minaret.app`) with TLS-level certificate pinning enforced.
  ///
  /// Pin set is selected by [env]:
  ///   production  → real pins from [pinnedDomains]
  ///   staging     → staging pins
  ///   development → no pinning (empty pin list)
  ///
  /// Pinning is disabled on web (the dart:io TLS stack is not available).
  static Dio forEnvironment(AppEnvironment env) {
    final pins = CertificatePins.forEnvironment(env);

    // Dart asserts are stripped in release builds — use a real throw instead.
    if (!kDebugMode && CertificatePins.hasPlaceholders(pins)) {
      throw StateError(
        'CertificatePins still contains placeholder values. '
        'Extract real pins with:\n'
        '  openssl s_client -connect api.minaret.app:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64\n'
        'Then update lib/core/config/certificate_pins.dart before building for release.',
      );
    }

    // Web does not support the dart:io TLS stack.
    // Development environments have no pins by design.
    if (pins.isEmpty || kIsWeb) {
      return _build(pinnedInterceptor: null);
    }

    return _build(
      pinnedInterceptor: _CertificatePinningInterceptor(
        pinnedHosts: {CertificatePins.pinnedApiHost},
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

    // Wire TLS-level pin checking before any interceptors run.
    // configureDio hooks IOHttpClientAdapter.createHttpClient so that every
    // connection to a pinned host goes through CertificatePins.containsPin().
    pinnedInterceptor?.configureDio(dio);

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
