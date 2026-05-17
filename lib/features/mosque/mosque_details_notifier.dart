import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/base/base_notifier.dart';
import '../../repositories/janaza_repository.dart';
import '../../repositories/mosque_repository.dart';

class MosqueDetailsNotifier extends BaseNotifier {
  final MosqueRepository _mosqueRepository;
  final JanazaRepository _janazaRepository;

  Mosque? _mosque;
  List<JanazaAnnouncement> _janazaAnnouncements = [];
  bool _isFollowing = false;
  String? _mosqueId;

  Mosque? get mosque => _mosque;
  List<JanazaAnnouncement> get janazaAnnouncements => _janazaAnnouncements;
  bool get isFollowing => _isFollowing;

  bool get canEdit {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == (_mosque?.adminUid ?? _mosqueId);
  }

  MosqueDetailsNotifier({
    required MosqueRepository mosqueRepository,
    required JanazaRepository janazaRepository,
  })  : _mosqueRepository = mosqueRepository,
        _janazaRepository = janazaRepository;

  /// Call immediately after construction to subscribe to all three streams.
  void init(String mosqueId, Map<String, dynamic> initialData) {
    _mosqueId = mosqueId;

    listenToStream(
      _mosqueRepository.getMosqueStream(mosqueId),
      onData: (mosque) {
        _mosque = mosque;
        notifyListeners();
      },
    );

    listenToStream(
      _janazaRepository.activeForMosque(mosqueId),
      onData: (list) {
        _janazaAnnouncements = list;
        notifyListeners();
      },
    );

    listenToStream(
      _mosqueRepository.isFollowingStream(mosqueId),
      onData: (following) {
        _isFollowing = following;
        notifyListeners();
      },
    );

    _handleAutoVerification(mosqueId, initialData);
  }

  Future<void> _handleAutoVerification(
      String mosqueId, Map<String, dynamic> data) async {
    final isVerified = data['isVerified'] as bool? ?? false;
    if (isVerified) return;

    final lastReportAt = data['lastReportAt'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;
    final reference =
        lastReportAt?.toDate() ?? createdAt?.toDate() ?? DateTime.now();

    if (DateTime.now().difference(reference).inDays >= 30) {
      await runAsync(() => _mosqueRepository.updateMosque(mosqueId, {
            'isVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          }));
    }
  }

  Future<void> toggleFollow() async {
    final id = _mosqueId;
    if (id == null) return;
    await runAsync(() async {
      if (_isFollowing) {
        await _mosqueRepository.unfollow(id);
      } else {
        await _mosqueRepository.follow(id);
      }
    });
  }
}
