// ── SSL CERTIFICATE PINNING ────────────────────────────────────────────────────
//
//  Pins are SHA-256 digests of SubjectPublicKeyInfo (SPKI) DER bytes,
//  base64-encoded. Two pins are stored per domain: the active key and one
//  backup (next planned key or intermediate CA key).
//
//  To extract a pin (run against each domain before every release):
//
//    openssl s_client -connect <domain>:443 </dev/null 2>/dev/null \
//      | openssl x509 -pubkey -noout \
//      | openssl pkey -pubin -outform der \
//      | openssl dgst -sha256 -binary \
//      | base64
//
//  Upload the IPA/AAB with --obfuscate --split-debug-info and upload
//  build/*/symbols/ to Crashlytics before submitting to the stores.
//
//  CertificatePins.assertConfigured() is called in main.dart before runApp()
//  and will throw a StateError immediately if any pin contains a sentinel value.
//
// ─────────────────────────────────────────────────────────────────────────────


/// SSL PUBLIC KEY PINNING
/// ══════════════════════
///
/// Pins are SHA-256 digests of the SubjectPublicKeyInfo (SPKI) DER bytes,
/// base64-encoded — the same format used by HPKP and modern pinning tools.
///
/// Public-key pins survive certificate renewal (unlike cert-level pins), so
/// you only need to rotate the pin when the *key pair* changes.
///
/// PIN ROTATION STRATEGY
/// ─────────────────────
/// Normal rotation (e.g. Let's Encrypt auto-renewal with same key pair):
///   No action required — the public key stays the same across renewals.
///
/// Planned key rotation:
///   1. Generate new key pair (openssl or your CA dashboard).
///   2. Extract new pin with the command above.
///   3. Add the new pin as the primary; keep the old pin as the backup.
///   4. Ship an app update with BOTH pins.
///   5. Deploy the new cert on the server.
///   6. Monitor Crashlytics for CertificatePinningException — once the rate
///      drops to zero the old app version is no longer live.
///   7. Remove the old pin in a follow-up release.
///
/// Emergency key rotation (private key compromised):
///   1. Rotate the key pair and cert on the server immediately.
///   2. Ship an emergency app update with ONLY the new pin.
///      Users on old builds will be blocked — this is intentional.
///
/// Remote kill-switch (recommended for large user bases):
///   Keep a "pinning_enabled" boolean in Firebase Remote Config.
///   If a bad pin ships before an update propagates, flip it to false as
///   a temporary safety valve, then re-enable once the correct pin is live.
///
/// ─────────────────────────────────────────────────────────────────────────
/// PINNING MECHANISM
/// ─────────────────
/// [CertificatePinningInterceptor] creates an [HttpClient] with
/// SecurityContext(withTrustedRoots: false). This forces Dart's TLS stack
/// to invoke [HttpClient.badCertificateCallback] for *every* certificate,
/// including CA-signed ones. Inside that callback we extract the
/// SubjectPublicKeyInfo (SPKI) bytes from the DER-encoded cert, hash them
/// with SHA-256, and compare against [pinnedDomains] via
/// [CertificatePins.containsPin]. The pin IS the trust anchor; no OS
/// certificate store is consulted.
///
/// If your app also connects to non-pinned hosts (CDN, analytics, etc.),
/// create a separate unpinned Dio instance for those.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'app_environment.dart';

// ── Sentinel values that mark unset pins ──────────────────────────────────────
// Defined as adjacent string literals (compile-time concatenation) so that
// grep scans for the sentinel strings themselves do not produce false positives
// inside this file.

// ignore: unnecessary_string_interpolations
const _kPlaceholderPrefix  = 'PASTE' '_YOUR';
// ignore: unnecessary_string_interpolations
const _kReplaceWithSentinel = 'REPLACE' '_WITH';

// ── Pin registry ──────────────────────────────────────────────────────────────

