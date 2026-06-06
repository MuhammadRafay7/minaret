import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Level thresholds (index = level-1, value = totalCoinsEarned needed) ──────

const List<int> kLevelThresholds = [0, 500, 1500, 3500, 7500, 15000, 30000];

int levelFromCoins(int totalCoins) {
  int level = 1;
  for (int i = 0; i < kLevelThresholds.length; i++) {
    if (totalCoins >= kLevelThresholds[i]) level = i + 1;
  }
  return level;
}

double multiplierForLevel(int level) {
  if (level >= 7) return 2.5;
  if (level >= 5) return 2.0;
  if (level >= 3) return 1.5;
  return 1.0;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class UserProgress {
  final String uid;
  final int level;
  final int totalCoinsEarned;
  final int currentCoins;
  final double multiplier;
  final Map<String, bool> milestones;
  final String? lastHadithDate;
  final String? lastLoginDate;

  const UserProgress({
    required this.uid,
    required this.level,
    required this.totalCoinsEarned,
    required this.currentCoins,
    required this.multiplier,
    required this.milestones,
    this.lastHadithDate,
    this.lastLoginDate,
  });

  int get coinsToNextLevel {
    if (level >= 7) return 0;
    return kLevelThresholds[level] - totalCoinsEarned;
  }

  double get levelProgress {
    if (level >= 7) return 1.0;
    final start = kLevelThresholds[level - 1];
    final end = kLevelThresholds[level];
    return (totalCoinsEarned - start) / (end - start);
  }

  factory UserProgress.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final totalCoins = (d['totalCoinsEarned'] as num?)?.toInt() ?? 0;
    final level = (d['level'] as num?)?.toInt() ?? levelFromCoins(totalCoins);
    return UserProgress(
      uid: doc.id,
      level: level,
      totalCoinsEarned: totalCoins,
      currentCoins: (d['currentCoins'] as num?)?.toInt() ?? 0,
      multiplier: (d['multiplier'] as num?)?.toDouble() ?? multiplierForLevel(level),
      milestones: ((d['milestones'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v as bool)),
      lastHadithDate: d['lastHadithDate'] as String?,
      lastLoginDate: d['lastLoginDate'] as String?,
    );
  }

  factory UserProgress.empty(String uid) => UserProgress(
        uid: uid,
        level: 1,
        totalCoinsEarned: 0,
        currentCoins: 0,
        multiplier: 1.0,
        milestones: {},
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class ProgressRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  DocumentReference get _doc => _db.collection('user_progress').doc(_uid);

  Stream<UserProgress> progressStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return UserProgress.empty(_uid);
      return UserProgress.fromDoc(snap);
    });
  }

  Future<UserProgress> getProgress() async {
    if (_uid.isEmpty) return UserProgress.empty('');
    final snap = await _doc.get();
    if (!snap.exists) return UserProgress.empty(_uid);
    return UserProgress.fromDoc(snap);
  }

  // Awards coins to the current user. Returns updated progress.
  Future<UserProgress> awardCoins(
    int coins, {
    required String type,
    required String description,
  }) async {
    if (_uid.isEmpty || coins <= 0) return getProgress();

    final newProgress = await _db.runTransaction<UserProgress>((tx) async {
      final snap = await tx.get(_doc);
      final current = snap.exists ? UserProgress.fromDoc(snap) : UserProgress.empty(_uid);

      final newTotal = current.totalCoinsEarned + coins;
      final newCurrent = current.currentCoins + coins;
      final newLevel = levelFromCoins(newTotal);
      final newMultiplier = multiplierForLevel(newLevel);

      tx.set(
        _doc,
        {
          'uid': _uid,
          'totalCoinsEarned': newTotal,
          'currentCoins': newCurrent,
          'level': newLevel,
          'multiplier': newMultiplier,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return UserProgress(
        uid: _uid,
        level: newLevel,
        totalCoinsEarned: newTotal,
        currentCoins: newCurrent,
        multiplier: newMultiplier,
        milestones: current.milestones,
        lastHadithDate: current.lastHadithDate,
        lastLoginDate: current.lastLoginDate,
      );
    });

    // Log the transaction (fire-and-forget)
    _doc.collection('transactions').add({
      'type': type,
      'coins': coins,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return newProgress;
  }

  // Awards milestone bonus only once. Coin award is inside the same transaction
  // so concurrent callers cannot double-award the same milestone.
  Future<bool> checkAndAwardMilestone(
    String key,
    int bonusCoins,
    String description,
  ) async {
    if (_uid.isEmpty) return false;

    bool isNew = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final milestones = snap.exists
          ? ((snap.data() as Map<String, dynamic>)['milestones'] as Map? ?? {})
              .cast<String, bool>()
          : <String, bool>{};

      if (milestones[key] == true) {
        isNew = false;
        return;
      }

      final current =
          snap.exists ? UserProgress.fromDoc(snap) : UserProgress.empty(_uid);
      final newTotal = current.totalCoinsEarned + bonusCoins;
      final newCurrent = current.currentCoins + bonusCoins;
      final newLevel = levelFromCoins(newTotal);

      tx.set(
        _doc,
        {
          'milestones': {key: true},
          'totalCoinsEarned': newTotal,
          'currentCoins': newCurrent,
          'level': newLevel,
          'multiplier': multiplierForLevel(newLevel),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      isNew = true;
    });

    if (isNew) {
      _doc.collection('transactions').add({
        'type': 'milestone',
        'coins': bonusCoins,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    return isNew;
  }

  Future<void> setLastHadithDate(String date) async {
    if (_uid.isEmpty) return;
    await _doc.set({'lastHadithDate': date}, SetOptions(merge: true));
  }

  Future<void> setLastLoginDate(String date) async {
    if (_uid.isEmpty) return;
    await _doc.set({'lastLoginDate': date}, SetOptions(merge: true));
  }

  // Atomically checks + records the daily login and awards coins in one
  // transaction so two concurrent app launches cannot both award the bonus.
  Future<bool> recordDailyLogin(String today, int coins) async {
    if (_uid.isEmpty) return false;
    bool awarded = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final d = snap.data() as Map<String, dynamic>? ?? {};
      if (d['lastLoginDate'] == today) {
        awarded = false;
        return;
      }
      final current =
          snap.exists ? UserProgress.fromDoc(snap) : UserProgress.empty(_uid);
      final newTotal = current.totalCoinsEarned + coins;
      final newCurrent = current.currentCoins + coins;
      final newLevel = levelFromCoins(newTotal);
      tx.set(
        _doc,
        {
          'lastLoginDate': today,
          'totalCoinsEarned': newTotal,
          'currentCoins': newCurrent,
          'level': newLevel,
          'multiplier': multiplierForLevel(newLevel),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      awarded = true;
    });
    return awarded;
  }

  // ── Admin methods (operate on any uid) ───────────────────────────────────────

  static Future<void> adminSetLevel(String uid, int level) async {
    assert(level >= 1 && level <= 7);
    final db = FirebaseFirestore.instance;
    final ref = db.collection('user_progress').doc(uid);

    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists ? UserProgress.fromDoc(snap) : UserProgress.empty(uid);

      final minCoins = kLevelThresholds[level - 1];
      final newTotal =
          current.totalCoinsEarned < minCoins ? minCoins : current.totalCoinsEarned;

      tx.set(
        ref,
        {
          'uid': uid,
          'level': level,
          'multiplier': multiplierForLevel(level),
          'totalCoinsEarned': newTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> adminAdjustCoins(
    String uid,
    int delta,
    String reason,
  ) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('user_progress').doc(uid);

    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists ? UserProgress.fromDoc(snap) : UserProgress.empty(uid);

      final newCurrent = (current.currentCoins + delta).clamp(0, 9999999);
      final newTotal = delta > 0
          ? current.totalCoinsEarned + delta
          : current.totalCoinsEarned;
      final newLevel = levelFromCoins(newTotal);

      tx.set(
        ref,
        {
          'uid': uid,
          'currentCoins': newCurrent,
          'totalCoinsEarned': newTotal,
          'level': newLevel,
          'multiplier': multiplierForLevel(newLevel),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    ref.collection('transactions').add({
      'type': 'admin_adjustment',
      'coins': delta,
      'description': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
