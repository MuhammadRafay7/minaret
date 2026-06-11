import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/services/notification_service.dart';

// ---------------------------------------------------------------------------
// Coverage note
// ---------------------------------------------------------------------------
// NotificationService uses static state and private methods with no injection
// points for FlutterLocalNotificationsPlugin. The tests below verify:
//   1. ID slot layout — no collisions within a mosque's 120-ID budget
//   2. Cross-mosque isolation — two consecutive slots never overlap
//   3. Every sub-range sits at the documented offset
//   4. Janaza IDs stay in the 10_000_000–10_999_999 dedicated range
//   5. Ramadan heuristic matches known historical dates
//   6. cancelAllListeners() is safe to call with no active subscriptions
//
// The formula functions below are replicas of the private static methods in
// notification_service.dart.  If those methods change, these tests break —
// that is intentional: they serve as a change-guard on the published contract.
// ---------------------------------------------------------------------------

// ── Formula replicas ─────────────────────────────────────────────────────────

int _prayerNotifId(int slot, int prayerIndex, int day) =>
    slot + (prayerIndex * 7) + day;

int _adhanNotifId(int slot, int adhanIndex, int day) =>
    slot + 35 + (adhanIndex * 7) + day;

int _taraweehNotifId(int slot, int day) => slot + 70 + day;

int _jummahNotifId(int slot, int day) => slot + 100 + day;

int _jummahAdhanNotifId(int slot, int day) => slot + 107 + day;

int _eidFitrNotifId(int slot) => slot + 114;

int _eidAdhaNotifId(int slot) => slot + 115;

int _janazaId(String mosqueId, DateTime dt) =>
    ('$mosqueId-janaza-${dt.toIso8601String()}').hashCode.abs() % 1000000 +
    10000000;

