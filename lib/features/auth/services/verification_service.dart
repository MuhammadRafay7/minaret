import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:string_similarity/string_similarity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Typed result hierarchy (sealed — exhaustive switch in callers)
// ─────────────────────────────────────────────────────────────────────────────

sealed class VerificationResult {
  final int score;
  final String reason;
  const VerificationResult({required this.score, required this.reason});
}

final class VerificationSuccess extends VerificationResult {
  final int nameMatchConfidence;
  const VerificationSuccess({
    required super.score,
    required super.reason,
    required this.nameMatchConfidence,
  });
}

final class VerificationFailure extends VerificationResult {
  const VerificationFailure({required super.score, required super.reason});
}

final class VerificationPending extends VerificationResult {
  const VerificationPending({required super.score, required super.reason});
}

extension VerificationResultX on VerificationResult {
  bool get approved => this is VerificationSuccess;

  String get status => switch (this) {
        VerificationSuccess() => 'approved',
        VerificationFailure() => 'rejected',
        VerificationPending() => 'needs_review',
      };

  int get nameMatchConfidence => switch (this) {
        VerificationSuccess(:final nameMatchConfidence) => nameMatchConfidence,
        _ => 0,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Country configuration
// ─────────────────────────────────────────────────────────────────────────────

class CountryConfig {
  final String name;
  final List<String> idPatterns;
  final List<String> nameKeywords;
  final List<TextRecognitionScript> scripts;

  const CountryConfig({
    required this.name,
    required this.idPatterns,
    required this.nameKeywords,
    required this.scripts,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload progress events
// ─────────────────────────────────────────────────────────────────────────────

sealed class UploadEvent {}

final class UploadProgress extends UploadEvent {
  final double fraction;
  UploadProgress(this.fraction);
}

final class UploadComplete extends UploadEvent {
  final Map<String, String> urls;
  UploadComplete(this.urls);
}

final class UploadError extends UploadEvent {
  final String message;
  UploadError(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// Imam profile data for Firestore write
// ─────────────────────────────────────────────────────────────────────────────

class ImamProfileData {
  final String fullName;
  final String fatherName;
  final String phoneNumber;
  final bool offersTeaching;
  final String teachingAudience;
  final double? teachingFee;
  final String? teachingNotes;

  const ImamProfileData({
    required this.fullName,
    required this.fatherName,
    required this.phoneNumber,
    required this.offersTeaching,
    required this.teachingAudience,
    this.teachingFee,
    this.teachingNotes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// InternationalVerificationService — pure Dart, no widget imports
// ─────────────────────────────────────────────────────────────────────────────

class InternationalVerificationService {
  static const Map<String, CountryConfig> _countries = {
    'PK': CountryConfig(
      name: 'Pakistan',
      idPatterns: [r'\b(\d{5}[\s\-]?\d{7}[\s\-]?\d{1})\b'],
      nameKeywords: ['name', 'naam', 'full name', 'holder', 'issued to', 'applicant', 'نام'],
      scripts: [TextRecognitionScript.latin],
    ),
    'US': CountryConfig(
      name: 'United States',
      idPatterns: [r'\b(\d{3}[\s\-]?\d{2}[\s\-]?\d{4})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'first name', 'last name'],
      scripts: [TextRecognitionScript.latin],
    ),
    'GB': CountryConfig(
      name: 'United Kingdom',
      idPatterns: [r'\b([A-Z]{2}\d{6})\b', r'\b(\d{9})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'forename', 'surname'],
      scripts: [TextRecognitionScript.latin],
    ),
    'SA': CountryConfig(
      name: 'Saudi Arabia',
      idPatterns: [r'\b(\d{10})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'],
      scripts: [TextRecognitionScript.latin],
    ),
    'AE': CountryConfig(
      name: 'United Arab Emirates',
      idPatterns: [r'\b(\d{3}[\s\-]?\d{4}[\s\-]?\d{7}[\s\-]?\d{1})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'],
      scripts: [TextRecognitionScript.latin],
    ),
    'IN': CountryConfig(
      name: 'India',
      idPatterns: [r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'नाम', 'nam'],
      scripts: [TextRecognitionScript.latin],
    ),
    'EG': CountryConfig(
      name: 'Egypt',
      idPatterns: [r'\b(\d{14})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'],
      scripts: [TextRecognitionScript.latin],
    ),
    'TR': CountryConfig(
      name: 'Turkey',
      idPatterns: [r'\b(\d{11})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'ad', 'soyad'],
      scripts: [TextRecognitionScript.latin],
    ),
    'FR': CountryConfig(
      name: 'France',
      idPatterns: [r'\b(\d{12}[\s\-]?\d{2})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'nom', 'prénom'],
      scripts: [TextRecognitionScript.latin],
    ),
    'DE': CountryConfig(
      name: 'Germany',
      idPatterns: [r'\b([A-Z]{2}\d{8})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant', 'vorname', 'nachname'],
      scripts: [TextRecognitionScript.latin],
    ),
    'GENERIC': CountryConfig(
      name: 'Generic',
      idPatterns: [r'\b([A-Z]\d{7,9})\b', r'\b([A-Z]{2}\d{6,8})\b'],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant'],
      scripts: [TextRecognitionScript.latin],
    ),
  };

  static List<String> get supportedCountries => _countries.keys.toList();

  static CountryConfig configFor(String countryCode) =>
      _countries[countryCode] ?? _countries['GENERIC']!;

  // ── OCR ───────────────────────────────────────────────────────────────────

  static Future<File> _bytesToTempFile(Uint8List bytes, String tag) async {
    final dir = await getTemporaryDirectory();
    final unique = '${tag}_${DateTime.now().microsecondsSinceEpoch}';
    final file = File('${dir.path}/$unique.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<String> _extractText(
    Uint8List bytes,
    String tag,
    List<TextRecognitionScript> scripts,
  ) async {
    final file = await _bytesToTempFile(bytes, tag);
    final inputImage = InputImage.fromFile(file);
    final buffer = StringBuffer();
    for (final script in scripts) {
      final recognizer = TextRecognizer(script: script);
      try {
        final result = await recognizer.processImage(inputImage);
        if (result.text.trim().isNotEmpty) buffer.writeln(result.text);
      } catch (_) {
        continue;
      } finally {
        recognizer.close();
      }
    }
    return buffer.toString().trim();
  }

  // ── Scoring helpers (also used by verifyFromText) ─────────────────────────

  static String _clean(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

  static String? _extractIdNumber(String raw, List<String> patterns) {
    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(raw);
      if (match != null) {
        return match.group(1)?.replaceAll(RegExp(r'[\s\-]'), '');
      }
    }
    return null;
  }

  static String _extractName(String raw, List<String> keywords) {
    final lines = raw.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).toList();
    final kw = RegExp(r'\b(' + keywords.join('|') + r')\b', caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
      if (kw.hasMatch(lines[i])) {
        final inline = lines[i].replaceAll(kw, '').replaceAll(':', '').trim();
        if (inline.length > 2) return _clean(inline);
        if (i + 1 < lines.length) return _clean(lines[i + 1]);
      }
    }
    return lines
        .map(_clean)
        .where((l) => l.isNotEmpty && RegExp(r'^[a-z ]+$').hasMatch(l))
        .fold('', (best, l) => l.length > best.length ? l : best);
  }

  static VerificationResult _score(
    String idText,
    String sanadText,
    CountryConfig config,
  ) {
    final idNumber = _extractIdNumber(idText, config.idPatterns);
    final sanadNumber = _extractIdNumber(sanadText, config.idPatterns);

    if (idNumber != null && sanadNumber != null) {
      if (idNumber == sanadNumber) {
        return const VerificationSuccess(
          score: 100,
          reason: 'ID numbers match',
          nameMatchConfidence: 100,
        );
      }
      return VerificationFailure(
        score: 0,
        reason: 'ID numbers do not match ($idNumber vs $sanadNumber)',
      );
    }

    final idName = _extractName(idText, config.nameKeywords);
    final sanadName = _extractName(sanadText, config.nameKeywords);

    if (idName.length < 3 || sanadName.length < 3) {
      return const VerificationPending(
        score: 0,
        reason: 'Could not extract a readable name from one or both documents',
      );
    }

    final similarity = idName.similarityTo(sanadName);
    final score = (similarity * 100).round();

    if (similarity >= 0.80) {
      return VerificationSuccess(
        score: score,
        reason: 'Names match (${config.name})',
        nameMatchConfidence: score,
      );
    } else if (similarity >= 0.55) {
      return VerificationPending(
        score: score,
        reason: 'Names are similar but confidence is low for ${config.name} — saved for manual review.',
      );
    } else {
      return VerificationFailure(
        score: score,
        reason: 'Names do not appear to match for ${config.name}. Please upload the correct ID and Sanad.',
      );
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Run OCR and score against each other. Main entry point for live flows.
  static Future<VerificationResult> verify({
    required Uint8List idCardBytes,
    required Uint8List idCardBackBytes,
    required Uint8List sanadBytes,
    required String countryCode,
  }) async {
    final config = configFor(countryCode);
    final idRaw = await _extractText(idCardBytes, 'id_front', config.scripts);
    final idBackRaw = await _extractText(idCardBackBytes, 'id_back', config.scripts);
    final sanadRaw = await _extractText(sanadBytes, 'sanad', config.scripts);
    return _score('$idRaw\n$idBackRaw', sanadRaw, config);
  }

  /// Skip OCR — inject raw text directly. Bypasses disk I/O for unit tests.
  @visibleForTesting
  static VerificationResult verifyFromText({
    required String idRawText,
    required String sanadRawText,
    String countryCode = 'GENERIC',
  }) =>
      _score(idRawText, sanadRawText, configFor(countryCode));

  // ── Firebase Storage upload with progress ─────────────────────────────────

  /// Yields [UploadProgress] (0.0–1.0 across all three files) then
  /// [UploadComplete] with the download URLs, or [UploadError] on failure.
  static Stream<UploadEvent> uploadDocuments({
    required String uid,
    required Uint8List idCardBytes,
    required Uint8List idCardBackBytes,
    required Uint8List sanadBytes,
  }) async* {
    const labels = ['id_card_front', 'id_card_back', 'sanad'];
    final blobs = [idCardBytes, idCardBackBytes, sanadBytes];
    final urls = <String>[];
    final meta = SettableMetadata(contentType: 'image/jpeg');

    for (int i = 0; i < 3; i++) {
      final unique = '${labels[i]}_${DateTime.now().microsecondsSinceEpoch}';
      final ref = FirebaseStorage.instance.ref('imam_documents/$uid/$unique.jpg');
      final task = ref.putData(blobs[i], meta);

      await for (final snap in task.snapshotEvents) {
        if (snap.totalBytes > 0) {
          final fileProgress = snap.bytesTransferred / snap.totalBytes;
          yield UploadProgress((i + fileProgress) / 3);
        }
        if (snap.state == TaskState.error) {
          yield UploadError('Upload failed for ${labels[i]}');
          return;
        }
      }

      try {
        urls.add(await ref.getDownloadURL());
      } catch (e) {
        yield UploadError('Could not retrieve download URL for ${labels[i]}: $e');
        return;
      }
    }

    yield UploadComplete({
      'idCardUrl': urls[0],
      'idCardBackUrl': urls[1],
      'sanadUrl': urls[2],
    });
  }

  // ── Firestore write ───────────────────────────────────────────────────────

  /// Writes the complete imam registration record to Firestore.
  /// Must be called while the user is still authenticated (before signOut).
  static Future<void> writeRegistration({
    required String uid,
    required String email,
    required String city,
    required Map<String, String> documentUrls,
    required VerificationResult verificationResult,
    required String countryCode,
    required ImamProfileData profile,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': email,
      'city': city,
      'role': 'imam',
      'createdAt': FieldValue.serverTimestamp(),
      'favorites': <String>[],
      'followedMosques': <String>[],
      'notificationsEnabled': true,
      'notificationPrefs': {
        'janaza': true,
        'adhan': true,
        'namaz': true,
        'eid': true,
        'taraweeh': true,
      },
      'fullName': profile.fullName,
      'fatherName': profile.fatherName,
      'phoneNumber': profile.phoneNumber,
      'imamProfile': {
        'fullName': profile.fullName,
        'fatherName': profile.fatherName,
        'phoneNumber': profile.phoneNumber,
        'offersTeaching': profile.offersTeaching,
        'teachingAudience': profile.offersTeaching ? profile.teachingAudience : null,
        'teachingFee': profile.offersTeaching ? profile.teachingFee : null,
        'teachingNotes': profile.offersTeaching ? profile.teachingNotes : null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'idCardUrl': documentUrls['idCardUrl'],
      'idCardBackUrl': documentUrls['idCardBackUrl'],
      'sanadUrl': documentUrls['sanadUrl'],
      'documentsVerified': verificationResult.approved,
      'verificationStatus': verificationResult.status,
      'verificationScore': verificationResult.score,
      'verificationReason': verificationResult.reason,
      'nameMatchConfidence': verificationResult.nameMatchConfidence,
      'verificationMethod': 'on_device_mlkit',
      'verificationCountry': countryCode,
    }, SetOptions(merge: false));
  }
}
