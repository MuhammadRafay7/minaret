import 'dart:async';
import 'package:flutter/foundation.dart';
import '../errors/app_error.dart';

/// Abstract base for all page-level notifiers.
///
/// Provides:
///   • [isLoading] / [error] state managed by [runAsync].
///   • [listenToStream] — stores [StreamSubscription]s and cancels them in
///     [dispose], preventing leaks when a route is popped.
///   • A [_disposed] guard so late stream events never call [notifyListeners]
///     after the notifier is gone.
abstract class BaseNotifier extends ChangeNotifier {
  bool _isLoading = false;
  AppError? _error;
  bool _disposed = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool get isLoading => _isLoading;
  AppError? get error => _error;
  bool get hasError => _error != null;

  /// Wraps an async operation with loading/error lifecycle.
  ///
  /// Returns `true` on success, `false` on failure (error stored in [error]).
  Future<bool> runAsync(Future<void> Function() fn) async {
    if (_disposed) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
      return true;
    } catch (e, st) {
      if (!_disposed) {
        _error = AppError.fromException(e, st);
      }
      return false;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Subscribes to [stream] and stores the subscription for automatic cleanup.
  ///
  /// [onData] is called for each event. Stream errors are converted to
  /// [AppError] and stored in [error]; the subscription is not cancelled on
  /// error so the stream can recover (e.g. Firestore offline → online).
  void listenToStream<T>(
    Stream<T> stream, {
    required void Function(T data) onData,
  }) {
    final sub = stream.listen(
      (data) {
        if (!_disposed) onData(data);
      },
      onError: (Object e, StackTrace st) {
        if (_disposed) return;
        _error = AppError.fromException(e, st);
        notifyListeners();
      },
      cancelOnError: false,
    );
    _subscriptions.add(sub);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
