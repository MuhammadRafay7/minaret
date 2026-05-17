import 'package:cloud_firestore/cloud_firestore.dart';

class AppContentService {
  AppContentService._();

  static final _db = FirebaseFirestore.instance;

  static Stream<DocumentSnapshot> contentStream() {
    return _db.collection('app_settings').doc('content').snapshots();
  }

  static String resolveText({
    required Map<String, dynamic> contentData,
    required String key,
    required String langCode,
    required String fallback,
  }) {
    final raw = contentData[key];
    if (raw is Map<String, dynamic>) {
      final exact = (raw[langCode] as String?)?.trim();
      if (exact != null && exact.isNotEmpty) return exact;
      final en = (raw['en'] as String?)?.trim();
      if (en != null && en.isNotEmpty) return en;
    }
    return fallback;
  }

  static Future<void> upsertText({
    required String key,
    required String langCode,
    required String value,
  }) async {
    await _db.collection('app_settings').doc('content').set({
      key: {langCode: value},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

