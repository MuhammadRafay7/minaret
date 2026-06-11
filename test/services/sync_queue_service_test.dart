import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:minaret/services/sync_queue.dart';
import 'package:minaret/services/connectivity_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockConnectivityService extends Mock implements ConnectivityService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Pump the Dart event queue enough times to let multiple async chains complete.
Future<void> _settle() => pumpEventQueue(times: 100);

Future<Box> _openBox() async {
  if (!Hive.isBoxOpen('minaret_sync_queue')) {
    await Hive.openBox('minaret_sync_queue');
  }
  return Hive.box('minaret_sync_queue');
}

Future<void> _clearBox() async {
  final box = await _openBox();
  await box.clear();
}

/// Directly seeds an entry into the Hive box bypassing SyncQueue.enqueue,
/// useful for testing backoff / failure-count edge cases.
Future<void> _seedEntry({
  required String type,
  required Map<String, dynamic> payload,
  int failureCount = 0,
  int nextRetryAt = 0,
}) async {
  final box = await _openBox();
  await box.add(<String, dynamic>{
    'type': type,
    'payload': payload,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'failureCount': failureCount,
    'nextRetryAt': nextRetryAt,
  });
}

/// Triggers processing on [queue] via a mock connectivity signal and waits
/// for the async processing chain to settle.
Future<void> _triggerProcessing(
  SyncQueue queue,
  StreamController<bool> ctrl,
  MockConnectivityService conn,
) async {
  ctrl.add(true);
  await _settle();
}

// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('sync_queue_test_');
    Hive.init(tempDir.path);
    await SyncQueue.initStorage();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await _clearBox();
  });

  // =========================================================================
  // enqueue
  // =========================================================================

  group('enqueue', () {
    test('adds entry to the Hive box', () async {
      final queue = SyncQueue();
      await queue.enqueue('mosque_follow', {'mosqueId': 'abc'});

      final box = await _openBox();
      expect(box.length, 1);
    });

    test('stored entry has type and payload fields', () async {
      final queue = SyncQueue();
      await queue.enqueue('mosque_unfollow', {'mosqueId': 'xyz'});

      final box = await _openBox();
      final entry = Map<String, dynamic>.from(box.values.first as Map);
      expect(entry['type'], 'mosque_unfollow');
      expect((entry['payload'] as Map)['mosqueId'], 'xyz');
    });

    test('new entry has failureCount=0 and nextRetryAt=0', () async {
      final queue = SyncQueue();
      await queue.enqueue('op', {});

      final box = await _openBox();
      final entry = Map<String, dynamic>.from(box.values.first as Map);
      expect(entry['failureCount'], 0);
      expect(entry['nextRetryAt'], 0);
    });

    test('stores createdAt timestamp', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final queue = SyncQueue();
      await queue.enqueue('op', {});
      final after = DateTime.now().millisecondsSinceEpoch;

      final box = await _openBox();
      final ts = (box.values.first as Map)['createdAt'] as int;
      expect(ts, greaterThanOrEqualTo(before));
      expect(ts, lessThanOrEqualTo(after));
    });

    test('multiple enqueues preserve insertion order', () async {
      final queue = SyncQueue();
      await queue.enqueue('op_1', {'i': 1});
      await queue.enqueue('op_2', {'i': 2});
      await queue.enqueue('op_3', {'i': 3});

      final box = await _openBox();
      final types = box.values.map((e) => (e as Map)['type'] as String).toList();
      expect(types, ['op_1', 'op_2', 'op_3']);
    });
  });

  // =========================================================================
  // Processing — happy path
  // =========================================================================

  group('processing — successful execution', () {
    test('entry is removed from box after executor succeeds', () async {
      final queue = SyncQueue();
      SyncQueue.registerExecutor('succ_follow', (_) async {});

      await queue.enqueue('succ_follow', {'mosqueId': 'abc'});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      final box = await _openBox();
      expect(box.length, 0);

      await ctrl.close();
      queue.dispose();
    });

    test('executor receives the correct payload', () async {
      final queue = SyncQueue();
      Map<String, dynamic>? received;

      SyncQueue.registerExecutor('payload_check', (p) async {
        received = p;
      });

      await queue.enqueue('payload_check', {'key': 'value', 'num': 42});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      expect(received, isNotNull);
      expect(received!['key'], 'value');
      expect(received!['num'], 42);

      await ctrl.close();
      queue.dispose();
    });

    test('all entries processed in order when all succeed', () async {
      final queue = SyncQueue();
      final order = <int>[];

      SyncQueue.registerExecutor('ordered_op', (p) async {
        order.add(p['i'] as int);
      });

      await queue.enqueue('ordered_op', {'i': 1});
      await queue.enqueue('ordered_op', {'i': 2});
      await queue.enqueue('ordered_op', {'i': 3});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      expect(order, [1, 2, 3]);
      final box = await _openBox();
      expect(box.length, 0);

      await ctrl.close();
      queue.dispose();
    });

    test('immediately processes queue when already online at startListening', () async {
      final queue = SyncQueue();
      var called = false;

      SyncQueue.registerExecutor('imm_op', (_) async { called = true; });

      await queue.enqueue('imm_op', {});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(true); // already online

      queue.startListening(conn);
      await _settle();

      expect(called, isTrue);

      await ctrl.close();
      queue.dispose();
    });
  });

  // =========================================================================
  // Processing — failure handling (exponential backoff)
  // =========================================================================

  group('processing — exponential backoff on failure', () {
    test('failed entry has failureCount incremented to 1', () async {
      final queue = SyncQueue();
      SyncQueue.registerExecutor('fail_once', (_) async {
        throw Exception('network error');
      });

      await queue.enqueue('fail_once', {});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      final box = await _openBox();
      // Entry stays in box, not removed
      expect(box.length, 1);
      final entry = Map<String, dynamic>.from(box.values.first as Map);
      expect(entry['failureCount'], 1);
    });

    test('failed entry has nextRetryAt set to a future timestamp', () async {
      final queue = SyncQueue();
      SyncQueue.registerExecutor('fail_backoff', (_) async {
        throw Exception('network error');
      });

      await queue.enqueue('fail_backoff', {});

      final before = DateTime.now().millisecondsSinceEpoch;

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      final box = await _openBox();
      final entry = Map<String, dynamic>.from(box.values.first as Map);
      final nextRetry = entry['nextRetryAt'] as int;

      // nextRetryAt must be after the current time (backoff applied)
      expect(nextRetry, greaterThan(before));
    });

    test('processing continues past a failing entry to succeeding ones', () async {
      final queue = SyncQueue();
      final executed = <int>[];

      SyncQueue.registerExecutor('mixed_op', (p) async {
        final i = p['i'] as int;
        if (i == 2) throw Exception('fails');
        executed.add(i);
      });

      await queue.enqueue('mixed_op', {'i': 1}); // succeeds
      await queue.enqueue('mixed_op', {'i': 2}); // fails
      await queue.enqueue('mixed_op', {'i': 3}); // succeeds

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      // Items 1 and 3 are processed; 2 gets backoff and stays in box
      expect(executed, containsAll([1, 3]));
      expect(executed, isNot(contains(2)));

      final box = await _openBox();
      expect(box.length, 1); // only item 2 remains
      final remaining = Map<String, dynamic>.from(box.values.first as Map);
      expect((remaining['payload'] as Map)['i'], 2);

      await ctrl.close();
      queue.dispose();
    });

    test('entry in backoff window is skipped on subsequent processing pass', () async {
      final queue = SyncQueue();
      final executed = <String>[];

      SyncQueue.registerExecutor('backoff_op', (p) async {
        executed.add(p['id'] as String);
      });

      // Seed entry with nextRetryAt = far future
      final futureMs = DateTime.now().millisecondsSinceEpoch + 60000; // 60s from now
      await _seedEntry(
        type: 'backoff_op',
        payload: {'id': 'should_skip'},
        failureCount: 1,
        nextRetryAt: futureMs,
      );

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      // Executor should NOT have been called — entry is in backoff window
      expect(executed, isEmpty);

      // Entry should still be in the box
      final box = await _openBox();
      expect(box.length, 1);

      await ctrl.close();
      queue.dispose();
    });

    test('entry with failureCount=5 is dropped on next processing pass', () async {
      final queue = SyncQueue();
      SyncQueue.registerExecutor('abandoned_op', (_) async {
        throw Exception('always fails');
      });

      // Seed entry already at max failures — should be dropped immediately
      await _seedEntry(
        type: 'abandoned_op',
        payload: {'id': 'doomed'},
        failureCount: 5,
        nextRetryAt: 0, // not in backoff
      );

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      // Entry is dropped — box should be empty
      final box = await _openBox();
      expect(box.length, 0);

      await ctrl.close();
      queue.dispose();
    });
  });

  // =========================================================================
  // Unregistered executor
  // =========================================================================

  group('unregistered executor', () {
    test('entry with no executor is dropped and processing continues to next entry',
        () async {
      final queue = SyncQueue();
      final executed = <String>[];

      SyncQueue.registerExecutor('known_op_2', (p) async {
        executed.add(p['id'] as String);
      });

      await queue.enqueue('totally_unknown_op_xyz', {'id': 'drop_me'});
      await queue.enqueue('known_op_2', {'id': 'keep_me'});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      await _triggerProcessing(queue, ctrl, conn);

      expect(executed, ['keep_me']);

      final box = await _openBox();
      expect(box.length, 0);

      await ctrl.close();
      queue.dispose();
    });
  });

  // =========================================================================
  // Re-entrancy guard
  // =========================================================================

  group('re-entrancy guard', () {
    test('a second online signal while processing is active does not re-enter',
        () async {
      final queue = SyncQueue();
      var callCount = 0;
      final completer = Completer<void>();

      SyncQueue.registerExecutor('slow_op_2', (_) async {
        callCount++;
        await completer.future; // block until released
      });

      await queue.enqueue('slow_op_2', {});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);

      ctrl.add(true);
      ctrl.add(true); // second signal while first is still running
      await pumpEventQueue(times: 10);

      expect(callCount, 1, reason: 'Executor was called more than once');

      completer.complete();
      await _settle();

      await ctrl.close();
      queue.dispose();
    });
  });

  // =========================================================================
  // dispose
  // =========================================================================

  group('dispose', () {
    test('connectivity subscription is cancelled after dispose', () async {
      final queue = SyncQueue();
      var processed = false;

      SyncQueue.registerExecutor('disp_op', (_) async { processed = true; });

      await queue.enqueue('disp_op', {});

      final ctrl = StreamController<bool>.broadcast();
      final conn = MockConnectivityService();
      when(() => conn.onlineStream).thenAnswer((_) => ctrl.stream);
      when(() => conn.isOnline).thenReturn(false);

      queue.startListening(conn);
      queue.dispose(); // cancel before any signal

      ctrl.add(true);
      await _settle();

      expect(processed, isFalse);
      await ctrl.close();
    });
  });

  // =========================================================================
  // initStorage
  // =========================================================================

  group('initStorage', () {
    test('is idempotent — calling twice does not throw', () async {
      await expectLater(SyncQueue.initStorage(), completes);
      await expectLater(SyncQueue.initStorage(), completes);
    });
  });
}
