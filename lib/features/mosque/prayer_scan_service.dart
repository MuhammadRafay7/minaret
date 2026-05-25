import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:string_similarity/string_similarity.dart';

// ── Public result model ───────────────────────────────────────────────────────

class ScannedPrayerTimes {
  final String? adhanFajr;
  final String? adhanDhuhr;
  final String? adhanAsr;
  final String? adhanMaghrib;
  final String? adhanIsha;
  final String? adhanJummah;

  final String? fajr;
  final String? dhuhr;
  final String? asr;
  final String? maghrib;
  final String? isha;
  final String? jummah;

  final String timeType;   // 'azan' | 'iqamah' | 'unknown'
  final int confidence;    // 0–100
  final String note;

  const ScannedPrayerTimes({
    this.adhanFajr,
    this.adhanDhuhr,
    this.adhanAsr,
    this.adhanMaghrib,
    this.adhanIsha,
    this.adhanJummah,
    this.fajr,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
    this.jummah,
    required this.timeType,
    required this.confidence,
    required this.note,
  });
}

// Thrown when the photo appears to be an analog clock board (no digits found)
class AnalogBoardException implements Exception {
  const AnalogBoardException();
}

// Thrown when OCR finds no useful content at all
class NoTimesFoundException implements Exception {
  const NoTimesFoundException();
}

// ── Service ───────────────────────────────────────────────────────────────────

class PrayerScanService {
  static final _picker = ImagePicker();

  // Iqamah offset after Azan (minutes)
  static const _iqamahOffset = {
    'fajr': 20, 'dhuhr': 15, 'asr': 15,
    'maghrib': 10, 'isha': 20, 'jummah': 20,
  };

  // Time pattern: "3:37", "16:29", "5:20 AM"
  static final _timeRx = RegExp(r'\b(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\b');

  // Prayer label keywords in Arabic, Urdu, and English
  static const _labels = <String, List<String>>{
    'fajr':    ['فجر', 'صبح', 'الفجر', 'فجر', 'fajr', 'fajar', 'subh'],
    'dhuhr':   ['ظهر', 'الظهر', 'ظہر', 'dhuhr', 'zuhr', 'zohar'],
    'asr':     ['عصر', 'العصر', 'asr'],
    'maghrib': ['مغرب', 'المغرب', 'maghrib'],
    'isha':    ['عشاء', 'العشاء', 'عشا', 'isha'],
    'jummah':  ['جمعة', 'الجمعة', 'جمعه', 'جمعت', 'jummah', 'jumma', 'friday'],
  };

  // Labels that indicate sunrise (not a prayer — skip)
  static final _sunriseRx = RegExp(r'شروق|sunrise|طلوع', caseSensitive: false);

  // ── Public entry point ──────────────────────────────────────────────────────

  static Future<ScannedPrayerTimes?> pickAndScan(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _process(file.path);
  }

  // ── OCR + parsing pipeline ──────────────────────────────────────────────────

  static Future<ScannedPrayerTimes?> _process(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    late RecognizedText recognized;
    try {
      recognized = await recognizer.processImage(inputImage);
    } finally {
      recognizer.close();
    }

    final allText = recognized.text.trim();

    // Detect analog board: prayer labels found but zero time patterns
    final hasTimeDigits = _timeRx.hasMatch(allText);
    final hasPrayerLabel = _labels.values
        .any((kws) => kws.any((kw) => allText.toLowerCase().contains(kw.toLowerCase())));

    if (!hasTimeDigits && hasPrayerLabel) throw const AnalogBoardException();
    if (!hasTimeDigits) throw const NoTimesFoundException();

    // Collect line-level blocks with bounding boxes
    final blocks = <_Block>[
      for (final b in recognized.blocks)
        for (final l in b.lines)
          if (l.text.trim().isNotEmpty) _Block(l.text.trim(), l.boundingBox),
    ];

    // Strategy 1: match prayer labels to nearest time block
    final byLabel = _matchByLabels(blocks);
    final labelHits = byLabel.values.where((v) => v != null).length;
    if (labelHits >= 3) return _buildResult(byLabel, labelHits >= 4 ? 80 : 65);

    // Strategy 2: sort all time blocks top-to-bottom and assign in prayer order
    return _matchByPosition(blocks);
  }

  // ── Strategy 1: label proximity ────────────────────────────────────────────

  static Map<String, String?> _matchByLabels(List<_Block> blocks) {
    final result = <String, String?>{
      for (final k in _labels.keys) k: null,
    };

    for (final block in blocks) {
      final prayer = _prayerFor(block.text);
      if (prayer == null) continue;
      final t = _nearestTime(block, blocks);
      if (t != null) result[prayer] = t;
    }

    return result;
  }

