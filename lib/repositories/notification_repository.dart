import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? body;
  final String? mosqueId;
  final String? mosqueName;
  final bool read;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> raw;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.body,
    this.mosqueId,
    this.mosqueName,
    required this.read,
    required this.createdAt,
    Map<String, dynamic>? raw,
  })  : isRead = read,
        raw = raw ?? {};

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      body: data['message'] as String?,
      mosqueId: data['mosqueId'] as String?,
      mosqueName: data['mosqueName'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      raw: data,
    );
  }
}

class NotificationRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _notifs => _db.collection('notifications');

  Future<void> addNotification(Map<String, dynamic> data) =>
      _notifs.add({...data, 'createdAt': FieldValue.serverTimestamp(), 'read': false});

  Stream<List<AppNotification>> getUserNotificationsStream(
    String uid, {
    int limit = 20,
  }) =>
      _notifs
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Stream<int> getUnreadCountStream(String uid) => _notifs
      .where('userId', isEqualTo: uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<int> getUnreadCount(String uid) async {
    final snap = await _notifs
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    return snap.docs.length;
  }

  Future<void> deleteNotification(String id) => _notifs.doc(id).delete();

  Future<void> markAsRead(String id) =>
      _notifs.doc(id).update({'read': true});

  Future<void> markAllAsRead(String uid) async {
    final snap = await _notifs
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
