import 'dart:async';

import '../../../core/base/base_notifier.dart';
import '../../../repositories/notification_repository.dart';

class NotificationsNotifier extends BaseNotifier {
  final NotificationRepository _repo;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _initialized = false;
  int _limit = 20;
  bool _hasMore = true;
  String? _uid;
  StreamSubscription<List<AppNotification>>? _notifSub;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get initialized => _initialized;
  bool get hasMore => _hasMore;

  NotificationsNotifier({required NotificationRepository repo}) : _repo = repo;

  void init(String uid) {
    _uid = uid;
    _resubscribeNotifications();
    listenToStream(
      _repo.getUnreadCountStream(uid),
      onData: (count) {
        _unreadCount = count;
        notifyListeners();
      },
    );
  }

  void _resubscribeNotifications() {
    _notifSub?.cancel();
    _notifSub = _repo
        .getUserNotificationsStream(_uid!, limit: _limit)
        .listen(
          (list) {
            _notifications = list;
            _hasMore = list.length >= _limit;
            _initialized = true;
            notifyListeners();
          },
          onError: (Object e, StackTrace st) {
            // Error surfaces through BaseNotifier error state via runAsync.
          },
          cancelOnError: false,
        );
  }

  void loadMore() {
    if (!_hasMore || _uid == null) return;
    _limit += 20;
    _resubscribeNotifications();
  }

  Future<void> deleteNotification(String id) =>
      runAsync(() => _repo.deleteNotification(id));

  Future<void> markAsRead(String id) => runAsync(() => _repo.markAsRead(id));

  Future<void> markAllAsRead(String uid) =>
      runAsync(() => _repo.markAllAsRead(uid));

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }
}