  static String? _prayerFor(String text) {
    final low = text.toLowerCase().trim();
    for (final entry in _labels.entries) {
      for (final kw in entry.value) {
        if (low.contains(kw.toLowerCase())) return entry.key;
      }
      // Fuzzy fallback for partially-recognised Arabic glyphs
      for (final kw in entry.value) {
        if (kw.length > 2 && low.similarityTo(kw.toLowerCase()) > 0.62) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String? _nearestTime(_Block label, List<_Block> all) {
    final lc = Offset(
      label.rect.left + label.rect.width / 2,
      label.rect.top + label.rect.height / 2,
    );

    String? best;
    double bestDist = double.infinity;

    for (final b in all) {
      final m = _timeRx.firstMatch(b.text);
      if (m == null) continue;
      final bc = Offset(
        b.rect.left + b.rect.width / 2,
        b.rect.top + b.rect.height / 2,
      );
      final dist = (bc - lc).distance;
      if (dist < bestDist && dist < 600) {
        bestDist = dist;
        best = _normalise(m);
      }
    }

    return best;
  }

  // ── Strategy 2: vertical ordering ──────────────────────────────────────────

  static ScannedPrayerTimes? _matchByPosition(List<_Block> blocks) {
    final timed = <_Timed>[];

    for (final b in blocks) {
      if (_sunriseRx.hasMatch(b.text)) continue;
      final m = _timeRx.firstMatch(b.text);
      if (m == null) continue;
      final t = _normalise(m);
      if (t != null) timed.add(_Timed(t, b.rect.top));
    }

    timed.sort((a, b) => a.y.compareTo(b.y));
    if (timed.length < 5) return null;

    final times = timed.map((t) => t.time).toList();
    // If 6 times found, slot 1 is likely sunrise — drop it
    if (times.length >= 6) times.removeAt(1);

    const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final map = <String, String?>{for (final k in _labels.keys) k: null};
    for (var i = 0; i < prayers.length && i < times.length; i++) {
      map[prayers[i]] = times[i];
    }

    return _buildResult(map, 55);
  }

  // ── Build final result with calculated counterpart times ────────────────────

  static ScannedPrayerTimes _buildResult(Map<String, String?> azan, int confidence) {
    return ScannedPrayerTimes(
      // Extracted times go into the Azan fields
      adhanFajr:    azan['fajr'],
      adhanDhuhr:   azan['dhuhr'],
      adhanAsr:     azan['asr'],
      adhanMaghrib: azan['maghrib'],
      adhanIsha:    azan['isha'],
      adhanJummah:  azan['jummah'],
      // Iqamah auto-calculated by adding standard offset
      fajr:    _add(azan['fajr'],    _iqamahOffset['fajr']!),
      dhuhr:   _add(azan['dhuhr'],   _iqamahOffset['dhuhr']!),
      asr:     _add(azan['asr'],     _iqamahOffset['asr']!),
      maghrib: _add(azan['maghrib'], _iqamahOffset['maghrib']!),
      isha:    _add(azan['isha'],    _iqamahOffset['isha']!),
      jummah:  _add(azan['jummah'],  _iqamahOffset['jummah']!),
      timeType: 'azan',
      confidence: confidence,
      note: 'Read via on-device ML Kit OCR',
    );
  }

  // ── Time helpers ────────────────────────────────────────────────────────────

  static String? _normalise(RegExpMatch m) {
    int h = int.parse(m.group(1)!);
    final int min = int.parse(m.group(2)!);
    final String? ap = m.group(3)?.toUpperCase();
    if (min > 59) return null;
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    // h >= 13 with no AM/PM → unambiguous 24-hour → keep
    if (h > 23) return null;
    return _fmt(TimeOfDay(hour: h, minute: min));
  }

  static String? _add(String? s, int minutes) {
    if (s == null) return null;
    final tod = _parse(s);
    if (tod == null) return null;
    int total = tod.hour * 60 + tod.minute + minutes;
    total %= 1440;
    return _fmt(TimeOfDay(hour: total ~/ 60, minute: total % 60));
  }

  static TimeOfDay? _parse(String s) {
    try {
      final dt = DateFormat('h:mm a').parse(s.trim().toUpperCase());
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {}
    try {
      final dt = DateFormat('HH:mm').parse(s.trim());
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {}
    return null;
  }

  static String _fmt(TimeOfDay tod) {
    final now = DateTime.now();
    return DateFormat.jm().format(
      DateTime(now.year, now.month, now.day, tod.hour, tod.minute),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _Block {
  final String text;
  final Rect rect;
  const _Block(this.text, this.rect);
}

class _Timed {
  final String time;
  final double y;
  const _Timed(this.time, this.y);
}
