import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  ConnectivityService() {
    _init();
  }

  bool get isOnline => _isOnline;

  Stream<bool> get onlineStream => _controller.stream;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _update(results);
    _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
      debugPrint('ConnectivityService: ${online ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  void dispose() => _controller.close();
}
