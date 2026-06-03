import 'package:cloud_firestore/cloud_firestore.dart';

class SystemConfig {
  final bool maintenanceMode;
  final String minAppVersion;
  final String latestAppVersion;
  final bool forceUpdate;
  final String apiEndpoint;

  SystemConfig({
    required this.maintenanceMode,
    required this.minAppVersion,
    required this.latestAppVersion,
    required this.forceUpdate,
    required this.apiEndpoint,
  });

  factory SystemConfig.fromMap(Map<String, dynamic> map) {
    return SystemConfig(
      maintenanceMode: map['maintenanceMode'] ?? false,
      minAppVersion: map['minAppVersion'] ?? '1.0.0',
      latestAppVersion: map['latestAppVersion'] ?? '1.0.0',
      forceUpdate: map['forceUpdate'] ?? false,
      apiEndpoint: map['apiEndpoint'] ?? '',
    );
  }
}

class GlobalSettings {
  final bool allowNewRegistrations;
  final String calculationMethod;
  final String madhab;
  final FeatureConfig features;
  final RamadanConfig ramadan;

  GlobalSettings({
    required this.allowNewRegistrations,
    required this.calculationMethod,
    required this.madhab,
    required this.features,
    required this.ramadan,
  });

  factory GlobalSettings.fromMap(Map<String, dynamic> map) {
    final prayer = map['prayerTimeCalculation'] ?? {};
    final feats = map['features'] ?? {};
    return GlobalSettings(
      allowNewRegistrations: map['allowNewRegistrations'] ?? true,
      calculationMethod: prayer['method'] ?? 'MuslimWorldLeague',
      madhab: prayer['madhab'] ?? 'Hanafi',
      features: FeatureConfig.fromMap(Map<String, dynamic>.from(feats)),
      ramadan: RamadanConfig.fromMap(
          map['ramadan'] is Map ? Map<String, dynamic>.from(map['ramadan']) : const {}),
    );
  }
}

/// Admin-controlled Ramadan switch stored at app_settings/global → `ramadan`.
///   mode: 'auto' (calendar/mosque-driven) | 'on' (force) | 'off' (force off)
/// Used by the app to override the local Ramadan detection — handy for testing.
class RamadanConfig {
  final String mode; // 'auto' | 'on' | 'off'
  final DateTime? startDate;
  final DateTime? eidDate;

  const RamadanConfig({this.mode = 'auto', this.startDate, this.eidDate});

  bool get forcedOn => mode == 'on';
  bool get forcedOff => mode == 'off';

  factory RamadanConfig.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic v) {
      if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
      return null;
    }

    final raw = (map['mode'] as String?)?.toLowerCase();
    return RamadanConfig(
      mode: (raw == 'on' || raw == 'off') ? raw! : 'auto',
      startDate: parse(map['startDate'] ?? map['ramadanStartDate']),
      eidDate: parse(map['eidDate'] ?? map['eidFitrDate']),
    );
  }
}

class FeatureConfig {
  final bool enableHadith;
  final bool enableQuran;
  final bool enableMosqueDiscovery;
  final bool enablePrayerTracking;
  final bool enableJanazaAnnouncements;
  final bool enableQibla;

  FeatureConfig({
    required this.enableHadith,
    required this.enableQuran,
    required this.enableMosqueDiscovery,
    required this.enablePrayerTracking,
    required this.enableJanazaAnnouncements,
    required this.enableQibla,
  });

  factory FeatureConfig.fromMap(Map<String, dynamic> map) {
    return FeatureConfig(
      enableHadith: map['enableHadith'] ?? true,
      enableQuran: map['enableQuran'] ?? true,
      enableMosqueDiscovery: map['enableMosqueDiscovery'] ?? true,
      enablePrayerTracking: map['enablePrayerTracking'] ?? true,
      enableJanazaAnnouncements: map['enableJanazaAnnouncements'] ?? true,
      enableQibla: map['enableQibla'] ?? true,
    );
  }
}

class SystemConfigService {
  static final _db = FirebaseFirestore.instance;

  static Stream<SystemConfig> systemConfigStream() {
    return _db.collection('app_settings').doc('system').snapshots().map((doc) {
      if (!doc.exists) {
        return SystemConfig(
          maintenanceMode: false,
          minAppVersion: '1.0.0',
          latestAppVersion: '1.0.0',
          forceUpdate: false,
          apiEndpoint: '',
        );
      }
      return SystemConfig.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  static Stream<GlobalSettings> globalSettingsStream() {
    return _db.collection('app_settings').doc('global').snapshots().map((doc) {
      if (!doc.exists) {
        return GlobalSettings(
          allowNewRegistrations: true,
          calculationMethod: 'MuslimWorldLeague',
          madhab: 'Hanafi',
          features: FeatureConfig(
            enableHadith: true,
            enableQuran: true,
            enableMosqueDiscovery: true,
            enablePrayerTracking: true,
            enableJanazaAnnouncements: true,
            enableQibla: true,
          ),
          ramadan: const RamadanConfig(),
        );
      }
      return GlobalSettings.fromMap(doc.data() as Map<String, dynamic>);
    });
  }
}
