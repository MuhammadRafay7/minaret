import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the Hive AES-256 encryption key in the platform secure enclave.
///
/// iOS  — Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
///         The device must be currently unlocked to read the key; it is never
///         migrated to a new device or restored from an iCloud backup.
///
/// Android — EncryptedSharedPreferences backed by the Android Keystore.
///            On API 28+ the master key is stored in StrongBox (HSM) if
///            available.
class SecureStorageService {
  SecureStorageService._();

  static const _keyAlias = 'hive_encryption_key';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Returns the 32-byte AES-256 key for Hive, generating and persisting it
  /// on first call.
  ///
  /// If the secure storage read fails (rare Keystore/Keychain error) a new key
  /// is generated. The caller must then handle boxes that can no longer be
  /// decrypted (see [HiveMigration] / [OfflineCacheService._openBoxSafe]).
  static Future<Uint8List> getOrCreateHiveKey() async {
    try {
      final stored = await _storage.read(key: _keyAlias);
      if (stored != null && stored.isNotEmpty) {
        return base64Decode(stored);
      }
    } catch (e) {
      debugPrint('SecureStorage: read failed ($e) — generating fresh key');
    }

    final key = _generateKey();
    await _storage.write(key: _keyAlias, value: base64Encode(key));
    return key;
  }

  static Uint8List _generateKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
