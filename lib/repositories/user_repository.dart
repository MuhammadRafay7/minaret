import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minaret/core/constants/app_defaults.dart';

class UserProfile {
  final String uid;
  final String role;
  final String? displayName;
  final String? gender;
  final String? phoneNumber;
  final String? city;
  final List<String> followedMosques;
  final bool notificationsEnabled;
  final Map<String, dynamic> notificationPrefs;
  final Map<String, dynamic> raw;

  UserProfile({
    required this.uid,
    required this.role,
    this.displayName,
    this.gender,
    this.phoneNumber,
    this.city,
    required this.followedMosques,
    required this.notificationsEnabled,
    required this.notificationPrefs,
    required this.raw,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      role: data['role'] as String? ?? kDefaultRole,
      displayName: data['displayName'] as String?,
      gender: data['gender'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      city: data['city'] as String?,
      followedMosques:
          ((data['followedMosques'] as List?) ?? []).cast<String>(),
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      notificationPrefs:
          (data['notificationPrefs'] as Map<String, dynamic>?) ?? {},
      raw: data,
    );
  }
}

class UserRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  Stream<UserProfile?> getUserStream(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserProfile.fromDoc(doc) : null);

  Future<UserProfile?> getUser(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      return doc.exists ? UserProfile.fromDoc(doc) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).set(
          {'createdAt': FieldValue.serverTimestamp(), ...data},
          SetOptions(merge: true));

  Future<void> ensureExists(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).set(
          {'createdAt': FieldValue.serverTimestamp(), ...data},
          SetOptions(merge: true));

  Future<void> saveFcmToken(String uid, String token) =>
      _users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true));

  Future<void> removeFcmToken(String uid) =>
      _users.doc(uid).update({'fcmToken': FieldValue.delete()});

  Future<void> saveVerificationResult(
          String uid, Map<String, dynamic> updates) =>
      _users.doc(uid).update(updates);
}
