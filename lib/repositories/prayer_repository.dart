import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/coin_service.dart';

class PrayerRecord {
  final String id;
  final String userId;
  final DateTime date;
  final List<String> completedPrayers;
  final double completionRate;

  PrayerRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.completedPrayers,
    required this.completionRate,
  });

  factory PrayerRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PrayerRecord(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedPrayers:
          ((data['completedPrayers'] as List?) ?? []).cast<String>(),
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UserPrayerStats {
  final String userId;
  final int totalPrayers;
  final int totalDaysPrayed;
  final int currentStreak;
  final int longestStreak;
  final double overallCompletionRate;
  final Map<String, int> prayerCounts;
  final Map<String, double> prayerCompletionRates;
  final DateTime lastPrayerDate;

  UserPrayerStats({
    required this.userId,
    required this.totalPrayers,
    required this.totalDaysPrayed,
    required this.currentStreak,
    required this.longestStreak,
    required this.overallCompletionRate,
    required this.prayerCounts,
    Map<String, double>? prayerCompletionRates,
    DateTime? lastPrayerDate,
  })  : prayerCompletionRates = prayerCompletionRates ?? {},
        lastPrayerDate = lastPrayerDate ?? DateTime.now();

  factory UserPrayerStats.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserPrayerStats(
      userId: doc.id,
      totalPrayers: (data['totalPrayers'] as num?)?.toInt() ?? 0,
      totalDaysPrayed: (data['totalDaysPrayed'] as num?)?.toInt() ?? 0,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      overallCompletionRate:
          (data['overallCompletionRate'] as num?)?.toDouble() ?? 0.0,
      prayerCounts: ((data['prayerCounts'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      prayerCompletionRates: ((data['prayerCompletionRates'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      lastPrayerDate: (data['lastPrayerDate'] as Timestamp?)?.toDate(),
    );
  }

  factory UserPrayerStats.empty(String userId) => UserPrayerStats(
        userId: userId,
        totalPrayers: 0,
        totalDaysPrayed: 0,
        currentStreak: 0,
        longestStreak: 0,
        overallCompletionRate: 0.0,
        prayerCounts: {},
      );
}

const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class PrayerRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  SharedPreferences? _prefs;

  CollectionReference get _records => _db.collection('prayer_records');
  CollectionReference get _stats => _db.collection('user_prayer_stats');

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Local (SharedPreferences) ─────────────────────────────────────────────

  Future<void> initLocal() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<String> getLocalDayStatus(DateTime date) {
    final raw = _prefs?.getStringList('prayers_${_dayKey(date)}') ?? [];
    return raw;
  }

  Future<void> toggleLocal(DateTime date, String prayerKey) async {
    final key = 'prayers_${_dayKey(date)}';
    final current = _prefs?.getStringList(key) ?? [];
    if (current.contains(prayerKey)) {
      current.remove(prayerKey);
    } else {
      current.add(prayerKey);
    }
    await _prefs?.setStringList(key, current);
  }

  int getLocalStreak() {
    int streak = 0;
    var day = DateTime.now();
    // Skip today if not all 5 prayers are complete — mirrors Firestore streak logic.
    if (getLocalDayStatus(day).length < 5) {
      day = day.subtract(const Duration(days: 1));
    }
    while (true) {
      final done = getLocalDayStatus(day);
      if (done.length < 5) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<UserPrayerStats?> togglePrayer(String prayerName, {bool queued = false}) async {
    if (_uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final today = DateTime.now();
    final dateKey = _dayKey(today);
    final docId = '${_uid}_$dateKey';
    final ref = _records.doc(docId);

    bool wasAdded = false;
    List<String> finalCompleted = [];

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        List<String> completed;
        if (snap.exists) {
          completed =
              ((snap.data() as Map)['completedPrayers'] as List? ?? [])
                  .cast<String>();
        } else {
          completed = [];
        }

        if (completed.contains(prayerName)) {
          completed.remove(prayerName);
          wasAdded = false;
        } else {
          completed.add(prayerName);
          wasAdded = true;
        }
        finalCompleted = List<String>.from(completed);

        final rate = completed.length / _prayers.length;
        tx.set(ref, {
          'userId': _uid,
          'date': Timestamp.fromDate(
              DateTime(today.year, today.month, today.day)),
          'completedPrayers': completed,
          'completionRate': rate,
        });
      });
    } catch (e) {
      throw Exception('Failed to update prayer record: $e');
    }

    UserPrayerStats? stats;
    try {
      stats = await _updateStats();
    } catch (e) {
      throw Exception('Failed to update prayer statistics: $e');
    }

    if (wasAdded && stats != null) {
      try {
        await CoinService.instance.onPrayerToggled(
          prayerName,
          finalCompleted,
          stats.currentStreak,
        );
      } catch (e) {
        // Log coin service error but don't fail the prayer toggle
        debugPrint('Warning: Coin service error: $e');
      }
    }

    return stats;
  }

  Future<UserPrayerStats?> _updateStats() async {
    if (_uid.isEmpty) return null;

    try {
      // Fetch records needed for streak calculation.
      // Note: Uses ASCENDING index (userId ASC, date ASC) - sorting done client-side.
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 21));
      final snap = await _records
          .where('userId', isEqualTo: _uid)
          .where('date', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      final records = snap.docs
          .map(PrayerRecord.fromDoc)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)); // Sort ascending for streak calculation

      int totalPrayers = 0;
      int totalDaysPrayed = 0;
      final prayerCounts = <String, int>{};
      DateTime? lastPrayerDate;

      for (final record in records) {
        if (record.completedPrayers.isEmpty) continue;
        totalDaysPrayed++;
        totalPrayers += record.completedPrayers.length;
        lastPrayerDate = record.date;
        for (final prayer in record.completedPrayers) {
          prayerCounts[prayer] = (prayerCounts[prayer] ?? 0) + 1;
        }
      }

      final recordMap = <String, PrayerRecord>{};
      for (final r in records) {
        recordMap[_dayKey(r.date)] = r;
      }

      // Current streak: consecutive fully-completed days (going backward from today).
      int currentStreak = 0;
      var checkDay = DateTime.now();
      final todayRecord = recordMap[_dayKey(checkDay)];

      // If today is incomplete, start checking from yesterday
      if (todayRecord == null || todayRecord.completedPrayers.length < _prayers.length) {
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      // Walk backward counting consecutive full days
      while (true) {
        final r = recordMap[_dayKey(checkDay)];
        if (r == null || r.completedPrayers.length < _prayers.length) break;
        currentStreak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      // Longest streak: iterate in chronological order (oldest first)
      int longestStreak = currentStreak; // Start with current streak as minimum
      int tempStreak = 0;
      DateTime? prevFullDay;
      for (final record in records) { // Already sorted ascending
        if (record.completedPrayers.length < _prayers.length) continue;
        final d = DateTime(record.date.year, record.date.month, record.date.day);
        if (prevFullDay == null || d.difference(prevFullDay).inDays == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
        if (tempStreak > longestStreak) longestStreak = tempStreak;
        prevFullDay = d;
      }

      final overallCompletionRate = totalDaysPrayed == 0
          ? 0.0
          : totalPrayers / (totalDaysPrayed * 5.0);

      final prayerCompletionRates = <String, double>{
        for (final e in prayerCounts.entries)
          e.key: totalDaysPrayed == 0 ? 0.0 : e.value / totalDaysPrayed,
      };

      final stats = UserPrayerStats(
        userId: _uid,
        totalPrayers: totalPrayers,
        totalDaysPrayed: totalDaysPrayed,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        overallCompletionRate: overallCompletionRate,
        prayerCounts: prayerCounts,
        prayerCompletionRates: prayerCompletionRates,
        lastPrayerDate: lastPrayerDate ?? DateTime.now(),
      );

      await _stats.doc(_uid).set({
        'userId': _uid,
        'totalPrayers': totalPrayers,
        'totalDaysPrayed': totalDaysPrayed,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'overallCompletionRate': overallCompletionRate,
        'prayerCounts': prayerCounts,
        'prayerCompletionRates': prayerCompletionRates,
        'lastPrayerDate': lastPrayerDate != null
            ? Timestamp.fromDate(lastPrayerDate)
            : Timestamp.fromDate(DateTime.now()),
      });

      return stats;
    } catch (e) {
      debugPrint('Error in _updateStats: $e');
      rethrow;
    }
  }

  Future<List<String>> getTodayPrayers() async {
    if (_uid.isEmpty) return [];
    final dateKey = _dayKey(DateTime.now());
    final snap = await _records.doc('${_uid}_$dateKey').get();
    if (!snap.exists) return [];
    final data = snap.data() as Map;
    return ((data['completedPrayers'] as List?) ?? []).cast<String>();
  }

  Future<List<PrayerRecord>> getPrayerRecords({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_uid.isEmpty) return [];
    final snap = await _records.where('userId', isEqualTo: _uid).get();
    var records = snap.docs.map(PrayerRecord.fromDoc).toList();
    if (startDate != null) {
      records = records.where((r) => !r.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      records = records.where((r) => !r.date.isAfter(endDate)).toList();
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  Future<UserPrayerStats?> getUserStats(String userId) async {
    final snap = await _stats.doc(userId).get();
    if (!snap.exists) return null;
    return UserPrayerStats.fromDoc(snap);
  }

  Future<UserPrayerStats?> getCurrentUserStats() async {
    if (_uid.isEmpty) return null;
    return getUserStats(_uid);
  }

  /// Recomputes stats from prayer records and persists them. Use this on
  /// initial load to ensure the displayed total reflects actual Firestore data.
  Future<UserPrayerStats?> refreshCurrentUserStats() async {
    if (_uid.isEmpty) return null;
    return _updateStats();
  }

  Future<List<UserPrayerStats>> getLeaderboard({
    String sortBy = 'currentStreak',
    int limit = 10,
  }) async {
    final snap = await _stats
        .orderBy(sortBy, descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(UserPrayerStats.fromDoc).toList();
  }

  Future<Map<String, dynamic>> getAnalyticsData() async {
    final stats = await getCurrentUserStats();
    return {
      'currentStreak': stats?.currentStreak ?? 0,
      'totalPrayers': stats?.totalPrayers ?? 0,
      'completionRate': stats?.overallCompletionRate ?? 0.0,
      'prayerCounts': stats?.prayerCounts ?? {},
    };
  }
}
