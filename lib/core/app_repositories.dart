import 'dependency_injection.dart';
import '../repositories/mosque_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/prayer_repository.dart';
import '../repositories/janaza_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/connectivity_service.dart';
import '../services/sync_queue.dart';

/// Registers all domain repositories and infrastructure services as singletons.
/// Call once in main(), after Firebase.initializeApp() and after Hive is open.
void configureRepositories() {
  final container = ServiceContainer();

  // ── Infrastructure ─────────────────────────────────────────────────────────

  final connectivity = ConnectivityService();
  container.registerSingletonInstance<ConnectivityService>(connectivity);

  final syncQueue = SyncQueue();
  container.registerSingletonInstance<SyncQueue>(syncQueue);

  // ── Domain repositories ────────────────────────────────────────────────────

  final notifRepo = NotificationRepository();
  container.registerSingletonInstance<NotificationRepository>(notifRepo);

  final mosqueRepo = MosqueRepository();
  container.registerSingletonInstance<MosqueRepository>(mosqueRepo);

  container.registerSingletonInstance<UserRepository>(UserRepository());

  final prayerRepo = PrayerRepository();
  container.registerSingletonInstance<PrayerRepository>(prayerRepo);

  container.registerSingletonInstance<JanazaRepository>(
    JanazaRepository(notifRepo: notifRepo),
  );

  // ── SyncQueue executors ────────────────────────────────────────────────────
  // Executors are registered here (not in SyncQueue itself) to avoid circular
  // imports between SyncQueue and the repositories.

  SyncQueue.registerExecutor(
    'mosque_follow',
    (p) => mosqueRepo.follow(p['mosqueId'] as String, queued: true),
  );
  SyncQueue.registerExecutor(
    'mosque_unfollow',
    (p) => mosqueRepo.unfollow(p['mosqueId'] as String, queued: true),
  );
  SyncQueue.registerExecutor(
    'toggle_prayer',
    (p) => prayerRepo.togglePrayer(p['prayerName'] as String, queued: true),
  );

  // Start processing any entries left from a previous session.
  syncQueue.startListening(connectivity);
}
