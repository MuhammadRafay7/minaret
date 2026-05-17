import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<Position?> getCurrentPositionWeb() async {
  try {
    final completer = Completer<Position?>();

    final geolocation = web.window.navigator.geolocation;

    void successCallback(web.GeolocationPosition position) {
      final coords = position.coords;
      final result = Position(
        latitude: coords.latitude.toDouble(),
        longitude: coords.longitude.toDouble(),
        timestamp: DateTime.now(),
        accuracy: coords.accuracy.toDouble(),
        altitude: coords.altitude?.toDouble() ?? 0.0,
        altitudeAccuracy: coords.altitudeAccuracy?.toDouble() ?? 0.0,
        heading: coords.heading?.toDouble() ?? 0.0,
        headingAccuracy: 0.0,
        speed: coords.speed?.toDouble() ?? 0.0,
        speedAccuracy: 0.0,
      );
      if (!completer.isCompleted) completer.complete(result);
    }

    void errorCallback(web.GeolocationPositionError error) {
      debugPrint("Geolocation error: ${error.message}");
      if (!completer.isCompleted) completer.complete(null);
    }

    final options = web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 60000,
    );

    geolocation.getCurrentPosition(
      successCallback.toJS,
      errorCallback.toJS,
      options,
    );

    return await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint("Web geolocation timed out");
        return null;
      },
    );
  } catch (e) {
    debugPrint("Web geolocation error: $e");
    return null;
  }
}
