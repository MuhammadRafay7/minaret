import '../../../core/base/base_notifier.dart';
import '../../../repositories/notification_repository.dart';

class NotificationsNotifier extends BaseNotifier {
  final NotificationRepository _repo;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _initialized = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get initialized => _initialized;

  NotificationsNotifier({required NotificationRepository repo}) : _repo = repo;

  void init(String uid) {
    listenToStream(
      _repo.getUserNotificationsStream(uid),
      onData: (list) {
        _notifications = list;
        _initialized = true;
        notifyListeners();
      },
    );
    listenToStream(
      _repo.getUnreadCountStream(uid),
      onData: (count) {
        _unreadCount = count;
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String id) => runAsync(() => _repo.markAsRead(id));

  Future<void> markAllAsRead(String uid) =>
      runAsync(() => _repo.markAllAsRead(uid));
}
