import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_defaults.dart';
import 'system_config_service.dart';

class PrayerManager {
  static const String _calcMethodKey = 'pref_calculation_method';
  static const String _madhabKey = 'pref_madhab';

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Logic to calculate prayer times for the UI
  Future<PrayerTimes> getTodayTimes(double lat, double lng, {GlobalSettings? globalSettings}) async {
    final coordinates = Coordinates(lat, lng);
    final prefs = await _getPrefs();

    // Priority: 1. User Local Prefs -> 2. Admin Global Defaults -> 3. Hardcoded Fallback
    final savedMethod = prefs.getString(_calcMethodKey) ??
                       globalSettings?.calculationMethod.toLowerCase() ??
                       kDefaultCalcMethod;

    final savedMadhab = prefs.getString(_madhabKey) ??
                       globalSettings?.madhab.toLowerCase() ??
                       kDefaultMadhab;

    final params = _getParams(savedMethod);
    params.madhab = savedMadhab == kMadhabShafi ? Madhab.shafi : Madhab.hanafi;

    final date = DateTime.now();
    final components = DateComponents(date.year, date.month, date.day);

    return PrayerTimes(coordinates, components, params);
  }

  CalculationParameters _getParams(String method) {
    switch (method.toLowerCase()) {
      case 'isna':
      case 'islamicsociety':
        return CalculationMethod.north_america.getParameters();
      case 'mwl':
      case 'muslimworldleague':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'egypt':
        return CalculationMethod.egyptian.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'singapore':
        return CalculationMethod.singapore.getParameters();
      case 'tehran':
        return CalculationMethod.tehran.getParameters();
      case 'turkey':
        return CalculationMethod.turkey.getParameters();
      case 'ummalqura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'karachi':
      default:
        return CalculationMethod.karachi.getParameters();
    }
  }

  String getPrayerStatus(PrayerTimes times) {
    final next = times.nextPrayer();
    if (next == Prayer.none) {
      return "ISHA PASSED";
    }
    return next.toString().split('.').last.toUpperCase();
  }

  DateTime? getTimeForPrayer(PrayerTimes times, Prayer prayer) {
    return times.timeForPrayer(prayer);
  }
  
  static Future<void> setMethod(String method) async {
    final prefs = await _getPrefs();
    await prefs.setString(_calcMethodKey, method);
  }

  static Future<void> setMadhab(String madhab) async {
    final prefs = await _getPrefs();
    await prefs.setString(_madhabKey, madhab);
  }
}
