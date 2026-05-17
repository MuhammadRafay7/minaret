/// fiqh_constants.dart
/// Single source of truth for all Fiqh / Madhab options.
/// Import this wherever a Fiqh selector or filter is needed.

class FiqhConstants {
  FiqhConstants._();

  /// All selectable Fiqh values stored in Firestore.
  /// The key is the Firestore string value; the value is the display label.
  static const Map<String, String> options = {
    '': 'Not Specified',
    'sunni_hanafi': 'Sunni — Hanafi',
    'sunni_shafii': 'Sunni — Shāfiʿī',
    'sunni_maliki': 'Sunni — Mālikī',
    'sunni_hanbali': 'Sunni — Ḥanbalī',
    'sunni_deobandi': 'Sunni — Deobandi',
    'sunni_barelvi': 'Sunni — Barelvi',
    'sunni_salafi': 'Sunni — Salafi / Ahl al-Hadith',
    'shia_ithna': 'Shia — Ithna Ashari',
    'shia_ismaili': 'Shia — Ismaili',
    'other': 'Other',
  };

  /// Ordered list of keys for rendering chips/dropdowns in a stable sequence.
  static const List<String> orderedKeys = [
    '',
    'sunni_hanafi',
    'sunni_shafii',
    'sunni_maliki',
    'sunni_hanbali',
    'sunni_deobandi',
    'sunni_barelvi',
    'sunni_salafi',
    'shia_ithna',
    'shia_ismaili',
    'other',
  ];

  /// Returns the display label for a stored key.
  /// Falls back to 'Not Specified' for unknown values.
  static String labelFor(String? key) {
    if (key == null || key.isEmpty) return options['']!;
    return options[key] ?? 'Not Specified';
  }

  /// Returns true if the given key is a valid, non-empty Fiqh value.
  static bool isValid(String? key) => key != null && options.containsKey(key);

  /// Broad category helpers for UI grouping.
  static bool isSunni(String key) => key.startsWith('sunni_');
  static bool isShia(String key) => key.startsWith('shia_');
}