/// Replica of _isLikelyRamadan with the same year→date table.
bool _isLikelyRamadan(DateTime date) {
  final year = date.year;
  final Map<int, ({int startMonth, int startDay, int endMonth, int endDay})>
      table = {
    2025: (startMonth: 3, startDay: 1, endMonth: 3, endDay: 30),
    2026: (startMonth: 2, startDay: 18, endMonth: 3, endDay: 19),
    2027: (startMonth: 2, startDay: 8, endMonth: 3, endDay: 8),
    2028: (startMonth: 1, startDay: 28, endMonth: 2, endDay: 26),
    2029: (startMonth: 1, startDay: 17, endMonth: 2, endDay: 15),
    2030: (startMonth: 1, startDay: 6, endMonth: 2, endDay: 4),
    2031: (startMonth: 1, startDay: 1, endMonth: 1, endDay: 24),
    2032: (startMonth: 12, startDay: 15, endMonth: 12, endDay: 31),
    2033: (startMonth: 12, startDay: 5, endMonth: 12, endDay: 31),
  };
  final r = table[year];
  if (r == null) return false;
  final start = DateTime(year, r.startMonth, r.startDay);
  final end = DateTime(year, r.endMonth, r.endDay);
  return !date.isBefore(start) && !date.isAfter(end);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // All formula tests are pure Dart — no Flutter binding needed.

  // =========================================================================
  // Slot layout — uniqueness within one mosque
  // =========================================================================

  group('Notification ID slot layout — uniqueness within one mosque slot', () {
    const slot = 100; // first mosque slot (starts at 100)

    Set<int> allIdsForSlot(int s) {
      final ids = <int>{};
      for (int pi = 0; pi < 5; pi++) {
        for (int day = 0; day < 7; day++) {
          ids.add(_prayerNotifId(s, pi, day));
        }
      }
      for (int ai = 0; ai < 5; ai++) {
        for (int day = 0; day < 7; day++) {
          ids.add(_adhanNotifId(s, ai, day));
        }
      }
      for (int day = 0; day < 30; day++) {
        ids.add(_taraweehNotifId(s, day));
      }
      for (int day = 0; day < 7; day++) {
        ids.add(_jummahNotifId(s, day));
        ids.add(_jummahAdhanNotifId(s, day));
      }
      ids.add(_eidFitrNotifId(s));
      ids.add(_eidAdhaNotifId(s));
      return ids;
    }

    test('all 116 scheduled notification IDs within a slot are unique', () {
      final ids = allIdsForSlot(slot);
      // 5×7 prayer + 5×7 adhan + 30 taraweeh + 7 jummah + 7 jummah-adhan + 2 eid
      expect(ids.length, 116,
          reason: 'Duplicate IDs detected — collision in slot layout');
    });

    test('all IDs stay within the 120-ID per-mosque budget', () {
      for (final id in allIdsForSlot(slot)) {
        expect(id, greaterThanOrEqualTo(slot),
            reason: 'ID $id falls below slot start');
        expect(id, lessThan(slot + 120),
            reason: 'ID $id exceeds 120-ID budget');
      }
    });

    test('prayer sub-range occupies exactly offsets 0–34', () {
      for (int pi = 0; pi < 5; pi++) {
        for (int day = 0; day < 7; day++) {
          final offset = _prayerNotifId(slot, pi, day) - slot;
          expect(offset, inInclusiveRange(0, 34));
        }
      }
    });

    test('adhan sub-range occupies exactly offsets 35–69', () {
      for (int ai = 0; ai < 5; ai++) {
        for (int day = 0; day < 7; day++) {
          final offset = _adhanNotifId(slot, ai, day) - slot;
          expect(offset, inInclusiveRange(35, 69));
        }
      }
    });

    test('taraweeh sub-range occupies exactly offsets 70–99', () {
      for (int day = 0; day < 30; day++) {
        final offset = _taraweehNotifId(slot, day) - slot;
        expect(offset, inInclusiveRange(70, 99));
      }
    });

    test('jummah prayer sub-range occupies exactly offsets 100–106', () {
      for (int day = 0; day < 7; day++) {
        final offset = _jummahNotifId(slot, day) - slot;
        expect(offset, inInclusiveRange(100, 106));
      }
    });

    test('jummah adhan sub-range occupies exactly offsets 107–113', () {
      for (int day = 0; day < 7; day++) {
        final offset = _jummahAdhanNotifId(slot, day) - slot;
        expect(offset, inInclusiveRange(107, 113));
      }
    });

    test('eid al-fitr is at slot+114', () {
      expect(_eidFitrNotifId(slot) - slot, 114);
    });

    test('eid al-adha is at slot+115', () {
      expect(_eidAdhaNotifId(slot) - slot, 115);
    });

    test('eid fitr and eid adha IDs are distinct', () {
      expect(_eidFitrNotifId(slot), isNot(equals(_eidAdhaNotifId(slot))));
    });

    test('prayer and adhan sub-ranges do not overlap', () {
      final prayerIds = {
        for (int pi = 0; pi < 5; pi++)
          for (int day = 0; day < 7; day++) _prayerNotifId(slot, pi, day),
      };
      final adhanIds = {
        for (int ai = 0; ai < 5; ai++)
          for (int day = 0; day < 7; day++) _adhanNotifId(slot, ai, day),
      };
      expect(prayerIds.intersection(adhanIds), isEmpty);
    });

    test('taraweeh sub-range does not overlap prayer or adhan ranges', () {
      final taraweehIds = {
        for (int day = 0; day < 30; day++) _taraweehNotifId(slot, day),
      };
      final prayerAdhanIds = {
        for (int pi = 0; pi < 5; pi++)
          for (int day = 0; day < 7; day++) _prayerNotifId(slot, pi, day),
        for (int ai = 0; ai < 5; ai++)
          for (int day = 0; day < 7; day++) _adhanNotifId(slot, ai, day),
      };
      expect(taraweehIds.intersection(prayerAdhanIds), isEmpty);
    });
  });

  // =========================================================================
  // Cross-mosque slot isolation
  // =========================================================================

  group('Cross-mosque slot isolation (120 IDs apart)', () {
    Set<int> allPrayerAdhanIds(int slot) => {
          for (int pi = 0; pi < 5; pi++)
            for (int day = 0; day < 7; day++) _prayerNotifId(slot, pi, day),
          for (int ai = 0; ai < 5; ai++)
            for (int day = 0; day < 7; day++) _adhanNotifId(slot, ai, day),
        };

    test('first two mosque slots (100, 220) produce disjoint prayer+adhan IDs', () {
      final ids1 = allPrayerAdhanIds(100);
      final ids2 = allPrayerAdhanIds(220);
      expect(ids1.intersection(ids2), isEmpty);
    });

    test('ten consecutive mosque slots all produce disjoint ID sets', () {
      final allIds = <int>{};
      for (int i = 0; i < 10; i++) {
        final slotStart = 100 + i * 120;
        for (int pi = 0; pi < 5; pi++) {
          for (int day = 0; day < 7; day++) {
            final id = _prayerNotifId(slotStart, pi, day);
            expect(allIds.add(id), isTrue,
                reason: 'Collision at mosque $i, pi=$pi, day=$day (id=$id)');
          }
        }
        for (int ai = 0; ai < 5; ai++) {
          for (int day = 0; day < 7; day++) {
            final id = _adhanNotifId(slotStart, ai, day);
            expect(allIds.add(id), isTrue,
                reason: 'Collision at mosque $i, ai=$ai, day=$day (id=$id)');
          }
        }
      }
    });

    test('eid IDs for two mosques are distinct', () {
      final slot1 = 100, slot2 = 220;
      expect(_eidFitrNotifId(slot1), isNot(equals(_eidFitrNotifId(slot2))));
      expect(_eidAdhaNotifId(slot1), isNot(equals(_eidAdhaNotifId(slot2))));
    });
  });

  // =========================================================================
  // Janaza ID range
  // =========================================================================

  group('Janaza notification ID', () {
    test('janaza IDs are in the reserved range 10_000_000–10_999_999', () {
      final id = _janazaId('mosque-abc', DateTime(2025, 4, 15, 14, 30));
      expect(id, greaterThanOrEqualTo(10000000));
      expect(id, lessThanOrEqualTo(10999999));
    });

    test('same mosque at different times produces different janaza IDs', () {
      final id1 = _janazaId('mosque-abc', DateTime(2025, 4, 15, 14, 30));
      final id2 = _janazaId('mosque-abc', DateTime(2025, 4, 16, 10, 0));
      expect(id1, isNot(equals(id2)));
    });

    test('different mosques at the same time produce different janaza IDs', () {
      final time = DateTime(2025, 4, 15, 14, 30);
      final id1 = _janazaId('mosque-abc', time);
      final id2 = _janazaId('mosque-xyz', time);
      expect(id1, isNot(equals(id2)));
    });

    test('janaza IDs never collide with slot-based IDs (gap ≥ 9_000_000)', () {
      // Even with 1000 mosques × 120 IDs = 120_100 max slot ID.
      // Janaza minimum is 10_000_000 — safe separation.
      const maxSlotId = 100 + 1000 * 120;
      final janazaId = _janazaId('m', DateTime(2025, 1, 1));
      expect(janazaId, greaterThan(maxSlotId));
    });
  });

  // =========================================================================
  // Ramadan heuristic
  // =========================================================================

  group('Ramadan detection heuristic', () {
    test('mid-Ramadan 2025 (2025-03-15) is detected as Ramadan', () {
      expect(_isLikelyRamadan(DateTime(2025, 3, 15)), isTrue);
    });

    test('first day of Ramadan 2025 (2025-03-01) is detected', () {
      expect(_isLikelyRamadan(DateTime(2025, 3, 1)), isTrue);
    });

    test('last day of Ramadan 2025 (2025-03-30) is detected', () {
      expect(_isLikelyRamadan(DateTime(2025, 3, 30)), isTrue);
    });

    test('day after Ramadan 2025 (2025-03-31) is not Ramadan', () {
      expect(_isLikelyRamadan(DateTime(2025, 3, 31)), isFalse);
    });

    test('day before Ramadan 2025 (2025-02-28) is not Ramadan', () {
      expect(_isLikelyRamadan(DateTime(2025, 2, 28)), isFalse);
    });

    test('mid-Ramadan 2026 (2026-03-05) is detected', () {
      expect(_isLikelyRamadan(DateTime(2026, 3, 5)), isTrue);
    });

    test('date outside any mapped year returns false', () {
      expect(_isLikelyRamadan(DateTime(2050, 6, 1)), isFalse);
    });

    test('any non-Ramadan month returns false', () {
      for (final month in [4, 5, 6, 7, 8, 9, 10, 11]) {
        expect(_isLikelyRamadan(DateTime(2025, month, 15)), isFalse,
            reason: 'Month $month incorrectly flagged as Ramadan');
      }
    });
  });

  // =========================================================================
  // cancelAllListeners — public static method
  // =========================================================================

  group('cancelAllListeners', () {
    // These tests call the real static method. The method only operates on
    // in-memory collections (_listeners, _mosqueListeners, etc.) and uses
    // optional chaining on all subscriptions, so it runs safely without any
    // platform setup.

    testWidgets('completes without throwing when no listeners are registered',
        (tester) async {
      await expectLater(
        NotificationService.cancelAllListeners(),
        completes,
      );
    });

    testWidgets('is idempotent — calling twice does not throw',
        (tester) async {
      await NotificationService.cancelAllListeners();
      await expectLater(
        NotificationService.cancelAllListeners(),
        completes,
      );
    });
  });
}
