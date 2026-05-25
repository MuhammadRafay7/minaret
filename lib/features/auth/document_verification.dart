import 'dart:typed_data';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:string_similarity/string_similarity.dart';

class ImamVerificationResult {
  final bool approved;
  final String status; // 'approved' | 'rejected' | 'needs_review'
  final int score; // 0-100
  final String reason;
  final int nameMatchConfidence; // 0-100

  const ImamVerificationResult({
    required this.approved,
    required this.status,
    required this.score,
    required this.reason,
    required this.nameMatchConfidence,
  });
}

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

class InternationalDocumentVerificationService {
  static const Map<String, CountryConfig> _countries = {
    'PK': CountryConfig(
      name: 'Pakistan',
      idPatterns: [r'\b(\d{5}[\s\-]?\d{7}[\s\-]?\d{1})\b'],
      nameKeywords: [
        'name', 'naam', 'full name', 'holder', 'issued to', 'applicant', 'نام'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'US': CountryConfig(
      name: 'United States',
      idPatterns: [r'\b(\d{3}[\s\-]?\d{2}[\s\-]?\d{4})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'first name', 'last name'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'GB': CountryConfig(
      name: 'United Kingdom',
      idPatterns: [r'\b([A-Z]{2}\d{6})\b', r'\b(\d{9})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'forename', 'surname'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'SA': CountryConfig(
      name: 'Saudi Arabia',
      idPatterns: [r'\b(\d{10})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'AE': CountryConfig(
      name: 'United Arab Emirates',
      idPatterns: [r'\b(\d{3}[\s\-]?\d{4}[\s\-]?\d{7}[\s\-]?\d{1})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'IN': CountryConfig(
      name: 'India',
      idPatterns: [r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'नाम', 'nam'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'EG': CountryConfig(
      name: 'Egypt',
      idPatterns: [r'\b(\d{14})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'الاسم', 'اسم'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'TR': CountryConfig(
      name: 'Turkey',
      idPatterns: [r'\b(\d{11})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'ad', 'soyad'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'FR': CountryConfig(
      name: 'France',
      idPatterns: [r'\b(\d{12}[\s\-]?\d{2})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'nom', 'prénom'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'DE': CountryConfig(
      name: 'Germany',
      idPatterns: [r'\b([A-Z]{2}\d{8})\b'],
      nameKeywords: [
        'name', 'full name', 'holder', 'issued to', 'applicant', 'name', 'vorname', 'nachname'
      ],
      scripts: [TextRecognitionScript.latin],
    ),
    'GENERIC': CountryConfig(
      name: 'Generic',
      idPatterns: [
        r'\b([A-Z]\d{7,9})\b',
        r'\b([A-Z]{2}\d{6,8})\b',
      ],
      nameKeywords: ['name', 'full name', 'holder', 'issued to', 'applicant'],
      scripts: [TextRecognitionScript.latin],
    ),
  };

  static List<String> getSupportedCountries() => _countries.keys.toList();

  static CountryConfig getCountryConfig(String countryCode) =>
      _countries[countryCode] ?? _countries['GENERIC']!;

  static Future<File> _bytesToTempFile(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<String> _extractText(
      Uint8List imageBytes, String tag, List<TextRecognitionScript> scripts) async {
    final file = await _bytesToTempFile(imageBytes, tag);
    final inputImage = InputImage.fromFile(file);
    String combinedText = '';
    for (final script in scripts) {
      final recognizer = TextRecognizer(script: script);
      try {
        final result = await recognizer.processImage(inputImage);
        if (result.text.trim().isNotEmpty) {
          combinedText += result.text + '\n';
        }
      } catch (_) {
        continue;
      } finally {
        recognizer.close();
      }
    }
    return combinedText.trim();
  }

  static String _clean(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

  static String? _extractIdNumber(String raw, List<String> patterns) {
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(raw);
      if (match != null) {
        return match.group(1)?.replaceAll(RegExp(r'[\s\-]'), '');
      }
    }
    return null;
  }

  static String _extractName(String raw, List<String> keywords) {
    final lines = raw.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).toList();
    final keywordPattern = RegExp(
      r'\b(' + keywords.join('|') + r')\b',
      caseSensitive: false,
    );
    for (int i = 0; i < lines.length; i++) {
      if (keywordPattern.hasMatch(lines[i])) {
        final sameLineValue =
            lines[i].replaceAll(keywordPattern, '').replaceAll(':', '').trim();
        if (sameLineValue.length > 2) return _clean(sameLineValue);
        if (i + 1 < lines.length) return _clean(lines[i + 1]);
      }
    }
    return lines
        .map(_clean)
        .where((l) => l.isNotEmpty && RegExp(r'^[a-z ]+$').hasMatch(l))
        .fold('', (a, b) => b.length > a.length ? b : a);
  }

  static Future<ImamVerificationResult> verify({
    required Uint8List idCardBytes,
    required Uint8List idCardBackBytes,
    required Uint8List sanadBytes,
    required String countryCode,
  }) async {
    final config = getCountryConfig(countryCode);
    final idRaw = await _extractText(idCardBytes, 'id_card', config.scripts);
    final idBackRaw = await _extractText(idCardBackBytes, 'id_card_back', config.scripts);
    final sanadRaw = await _extractText(sanadBytes, 'sanad', config.scripts);
    final combinedIdText = '$idRaw\n$idBackRaw';

    final idNumber = _extractIdNumber(combinedIdText, config.idPatterns);
    final sanadNumber = _extractIdNumber(sanadRaw, config.idPatterns);

    if (idNumber != null && sanadNumber != null) {
      if (idNumber == sanadNumber) {
        return ImamVerificationResult(
          approved: true,
          status: 'approved',
          score: 100,
          reason: 'ID numbers match (${config.name})',
          nameMatchConfidence: 100,
        );
      } else {
        return ImamVerificationResult(
          approved: false,
          status: 'rejected',
          score: 0,
          reason:
              'ID numbers found on both documents do not match ($idNumber vs $sanadNumber) for ${config.name}.',
          nameMatchConfidence: 0,
        );
      }
    }

    final idName = _extractName(combinedIdText, config.nameKeywords);
    final sanadName = _extractName(sanadRaw, config.nameKeywords);

    if (idName.length < 3 || sanadName.length < 3) {
      return ImamVerificationResult(
        approved: false,
        status: 'needs_review',
        score: 0,
        reason: 'Could not extract a readable name from one or both documents for ${config.name}. '
            'Documents have been saved for manual review.',
        nameMatchConfidence: 0,
      );
    }

    final similarity = idName.similarityTo(sanadName);
    final score = (similarity * 100).round();
    final confidence = score;

    if (similarity >= 0.80) {
      return ImamVerificationResult(
        approved: true,
        status: 'approved',
        score: score,
        reason: 'Names match for ${config.name}',
        nameMatchConfidence: confidence,
      );
    } else if (similarity >= 0.55) {
      return ImamVerificationResult(
        approved: false,
        status: 'needs_review',
        score: score,
        reason: 'Names are similar but confidence is low for ${config.name} (possible OCR noise). '
            'Saved for manual review.',
        nameMatchConfidence: confidence,
      );
    } else {
      return ImamVerificationResult(
        approved: false,
        status: 'rejected',
        score: score,
        reason: 'Names on documents do not appear to match for ${config.name}. '
            'Please upload the correct ID and Sanad.',
        nameMatchConfidence: confidence,
      );
    }
  }
}

class OnDeviceVerificationService {
  static Future<ImamVerificationResult> verify({
    required Uint8List idCardBytes,
    required Uint8List sanadBytes,
  }) async {
    return InternationalDocumentVerificationService.verify(
      idCardBytes: idCardBytes,
      idCardBackBytes: idCardBytes,
      sanadBytes: sanadBytes,
      countryCode: 'PK',
    );
  }
}
