import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/dependency_injection.dart';
import '../repositories/user_repository.dart';

class FcmTokenService {
  FcmTokenService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _handlersReady = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;

  static UserRepository get _repo => ServiceLocator.get<UserRepository>();

  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('🔴 FCM: notification permission not granted');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _repo.saveFcmToken(user.uid, token);
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _repo.saveFcmToken(currentUser.uid, newToken);
        }
      });

      await _initMessageHandlers();
    } catch (e) {
      // Notification permission blocked by browser/OS — not fatal, app continues normally.
      debugPrint('🔴 FCM init skipped: $e');
    }
  }

  static Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _repo.removeFcmToken(user.uid);
  }

  static Future<void> _initMessageHandlers() async {
    if (!_handlersReady) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
          const InitializationSettings(android: androidSettings));
      _handlersReady = true;
    }

    await _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      final notif = message.notification;
      if (notif == null) return;
      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notif.title ?? 'Minaret',
        notif.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'push_alerts',
            'Push Alerts',
            channelDescription: 'Realtime app push notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });
  }
}
