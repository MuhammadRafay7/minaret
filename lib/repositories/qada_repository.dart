import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'prayer_repository.dart';
import '../services/coin_service.dart';

const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class QadaData {
  final Map<String, int> completedQada;
  final Map<String, int> manualDebt;
  final Map<String, int> autoMissed;

  const QadaData({
    required this.completedQada,
    required this.manualDebt,
    required this.autoMissed,
  });

  int pendingFor(String prayer) {
    final total = (autoMissed[prayer] ?? 0) + (manualDebt[prayer] ?? 0);
    final done = completedQada[prayer] ?? 0;
    return (total - done).clamp(0, 999999);
  }

  int get totalPending => _prayers.fold(0, (s, p) => s + pendingFor(p));
  int get totalCompleted => completedQada.values.fold(0, (a, b) => a + b);

  static Map<String, int> missedFromRecords(List<PrayerRecord> records) {
    final missed = {for (final p in _prayers) p: 0};
    for (final record in records) {
      for (final prayer in _prayers) {
        if (!record.completedPrayers.contains(prayer)) {
          missed[prayer] = missed[prayer]! + 1;
        }
      }
    }
    return missed;
  }
}

class QadaRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  DocumentReference get _doc => _db.collection('qada_records').doc(_uid);

  Future<QadaData> getQadaData(List<PrayerRecord> allRecords) async {
    final autoMissed = QadaData.missedFromRecords(allRecords);

    if (_uid.isEmpty) {
      return QadaData(
        completedQada: {},
        manualDebt: {},
        autoMissed: autoMissed,
      );
    }

    final snap = await _doc.get();
    if (!snap.exists) {
      return QadaData(
        completedQada: {},
        manualDebt: {},
        autoMissed: autoMissed,
      );
    }

    final data = snap.data() as Map<String, dynamic>;
    final completedQada = ((data['completedQada'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    final manualDebt = ((data['manualDebt'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));

    return QadaData(
      completedQada: completedQada,
      manualDebt: manualDebt,
      autoMissed: autoMissed,
    );
  }

  // Logs one make-up for the given prayer. Does NOT touch prayer_records,
  // so it never affects streak calculations.
  Future<void> logMakeUp(String prayerName) async {
    if (_uid.isEmpty) return;

    final snap = await _doc.get();
    final isFirstEver = !snap.exists ||
        ((snap.data() as Map<String, dynamic>?)?['completedQada'] == null);

    await _doc.set({
      'completedQada': {prayerName: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    CoinService.instance.onQadaMakeUp(isFirstEver);
  }

  Future<void> addManualDebt(String prayerName, int count) async {
    if (_uid.isEmpty || count <= 0) return;
    await _doc.set({
      'manualDebt': {prayerName: FieldValue.increment(count)},
    }, SetOptions(merge: true));
  }
}
