import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Mosque {
  final String id;
  final double lat;
  final double lng;
  final Map<String, dynamic> _raw;

  Mosque._(this.id, this.lat, this.lng, this._raw);

  factory Mosque.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Mosque._(
      doc.id,
      (data['lat'] as num?)?.toDouble() ?? 0.0,
      (data['lng'] as num?)?.toDouble() ?? 0.0,
      data,
    );
  }

  Map<String, dynamic> get raw => _raw;
  String get adminUid => _raw['adminUid'] as String? ?? '';

  Map<String, dynamic> toScheduleMap() => {'id': id, ..._raw};
}

class MosqueRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _mosques => _db.collection('mosques');

  DocumentReference? _userDoc() {
    final uid = _auth.currentUser?.uid;
    return uid != null ? _db.collection('users').doc(uid) : null;
  }

  Future<void> addMosque(Map<String, dynamic> data) =>
      _mosques.add({...data, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> updateMosque(String docId, Map<String, dynamic> updates) =>
      _mosques.doc(docId).update(updates);

  Future<void> deleteMosque(String docId) => _mosques.doc(docId).delete();

  Future<void> postAnnouncement(
          String mosqueId, String mosqueName, String text) =>
      _mosques.doc(mosqueId).collection('announcements').add({
        'text': text,
        'mosqueName': mosqueName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

  Future<void> follow(String mosqueId, {bool queued = false}) async {
    final userDoc = _userDoc();
    if (userDoc == null) return;
    await Future.wait([
      userDoc.set(
          {'followedMosques': FieldValue.arrayUnion([mosqueId])},
          SetOptions(merge: true)),
      _mosques
          .doc(mosqueId)
          .update({'followerCount': FieldValue.increment(1)}),
    ]);
  }

  Future<void> unfollow(String mosqueId, {bool queued = false}) async {
    final userDoc = _userDoc();
    if (userDoc == null) return;
    await Future.wait([
      userDoc.set(
          {'followedMosques': FieldValue.arrayRemove([mosqueId])},
          SetOptions(merge: true)),
      _mosques
          .doc(mosqueId)
          .update({'followerCount': FieldValue.increment(-1)}),
    ]);
  }

  Future<bool> isFollowing(String mosqueId) async {
    final userDoc = _userDoc();
    if (userDoc == null) return false;
    final doc = await userDoc.get();
    final data = doc.data() as Map?;
    return ((data?['followedMosques'] as List?) ?? []).contains(mosqueId);
  }

  Stream<bool> isFollowingStream(String mosqueId) {
    final userDoc = _userDoc();
    if (userDoc == null) return Stream.value(false);
    return userDoc.snapshots().map((doc) {
      final data = doc.data() as Map?;
      return ((data?['followedMosques'] as List?) ?? []).contains(mosqueId);
    });
  }

  Stream<List<String>> followedMosqueIds() {
    final userDoc = _userDoc();
    if (userDoc == null) return Stream.value([]);
    return userDoc.snapshots().map((doc) {
      final data = doc.data() as Map?;
      return ((data?['followedMosques'] as List?) ?? []).cast<String>();
    });
  }

  Stream<Mosque?> getMosqueStream(String mosqueId) => _mosques
      .doc(mosqueId)
      .snapshots()
      .map((doc) => doc.exists ? Mosque.fromDoc(doc) : null);

  Future<List<Mosque>> searchNearby(
      double lat, double lng, double delta) async {
    final snap = await _mosques
        .where('lat', isGreaterThan: lat - delta, isLessThan: lat + delta)
        .get();
    return snap.docs
        .map(Mosque.fromDoc)
        .where((m) => (m.lng - lng).abs() <= delta)
        .toList();
  }
}
