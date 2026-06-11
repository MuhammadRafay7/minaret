import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:minaret/repositories/mosque_repository.dart';

import '../helpers/fake_auth.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _mosqueData({
  String name = 'Test Mosque',
  String? city,
  String? fiqh,
  bool isVerified = false,
  double lat = 33.7,
  double lng = 73.1,
  String? adminUid,
  int followerCount = 0,
}) =>
    {
      'name': name,
      'city': city ?? 'Islamabad',
      'fiqh': fiqh,
      'isVerified': isVerified,
      'lat': lat,
      'lng': lng,
      'adminUid': adminUid,
      'followerCount': followerCount,
    };

void main() {
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MosqueRepository repo;

  const userId = 'user-uid-001';
  const mosqueId = 'mosque-id-001';

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn(userId);
    repo = MosqueRepository(db: fakeDb, auth: mockAuth);
  });

  // =========================================================================
  // getMosque
  // =========================================================================

  group('getMosque', () {
    test('returns null when document does not exist', () async {
      final result = await repo.getMosque('nonexistent');
      expect(result, isNull);
    });

    test('returns Mosque when document exists', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
      final result = await repo.getMosque(mosqueId);

      expect(result, isNotNull);
      expect(result!.id, mosqueId);
      expect(result.name, 'Test Mosque');
    });

    test('maps all core fields from Firestore document', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(
        name: 'Jamia Mosque',
        city: 'Lahore',
        fiqh: 'Hanafi',
        isVerified: true,
        lat: 31.5,
        lng: 74.3,
        adminUid: userId,
        followerCount: 42,
      ));

      final m = await repo.getMosque(mosqueId);

      expect(m!.name, 'Jamia Mosque');
      expect(m.city, 'Lahore');
      expect(m.fiqh, 'Hanafi');
      expect(m.isVerified, isTrue);
      expect(m.lat, closeTo(31.5, 0.001));
      expect(m.lng, closeTo(74.3, 0.001));
      expect(m.adminUid, userId);
      expect(m.followerCount, 42);
    });

    test('returns Mosque with safe defaults for missing optional fields', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set({'name': 'Min Mosque'});

      final m = await repo.getMosque(mosqueId);

      expect(m, isNotNull);
      expect(m!.followerCount, 0);
      expect(m.isVerified, isFalse);
      expect(m.city, isNull);
      expect(m.lat, isNull);
      expect(m.lng, isNull);
    });
  });

  // =========================================================================
  // getMosqueStream
  // =========================================================================

  group('getMosqueStream', () {
    test('emits null when document does not exist', () async {
      await expectLater(
        repo.getMosqueStream('nonexistent').first,
        completion(isNull),
      );
    });

    test('emits Mosque when document exists', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
      final mosque = await repo.getMosqueStream(mosqueId).first;

      expect(mosque, isNotNull);
      expect(mosque!.id, mosqueId);
    });

    test('emits updated value after document write', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(name: 'Before'));

      final stream = repo.getMosqueStream(mosqueId);
      final updates = <String?>[];

      final sub = stream.listen((m) => updates.add(m?.name));
      await Future<void>.delayed(Duration.zero);

      await fakeDb.collection('mosques').doc(mosqueId).update({'name': 'After'});
      await Future<void>.delayed(Duration.zero);

      expect(updates, contains('Before'));
      expect(updates, contains('After'));

      await sub.cancel();
    });
  });

  // =========================================================================
  // addMosque
  // =========================================================================

  group('addMosque', () {
    test('returns a non-empty document ID', () async {
      final id = await repo.addMosque(_mosqueData());
      expect(id, isNotEmpty);
    });

    test('document is readable after creation', () async {
      final id = await repo.addMosque(_mosqueData(name: 'New Mosque'));
      final doc = await fakeDb.collection('mosques').doc(id).get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'New Mosque');
    });
  });

  // =========================================================================
  // updateMosque
  // =========================================================================

  group('updateMosque', () {
    setUp(() async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
    });

    test('updates specified fields without touching others', () async {
      await repo.updateMosque(mosqueId, {'name': 'Updated Name'});

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['name'], 'Updated Name');
      expect(doc.data()?['city'], 'Islamabad'); // untouched
    });

    test('can update multiple fields atomically', () async {
      await repo.updateMosque(mosqueId, {'fajr': '05:00', 'dhuhr': '12:30'});

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['fajr'], '05:00');
      expect(doc.data()?['dhuhr'], '12:30');
    });
  });

  // =========================================================================
  // setMosque
  // =========================================================================

  group('setMosque', () {
    test('creates a document at a specific ID', () async {
      await repo.setMosque('custom-id', _mosqueData(name: 'Custom'));
      final doc = await fakeDb.collection('mosques').doc('custom-id').get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Custom');
    });

    test('merge:false overwrites the whole document', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(name: 'Old', city: 'Karachi'));

      await repo.setMosque(mosqueId, {'name': 'New'});

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['name'], 'New');
      expect(doc.data()?['city'], isNull); // city is gone
    });

    test('merge:true preserves existing fields', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(name: 'Old', city: 'Karachi'));

      await repo.setMosque(mosqueId, {'name': 'New'}, merge: true);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['name'], 'New');
      expect(doc.data()?['city'], 'Karachi'); // preserved
    });
  });

  // =========================================================================
  // deleteMosque
  // =========================================================================

  group('deleteMosque', () {
    test('document is gone after delete', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
      await repo.deleteMosque(mosqueId);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.exists, isFalse);
    });
  });

  // =========================================================================
  // searchNearby
  // =========================================================================

  group('searchNearby', () {
    setUp(() async {
      // Mosque exactly at query point
      await fakeDb.collection('mosques').doc('m-center').set(
          _mosqueData(name: 'Center', lat: 33.7, lng: 73.1));
      // Mosque within bounding box (delta = 0.1 degrees)
      await fakeDb.collection('mosques').doc('m-nearby').set(
          _mosqueData(name: 'Nearby', lat: 33.75, lng: 73.15));
      // Mosque far outside bounding box
      await fakeDb.collection('mosques').doc('m-far').set(
          _mosqueData(name: 'Far', lat: 30.0, lng: 70.0));
    });

    test('returns mosques within the bounding box', () async {
      // delta=0.1 → lat range [33.6, 33.8], lng range [73.0, 73.2]
      final results = await repo.searchNearby(33.7, 73.1, 0.1);
      final names = results.map((m) => m.name).toSet();

      expect(names, contains('Center'));
      expect(names, contains('Nearby'));
    });

    test('excludes mosques outside the bounding box', () async {
      final results = await repo.searchNearby(33.7, 73.1, 0.1);
      final names = results.map((m) => m.name).toSet();

      expect(names, isNot(contains('Far')));
    });

    test('returns empty list when no mosques are in range', () async {
      final results = await repo.searchNearby(0.0, 0.0, 0.01);
      expect(results, isEmpty);
    });

    test('excludes mosques whose lng is outside the range even if lat matches', () async {
      // lat is in range but lng is not
      await fakeDb.collection('mosques').doc('m-wrong-lng').set(
          _mosqueData(name: 'WrongLng', lat: 33.75, lng: 80.0));

      final results = await repo.searchNearby(33.7, 73.1, 0.1);
      final names = results.map((m) => m.name).toSet();

      expect(names, isNot(contains('WrongLng')));
    });
  });

  // =========================================================================
  // queryMosques
  // =========================================================================

  group('queryMosques', () {
    setUp(() async {
      await fakeDb.collection('mosques').add(_mosqueData(
          name: 'Hanafi Islamabad', city: 'Islamabad', fiqh: 'Hanafi', isVerified: true));
      await fakeDb.collection('mosques').add(_mosqueData(
          name: 'Shafi Islamabad', city: 'Islamabad', fiqh: 'Shafi', isVerified: false));
      await fakeDb.collection('mosques').add(_mosqueData(
          name: 'Hanafi Lahore', city: 'Lahore', fiqh: 'Hanafi', isVerified: false));
    });

    test('returns all mosques when no filters applied', () async {
      final results = await repo.queryMosques(limit: 10);
      expect(results.length, 3);
    });

    test('cityFilter returns only mosques in that city', () async {
      final results = await repo.queryMosques(cityFilter: 'Islamabad', limit: 10);
      expect(results.length, 2);
      expect(results.every((m) => m.city == 'Islamabad'), isTrue);
    });

    test('fiqhFilter returns only mosques with that fiqh', () async {
      final results = await repo.queryMosques(fiqhFilter: 'Hanafi', limit: 10);
      expect(results.length, 2);
      expect(results.every((m) => m.fiqh == 'Hanafi'), isTrue);
    });

    test('verifiedOnly filters to isVerified==true mosques', () async {
      final results = await repo.queryMosques(verifiedOnly: true, limit: 10);
      expect(results.length, 1);
      expect(results.first.name, 'Hanafi Islamabad');
    });

    test('limit caps the result count', () async {
      final results = await repo.queryMosques(limit: 2);
      expect(results.length, lessThanOrEqualTo(2));
    });
  });

  // =========================================================================
  // follow
  // =========================================================================

  group('follow', () {
    setUp(() async {
      // Start at 0: fake_cloud_firestore handles FieldValue.increment in
      // set()+merge correctly when the field starts at 0, but not when
      // atomically adding to an existing non-zero value. Starting at 0 lets
      // us verify the count went up without hitting that limitation.
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(followerCount: 0));
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': <String>[]});
    });

    test('increments followerCount by 1', () async {
      await repo.follow(mosqueId);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['followerCount'], 1);
    });

    test('adds mosqueId to user\'s followedMosques array', () async {
      await repo.follow(mosqueId);

      final userDoc = await fakeDb.collection('users').doc(userId).get();
      final followed = (userDoc.data()?['followedMosques'] as List).cast<String>();
      expect(followed, contains(mosqueId));
    });

    test('is idempotent — following twice does not double-increment', () async {
      await repo.follow(mosqueId);
      await repo.follow(mosqueId);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      // Second follow is a no-op — count stays at 1, not 2
      expect(doc.data()?['followerCount'], 1);
    });

    test('throws when user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      await expectLater(repo.follow(mosqueId), throwsException);
    });
  });

  // =========================================================================
  // unfollow
  // =========================================================================

  group('unfollow', () {
    setUp(() async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(followerCount: 5));
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': [mosqueId]});
    });

    test('decrements followerCount by 1', () async {
      await repo.unfollow(mosqueId);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['followerCount'], 4);
    });

    test('removes mosqueId from user\'s followedMosques array', () async {
      await repo.unfollow(mosqueId);

      final userDoc = await fakeDb.collection('users').doc(userId).get();
      final followed = (userDoc.data()?['followedMosques'] as List).cast<String>();
      expect(followed, isNot(contains(mosqueId)));
    });

    test('is no-op when user is not following the mosque', () async {
      // Unfollow when not in list — should not throw or decrement
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': <String>[]});

      await repo.unfollow(mosqueId);

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['followerCount'], 5); // unchanged
    });

    test('throws when user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      await expectLater(repo.unfollow(mosqueId), throwsException);
    });
  });

  // =========================================================================
  // isFollowing
  // =========================================================================

  group('isFollowing', () {
    test('returns true when mosque is in followedMosques', () async {
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': [mosqueId]});

      expect(await repo.isFollowing(mosqueId), isTrue);
    });

    test('returns false when mosque is not in followedMosques', () async {
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': <String>[]});

      expect(await repo.isFollowing(mosqueId), isFalse);
    });

    test('returns false when user document does not exist', () async {
      // no user document seeded
      expect(await repo.isFollowing(mosqueId), isFalse);
    });

    test('returns false when user is unauthenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(await repo.isFollowing(mosqueId), isFalse);
    });
  });

  // =========================================================================
  // followedMosqueIds stream
  // =========================================================================

  group('followedMosqueIds', () {
    test('emits current followedMosques list', () async {
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': [mosqueId, 'other-id']});

      final ids = await repo.followedMosqueIds().first;
      expect(ids, containsAll([mosqueId, 'other-id']));
    });

    test('emits empty list when user document has no followedMosques', () async {
      await fakeDb.collection('users').doc(userId).set({});

      final ids = await repo.followedMosqueIds().first;
      expect(ids, isEmpty);
    });

    test('emits empty list when unauthenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final ids = await repo.followedMosqueIds().first;
      expect(ids, isEmpty);
    });

    test('emits updated list after mosque is followed', () async {
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': <String>[]});

      final emitted = <List<String>>[];
      final sub = repo.followedMosqueIds().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await fakeDb.collection('users').doc(userId).update({
        'followedMosques': FieldValue.arrayUnion([mosqueId]),
      });
      await Future<void>.delayed(Duration.zero);

      expect(emitted.any((list) => list.contains(mosqueId)), isTrue);
      await sub.cancel();
    });
  });

  // =========================================================================
  // isFollowingStream
  // =========================================================================

  group('isFollowingStream', () {
    test('emits true then false as follow state changes', () async {
      await fakeDb
          .collection('users')
          .doc(userId)
          .set({'followedMosques': [mosqueId]});

      final values = <bool>[];
      final sub = repo.isFollowingStream(mosqueId).listen(values.add);
      await Future<void>.delayed(Duration.zero);

      await fakeDb.collection('users').doc(userId).update({
        'followedMosques': FieldValue.arrayRemove([mosqueId]),
      });
      await Future<void>.delayed(Duration.zero);

      expect(values, containsAllInOrder([true, false]));
      await sub.cancel();
    });
  });

  // =========================================================================
  // postAnnouncement
  // =========================================================================

  group('postAnnouncement', () {
    setUp(() async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
    });

    test('creates a document in the announcements subcollection', () async {
      await repo.postAnnouncement(mosqueId, 'Test Mosque', 'Jummah at 1pm today');

      final snap = await fakeDb
          .collection('mosques')
          .doc(mosqueId)
          .collection('announcements')
          .get();

      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'Jummah at 1pm today');
    });

    test('updates lastAnnouncement on the mosque document', () async {
      await repo.postAnnouncement(mosqueId, 'Test Mosque', 'New announcement');

      final doc = await fakeDb.collection('mosques').doc(mosqueId).get();
      expect(doc.data()?['lastAnnouncement'], 'New announcement');
    });

    test('announcement document includes mosqueId and mosqueName', () async {
      await repo.postAnnouncement(mosqueId, 'Grand Mosque', 'Text');

      final snap = await fakeDb
          .collection('mosques')
          .doc(mosqueId)
          .collection('announcements')
          .get();

      final data = snap.docs.first.data();
      expect(data['mosqueId'], mosqueId);
      expect(data['mosqueName'], 'Grand Mosque');
    });
  });

  // =========================================================================
  // getMosquesStream
  // =========================================================================

  group('getMosquesStream', () {
    test('emits list with all mosques in the collection', () async {
      await fakeDb.collection('mosques').add(_mosqueData(name: 'A'));
      await fakeDb.collection('mosques').add(_mosqueData(name: 'B'));

      final list = await repo.getMosquesStream().first;
      final names = list.map((m) => m.name).toSet();

      expect(names, containsAll(['A', 'B']));
    });

    test('emits empty list when collection is empty', () async {
      final list = await repo.getMosquesStream().first;
      expect(list, isEmpty);
    });
  });

  // =========================================================================
  // Mosque.toScheduleMap
  // =========================================================================

  group('Mosque.toScheduleMap', () {
    test('includes _docId from mosque id', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData(
            name: 'Schedule Mosque',
          )..addAll({'fajr': '05:10'}));

      final mosque = await repo.getMosque(mosqueId);
      final map = mosque!.toScheduleMap();

      expect(map['_docId'], mosqueId);
      expect(map['name'], 'Schedule Mosque');
      expect(map['fajr'], '05:10');
    });

    test('all 16 schedule keys are present in the map', () async {
      await fakeDb.collection('mosques').doc(mosqueId).set(_mosqueData());
      final mosque = await repo.getMosque(mosqueId);
      final map = mosque!.toScheduleMap();

      const expectedKeys = [
        '_docId', 'name',
        'fajr', 'dhuhr', 'asr', 'maghrib', 'isha',
        'adhanFajr', 'adhanDhuhr', 'adhanAsr', 'adhanMaghrib', 'adhanIsha',
        'jummah', 'adhanJummah',
        'taraweeh', 'isRamadan',
        'eidFitr', 'eidAdha', 'eidFitrDate', 'eidAdhaDate',
        'janazaTime', 'janazaDate', 'janazaLabel',
      ];
      for (final key in expectedKeys) {
        expect(map.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });
  });
}
