import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/core/config/certificate_pins.dart';
import 'package:minaret/core/secure_http_client.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PinVerifier _rejectingVerifier({String reason = 'pin mismatch'}) =>
    ({required String serverUrl, required List<String> allowedPins}) async {
      throw CertificatePinningException(
        host: Uri.parse(serverUrl).host,
        message: reason,
      );
    };

PinVerifier _acceptingVerifier() =>
    ({required String serverUrl, required List<String> allowedPins}) async {
      // Verification passed — no-op.
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── CertificatePinningException ──────────────────────────────────────────
  group('CertificatePinningException', () {
    test('toString includes host and message', () {
      const e = CertificatePinningException(
        host: 'api.minaret.app',
        message: 'hash mismatch',
      );
      expect(e.toString(), contains('api.minaret.app'));
      expect(e.toString(), contains('hash mismatch'));
    });
  });

  // ── CertificatePins ──────────────────────────────────────────────────────
  group('CertificatePins', () {
    test('development returns an empty pin list', () {
      expect(
        CertificatePins.forEnvironment(AppEnvironment.development),
        isEmpty,
      );
    });

    test('production returns exactly two pins', () {
      expect(
        CertificatePins.forEnvironment(AppEnvironment.production),
        hasLength(2),
      );
    });

    test('staging returns exactly two pins', () {
      expect(
        CertificatePins.forEnvironment(AppEnvironment.staging),
        hasLength(2),
      );
    });

    test('hasPlaceholders detects placeholder values', () {
      expect(
        CertificatePins.hasPlaceholders([
          'PLACEHOLDER:00:00:00:00:00',
          'PLACEHOLDER:11:11:11:11:11',
        ]),
        isTrue,
      );
    });

    test('hasPlaceholders returns false for real-looking pins', () {
      const realPin =
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';
      expect(CertificatePins.hasPlaceholders([realPin]), isFalse);
    });
  });

  // ── SecureHttpClient.forEnvironment with injected verifier ───────────────
  group('SecureHttpClient.forEnvironment', () {
    setUp(() {
      // Clear the static pin cache so tests cannot pollute each other.
      SecureHttpClient.clearPinCacheForTest();
    });

    test(
      'throws CertificatePinningException wrapped in DioException '
      'when the verifier rejects',
      () async {
        final dio = SecureHttpClient.forEnvironment(
          AppEnvironment.production,
          pinVerifier: _rejectingVerifier(),
        );

        await expectLater(
          () => dio.get('https://api.minaret.app/health'),
          throwsA(
            isA<DioException>().having(
              (e) => e.error,
              'error',
              isA<CertificatePinningException>(),
            ),
          ),
        );
      },
    );

    test(
      'does not throw CertificatePinningException when the verifier accepts',
      () async {
        final dio = SecureHttpClient.forEnvironment(
          AppEnvironment.production,
          pinVerifier: _acceptingVerifier(),
        );

        // The request will fail at the network layer (no real server in tests),
        // but must NOT fail with a CertificatePinningException.
        try {
          await dio.get(
            'https://api.minaret.app/health',
            options: Options(sendTimeout: const Duration(milliseconds: 500)),
          );
        } on DioException catch (e) {
          expect(e.error, isNot(isA<CertificatePinningException>()),
              reason: 'Pinning should have passed; only a network error expected');
        }
      },
    );

    test(
      'never invokes verifier for non-pinned hosts',
      () async {
        // Even with a rejecting verifier, a request to a non-pinned host
        // must not trigger CertificatePinningException.
        final dio = SecureHttpClient.forEnvironment(
          AppEnvironment.production,
          pinVerifier: _rejectingVerifier(reason: 'should not be called'),
        );

        try {
          await dio.get(
            'https://api.alquran.cloud/v1/surah',
            options: Options(sendTimeout: const Duration(milliseconds: 500)),
          );
        } on DioException catch (e) {
          expect(e.error, isNot(isA<CertificatePinningException>()));
        }
      },
    );

    test(
      'development environment disables pinning entirely',
      () async {
        // In development the pin list is empty, so no pinning interceptor
        // is added. The rejecting verifier must never be called.
        final dio = SecureHttpClient.forEnvironment(
          AppEnvironment.development,
          pinVerifier: _rejectingVerifier(reason: 'should not be called in dev'),
        );

        try {
          await dio.get(
            'https://api.minaret.app/health',
            options: Options(sendTimeout: const Duration(milliseconds: 500)),
          );
        } on DioException catch (e) {
          expect(e.error, isNot(isA<CertificatePinningException>()));
        }
      },
    );

    test(
      'cached verification is not re-checked within TTL',
      () async {
        int callCount = 0;
        PinVerifier countingVerifier = ({
          required String serverUrl,
          required List<String> allowedPins,
        }) async {
          callCount++;
          // Accept on first call.
        };

        final dio = SecureHttpClient.forEnvironment(
          AppEnvironment.production,
          pinVerifier: countingVerifier,
        );

        // Two requests to the same pinned host — verifier called only once
        // because the first result is cached.
        for (var i = 0; i < 2; i++) {
          try {
            await dio.get(
              'https://api.minaret.app/health',
              options: Options(sendTimeout: const Duration(milliseconds: 500)),
            );
          } on DioException catch (_) {
            // Network error expected — ignore.
          }
        }

        expect(callCount, equals(1),
            reason: 'Verifier should be called once; second hit uses cache');
      },
    );
  });

  // ── NetworkSecurity ──────────────────────────────────────────────────────
  group('NetworkSecurity', () {
    test('isHttps returns true for https URLs', () {
      expect(NetworkSecurity.isHttps('https://api.minaret.app/v1'), isTrue);
    });

    test('isHttps returns false for http URLs', () {
      expect(NetworkSecurity.isHttps('http://example.com'), isFalse);
    });

    test('validateUrl accepts http and https', () {
      expect(NetworkSecurity.validateUrl('https://api.minaret.app'), isTrue);
      expect(NetworkSecurity.validateUrl('http://example.com'), isTrue);
    });

    test('validateUrl rejects javascript: and data: schemes', () {
      expect(NetworkSecurity.validateUrl('javascript:alert(1)'), isFalse);
      expect(NetworkSecurity.validateUrl('data:text/html,<h1>'), isFalse);
    });

    test('sanitizeUrl strips query and fragment', () {
      const url = 'https://api.minaret.app/v1/prayer?city=London#section';
      expect(NetworkSecurity.sanitizeUrl(url),
          equals('https://api.minaret.app/v1/prayer'));
    });

    test('sanitizeUrl returns empty string for non-http schemes', () {
      expect(NetworkSecurity.sanitizeUrl('ftp://files.example.com'), isEmpty);
    });
  });
}
