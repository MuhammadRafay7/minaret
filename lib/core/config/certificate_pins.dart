/// PIN FORMAT
/// ──────────
/// Pins are SHA-256 fingerprints of the leaf X.509 certificate DER bytes,
/// formatted as 32 uppercase colon-separated hex pairs:
///   'AA:BB:CC:DD:EE:FF:...'  (exactly 95 characters, 31 colons)
///
/// This is the format expected by the http_certificate_pinning package.
/// To extract the correct value, run:
///   bash scripts/extract_pin.sh api.minaret.app
///
/// ─────────────────────────────────────────────────────────────────────────
/// ROTATION STRATEGY
/// ─────────────────────────────────────────────────────────────────────────
///
/// Normal rotation (Let's Encrypt renews every 90 days):
///
///   Step 1 — Generate the new cert (or wait for auto-renewal).
///   Step 2 — Run scripts/extract_pin.sh api.minaret.app to get the new pin.
///   Step 3 — Add the new pin as _prodLeaf while keeping the current pin as
///             _prodBackup.  Ship an app update with BOTH pins.
///   Step 4 — Deploy the new cert on the server.
///   Step 5 — Wait until most users have updated (monitor via Crashlytics;
///             watch CertificatePinningException rate drop to zero).
///   Step 6 — Remove the old pin in a follow-up release.
///
/// Emergency rotation (private key compromised):
///
///   Step 1 — Rotate the cert on the server immediately.
///   Step 2 — Ship an emergency app update with ONLY the new cert's pin.
///             Users on old versions will be blocked — this is intentional.
///   Step 3 — Monitor Crashlytics. Old-version users see a hard error.
///
/// Remote kill-switch (recommended for large user bases):
///   Keep a "pinning_enabled" boolean in Firebase Remote Config.
///   If a cert incident locks out users before the app update propagates,
///   flip the flag to false as a temporary emergency measure while you
///   ship the corrected pin. Re-enable once the dust settles.
/// ─────────────────────────────────────────────────────────────────────────

enum AppEnvironment { production, staging, development }

abstract final class CertificatePins {
  // ── api.minaret.app — production ──────────────────────────────────────────
  //
  // TODO: Replace before production launch.
  //       Run:  bash scripts/extract_pin.sh api.minaret.app
  //       Copy the "Certificate Fingerprint" line into _prodLeaf.
  //       Copy the intermediate CA (or the next planned leaf cert) fingerprint
  //       into _prodBackup so the app still works during rotation.
  //
  // Format: 'XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:
  //          XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX'
  static const String _prodLeaf =
      'PLACEHOLDER:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:'
      '00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00';

  // Backup: use the intermediate CA fingerprint or the next scheduled leaf.
  static const String _prodBackup =
      'PLACEHOLDER:11:11:11:11:11:11:11:11:11:11:11:11:11:11:11:'
      '11:11:11:11:11:11:11:11:11:11:11:11:11:11:11:11';

  // ── staging-api.minaret.app — staging ─────────────────────────────────────
  //
  // TODO: Run:  bash scripts/extract_pin.sh staging-api.minaret.app
  static const String _stagingLeaf =
      'PLACEHOLDER:22:22:22:22:22:22:22:22:22:22:22:22:22:22:22:'
      '22:22:22:22:22:22:22:22:22:22:22:22:22:22:22:22';

  static const String _stagingBackup =
      'PLACEHOLDER:33:33:33:33:33:33:33:33:33:33:33:33:33:33:33:'
      '33:33:33:33:33:33:33:33:33:33:33:33:33:33:33:33';

  /// Returns the pin set for [env].
  ///
  /// Returns an empty list for [AppEnvironment.development] so no pinning
  /// interceptor is attached (localhost, emulator, self-signed certs).
  static List<String> forEnvironment(AppEnvironment env) => switch (env) {
        AppEnvironment.production => [_prodLeaf, _prodBackup],
        AppEnvironment.staging    => [_stagingLeaf, _stagingBackup],
        AppEnvironment.development => const [],
      };

  /// The hostname this pinning config applies to.
  static const String pinnedApiHost = 'api.minaret.app';

  /// True if any pin in [pins] is still a placeholder.
  /// Used in [SecureHttpClient.forEnvironment] to assert before release builds.
  static bool hasPlaceholders(List<String> pins) =>
      pins.any((p) => p.startsWith('PLACEHOLDER'));
}
