import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _storageKey = 'app_locale_code';
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_storageKey);
    if (savedCode == null || savedCode.isEmpty) return;
    _currentLocale = Locale(savedCode);
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    _persistLocale(locale.languageCode);
    notifyListeners();
  }

  Future<void> _persistLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
  }
}
