import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/coin_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fasting & Taraweeh logging — mirrors the qada_records shape: one document per
// user holding a date-keyed map, so the whole month loads in a single read and
// syncs offline like the rest of the app.
//
//   fasting_records/{uid}  → { 'days': { '2026-02-18': { fasted, reason } } }
//   taraweeh_records/{uid} → { 'nights': { '2026-02-18': true } }
// ─────────────────────────────────────────────────────────────────────────────

/// Why a fast was not kept — drives the make-up wording elsewhere in the app.
enum FastStatus { fasted, travel, illness, menstruation, skipped, other }

extension FastStatusCode on FastStatus {
  String get code => name;
  bool get isKept => this == FastStatus.fasted;

  static FastStatus fromCode(String? code) {
    return FastStatus.values.firstWhere(
      (s) => s.name == code,
      orElse: () => FastStatus.other,
    );
  }
}

class RamadanLog {
  /// date key (yyyy-MM-dd) → status of that day's fast.
  final Map<String, FastStatus> fasts;

  /// date key (yyyy-MM-dd) → whether Taraweeh was prayed that night.
  final Map<String, bool> taraweeh;

  const RamadanLog({required this.fasts, required this.taraweeh});

  const RamadanLog.empty()
      : fasts = const {},
        taraweeh = const {};

  FastStatus? statusFor(String dateKey) => fasts[dateKey];
  bool taraweehFor(String dateKey) => taraweeh[dateKey] ?? false;

  int get daysFasted => fasts.values.where((s) => s.isKept).length;
  int get daysMissed => fasts.values.where((s) => !s.isKept).length;
  int get taraweehNights => taraweeh.values.where((v) => v).length;
}

class FastingRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  DocumentReference get _fastDoc => _db.collection('fasting_records').doc(_uid);
  DocumentReference get _taraweehDoc =>
      _db.collection('taraweeh_records').doc(_uid);

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Loads the whole month's fasting + taraweeh log in two reads.
  /// Tolerates permission/offline errors by returning an empty log so the UI
  /// never crashes (e.g. before the Firestore rules are deployed).
  Future<RamadanLog> getLog() async {
    if (_uid.isEmpty) return const RamadanLog.empty();

    final List<DocumentSnapshot> results;
    try {
      results = await Future.wait([_fastDoc.get(), _taraweehDoc.get()]);
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ FastingRepository.getLog read failed: $e');
      return const RamadanLog.empty();
    }
    final fastData = (results[0].data() as Map<String, dynamic>?) ?? {};
    final taraweehData = (results[1].data() as Map<String, dynamic>?) ?? {};

    final fastsRaw = (fastData['days'] as Map?) ?? {};
    final fasts = <String, FastStatus>{};
    fastsRaw.forEach((k, v) {
      final code = (v is Map) ? v['status'] as String? : v as String?;
      fasts[k as String] = FastStatusCode.fromCode(code);
    });

    final nightsRaw = (taraweehData['nights'] as Map?) ?? {};
    final taraweeh = <String, bool>{};
    nightsRaw.forEach((k, v) => taraweeh[k as String] = v == true);

    return RamadanLog(fasts: fasts, taraweeh: taraweeh);
  }

  /// Records (or updates) the fast status for a given day. Awards coins only the
  /// first time a kept fast is logged for that date.
  /// Returns true on success, false if the write failed (e.g. offline / rules).
  Future<bool> setFast(DateTime day, FastStatus status) async {
    if (_uid.isEmpty) return false;
    final key = dateKey(day);

    try {
      final snap = await _fastDoc.get();
      final daysMap = (snap.data() as Map<String, dynamic>?)?['days'] as Map?;
      final existing = daysMap?[key] as Map?;
      final wasKept =
          FastStatusCode.fromCode(existing?['status'] as String?).isKept;

      await _fastDoc.set({
        'days': {
          key: {
            'status': status.code,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));

      if (status.isKept && !wasKept) {
        // Total kept fasts after this write = previously-kept days + this one.
        final priorKept = (daysMap ?? {}).entries.where((e) {
          if (e.key == key) return false; // exclude the day we just changed
          final m = e.value as Map?;
          return FastStatusCode.fromCode(m?['status'] as String?).isKept;
        }).length;
        await CoinService.instance.onFastLogged(daysFastedTotal: priorKept + 1);
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ FastingRepository.setFast failed: $e');
      return false;
    }
  }

  /// Toggles Taraweeh attendance for a night. Awards coins on the first mark.
  /// Returns true on success, false if the write failed.
  Future<bool> setTaraweeh(DateTime day, bool prayed) async {
    if (_uid.isEmpty) return false;
    final key = dateKey(day);

    try {
      final nightsMap =
          (await _taraweehDoc.get()).data() as Map<String, dynamic>?;
      final nights = nightsMap?['nights'] as Map?;
      final was = nights?[key] == true;

      await _taraweehDoc.set({
        'nights': {key: prayed}
      }, SetOptions(merge: true));

      if (prayed && !was) {
        // Total nights after this write = previously-true nights + this one.
        final priorNights = (nights ?? {}).entries
            .where((e) => e.key != key && e.value == true)
            .length;
        await CoinService.instance
            .onTaraweehLogged(taraweehNightsTotal: priorNights + 1);
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ FastingRepository.setTaraweeh failed: $e');
      return false;
    }
  }
}
