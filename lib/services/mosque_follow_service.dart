import '../core/dependency_injection.dart';
import '../repositories/mosque_repository.dart';

class MosqueFollowService {
  MosqueFollowService._();

  static MosqueRepository get _repo =>
      ServiceLocator.get<MosqueRepository>();

  static Future<void> follow(String mosqueId) => _repo.follow(mosqueId);

  static Future<void> unfollow(String mosqueId) =>
      _repo.unfollow(mosqueId);

  static Future<bool> isFollowing(String mosqueId) =>
      _repo.isFollowing(mosqueId);

  static Stream<List<String>> followedMosqueIds() =>
      _repo.followedMosqueIds();

  static Stream<bool> isFollowingStream(String mosqueId) =>
      _repo.isFollowingStream(mosqueId);
}
