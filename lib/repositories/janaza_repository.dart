import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_repository.dart';

class JanazaAnnouncement {
  final String id;
  final String mosqueId;
  final String mosqueName;
  final String mosqueFiqh;
  final String mosqueCity;
  final String deceasedName;
  final DateTime janazaTime;
  final String locationNote;
  final String gender;
  final String age;
  final String fatherName;
  final String motherName;
  final String husbandName;
  final String wifeName;
  final String brotherName;
  final String sisterName;
  final bool isActive;
  final DateTime createdAt;

  JanazaAnnouncement({
    required this.id,
    required this.mosqueId,
    required this.mosqueName,
    required this.mosqueFiqh,
    required this.mosqueCity,
    required this.deceasedName,
    required this.janazaTime,
    this.locationNote = '',
    this.gender = '',
    this.age = '',
    this.fatherName = '',
    this.motherName = '',
    this.husbandName = '',
    this.wifeName = '',
    this.brotherName = '',
    this.sisterName = '',
    required this.isActive,
    required this.createdAt,
  });

  factory JanazaAnnouncement.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return JanazaAnnouncement(
      id: doc.id,
      mosqueId: data['mosqueId'] as String? ?? '',
      mosqueName: data['mosqueName'] as String? ?? '',
      mosqueFiqh: data['mosqueFiqh'] as String? ?? '',
      mosqueCity: data['mosqueCity'] as String? ?? '',
      deceasedName: data['deceasedName'] as String? ?? '',
      janazaTime:
          (data['janazaTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      locationNote: data['locationNote'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      age: data['age'] as String? ?? '',
      fatherName: data['fatherName'] as String? ?? '',
      motherName: data['motherName'] as String? ?? '',
      husbandName: data['husbandName'] as String? ?? '',
      wifeName: data['wifeName'] as String? ?? '',
      brotherName: data['brotherName'] as String? ?? '',
      sisterName: data['sisterName'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class JanazaRepository {
  // ignore: unused_field
  final NotificationRepository _notifRepo;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  JanazaRepository({required NotificationRepository notifRepo})
      : _notifRepo = notifRepo;

  CollectionReference get _janazas => _db.collection('janaza');

  Future<void> postAnnouncement({
    required String mosqueId,
    required String mosqueName,
    required String mosqueFiqh,
    required String mosqueCity,
    required String deceasedName,
    required DateTime janazaTime,
    String locationNote = '',
    String gender = '',
    String fatherName = '',
    String motherName = '',
    String husbandName = '',
    String wifeName = '',
    String brotherName = '',
    String sisterName = '',
    String age = '',
  }) async {
    await _janazas.add({
      'mosqueId': mosqueId,
      'mosqueName': mosqueName,
      'mosqueFiqh': mosqueFiqh,
      'mosqueCity': mosqueCity,
      'deceasedName': deceasedName,
      'janazaTime': Timestamp.fromDate(janazaTime),
      'locationNote': locationNote,
      'gender': gender,
      'fatherName': fatherName,
      'motherName': motherName,
      'husbandName': husbandName,
      'wifeName': wifeName,
      'brotherName': brotherName,
      'sisterName': sisterName,
      'age': age,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'postedBy': _auth.currentUser?.uid ?? '',
    });
  }

  Future<void> updateAnnouncement(
          String announcementId, Map<String, dynamic> updates) =>
      _janazas.doc(announcementId).update(updates);

  Future<void> deactivate(String announcementId) =>
      _janazas.doc(announcementId).update({'isActive': false});

  Stream<List<JanazaAnnouncement>> activeForMosque(String mosqueId) =>
      _janazas
          .where('mosqueId', isEqualTo: mosqueId)
          .where('isActive', isEqualTo: true)
          .where('janazaTime',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
          .snapshots()
          .map((s) => s.docs.map(JanazaAnnouncement.fromDoc).toList());

  Stream<List<JanazaAnnouncement>> activeForMosques(
      List<String> mosqueIds) {
    if (mosqueIds.isEmpty) return Stream.value([]);
    return _janazas
        .where('mosqueId', whereIn: mosqueIds.take(10).toList())
        .where('isActive', isEqualTo: true)
        .where('janazaTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(hours: 24))))
        .snapshots()
        .map((s) => s.docs.map(JanazaAnnouncement.fromDoc).toList());
  }

  Stream<List<JanazaAnnouncement>> activeForCity(String city) => _janazas
      .where('mosqueCity', isEqualTo: city)
      .where('isActive', isEqualTo: true)
      .where('janazaTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 24))))
      .snapshots()
      .map((s) => s.docs.map(JanazaAnnouncement.fromDoc).toList());
}