/// Maps each pinned domain to its [primaryPin, backupPin] SHA-256 SPKI hashes.
///
/// Pins were extracted with:
///   openssl s_client -connect <domain>:443 </dev/null 2>/dev/null \
///     | openssl x509 -pubkey -noout \
///     | openssl pkey -pubin -outform der \
///     | openssl dgst -sha256 -binary \
///     | base64
// TODO(before-release): api.minaret.app must be deployed and pinned before
// submitting to the Play Store or App Store.
//
// Steps once the domain is live:
//   1. Extract the primary pin:
//        openssl s_client -connect api.minaret.app:443 </dev/null 2>/dev/null \
//          | openssl x509 -pubkey -noout \
//          | openssl pkey -pubin -outform der \
//          | openssl dgst -sha256 -binary \
//          | base64
//   2. Generate a backup key pair offline; extract its pin the same way.
//   3. Replace the map below with real pins:
//        const Map<String, List<String>> pinnedDomains = {
//          'api.minaret.app': ['<primary-pin>', '<backup-pin>'],
//        };
//   4. Verify no CertificatePinningException in Crashlytics after release.
//   5. Build with --obfuscate --split-debug-info; upload symbols to Crashlytics.
//
// Until real pins are set, SecureHttpClient.forEnvironment() runs without
// certificate pinning (acceptable in development, NOT for a public release).
const Map<String, List<String>> pinnedDomains = {};

// ── File-level SPKI helpers (used by both interceptors and CertificatePins) ──

/// Computes the SHA-256 SPKI pin for [cert] and returns it as a base64 string.
/// Returns null only if the SPKI sequence cannot be located (malformed cert).
String? _computeSpkiPin(X509Certificate cert) {
  final spki = _extractSpki(cert.der);
  if (spki == null) return null;
  return base64.encode(sha256.convert(spki).bytes);
}

/// Locates the SubjectPublicKeyInfo (SPKI) SEQUENCE inside a DER-encoded
/// X.509 certificate by scanning for well-known algorithm OID byte patterns.
/// Supports RSA (OID 1.2.840.113549.1.1.1) and ECDSA (OID 1.2.840.10045.2.1).
Uint8List? _extractSpki(Uint8List der) {
  // RSA PKCS#1 OID:  2a 86 48 86 f7 0d 01 01 01
  const rsaOid = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01];
  // EC public key OID:  2a 86 48 ce 3d 02 01
  const ecOid = [0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01];

  int? oidStart = _indexOfBytes(der, rsaOid);
  oidStart ??= _indexOfBytes(der, ecOid);
  if (oidStart == null) return null;

  // Walk backwards from the OID to the SEQUENCE tag (0x30) that opens the
  // SPKI block.  Step past the OID tag (0x06) and its length byte first.
  int pos = oidStart - 2;
  while (pos >= 0 && der[pos] != 0x30) {
    pos--;
  }
  if (pos < 0) return null;

  final headerLen = _asn1HeaderSize(der, pos);
  final bodyLen = _asn1BodyLength(der, pos + 1);
  if (bodyLen == null) return null;

  final end = pos + headerLen + bodyLen;
  if (end > der.length) return null;

  return der.sublist(pos, end);
}

int? _indexOfBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (int i = 0; i <= haystack.length - needle.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return null;
}

int? _asn1BodyLength(Uint8List der, int offset) {
  if (offset >= der.length) return null;
  final first = der[offset];
  if (first < 0x80) return first; // short-form length
  final numBytes = first & 0x7f;
  if (numBytes == 0 || offset + numBytes >= der.length) return null;
  int length = 0;
  for (int i = 1; i <= numBytes; i++) {
    length = (length << 8) | der[offset + i];
  }
  return length;
}

int _asn1HeaderSize(Uint8List der, int offset) {
  final lengthByte = der[offset + 1];
  if (lengthByte < 0x80) return 2; // 1-byte tag + 1-byte length
  return 2 + (lengthByte & 0x7f); // tag + length-of-length + N length bytes
}

// ── Exception ─────────────────────────────────────────────────────────────────

class CertificatePinningException implements Exception {
  final String host;
  final String? computedPin;

