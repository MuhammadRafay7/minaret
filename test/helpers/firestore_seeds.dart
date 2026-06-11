import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:intl/intl.dart';

const List<String> kAllPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

/// Seeds a prayer_records document for the given [date] with all 5 prayers completed.
Future<void> seedFullDay(
  FakeFirebaseFirestore db,
  String userId,
  DateTime date,
) =>
    _seedDay(db, userId, date, kAllPrayers);

/// Seeds a prayer_records document for the given [date] with no prayers completed.
Future<void> seedEmptyDay(
  FakeFirebaseFirestore db,
  String userId,
  DateTime date,
) =>
    _seedDay(db, userId, date, []);

Future<void> _seedDay(
  FakeFirebaseFirestore db,
  String userId,
  DateTime date,
  List<String> completedPrayers,
) async {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final docId = '${userId}_$dateKey';
  final dayStart = DateTime(date.year, date.month, date.day);
  await db.collection('prayer_records').doc(docId).set({
    'userId': userId,
    'date': Timestamp.fromDate(dayStart),
    'completedPrayers': completedPrayers,
    'timestamp': Timestamp.fromDate(dayStart),
    'streakCount': 0,
    'longestStreak': 0,
    'completionRate': completedPrayers.length / 5.0,
  });
}
