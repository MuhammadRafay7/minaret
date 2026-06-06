import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/location_service.dart';
import '../core/dependency_injection.dart';
import '../repositories/mosque_repository.dart';
import '../repositories/user_repository.dart';
import '../l10n/generated/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOUND SETUP — place these files in android/app/src/main/res/raw/
//   adhan.mp3      → played on every adhan notification
//   janaza.mp3     → played on every janaza notification
//                    (use a recitation of "Inna lillahi…" as the audio)
//
// IMPORTANT: Android caches notification channel settings on first creation.
// If you previously had these channels without sounds, uninstall the app
// (or change the channel IDs below to adhan_alerts_v2 / janaza_alerts_v2)
// so Android re-creates the channels with the sound attached.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final List<StreamSubscription> _listeners = [];
  static final Map<String, StreamSubscription?> _mosqueListeners = {};
  static StreamSubscription? _nearestMosqueSub;
  static StreamSubscription? _realtimeLocationSub;
  static String? _currentNearestId;
  static bool _isInitialized = false;
  // Whether the OS currently lets us schedule EXACT alarms. On Android 14+
  // SCHEDULE_EXACT_ALARM is revoked by default for non-alarm apps; when false
  // we fall back to inexact scheduling so zonedSchedule() never throws and
  // silently drops the notification.
  static bool _canScheduleExact = false;
  static bool _notificationsEnabled = true;
  static Map<String, dynamic> _notificationPrefs = const {
    'janaza': true,
    'adhan': true,
    'namaz': true,
    'eid': true,
    'taraweeh': true,
    'suhoor': true,
    'iftar': true,
  };

  // ── Notification channel IDs ──────────────────────────────────────────────
  // Bump the suffix (e.g. _v2) any time you change channel settings so Android
  // re-creates the channel with the new configuration.
  static const String _adhanChannelId = 'adhan_alerts_v2';
  static const String _janazaChannelId = 'janaza_alerts_v2';
  static const String _prayerChannelId = 'prayer_alerts';
  static const String _taraweehChannelId = 'taraweeh_alerts';
  static const String _eidChannelId = 'eid_alerts';
  static const String _updateChannelId = 'update_alerts';
  static const String _suhoorChannelId = 'suhoor_alerts';
  static const String _iftarChannelId = 'iftar_alerts';
  static const String _zakatChannelId = 'zakat_alerts';

  // ── Janaza verse ──────────────────────────────────────────────────────────
  static const String _janazaArabic =
      'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ';
  static const String _janazaTranslation =
      '"Indeed, to Allah we belong and to Him we shall return."';

  // ── Deterministic notification ID ranges per mosque ───────────────────────
  // Persisted to SharedPreferences so slot→mosque mappings survive app restarts.
  // Without persistence, the same mosque gets a different slot after restart
  // making old notifications impossible to cancel.
  static final Map<String, int> _mosqueSlots = {};
  // Last-known schedule data per mosque — used to re-apply notifications
  // immediately when the user changes a notification preference, without
  // waiting for the next Firestore stream event.
  static final Map<String, Map<String, dynamic>> _lastMosqueData = {};
  static int _nextSlot = 100;
  static const _slotsPrefKey = 'mosque_notif_slots';
  // Slot layout (120 IDs per mosque):
  //   0–34  : namaz   (5 prayers × 7 days)
  //   35–69 : adhan   (5 adhans  × 7 days)
  //   70–99 : taraweeh (day 0–29)
  //   100–106 : jummah prayer (7 days)
  //   107–113 : jummah adhan  (7 days)
  //   114   : eid al-fitr
  //   115   : eid al-adha
  //   116–119 : reserved

  static Future<void> _loadSlotsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_slotsPrefKey);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        _mosqueSlots.addAll(decoded.map((k, v) => MapEntry(k, v as int)));
        if (_mosqueSlots.isNotEmpty) {
          _nextSlot = _mosqueSlots.values.reduce((a, b) => a > b ? a : b) + 120;
        }
      }
    } catch (e) {
      debugPrint('🔴 _loadSlotsFromPrefs error: $e');
    }
  }

  static Future<void> _saveSlotsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_slotsPrefKey, jsonEncode(_mosqueSlots));
    } catch (e) {
      debugPrint('🔴 _saveSlotsToPrefs error: $e');
    }
  }

  static int _mosqueSlot(String mosqueId) {
    if (!_mosqueSlots.containsKey(mosqueId)) {
      _mosqueSlots[mosqueId] = _nextSlot;
      _nextSlot += 120;
      _saveSlotsToPrefs();
    }
    return _mosqueSlots[mosqueId]!;
  }

  /// Deterministic ID layout per mosque slot (120 IDs wide):
  ///   slot+0  – slot+34  : namaz   (5 prayers × 7 days)
  ///   slot+35 – slot+69  : adhan   (5 adhans  × 7 days)
  ///   slot+70 – slot+99  : taraweeh (day 0–29, Ramadan only)
  ///   slot+100– slot+106 : jummah prayer (7 days)
  ///   slot+107– slot+113 : jummah adhan  (7 days)
  ///   slot+114           : eid al-fitr
  ///   slot+115           : eid al-adha
  ///   slot+116– slot+119 : reserved
  /// Janaza (global, hash-based, never overlaps slot range):
  ///   10_000_000 – 10_999_999
  static int _prayerNotifId(String mosqueId, int prayerIndex, int day) =>
      _mosqueSlot(mosqueId) + (prayerIndex * 7) + day;

  static int _adhanNotifId(String mosqueId, int adhanIndex, int day) =>
      _mosqueSlot(mosqueId) + 35 + (adhanIndex * 7) + day;

  static int _taraweehNotifId(String mosqueId, int day) =>
      _mosqueSlot(mosqueId) + 70 + day;

  static int _jummahNotifId(String mosqueId, int day) =>
      _mosqueSlot(mosqueId) + 100 + day;

  static int _jummahAdhanNotifId(String mosqueId, int day) =>
      _mosqueSlot(mosqueId) + 107 + day;

  static int _eidNotifId(String mosqueId, String type) =>
      _mosqueSlot(mosqueId) + (type == 'fitr' ? 114 : 115);

  // Suhoor / iftar need 30 IDs each — more than the reserved tail of the
  // 120-wide slot — so they live in dedicated global ranges (like janaza).
  // _mosqueSlot grows in steps of 120, and day < 30, so slot+day never
  // collides across mosques within a range.
  static int _suhoorNotifId(String mosqueId, int day) =>
      20000000 + _mosqueSlot(mosqueId) + day;

  static int _iftarNotifId(String mosqueId, int day) =>
      21000000 + _mosqueSlot(mosqueId) + day;

  static int _zakatNotifId(String mosqueId) =>
      22000000 + _mosqueSlot(mosqueId);

  // Loads the app's saved-locale strings for use in background notifications,
  // so Ramadan alerts are translated like the rest of the UI.
  // A single Future is stored so concurrent callers share the same load and
  // never trigger two parallel delegate.load() calls.
  static Future<AppLocalizations>? _l10nFuture;
  static Future<AppLocalizations> _l10n() {
    return _l10nFuture ??= _loadL10n();
  }

  static Future<AppLocalizations> _loadL10n() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale_code') ?? 'en';
    return AppLocalizations.delegate.load(Locale(code));
  }

  // ── Shared notification details ───────────────────────────────────────────
  // Adhan: plays adhan.mp3 from res/raw
  static AndroidNotificationDetails _adhanDetails() =>
      AndroidNotificationDetails(
        _adhanChannelId,
        'Adhan Alerts',
        channelDescription: 'Adhan time reminders with adhan sound',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('adhan'),
      );

  // Janaza: plays janaza.mp3 and shows the Quranic verse in expanded view
  static AndroidNotificationDetails _janazaDetails({
    required String label,
    required String mosqueName,
  }) =>
      AndroidNotificationDetails(
        _janazaChannelId,
        'Janaza Alerts',
        channelDescription: 'Janaza prayer reminders with recitation',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('janaza'),
        // BigTextStyle expands when the user swipes down on the notification,
        // showing the full Arabic verse + English translation.
        styleInformation: BigTextStyleInformation(
          '$_janazaArabic\n\n$_janazaTranslation\n\n$label at $mosqueName in 15 minutes.',
          contentTitle: 'Janaza — $mosqueName',
          summaryText: 'Janaza reminder',
          htmlFormatBigText: false,
        ),
      );

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    await _loadSlotsFromPrefs();

    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      debugPrint('🕐 Device timezone: $tzName');
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('✅ Timezone set to: ${tz.local.name}');
    } catch (e) {
      debugPrint('🔴 Timezone setup error: $e — defaulting to Asia/Karachi');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (e2) {
        debugPrint('🔴 Fallback also failed: $e2');
      }
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    try {
      await _notifications.initialize(
        const InitializationSettings(android: androidSettings),
      );
      _isInitialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('🔴 Notification initialization failed: $e');
    }

    // Request both permissions proactively. These are no-ops on Android
    // versions that don't need them (pre-13 for notifications, pre-12 for
    // exact alarms). Without this, zonedSchedule() silently fails on Android 12+.
    // This must happen regardless of whether init() succeeded.
    try {
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // Create channels up front so they exist with the correct sound and
        // importance, appear in the system notification settings, and don't
        // depend on the first notification's timing to be created.
        await _createChannels(androidImpl);

        final bool? notifGranted =
            await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();

        // Detect whether exact alarms are actually allowed. If not, every
        // zonedSchedule() with exactAllowWhileIdle would throw and the
        // notification would be silently dropped — so we fall back to inexact.
        _canScheduleExact =
            await androidImpl.canScheduleExactNotifications() ?? false;
        final bool? enabled = await androidImpl.areNotificationsEnabled();

        debugPrint('✅ Notifications: requested=$notifGranted '
            'enabled=$enabled exactAlarms=$_canScheduleExact');
      }
    } catch (permError) {
      debugPrint('🔴 Permission/channel setup failed: $permError');
    }
  }

  /// Picks the schedule mode based on whether the OS grants exact alarms.
  /// Falls back to inexact (which never throws) on Android 14+ where exact
  /// alarms are off by default for non-alarm apps.
  static AndroidScheduleMode _scheduleMode() => _canScheduleExact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Explicitly create every notification channel so they exist with the right
  /// importance/sound regardless of when the first notification fires, and so
  /// the user can see/toggle them in Android's system settings.
  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin androidImpl,
  ) async {
    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        _adhanChannelId,
        'Adhan Alerts',
        description: 'Adhan time reminders with adhan sound',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
      ),
      AndroidNotificationChannel(
        _janazaChannelId,
        'Janaza Alerts',
        description: 'Janaza prayer reminders with recitation',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('janaza'),
      ),
      AndroidNotificationChannel(
        _prayerChannelId,
        'Prayer Alerts',
        description: 'Reminders 5 minutes before prayer',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _taraweehChannelId,
        'Taraweeh Alerts',
        description: 'Ramadan Taraweeh reminders',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _eidChannelId,
        'Eid Alerts',
        description: 'Eid prayer reminders',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _updateChannelId,
        'Time Updates',
        description: 'When Imam changes prayer times',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _suhoorChannelId,
        'Suhoor Alerts',
        description: 'Pre-dawn suhoor reminders during Ramadan',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _iftarChannelId,
        'Iftar Alerts',
        description: 'Iftar reminders during Ramadan',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        _zakatChannelId,
        'Zakat al-Fitr',
        description: 'Reminder to give Zakat al-Fitr before Eid',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'push_alerts',
        'Push Notifications',
        description: 'Remote push notifications from mosque admin',
        importance: Importance.max,
      ),
    ];
    for (final channel in channels) {
      await androidImpl.createNotificationChannel(channel);
    }
  }

  /// Shows a push notification using the already-initialised plugin.
  /// Used by the background FCM handler to avoid creating a second
  /// uninitialized FlutterLocalNotificationsPlugin instance.
  static Future<void> showRawPush({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();
    try {
      await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'push_alerts',
            'Push Notifications',
            channelDescription: 'Remote push notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('🔴 showRawPush failed: $e');
    }
  }

  /// Fires a notification immediately so the user can confirm notifications are
  /// permitted and rendering on this device, independent of mosque data.
  static Future<void> sendTestNotification() async {
    if (!_isInitialized) await init();
    try {
      await _notifications.show(
        12345,
        'M I N A R E T',
        'Test notification — if you see this, notifications are working ✅',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _prayerChannelId,
            'Prayer Alerts',
            channelDescription: 'Reminders 5 minutes before prayer',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint('🔔 Test notification sent');
    } catch (e) {
      debugPrint('🔴 Test notification failed: $e');
    }
  }

  /// Snapshot of the notification subsystem for diagnosing
  /// "I'm not getting notifications" reports.
  static Future<Map<String, dynamic>> debugStatus() async {
    if (!_isInitialized) await init();
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final pending = await _notifications.pendingNotificationRequests();
    final status = {
      'initialized': _isInitialized,
      'osNotificationsEnabled':
          await androidImpl?.areNotificationsEnabled() ?? false,
      'canScheduleExact':
          await androidImpl?.canScheduleExactNotifications() ?? false,
      'pendingScheduledCount': pending.length,
      'prefsMasterEnabled': _notificationsEnabled,
      'prefs': _notificationPrefs,
      'watchedMosques': _mosqueListeners.keys.toList(),
      'nearestMosque': _currentNearestId,
      'timezone': tz.local.name,
    };
    debugPrint('🔍 Notification status: $status');
    return status;
  }

  // ── Entry point ───────────────────────────────────────────────────────────

  static Future<void> startForUser() async {
    if (!_isInitialized) await init();

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
      user ??= await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
    } catch (e) {
      debugPrint('🔴 startForUser: could not read currentUser — $e');
      return;
    }

    if (user == null) {
      debugPrint('🔴 startForUser: no user logged in');
      return;
    }
    if (kDebugMode) debugPrint('🟢 startForUser: authenticated');

    await cancelAllListeners();

    await Future.wait([
      _setupFollowingListener(user.uid).catchError(
          (e) => debugPrint('🔴 _setupFollowingListener error: $e')),
      _startRealtimeLocationListener().catchError(
          (e) => debugPrint('🔴 _startRealtimeLocationListener error: $e')),
    ]);
  }

  // ── Cancel everything ─────────────────────────────────────────────────────

  static Future<void> cancelAllListeners() async {
    for (final sub in _listeners) {
      await sub
          .cancel()
          .catchError((e) => debugPrint('🔴 cancel listener error: $e'));
    }
    _listeners.clear();

    for (final entry in _mosqueListeners.entries) {
      await entry.value
          ?.cancel()
          .catchError((e) => debugPrint('🔴 cancel mosque listener error: $e'));
    }
    _mosqueListeners.clear();

    await _nearestMosqueSub
        ?.cancel()
        .catchError((e) => debugPrint('🔴 cancel nearest mosque error: $e'));
    _nearestMosqueSub = null;

    await _realtimeLocationSub
        ?.cancel()
        .catchError((e) => debugPrint('🔴 cancel realtime location error: $e'));
    _realtimeLocationSub = null;

    _currentNearestId = null;
    _lastMosqueData.clear();

    // Reset per-user state so a newly signed-in user inherits safe defaults
    // rather than the previous user's disabled/enabled flags.
    _notificationsEnabled = true;
    _notificationPrefs = const {
      'janaza': true,
      'adhan': true,
      'namaz': true,
      'eid': true,
      'taraweeh': true,
      'suhoor': true,
      'iftar': true,
    };
    // Clear cached locale so the next user's locale is loaded fresh.
    _l10nFuture = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOLLOWING
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _setupFollowingListener(String userId) async {
    final sub = ServiceLocator.get<UserRepository>()
        .getUserStream(userId)
        .listen(
      (userProfile) async {
        if (userProfile == null) return;

        final followed = userProfile.followedMosques;

        // Capture previous pref state before updating so we can detect changes.
        final prevEnabled = _notificationsEnabled;
        final prevPrefs = Map<String, dynamic>.from(_notificationPrefs);

        _notificationsEnabled = userProfile.notificationsEnabled;
        _notificationPrefs =
            userProfile.notificationPrefs.isNotEmpty
                ? userProfile.notificationPrefs
                : _notificationPrefs;

        final removed = _mosqueListeners.keys
            .where((id) => !followed.contains(id))
            .toList();

        for (final id in removed) {
          await _mosqueListeners[id]?.cancel();
          _mosqueListeners.remove(id);
          _lastMosqueData.remove(id);
          await _cancelPrayerNotificationsFor(id);
        }

        for (final mosqueId in followed) {
          if (_mosqueListeners.containsKey(mosqueId)) continue;
          _mosqueListeners[mosqueId] =
              await _watchMosque(mosqueId, isFollowing: true);
        }

        // If the master switch or any individual pref changed, immediately
        // cancel and re-apply notifications for every already-watched mosque
        // using the last cached data — no need to wait for the next Firestore
        // mosque stream event.
        final prefsChanged = prevEnabled != _notificationsEnabled ||
            !_mapsEqual(prevPrefs, _notificationPrefs);
        if (prefsChanged && _lastMosqueData.isNotEmpty) {
          await _applyPrefsToAllMosques();
        }
      },
      onError: (e) => debugPrint('🔴 Following stream error: $e'),
      cancelOnError: false,
    );
    _listeners.add(sub);
  }

  /// Cancel all existing alarms and re-schedule them using the current pref
  /// state for every mosque whose data we have already seen.
  static Future<void> _applyPrefsToAllMosques() async {
    for (final entry in _lastMosqueData.entries) {
      final mosqueId = entry.key;
      final data = entry.value;
      await _cancelPrayerNotificationsFor(mosqueId);
      if (_isEnabled('namaz')) await _schedulePrayersFor(data);
      if (_isEnabled('adhan')) await _scheduleAdhanFor(data);
      if (_isEnabled('taraweeh')) await _scheduleTaraweehFor(data);
      if (_isEnabled('suhoor')) await _scheduleSuhoorFor(data);
      if (_isEnabled('iftar')) await _scheduleIftarFor(data);
      await _scheduleZakatFitrFor(data);
      if (_isEnabled('eid')) await _scheduleEidFor(data);
      if (_isEnabled('janaza')) await _scheduleJanazaFor(data);
      debugPrint('🔄 Re-applied prefs for mosque $mosqueId');
    }
  }

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REAL-TIME LOCATION & NEAREST MOSQUE
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _startRealtimeLocationListener() async {
    await _updateNearestMosque();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    _realtimeLocationSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _updateNearestMosque(currentPos: position),
      onError: (e) => debugPrint('🔴 Realtime location sub error: $e'),
    );
  }

  static Future<void> _updateNearestMosque({Position? currentPos}) async {
    try {
      final position = currentPos ?? await LocationService.getCurrentLocation();
      if (position == null) return;

      const double delta = 0.45;
      final double lat = position.latitude;
      final double lng = position.longitude;

      final mosques = await ServiceLocator.get<MosqueRepository>()
          .searchNearby(lat, lng, delta);

      if (mosques.isEmpty) return;

      Mosque? nearest;
      double minDist = double.infinity;

      for (final mosque in mosques) {
        final dist = LocationService.calculateDistance(
            lat, lng, mosque.lat, mosque.lng);

        if (dist < minDist) {
          minDist = dist;
          nearest = mosque;
        }
      }

      if (nearest == null) return;

      if (nearest.id != _currentNearestId) {
        debugPrint(
            '📍 New nearest mosque: ${nearest.id} (${minDist.toStringAsFixed(0)}m)');
        await _nearestMosqueSub?.cancel();

        if (_mosqueListeners.containsKey(nearest.id)) {
          _currentNearestId = nearest.id;
          return;
        }

        if (_currentNearestId != null &&
            !_mosqueListeners.containsKey(_currentNearestId)) {
          await _cancelPrayerNotificationsFor(_currentNearestId!);
        }

        _currentNearestId = nearest.id;
        _nearestMosqueSub =
            await _watchMosque(nearest.id, isFollowing: false);
      }
    } catch (e) {
      debugPrint('🔴 _updateNearestMosque error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE: Watch a single mosque document
  // ══════════════════════════════════════════════════════════════════════════

  static Future<StreamSubscription?> _watchMosque(
    String mosqueId, {
    required bool isFollowing,
  }) async {
    Map<String, dynamic>? lastData;

    try {
      final sub = ServiceLocator.get<MosqueRepository>()
          .getMosqueStream(mosqueId)
          .listen(
        (mosque) async {
          if (mosque == null) return;
          final newData = mosque.toScheduleMap();

          const prayers = [
            'fajr',
            'dhuhr',
            'asr',
            'maghrib',
            'isha',
            'adhanFajr',
            'adhanDhuhr',
            'adhanAsr',
            'adhanMaghrib',
            'adhanIsha',
            'jummah',
            'adhanJummah',
            'taraweeh',
            'eidFitr',
            'eidAdha',
            'eidFitrDate',
            'eidAdhaDate',
            'janazaTime',
            'janazaDate',
          ];
          final hasChanged = lastData == null ||
              prayers.any((p) => newData[p] != lastData![p]);

          if (hasChanged) {
            if (lastData != null) {
              await _showUpdateBanner(
                newData['name'] as String? ?? 'Mosque',
                isFollowing: isFollowing,
              );
            }
            await _cancelPrayerNotificationsFor(mosqueId);
            if (_isEnabled('namaz')) await _schedulePrayersFor(newData);
            if (_isEnabled('adhan')) await _scheduleAdhanFor(newData);
            if (_isEnabled('taraweeh')) await _scheduleTaraweehFor(newData);
            if (_isEnabled('suhoor')) await _scheduleSuhoorFor(newData);
            if (_isEnabled('iftar')) await _scheduleIftarFor(newData);
            await _scheduleZakatFitrFor(newData);
            if (_isEnabled('eid')) await _scheduleEidFor(newData);
            if (_isEnabled('janaza')) {
              // Only flag a *newly* posted janaza — skip on the first snapshot
              // (lastData == null), otherwise an already-existing janaza fires
              // a false "New Janaza Posted" alert on every app launch.
              if (lastData != null) {
                await _checkAndNotifyJanazaPosted(mosqueId, newData, lastData);
              }
              await _scheduleJanazaFor(newData);
            }
            lastData = Map<String, dynamic>.from(newData);
            _lastMosqueData[mosqueId] = lastData!;

            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'last_notification_scheduled',
                DateTime.now().toIso8601String(),
              );
            } catch (_) {}
          }
        },
        onError: (e) {
          debugPrint('🔴 Mosque stream error ($mosqueId): $e');
          _mosqueListeners.remove(mosqueId);
        },
        cancelOnError: false,
      );
      return sub;
    } catch (e) {
      debugPrint('🔴 _watchMosque could not start stream ($mosqueId): $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCHEDULING
  // ══════════════════════════════════════════════════════════════════════════

  static const List<String> _prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha'
  ];
  static const List<String> _adhanKeys = [
    'adhanFajr',
    'adhanDhuhr',
    'adhanAsr',
    'adhanMaghrib',
    'adhanIsha'
  ];
  static const String _jummahKey = 'jummah';
  static const String _jummahAdhanKey = 'adhanJummah';

  // ── Namaz (prayer reminder, 5 min before) ─────────────────────────────────

  static Future<void> _schedulePrayersFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';

    for (int day = 0; day < 7; day++) {
      final isFriday = _isFriday(day);

      for (int pi = 0; pi < _prayerKeys.length; pi++) {
        final prayer = _prayerKeys[pi];
        if (isFriday && prayer == 'dhuhr') continue;

        final timeStr = data[prayer] as String?;
        if (timeStr == null || timeStr == '--:--' || timeStr.isEmpty) continue;

        final prayerTime = _parseTime(prayer, timeStr).add(Duration(days: day));
        final scheduledTime = prayerTime.subtract(const Duration(minutes: 5));
        if (scheduledTime.isBefore(DateTime.now())) continue;

        final id = _prayerNotifId(mosqueId, pi, day);

        try {
          await _notifications.zonedSchedule(
            id,
            'M I N A R E T',
            'Namaz (${prayer.toUpperCase()}) at ${data['name'] ?? 'your mosque'} in 5 minutes.',
            tz.TZDateTime.from(scheduledTime, tz.local),
            NotificationDetails(
              android: AndroidNotificationDetails(
                _prayerChannelId,
                'Prayer Alerts',
                channelDescription: 'Reminders 5 minutes before prayer',
                importance: Importance.max,
                priority: Priority.high,
                showWhen: true,
              ),
            ),
            androidScheduleMode: _scheduleMode(),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('🔴 Failed scheduling prayer: $e');
        }
      }

      // Jummah replaces Dhuhr on Fridays
      if (isFriday) {
        final jummahTimeStr = data[_jummahKey] as String?;
        if (jummahTimeStr != null &&
            jummahTimeStr != '--:--' &&
            jummahTimeStr.isNotEmpty) {
          final jummahTime =
              _parseTime(_jummahKey, jummahTimeStr).add(Duration(days: day));
          final jummahScheduledTime =
              jummahTime.subtract(const Duration(minutes: 5));
          if (!jummahScheduledTime.isBefore(DateTime.now())) {
            final jummahId = _jummahNotifId(mosqueId, day);
            try {
              await _notifications.zonedSchedule(
                jummahId,
                'M I N A R E T',
                'Jummah Prayer at ${data['name'] ?? 'your mosque'} in 5 minutes.',
                tz.TZDateTime.from(jummahScheduledTime, tz.local),
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    _prayerChannelId,
                    'Prayer Alerts',
                    channelDescription: 'Reminders 5 minutes before prayer',
                    importance: Importance.max,
                    priority: Priority.high,
                    showWhen: true,
                  ),
                ),
                androidScheduleMode: _scheduleMode(),
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
            } catch (e) {
              debugPrint('🔴 Failed scheduling jummah: $e');
            }
          }
        }
      }
    }
  }

  static bool _isFriday(int dayOffset) {
    final targetDate = DateTime.now().add(Duration(days: dayOffset));
    return targetDate.weekday == DateTime.friday;
  }

  // ── Adhan (plays adhan.mp3) ───────────────────────────────────────────────

  static Future<void> _scheduleAdhanFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';

    for (int day = 0; day < 7; day++) {
      final isFriday = _isFriday(day);

      for (int ai = 0; ai < _adhanKeys.length; ai++) {
        final key = _adhanKeys[ai];
        if (isFriday && key == 'adhanDhuhr') continue;

        final timeStr = data[key] as String?;
        if (timeStr == null || timeStr.trim().isEmpty || timeStr == '--:--') {
          continue;
        }

        final adhanTime = _parseTime(key, timeStr).add(Duration(days: day));
        if (adhanTime.isBefore(DateTime.now())) continue;

        final id = _adhanNotifId(mosqueId, ai, day);
        final prayerName = key.replaceFirst('adhan', '').toUpperCase();

        try {
          await _notifications.zonedSchedule(
            id,
            'M I N A R E T',
            'Adhan for $prayerName now at ${data['name'] ?? 'your mosque'}.',
            tz.TZDateTime.from(adhanTime, tz.local),
            // ← Adhan sound channel
            NotificationDetails(android: _adhanDetails()),
            androidScheduleMode: _scheduleMode(),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('🔴 Failed scheduling adhan: $e');
        }
      }

      // Jummah adhan on Fridays
      if (isFriday) {
        final jummahAdhanTimeStr = data[_jummahAdhanKey] as String?;
        final fallbackTimeStr = data[_jummahKey] as String?;
        final resolvedTimeStr = (jummahAdhanTimeStr != null &&
                jummahAdhanTimeStr != '--:--' &&
                jummahAdhanTimeStr.isNotEmpty)
            ? jummahAdhanTimeStr
            : fallbackTimeStr;

        if (resolvedTimeStr != null &&
            resolvedTimeStr != '--:--' &&
            resolvedTimeStr.isNotEmpty) {
          final jummahAdhanTime = _parseTime(_jummahAdhanKey, resolvedTimeStr)
              .add(Duration(days: day));
          if (!jummahAdhanTime.isBefore(DateTime.now())) {
            final jummahAdhanId = _jummahAdhanNotifId(mosqueId, day);
            try {
              await _notifications.zonedSchedule(
                jummahAdhanId,
                'M I N A R E T',
                'Jummah Prayer now at ${data['name'] ?? 'your mosque'}.',
                tz.TZDateTime.from(jummahAdhanTime, tz.local),
                // ← Adhan sound channel
                NotificationDetails(android: _adhanDetails()),
                androidScheduleMode: _scheduleMode(),
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
            } catch (e) {
              debugPrint('🔴 Failed scheduling jummah adhan: $e');
            }
          }
        }
      }
    }
  }

  // ── Taraweeh (Ramadan only) ───────────────────────────────────────────────

  static Future<void> _scheduleTaraweehFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    final timeStr = data['taraweeh'] as String?;
    if (timeStr == null || timeStr.trim().isEmpty || timeStr == '--:--') return;

    final isRamadanFlag = data['isRamadan'] as bool?;
    final bool isRamadan = isRamadanFlag ?? _isLikelyRamadan();

    if (!isRamadan) {
      debugPrint('⏭️ Skipping Taraweeh — not Ramadan');
      return;
    }

    for (int day = 0; day < 30; day++) {
      final prayerTime =
          _parseTime('taraweeh', timeStr).add(Duration(days: day));
      final scheduledTime = prayerTime.subtract(const Duration(minutes: 30));
      if (scheduledTime.isBefore(DateTime.now())) continue;

      final id = _taraweehNotifId(mosqueId, day);

      try {
        await _notifications.zonedSchedule(
          id,
          'M I N A R E T',
          'Taraweeh tonight at ${data['name'] ?? 'your mosque'} in 30 minutes.',
          tz.TZDateTime.from(scheduledTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _taraweehChannelId,
              'Taraweeh Alerts',
              channelDescription: 'Ramadan Taraweeh reminders',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: _scheduleMode(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('🔴 Failed scheduling taraweeh: $e');
      }
    }
  }

  // ── Suhoor ────────────────────────────────────────────────────────────────
  // A pre-dawn wake/warning fired 45 min before Fajr (suhoor ends at Fajr).
  static Future<void> _scheduleSuhoorFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    final timeStr = data['fajr'] as String?;
    if (timeStr == null || timeStr.trim().isEmpty || timeStr == '--:--') return;

    final bool isRamadan = (data['isRamadan'] as bool?) ?? _isLikelyRamadan();
    if (!isRamadan) return;

    const int warnMinutes = 45;
    final l10n = await _l10n();

    for (int day = 0; day < 30; day++) {
      final fajr = _parseTime('fajr', timeStr).add(Duration(days: day));
      final scheduledTime = fajr.subtract(const Duration(minutes: warnMinutes));
      if (scheduledTime.isBefore(DateTime.now())) continue;

      try {
        await _notifications.zonedSchedule(
          _suhoorNotifId(mosqueId, day),
          'M I N A R E T',
          l10n.ramadanSuhoorNotif(warnMinutes),
          tz.TZDateTime.from(scheduledTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _suhoorChannelId,
              'Suhoor Alerts',
              channelDescription: 'Pre-dawn suhoor reminders during Ramadan',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: _scheduleMode(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('🔴 Failed scheduling suhoor: $e');
      }
    }
  }

  // ── Iftar ─────────────────────────────────────────────────────────────────
  // Two alerts per day: a 15-min warning, then the iftar moment at Maghrib.
  static Future<void> _scheduleIftarFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    final timeStr = data['maghrib'] as String?;
    if (timeStr == null || timeStr.trim().isEmpty || timeStr == '--:--') return;

    final bool isRamadan = (data['isRamadan'] as bool?) ?? _isLikelyRamadan();
    if (!isRamadan) return;

    const int warnMinutes = 15;
    final l10n = await _l10n();
    final now = DateTime.now();

    for (int day = 0; day < 30; day++) {
      final maghrib = _parseTime('maghrib', timeStr).add(Duration(days: day));
      final warnTime = maghrib.subtract(const Duration(minutes: warnMinutes));

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _iftarChannelId,
          'Iftar Alerts',
          channelDescription: 'Iftar reminders during Ramadan',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      );

      // Pre-iftar warning.
      if (warnTime.isAfter(now)) {
        try {
          await _notifications.zonedSchedule(
            _iftarNotifId(mosqueId, day),
            'M I N A R E T',
            l10n.ramadanIftarSoonNotif(warnMinutes),
            tz.TZDateTime.from(warnTime, tz.local),
            details,
            androidScheduleMode: _scheduleMode(),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('🔴 Failed scheduling iftar warning: $e');
        }
      }

      // Iftar moment (offset by +30 in the same range to keep a distinct ID).
      if (maghrib.isAfter(now)) {
        try {
          await _notifications.zonedSchedule(
            _iftarNotifId(mosqueId, day + 30),
            'M I N A R E T',
            l10n.ramadanIftarNowNotif,
            tz.TZDateTime.from(maghrib, tz.local),
            details,
            androidScheduleMode: _scheduleMode(),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('🔴 Failed scheduling iftar: $e');
        }
      }
    }
  }

  // ── Zakat al-Fitr ───────────────────────────────────────────────────────────
  // One-shot reminder the day before the Eid al-Fitr prayer, if the mosque has
  // published an Eid date.
  static Future<void> _scheduleZakatFitrFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    final dateStr = data['eidFitrDate'] as String?;
    if (dateStr == null || dateStr.trim().isEmpty) return;

    DateTime? eidDate;
    try {
      eidDate = DateFormat('yyyy-MM-dd').parse(dateStr.trim());
    } catch (_) {
      eidDate = DateTime.tryParse(dateStr.trim());
    }
    if (eidDate == null) return;

    // 10:00 the morning before Eid.
    final remindAt =
        DateTime(eidDate.year, eidDate.month, eidDate.day, 10).subtract(const Duration(days: 1));
    if (remindAt.isBefore(DateTime.now())) return;

    final l10n = await _l10n();
    try {
      await _notifications.zonedSchedule(
        _zakatNotifId(mosqueId),
        'M I N A R E T',
        l10n.ramadanZakatReminder,
        tz.TZDateTime.from(remindAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _zakatChannelId,
            'Zakat al-Fitr',
            channelDescription: 'Reminder to give Zakat al-Fitr before Eid',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('🔴 Failed scheduling zakat reminder: $e');
    }
  }

  /// Rough Ramadan check based on Gregorian calendar heuristic.
  /// Prefer storing an `isRamadan` bool in Firestore and toggling from admin.
  static bool _isLikelyRamadan() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final day = now.day;

    final Map<int, ({int startMonth, int startDay, int endMonth, int endDay})>
        ramadanDates = {
      2025: (startMonth: 3, startDay: 1, endMonth: 3, endDay: 30),
      2026: (startMonth: 2, startDay: 18, endMonth: 3, endDay: 19),
      2027: (startMonth: 2, startDay: 8, endMonth: 3, endDay: 8),
      2028: (startMonth: 1, startDay: 28, endMonth: 2, endDay: 26),
      2029: (startMonth: 1, startDay: 17, endMonth: 2, endDay: 15),
      2030: (startMonth: 1, startDay: 6, endMonth: 2, endDay: 4),
      // 2031 Ramadan starts Dec 26 2030 — the Jan–Jan portion is captured here.
      // For the Dec 2030 window, set 2030 endDay further or handle via Firestore toggle.
      2031: (startMonth: 1, startDay: 1, endMonth: 1, endDay: 24),
      2032: (startMonth: 12, startDay: 15, endMonth: 12, endDay: 31),
      2033: (startMonth: 12, startDay: 5, endMonth: 12, endDay: 31),
    };

    final r = ramadanDates[year];
    if (r == null) return false;

    final start = DateTime(year, r.startMonth, r.startDay);
    final end = DateTime(year, r.endMonth, r.endDay);
    final today = DateTime(year, month, day);

    return !today.isBefore(start) && !today.isAfter(end);
  }

  // ── Eid ───────────────────────────────────────────────────────────────────

  static Future<void> _scheduleEidFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    await _scheduleSingleEid(
      mosqueId: mosqueId,
      mosqueName: data['name']?.toString() ?? 'your mosque',
      eventKey: 'eidFitr',
      dateStr: data['eidFitrDate'] as String?,
      timeStr: data['eidFitr'] as String?,
      label: 'Eid al-Fitr',
    );
    await _scheduleSingleEid(
      mosqueId: mosqueId,
      mosqueName: data['name']?.toString() ?? 'your mosque',
      eventKey: 'eidAdha',
      dateStr: data['eidAdhaDate'] as String?,
      timeStr: data['eidAdha'] as String?,
      label: 'Eid al-Adha',
    );
  }

  static Future<void> _scheduleSingleEid({
    required String mosqueId,
    required String mosqueName,
    required String eventKey,
    required String? dateStr,
    required String? timeStr,
    required String label,
  }) async {
    if (dateStr == null ||
        dateStr.trim().isEmpty ||
        timeStr == null ||
        timeStr.trim().isEmpty ||
        timeStr == '--:--') {
      return;
    }

    try {
      final date = DateTime.parse(dateStr.trim());
      final parsed = _parseTime(eventKey, timeStr);
      final eventDateTime =
          DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
      if (eventDateTime.isBefore(DateTime.now())) return;

      final id =
          _eidNotifId(mosqueId, eventKey.contains('Fitr') ? 'fitr' : 'adha');

      await _notifications.zonedSchedule(
        id,
        'M I N A R E T',
        '$label prayer at $mosqueName tomorrow.',
        tz.TZDateTime.from(
            eventDateTime.subtract(const Duration(days: 1)), tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _eidChannelId,
            'Eid Alerts',
            channelDescription: 'Eid prayer reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('🔴 Error scheduling Eid: $e');
    }
  }

  // ── Janaza immediate alert (when newly posted) ────────────────────────────
  // Detects when janaza is first posted and sends immediate alert.
  static Future<void> _checkAndNotifyJanazaPosted(
    String mosqueId,
    Map<String, dynamic> newData,
    Map<String, dynamic>? lastData,
  ) async {
    final newJanazaTime = newData['janazaTime'] as String?;
    final newJanazaDate = newData['janazaDate'] as String?;

    if (newJanazaTime == null || newJanazaTime.isEmpty || newJanazaTime == '--:--') {
      return;
    }

    final lastJanazaTime = lastData?['janazaTime'] as String?;
    final lastJanazaDate = lastData?['janazaDate'] as String?;

    final isNewJanaza = lastJanazaTime != newJanazaTime ||
                        lastJanazaDate != newJanazaDate;

    if (!isNewJanaza) return;

    try {
      final label = newData['janazaLabel'] as String? ?? 'Janaza prayer';
      final mosqueName = newData['name']?.toString() ?? 'your mosque';

      DateTime baseDate;
      final dateStr = newJanazaDate;
      if (dateStr != null && dateStr.trim().isNotEmpty) {
        baseDate = DateTime.parse(dateStr.trim());
      } else {
        baseDate = DateTime.now();
      }

      final parsed = _parseTime('janazaTime', newJanazaTime);
      final janazaDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsed.hour,
        parsed.minute,
      );

      if (janazaDateTime.isBefore(DateTime.now())) {
        debugPrint('⏭️ Janaza already passed, skipping immediate alert');
        return;
      }

      final timeUntilJanaza = janazaDateTime.difference(DateTime.now());
      final hours = timeUntilJanaza.inHours;
      final minutes = timeUntilJanaza.inMinutes % 60;

      String timeStr;
      if (hours > 0) {
        timeStr = 'in $hours hour${hours == 1 ? '' : 's'} ${minutes}m';
      } else {
        timeStr = 'in $minutes minutes';
      }

      final id = ('$mosqueId-janaza-posted-${janazaDateTime.toIso8601String()}')
                  .hashCode
                  .abs() %
              1000000 +
          10000001;

      await _notifications.show(
        id,
        '🕌 New Janaza Posted',
        '$label at $mosqueName — $timeStr',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _janazaChannelId,
            'Janaza Alerts',
            channelDescription: 'Janaza prayer reminders',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('janaza'),
          ),
        ),
      );

      debugPrint('🔔 Immediate janaza alert sent for $mosqueName: $label');
    } catch (e) {
      debugPrint('🔴 Error sending immediate janaza alert: $e');
    }
  }

  // ── Janaza (plays janaza.mp3 + shows Quranic verse) ──────────────────────
  //
  // Firestore fields expected on the mosque document:
  //   janazaTime  : "14:30"          — next janaza time (24h)
  //   janazaDate  : "2025-04-15"     — optional; defaults to today
  //   janazaLabel : "Janaza for …"   — optional display name
  //
  // The notification plays janaza.mp3 (place in res/raw/) and shows:
  //   Title : إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ
  //   Body  : (collapsed) label + mosque + "in 15 minutes"
  //   Body  : (expanded)  Arabic verse + English translation + details

  static Future<void> _scheduleJanazaFor(Map<String, dynamic> data) async {
    final mosqueId = data['_docId'] as String? ?? '';
    final timeStr = data['janazaTime'] as String?;
    if (timeStr == null || timeStr.trim().isEmpty || timeStr == '--:--') return;

    try {
      final dateStr = data['janazaDate'] as String?;
      final label = data['janazaLabel'] as String? ?? 'Janaza prayer';
      final mosqueName = data['name']?.toString() ?? 'your mosque';

      DateTime baseDate;
      if (dateStr != null && dateStr.trim().isNotEmpty) {
        baseDate = DateTime.parse(dateStr.trim());
      } else {
        baseDate = DateTime.now();
      }

      final parsed = _parseTime('janazaTime', timeStr);
      final janazaDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsed.hour,
        parsed.minute,
      );

      // Notify 15 minutes before janaza
      final scheduledTime =
          janazaDateTime.subtract(const Duration(minutes: 15));
      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint('⏭️ Janaza time already passed, skipping');
        return;
      }

      final id = ('$mosqueId-janaza-${janazaDateTime.toIso8601String()}')
                  .hashCode
                  .abs() %
              1000000 +
          10000000;

      await _notifications.zonedSchedule(
        id,
        // Title: the Arabic verse so it's the first thing the user reads
        _janazaArabic,
        // Collapsed body: simple reminder line
        '$label at $mosqueName in 15 minutes.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        // ← Janaza sound channel with BigText expanded view
        NotificationDetails(
          android: _janazaDetails(label: label, mosqueName: mosqueName),
        ),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('🕌 Janaza scheduled at $scheduledTime for $mosqueName');
    } catch (e) {
      debugPrint('🔴 Error scheduling Janaza: $e');
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> _cancelPrayerNotificationsFor(String mosqueId) async {
    final slot = _mosqueSlot(mosqueId);
    // 0–113 covers namaz, adhan, taraweeh, jummah prayer, jummah adhan.
    // Eid (114, 115) is cancelled separately below.
    for (int i = 0; i < 114; i++) {
      await _notifications.cancel(slot + i);
    }
    await _notifications.cancel(_eidNotifId(mosqueId, 'fitr'));
    await _notifications.cancel(_eidNotifId(mosqueId, 'adha'));

    // Ramadan suhoor (30) / iftar (warning 0–29 + moment 30–59) / zakat (1).
    for (int day = 0; day < 30; day++) {
      await _notifications.cancel(_suhoorNotifId(mosqueId, day));
    }
    for (int day = 0; day < 60; day++) {
      await _notifications.cancel(_iftarNotifId(mosqueId, day));
    }
    await _notifications.cancel(_zakatNotifId(mosqueId));
  }

  // ── Update banner ─────────────────────────────────────────────────────────

  static Future<void> _showUpdateBanner(
    String mosqueName, {
    required bool isFollowing,
  }) async {
    final label = isFollowing ? 'FOLLOWING' : 'NEAREST MOSQUE';
    await _notifications.show(
      999,
      'SCHEDULE UPDATED',
      '$label · $mosqueName has changed prayer times.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _updateChannelId,
          'Time Updates',
          channelDescription: 'When Imam changes prayer times',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isEnabled(String key) {
    if (!_notificationsEnabled) return false;
    return _notificationPrefs[key] != false;
  }

  static DateTime _parseTime(String key, String timeStr) {
    final now = DateTime.now();
    try {
      final cleaned = timeStr.trim();
      DateTime parsed;
      if (cleaned.toUpperCase().contains('AM') ||
          cleaned.toUpperCase().contains('PM')) {
        try {
          parsed = DateFormat('h:mm a').parse(cleaned);
        } catch (_) {
          try {
            parsed = DateFormat('hh:mm a').parse(cleaned);
          } catch (_) {
            parsed = DateFormat.jm().parse(cleaned);
          }
        }
      } else {
        parsed = DateFormat('HH:mm').parse(cleaned);
      }
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      debugPrint('🔴 _parseTime failed for $key "$timeStr": $e');
      return now;
    }
  }
}