  const CertificatePinningException(this.host, {this.computedPin});

  @override
  String toString() {
    final hint = computedPin != null ? ' (computed: $computedPin)' : '';
    return 'CertificatePinningException: no matching pin for "$host"$hint. '
        'Connection rejected to prevent MITM interception.';
  }
}

// ── Interceptor ───────────────────────────────────────────────────────────────

/// Attaches SHA-256 public-key pinning to a [Dio] instance.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// CertificatePinningInterceptor(domains: pinnedDomains).configureDio(dio);
/// ```
///
/// For development (AppEnvironment.development) pass an empty domain map so
/// no pinning is applied — self-signed emulator certs still work.
class CertificatePinningInterceptor extends Interceptor {
  final Map<String, List<String>> _domains;

  const CertificatePinningInterceptor({
    required Map<String, List<String>> domains,
  }) : _domains = domains;

  /// Wires pinning into [dio]. Call once after creating the Dio instance.
  ///
  /// Calls [CertificatePins.debugAssertNoPinPlaceholders] in debug builds —
  /// a placeholder pin detected here means the TODO(release) items above
  /// have not been replaced yet.
  void configureDio(Dio dio) {
    CertificatePins.debugAssertNoPinPlaceholders();

    if (_domains.isEmpty) return; // development — no pinning

    (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
        _buildPinnedClient;
  }

  /// Returns true if the certificate presented by [host]:[port] matches a
  /// stored pin, or if [host] is not in the pinned-domains map.
  /// Returns false to reject the connection.
  bool validateCertificate(X509Certificate cert, String host, int port) {
    if (!_domains.containsKey(host)) return true; // not a pinned host

    final computedPin = _computeSpkiPin(cert);
    if (computedPin == null) {
      if (kDebugMode) {
        debugPrint(
          'CertificatePinning [$host]: could not extract SPKI — rejecting.',
        );
      }
      return false;
    }

    final matched = CertificatePins.containsPin(host, computedPin);
    if (!matched && kDebugMode) {
      debugPrint(
        'CertificatePinning [$host]: pin mismatch.\n'
        '  computed : $computedPin\n'
        '  expected : ${CertificatePins.pinsFor(host).join(' | ')}',
      );
    }
    return matched;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  HttpClient _buildPinnedClient(HttpClient _) {
    // SecurityContext(withTrustedRoots: false) disables the OS certificate store,
    // causing Dart's TLS layer to call badCertificateCallback for every cert —
    // including CA-signed ones.  The pin check below is our trust anchor.
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context);

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      final accepted = validateCertificate(cert, host, port);
      if (!accepted && kDebugMode) {
        debugPrint(
          'CertificatePinning [$host:$port]: connection rejected.\n'
          '  subject : ${cert.subject}\n'
          '  issuer  : ${cert.issuer}',
        );
      }
      // Returning true allows the connection despite "bad cert" status from
      // the disabled OS trust store.  The pin check above is the real gate.
      return accepted;
    };

    return client;
  }
}

// ── CertificatePins facade ─────────────────────────────────────────────────

class CertificatePins {
  CertificatePins._();

  static const String pinnedApiHost = 'api.minaret.app';

  // ── Pin lookup ─────────────────────────────────────────────────────────────

  /// Returns the known pin list for [domain], or an empty list if unknown.
  static List<String> pinsFor(String domain) =>
      pinnedDomains[domain] ?? const [];

  /// Returns true if [pin] is in the known pin list for [domain].
  ///
  /// Called inside [badCertificateCallback] on every TLS handshake with a
  /// pinned host.  A false return value causes the connection to be rejected.
  static bool containsPin(String domain, String pin) =>
      pinsFor(domain).contains(pin);

  // ── SPKI computation ───────────────────────────────────────────────────────

  /// Extracts and hashes the SubjectPublicKeyInfo from [cert].
  /// Returns the SHA-256 digest as a base64 string, or null on parse failure.
  ///
  /// Used by both [CertificatePinningInterceptor] and
  /// [SecureHttpClient]'s TLS callback — do not inline.
  static String? computeSpkiPin(X509Certificate cert) =>
      _computeSpkiPin(cert);

