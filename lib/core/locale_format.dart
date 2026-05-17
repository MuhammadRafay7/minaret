import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class LocaleFormat {
  LocaleFormat._();

  static String decimal(BuildContext context, num value, {int digits = 1}) {
    final code = Localizations.localeOf(context).languageCode;
    return NumberFormat.decimalPatternDigits(
      locale: code,
      decimalDigits: digits,
    ).format(value);
  }

  static String localizedDigits(BuildContext context, String input) {
    final code = Localizations.localeOf(context).languageCode;
    final digitMap = _digitMaps[code];
    if (digitMap == null) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(digitMap[char] ?? char);
    }
    return buffer.toString();
  }

  static DateTime? parsePrayerTimeToday(String input, {DateTime? base}) {
    if (input.trim().isEmpty || input.trim() == '--:--') return null;
    final now = base ?? DateTime.now();
    final normalized = _normalizeToAsciiDigits(input)
        .trim()
        .toUpperCase()
        .replaceAll('.', ':')
        .replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$',
    ).firstMatch(normalized);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final suffix = match.group(3);
    if (minute < 0 || minute > 59) return null;

    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour < 0 || hour > 23) {
      return null;
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static String prayerDisplayTime(BuildContext context, String input) {
    final parsed = parsePrayerTimeToday(input);
    if (parsed == null) return localizedDigits(context, input);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return localizedDigits(context, DateFormat.jm(locale).format(parsed));
  }

  static String _normalizeToAsciiDigits(String input) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    final out = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      out.write(map[ch] ?? ch);
    }
    return out.toString();
  }

  static const Map<String, Map<String, String>> _digitMaps = {
    'ar': {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    },
    'fa': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
    'ur': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
  };
}
