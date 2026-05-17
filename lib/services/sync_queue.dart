import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'connectivity_service.dart';

/// Persistent write-operation queue. Stores failed writes in Hive and replays
/// them when connectivity is restored.
///
/// Operation types and their execution logic are registered via
/// [registerExecutor] — typically in app_repositories.dart. This keeps
/// SyncQueue free of direct repository imports.
///
/// Retry policy: exponential backoff (5s → 30s → 2m → 10m → 1h max) with
/// ±20% random jitter. After [_maxFailures] consecutive failures the entry is
/// dropped and the error is logged to Crashlytics.
class SyncQueue {
  static const _boxName = 'minaret_sync_queue';
  static const int _maxFailures = 5;

  // Backoff schedule. Index == (failureCount - 1), capped at last element.
  static const List<Duration> _backoffSchedule = [
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
    Duration(hours: 1),
  ];

  static final Map<String, Future<void> Function(Map<String, dynamic>)>
      _executors = {};

  StreamSubscription<bool>? _connectivitySub;
  bool _processing = false;

  // ── Storage init ──────────────────────────────────────────────────────────

  static Future<void> initStorage() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  Box get _box => Hive.box(_boxName);

  // ── Executor registry ─────────────────────────────────────────────────────

  static void registerExecutor(
    String type,
    Future<void> Function(Map<String, dynamic> payload) executor,
  ) {
    _executors[type] = executor;
  }

  // ── Connectivity wiring ───────────────────────────────────────────────────

  void startListening(ConnectivityService connectivity) {
    _connectivitySub?.cancel();
    _connectivitySub = connectivity.onlineStream.listen((online) {
      if (online) _processQueue();
    });
    if (connectivity.isOnline) _processQueue();
  }

  // ── Enqueue ───────────────────────────────────────────────────────────────

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    await _box.add(<String, dynamic>{
      'type': type,
      'payload': payload,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'failureCount': 0,
      'nextRetryAt': 0,
    });
    debugPrint('SyncQueue: enqueued $type → ${_box.length} pending');
  }

  // ── Process ───────────────────────────────────────────────────────────────

  Future<void> _processQueue() async {
    if (_processing || _box.isEmpty) return;
    _processing = true;
    debugPrint('SyncQueue: processing ${_box.length} entries');

    try {
      for (final key in _box.keys.toList()) {
        final raw = _box.get(key);
        if (raw == null) continue;

        final entry = Map<String, dynamic>.from(raw as Map);
        final type = entry['type'] as String;
        final failureCount = (entry['failureCount'] as int?) ?? 0;
        final nextRetryAt = (entry['nextRetryAt'] as int?) ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Drop permanently failed entries and log to Crashlytics.
        if (failureCount >= _maxFailures) {
          debugPrint(
              'SyncQueue: dropping "$type" after $_maxFailures failures');
          await _reportAbandoned(type, entry);
          await _box.delete(key);
          continue;
        }

        // Skip entries that are still in their backoff window.
        if (nextRetryAt > nowMs) {
          debugPrint(
              'SyncQueue: "$type" in backoff, retry in '
              '${(nextRetryAt - nowMs) ~/ 1000}s');
          continue;
        }

        final payload =
            Map<String, dynamic>.from(entry['payload'] as Map);
        final executor = _executors[type];

        if (executor == null) {
          debugPrint('SyncQueue: no executor for "$type" — dropping');
          await _box.delete(key);
          continue;
        }

        try {
          await executor(payload);
          await _box.delete(key);
          debugPrint('SyncQueue: completed "$type"');
        } catch (e, st) {
          final nextCount = failureCount + 1;
          final delay = _jitteredBackoff(nextCount);
          final retryAt = nowMs + delay.inMilliseconds;

          debugPrint(
              'SyncQueue: "$type" failed ($e) — attempt $nextCount/$_maxFailures, '
              'retry in ${delay.inSeconds}s');

          await _box.put(key, <String, dynamic>{
            ...entry,
            'failureCount': nextCount,
            'nextRetryAt': retryAt,
          });

          if (nextCount >= _maxFailures) {
            await _reportAbandoned(type, entry, e, st);
          }
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ── Backoff helpers ───────────────────────────────────────────────────────

  Duration _jitteredBackoff(int failureCount) {
    final idx = (failureCount - 1).clamp(0, _backoffSchedule.length - 1);
    final base = _backoffSchedule[idx].inMilliseconds;
    // ±20% uniform jitter
    final jitter = (math.Random().nextDouble() * 0.4 - 0.2);
    return Duration(milliseconds: (base * (1.0 + jitter)).round());
  }

  Future<void> _reportAbandoned(
    String type,
    Map<String, dynamic> entry, [
    Object? error,
    StackTrace? st,
  ]) async {
    final message = 'SyncQueue: abandoned "$type" after $_maxFailures failures'
        '${error != null ? " — last error: $error" : ""}';
    try {
      await FirebaseCrashlytics.instance.recordError(
        error ?? message,
        st,
        reason: message,
        fatal: false,
      );
    } catch (crashlyticsError) {
      debugPrint('SyncQueue: Crashlytics.recordError failed: $crashlyticsError');
    }
  }

  void dispose() => _connectivitySub?.cancel();
}
