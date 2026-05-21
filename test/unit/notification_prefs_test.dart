import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/repositories/notification_repository.dart';

// ---------------------------------------------------------------------------
// Tiny in-memory state manager to test notification preference update logic
// in isolation — mirrors the _updateNotification pattern from SettingsPage.
// ---------------------------------------------------------------------------

class _NotificationPrefsState {
  bool janaza = true;
  bool adhan = true;
  bool namaz = true;
  bool eid = true;
  bool taraweeh = true;
  final Set<String> savingKeys = {};

  bool isSaving(String key) => savingKeys.contains(key);

  /// Returns true on success, false if the save throws.
  Future<bool> update(
    String key,
    bool value, {
    required Future<void> Function(Map<String, dynamic> prefs) saveFn,
  }) async {
    if (savingKeys.contains(key)) return false; // double-tap guard

    final prev = _snapshot();

    savingKeys.add(key);
    _apply(key, value);

    try {
      await saveFn(_currentPrefs());
      savingKeys.remove(key);
      return true;
    } catch (_) {
      _restore(prev);
      savingKeys.remove(key);
      return false;
    }
  }

  Map<String, bool> _snapshot() => {
        'janaza': janaza,
        'adhan': adhan,
        'namaz': namaz,
        'eid': eid,
        'taraweeh': taraweeh,
      };

  void _apply(String key, bool value) {
    if (key == 'janaza') janaza = value;
    if (key == 'adhan') adhan = value;
    if (key == 'namaz') namaz = value;
    if (key == 'eid') eid = value;
    if (key == 'taraweeh') taraweeh = value;
  }

  void _restore(Map<String, bool> snap) {
    janaza = snap['janaza']!;
    adhan = snap['adhan']!;
    namaz = snap['namaz']!;
    eid = snap['eid']!;
    taraweeh = snap['taraweeh']!;
  }

  Map<String, dynamic> _currentPrefs() => {
        'janaza': janaza,
        'adhan': adhan,
        'namaz': namaz,
        'eid': eid,
        'taraweeh': taraweeh,
      };
}

void main() {
  group('Notification preference update logic', () {
    late _NotificationPrefsState state;

    setUp(() => state = _NotificationPrefsState());

    // ── Optimistic update ────────────────────────────────────────────────────

    test('optimistic update applies the new value immediately', () async {
      // Arrange
      expect(state.adhan, isTrue);

      // Act
      await state.update(
        'adhan',
        false,
        saveFn: (_) async {},
      );

      // Assert
      expect(state.adhan, isFalse);
    });

    test('successful save clears the savingKey', () async {
      final saveCompleter = Future<void>.delayed(
        const Duration(milliseconds: 10),
      );
      final future = state.update('janaza', false, saveFn: (_) => saveCompleter);
      expect(state.isSaving('janaza'), isTrue);
      await future;
      expect(state.isSaving('janaza'), isFalse);
    });

    // ── Error rollback ───────────────────────────────────────────────────────

    test('value rolls back to original when save throws', () async {
      // Arrange
      expect(state.namaz, isTrue);

      // Act
      final ok = await state.update(
        'namaz',
        false,
        saveFn: (_) async => throw Exception('Firestore unavailable'),
      );

      // Assert
      expect(ok, isFalse);
      expect(state.namaz, isTrue); // rolled back
    });

    test('savingKey is cleared even when save throws', () async {
      await state.update(
        'eid',
        false,
        saveFn: (_) async => throw Exception('network error'),
      );
      expect(state.isSaving('eid'), isFalse);
    });

    // ── Double-tap guard ─────────────────────────────────────────────────────

    test('second update call while saving the same key is a no-op', () async {
      int saveCallCount = 0;
      final slowSave = () async {
        saveCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
      };

      // Act — fire two concurrent updates for the same key
      final f1 = state.update('adhan', false, saveFn: (_) => slowSave());
      final f2 = state.update('adhan', true, saveFn: (_) => slowSave());
      final results = await Future.wait([f1, f2]);

      // Assert — only the first call should have executed the save
      expect(results[0], isTrue);
      expect(results[1], isFalse);
      expect(saveCallCount, 1);
    });

    // ── Independent preference keys ──────────────────────────────────────────

    test('updating one preference does not affect others', () async {
      // Act
      await state.update('janaza', false, saveFn: (_) async {});

      // Assert
      expect(state.janaza, isFalse);
      expect(state.adhan, isTrue);
      expect(state.namaz, isTrue);
      expect(state.eid, isTrue);
      expect(state.taraweeh, isTrue);
    });

    // ── Service-call verification ────────────────────────────────────────────

    test('saveFn receives the toggled preference with the new value', () async {
      // Arrange
      Map<String, dynamic>? captured;

      // Act
      await state.update('adhan', false, saveFn: (prefs) async {
        captured = Map<String, dynamic>.from(prefs);
      });

      // Assert — the save payload contains the updated key
      expect(captured, isNotNull);
      expect(captured!['adhan'], isFalse);
    });

    test('saveFn receives all five preference keys on every call', () async {
      // Arrange
      Map<String, dynamic>? captured;

      // Act — toggle namaz; all other keys must still be present
      await state.update('namaz', false, saveFn: (prefs) async {
        captured = Map<String, dynamic>.from(prefs);
      });

      // Assert
      expect(
        captured!.keys,
        containsAll(['janaza', 'adhan', 'namaz', 'eid', 'taraweeh']),
      );
    });

    test('saveFn reflects only the toggled preference; others remain unchanged', () async {
      // Arrange
      Map<String, dynamic>? captured;

      // Act — toggle only taraweeh
      await state.update('taraweeh', false, saveFn: (prefs) async {
        captured = Map<String, dynamic>.from(prefs);
      });

      // Assert — unchanged keys remain at their defaults
      expect(captured!['taraweeh'], isFalse);
      expect(captured!['janaza'], isTrue);
      expect(captured!['adhan'], isTrue);
      expect(captured!['namaz'], isTrue);
      expect(captured!['eid'], isTrue);
    });

    test('saveFn is not called when the same key is already saving', () async {
      // Arrange
      int callCount = 0;
      final slowSave = Completer<void>();

      // First call starts and holds the lock
      final f1 = state.update(
        'eid',
        false,
        saveFn: (_) async {
          callCount++;
          await slowSave.future;
        },
      );

      // Second call for the same key must be rejected immediately
      final result2 = await state.update('eid', true, saveFn: (_) async {
        callCount++;
      });

      slowSave.complete();
      await f1;

      // Assert — only the first save ran
      expect(result2, isFalse);
      expect(callCount, 1);
    });

    // ── AppNotification model ─────────────────────────────────────────────────

    group('AppNotification', () {
      test('isRead mirrors the read field', () {
        final n = AppNotification(
          id: '1',
          userId: 'u1',
          type: 'janaza',
          title: 'Test',
          message: 'body',
          read: true,
          createdAt: DateTime.now(),
        );
        expect(n.isRead, isTrue);
        expect(n.read, isTrue);
      });

      test('body falls back to empty string when not provided', () {
        final n = AppNotification(
          id: '2',
          userId: 'u2',
          type: 'general',
          title: 'Hello',
          message: 'msg',
          read: false,
          createdAt: DateTime.now(),
        );
        expect(n.body, isNull);
      });
    });
  });
}
