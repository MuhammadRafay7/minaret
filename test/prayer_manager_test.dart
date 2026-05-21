import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/services/prayer_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrayerManager Tests', () {
    late PrayerManager prayerManager;

    setUp(() {
      prayerManager = PrayerManager();
      SharedPreferences.setMockInitialValues({});
    });

    test('Calculates prayer times for a known coordinate (London)', () async {
      // London Coordinates
      const lat = 51.5074;
      const lng = -0.1278;

      final times = await prayerManager.getTodayTimes(lat, lng);

      expect(times.fajr, isNotNull);
      expect(times.dhuhr, isNotNull);
      expect(times.asr, isNotNull);
      expect(times.maghrib, isNotNull);
      expect(times.isha, isNotNull);
    });

    test('Respects Madhab settings (Hanafi vs Shafi)', () async {
      const lat = 31.5204; // Lahore
      const lng = 74.3587;

      // Set to Hanafi
      await PrayerManager.setMadhab('hanafi');
      final hanafiTimes = await prayerManager.getTodayTimes(lat, lng);

      // Set to Shafi
      await PrayerManager.setMadhab('shafii');
      final shafiTimes = await prayerManager.getTodayTimes(lat, lng);

      // Asr time should be different between the two Madhabs
      expect(hanafiTimes.asr.isAtSameMomentAs(shafiTimes.asr), isFalse);
      // Hanafi Asr is always later than Shafi Asr
      expect(hanafiTimes.asr.isAfter(shafiTimes.asr), isTrue);
    });

    test('Returns correct prayer status string', () async {
      const lat = 24.4539; // Abu Dhabi
      const lng = 54.3773;

      final times = await prayerManager.getTodayTimes(lat, lng);
      final status = prayerManager.getPrayerStatus(times);

      expect(status, anyOf([
        'FAJR', 'DHUHR', 'ASR', 'MAGHRIB', 'ISHA', 'ISHA PASSED'
      ]));
    });
  });
}
