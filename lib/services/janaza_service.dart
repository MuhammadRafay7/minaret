// Re-export model so existing widget imports remain unchanged.
export '../repositories/janaza_repository.dart' show JanazaAnnouncement;

import '../core/dependency_injection.dart';
import '../repositories/janaza_repository.dart';

// Backward-compatible static facade — delegates to JanazaRepository.
class JanazaService {
  JanazaService._();

  static JanazaRepository get _repo =>
      ServiceLocator.get<JanazaRepository>();

  static Future<void> postAnnouncement({
    required String mosqueId,
    required String mosqueName,
    required String mosqueFiqh,
    required String mosqueCity,
    required String deceasedName,
    required DateTime janazaTime,
    String locationNote = '',
    String gender = '',
    String fatherName = '',
    String motherName = '',
    String husbandName = '',
    String wifeName = '',
    String brotherName = '',
    String sisterName = '',
    String age = '',
  }) =>
      _repo.postAnnouncement(
        mosqueId: mosqueId,
        mosqueName: mosqueName,
        mosqueFiqh: mosqueFiqh,
        mosqueCity: mosqueCity,
        deceasedName: deceasedName,
        janazaTime: janazaTime,
        locationNote: locationNote,
        gender: gender,
        fatherName: fatherName,
        motherName: motherName,
        husbandName: husbandName,
        wifeName: wifeName,
        brotherName: brotherName,
        sisterName: sisterName,
        age: age,
      );

  static Stream<List<JanazaAnnouncement>> activeForMosque(
          String mosqueId) =>
      _repo.activeForMosque(mosqueId);

  static Stream<List<JanazaAnnouncement>> activeForMosques(
          List<String> mosqueIds) =>
      _repo.activeForMosques(mosqueIds);

  static Stream<List<JanazaAnnouncement>> activeForCity(String city) =>
      _repo.activeForCity(city);

  static Future<void> deactivate(String announcementId) =>
      _repo.deactivate(announcementId);
}
