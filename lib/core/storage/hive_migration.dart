import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration: copies data from unencrypted Hive boxes to their
/// encrypted replacements.
///
/// Strategy:
///   1. Check a SharedPreferences flag; skip if already done.
///   2. For each box, attempt to open it WITHOUT a cipher.
///      • Success + data present  → read all entries, delete the file,
///        re-open with the cipher, write the data back.
///      • Success + empty         → delete the file (let encrypted init
///        create a fresh encrypted box).
///      • Throws                  → box is already encrypted or corrupted;
///        skip and let normal init handle it.
///   3. Set the flag so this never runs again.
///
/// Run this BEFORE [OfflineCacheService.init] opens the boxes with a cipher.
class HiveMigration {
  HiveMigration._();

  static const _flagKey = 'hive_encryption_migration_v1';

  static const _boxes = [
    'minaret_vault',
    'minaret_sync_queue',
  ];

  /// Runs the migration if it has not been completed yet.
  ///
  /// [cipher] is the same [HiveAesCipher] that will be used for normal
  /// operation after migration — obtained from [SecureStorageService].
  static Future<void> runIfNeeded(HiveAesCipher cipher) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flagKey) == true) return;

    for (final name in _boxes) {
      await _migrateBox(name, cipher);
    }

    await prefs.setBool(_flagKey, true);
    debugPrint('HiveMigration: complete');
  }

  static Future<void> _migrateBox(String name, HiveAesCipher cipher) async {
    // A box that is already open was opened with the correct cipher by an
    // earlier call — nothing to do.
    if (Hive.isBoxOpen(name)) return;

    Box<dynamic>? plain;
    try {
      // Attempt plain (unencrypted) open.
      // • Unencrypted box on disk → succeeds.
      // • Encrypted box on disk   → HiveError (wrong frame format) → caught.
      plain = await Hive.openBox<dynamic>(name);
    } catch (_) {
      // Cannot open without cipher — already encrypted or corrupted.
      // Normal init (_openBoxSafe) will handle it.
      return;
    }

    final snapshot = Map<dynamic, dynamic>.from(plain.toMap());
    await plain.close();

    // Always delete: empty unencrypted files have a plain header; we want the
    // encrypted init to create a fresh file with the encrypted header.
    await Hive.deleteBoxFromDisk(name);

    if (snapshot.isEmpty) {
      debugPrint('HiveMigration: $name was empty — recreated as encrypted');
      return;
    }

    // Re-open with encryption and restore all entries.
    final encrypted = await Hive.openBox<dynamic>(
      name,
      encryptionCipher: cipher,
    );
    await encrypted.putAll(snapshot);
    await encrypted.close();
    debugPrint('HiveMigration: migrated $name (${snapshot.length} entries)');
  }
}
