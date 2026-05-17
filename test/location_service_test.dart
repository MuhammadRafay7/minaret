import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/core/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Manual location storage and retrieval', () async {
      const lat = 24.8607;
      const lng = 67.0011;
      const name = 'Karachi, Pakistan';

      await LocationService.setManualLocation(lat, lng, name);
      
      final pos = await LocationService.getCurrentLocation();
      final savedName = await LocationService.getManualCityName();

      expect(pos?.latitude, lat);
      expect(pos?.longitude, lng);
      expect(savedName, name);
    });

    test('Clear manual location works', () async {
      await LocationService.setManualLocation(1.0, 1.0, 'Test');
      await LocationService.clearManualLocation();

      final savedName = await LocationService.getManualCityName();
      expect(savedName, isNull);
    });

    test('Calculate distance between two points', () {
      // London to Paris roughly 340km
      final dist = LocationService.calculateDistance(51.5074, -0.1278, 48.8566, 2.3522);
      expect(dist, closeTo(340, 20));
    });
  });
}