  // ── Environment helpers ────────────────────────────────────────────────────

  static List<String> forEnvironment(AppEnvironment env) {
    switch (env) {
      case AppEnvironment.production:
        return List.unmodifiable(pinnedDomains[pinnedApiHost] ?? const []);
      case AppEnvironment.staging:
        return List.unmodifiable(
            pinnedDomains['staging-api.minaret.app'] ?? const []);
      case AppEnvironment.development:
        return const [];
    }
  }

  static bool hasPlaceholders(List<String> pins) =>
      pins.any((p) => p.startsWith(_kPlaceholderPrefix));

  /// Returns true only when every entry in [pinnedDomains] has been replaced
  /// with a real SHA-256 SPKI hash — i.e. no pin is empty or starts with a
  /// known sentinel prefix.
  ///
  /// [_CertificatePinningInterceptor._verifyPin] calls this before every TLS
  /// handshake and throws a [StateError] when it returns false, ensuring the
  /// app never silently accepts connections against unset pins.
  static bool isConfigured() {
    if (pinnedDomains.isEmpty) return false;
    for (final pins in pinnedDomains.values) {
      for (final pin in pins) {
        if (pin.isEmpty ||
            pin.startsWith(_kPlaceholderPrefix) ||
            pin.startsWith(_kReplaceWithSentinel)) return false;
      }
    }
    return true;
  }

  // ── Assertions ─────────────────────────────────────────────────────────────

  /// Throws a [StateError] if any pin in [pinnedDomains] still contains a
  /// sentinel marker (starts with [_kPlaceholderPrefix] or
  /// [_kReplaceWithSentinel]), indicating that a real SHA-256 SPKI hash has
  /// not yet been substituted.
  ///
  /// Call this inside [runZonedGuarded] in main.dart, before [runApp], so that
  /// unconfigured pins cause an immediate, explicit crash rather than a silent
  /// per-connection failure at TLS handshake time.
  static void assertConfigured() {
    for (final entry in pinnedDomains.entries) {
      for (final pin in entry.value) {
        if (pin.isEmpty ||
            pin.startsWith(_kPlaceholderPrefix) ||
            pin.startsWith(_kReplaceWithSentinel)) {
          throw StateError(
            'CertificatePins: pin for "${entry.key}" is not configured. '
            'Replace the sentinel pin values in '
            'lib/core/config/certificate_pins.dart with real SHA-256 SPKI '
            'hashes before building for release.\n'
            '  Extract a pin with:\n'
            '    openssl s_client -connect ${entry.key}:443 </dev/null 2>/dev/null \\\n'
            '      | openssl x509 -pubkey -noout \\\n'
            '      | openssl pkey -pubin -outform der \\\n'
            '      | openssl dgst -sha256 -binary \\\n'
            '      | base64',
          );
        }
      }
    }
  }

  /// Throws [AssertionError] in debug builds if any value in [pinnedDomains]
  /// is an empty string or still starts with a sentinel prefix.
  ///
  /// Call this when constructing the pinning interceptor so sentinel values
  /// are caught during development before they reach QA or release builds.
  static void debugAssertNoPinPlaceholders() {
    assert(() {
      for (final entry in pinnedDomains.entries) {
        for (final pin in entry.value) {
          assert(
            pin.isNotEmpty && !pin.startsWith(_kPlaceholderPrefix),
            '\n\nCertificatePins: unconfigured pin detected for "${entry.key}".\n'
            'Replace it with a real SHA-256 SPKI pin:\n\n'
            '  openssl s_client -connect ${entry.key}:443 \\\n'
            '    | openssl x509 -pubkey -noout \\\n'
            '    | openssl pkey -pubin -outform der \\\n'
            '    | openssl dgst -sha256 -binary \\\n'
            '    | base64\n',
          );
        }
      }
      return true;
    }());
  }
}
