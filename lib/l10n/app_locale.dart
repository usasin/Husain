import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  static const _key = 'prono4_language';
  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'fr' || value == 'en') _locale = Locale(value!);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      _locale = null;
      await prefs.remove(_key);
    } else {
      _locale = Locale(code);
      await prefs.setString(_key, code);
    }
    notifyListeners();
  }
}

extension Prono4Translation on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';
  String tr(String fr, String en) => isEnglish ? en : fr;
}
