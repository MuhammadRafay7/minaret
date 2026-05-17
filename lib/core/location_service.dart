import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'location_service_stub.dart'
    if (dart.library.js_interop) 'location_service_web.dart';

class LocationService {
  static Position? _cachedPosition;

  // Use a Completer to properly await in-flight permission requests
  // instead of a busy-wait loop that can deadlock if an exception is thrown.
  static Completer<void>? _permissionCompleter;

  static Future<Position?> getCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final manualLat = prefs.getDouble('manual_lat');
    final manualLng = prefs.getDouble('manual_lng');

    if (manualLat != null && manualLng != null) {
      return Position(
        latitude: manualLat,
        longitude: manualLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    if (_cachedPosition != null) return _cachedPosition;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // If a request is already in-flight, wait for it to complete
      if (_permissionCompleter != null) {
        await _permissionCompleter!.future;
        permission = await Geolocator.checkPermission();
      } else {
        _permissionCompleter = Completer<void>();
        try {
          permission = await Geolocator.requestPermission();
        } finally {
          _permissionCompleter!.complete();
          _permissionCompleter = null;
        }
      }
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      if (kIsWeb) {
        _cachedPosition = await getCurrentPositionWeb();
        return _cachedPosition;
      } else {
        _cachedPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return _cachedPosition;
      }
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  static Future<void> setManualLocation(
      double lat, double lng, String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_lat', lat);
    await prefs.setDouble('manual_lng', lng);
    await prefs.setString('manual_city_name', cityName);
    _cachedPosition = null;
  }

  static Future<void> clearManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manual_lat');
    await prefs.remove('manual_lng');
    await prefs.remove('manual_city_name');
    _cachedPosition = null;
  }

  static Future<String?> getManualCityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('manual_city_name');
  }

  static Future<List<Map<String, dynamic>>> searchCities(String query) async {
    if (kIsWeb) return [];

    try {
      List<Location> locations = await locationFromAddress(query)
          .timeout(const Duration(seconds: 10));
      List<Map<String, dynamic>> results = [];

      for (var loc in locations.take(5)) {
        String displayName = query;
        try {
          List<Placemark> placemarks =
              await placemarkFromCoordinates(loc.latitude, loc.longitude)
                  .timeout(const Duration(seconds: 5));
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final city = p.locality ??
                p.subAdministrativeArea ??
                p.administrativeArea ??
                '';
            final country = p.country ?? '';
            if (city.isNotEmpty && country.isNotEmpty) {
              displayName = '$city, $country';
            } else if (city.isNotEmpty || country.isNotEmpty) {
              displayName = city.isNotEmpty ? city : country;
            }
          }
        } catch (e) {
          debugPrint('Placemark lookup failed for $query: $e');
        }

        results.add({
          'lat': loc.latitude,
          'lng': loc.longitude,
          'name': displayName.isNotEmpty ? displayName : query,
        });
      }
      return results;
    } catch (e) {
      debugPrint('City search error for $query: $e');
      return [];
    }
  }

  static Stream<Position> getPositionStream() {
    if (kIsWeb) {
      return Stream.periodic(const Duration(seconds: 5), (_) => _cachedPosition)
          .where((position) => position != null)
          .cast<Position>();
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  static void clearCache() => _cachedPosition = null;

  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000;
  }

  static String formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)} M';
    }
    return '${distance.toStringAsFixed(1)} KM';
  }
}
