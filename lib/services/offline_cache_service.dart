import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/storage/hive_migration.dart';
import '../core/storage/secure_storage_service.dart';

class OfflineCacheService {
  static const String _boxName = 'minaret_vault';
  static const String _syncBoxName = 'minaret_sync_queue';

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Initializes Hive with AES-256 encryption.  Call once in main().
  ///
  /// Sequence:
  ///   1. initFlutter — locates platform storage path.
  ///   2. getOrCreateHiveKey — retrieves (or generates) the 32-byte key from
  ///      the platform secure enclave (Keychain / Android Keystore).
  ///   3. runIfNeeded — one-time migration from unencrypted → encrypted boxes.
  ///   4. Future.wait — opens both boxes in parallel with the cipher.
  ///
  /// If a box fails to open (e.g. the device was factory-reset and the secure
  /// storage key was wiped), [_openBoxSafe] deletes and recreates it so the
  /// app never crashes on startup — cached data is lost but the app recovers.
  static Future<void> init() async {
    await Hive.initFlutter();

    final rawKey = await SecureStorageService.getOrCreateHiveKey();
    final cipher = HiveAesCipher(rawKey);

    // One-time migration for existing users with unencrypted boxes.
    await HiveMigration.runIfNeeded(cipher);

    // Open both boxes in parallel — typically saves ~30–80 ms on cold start.
    await Future.wait([
      _openBoxSafe(_boxName, cipher),
      _openBoxSafe(_syncBoxName, cipher),
    ]);
  }

  /// Opens a box with encryption.  If decryption fails (key mismatch after a
  /// device reset), the box is deleted and recreated empty.
  static Future<void> _openBoxSafe(String name, HiveAesCipher cipher) async {
    if (Hive.isBoxOpen(name)) return;
    try {
      await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
    } catch (e) {
      // Key mismatch — secure storage was wiped (factory reset, backup restore
      // to a different device, etc.).  Data is unrecoverable; start fresh.
      debugPrint('Hive: key mismatch for "$name", recreating ($e)');
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
    }
  }

  // ── Read / Write ───────────────────────────────────────────────────────────

  static Future<void> setJson(String key, String jsonString) async {
    await _ensureOpen(_boxName);
    await Hive.box<dynamic>(_boxName).put(key, jsonString);
  }

  static Future<String?> getJson(String key) async {
    await _ensureOpen(_boxName);
    return Hive.box<dynamic>(_boxName).get(key) as String?;
  }

  static Future<Map<String, dynamic>?> getMap(String key) async {
    final data = await getJson(key);
    if (data == null || data.isEmpty) return null;
    try {
      return json.decode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String key) async {
    await _ensureOpen(_boxName);
    await Hive.box<dynamic>(_boxName).delete(key);
  }

  static Future<void> clearAllCache() async {
    await _ensureOpen(_boxName);
    await Hive.box<dynamic>(_boxName).clear();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Guard for callers that might run before [init] completes (defensive only —
  /// in normal startup the box is always open before any read/write).
  static Future<void> _ensureOpen(String name) async {
    if (!Hive.isBoxOpen(name)) {
      final rawKey = await SecureStorageService.getOrCreateHiveKey();
      await Hive.openBox<dynamic>(name, encryptionCipher: HiveAesCipher(rawKey));
    }
  }
}
