import 'package:flutter/material.dart';

/// Convenience extension for inline locale-aware strings.
///
/// Usage:
///   context.localText(en: 'Save', ar: 'حفظ', ur: 'محفوظ کریں', ru: 'Сохранить')
extension LocaleText on BuildContext {
  String localText({
    required String en,
    required String ar,
    required String ur,
    required String ru,
    String? fa,
    String? nl,
    String? zh,
  }) {
    switch (Localizations.localeOf(this).languageCode) {
      case 'ar':
        return ar;
      case 'ur':
        return ur;
      case 'ru':
        return ru;
      case 'fa':
        return fa ?? en;
      case 'nl':
        return nl ?? en;
      case 'zh':
        return zh ?? en;
      default:
        return en;
    }
  }
}
