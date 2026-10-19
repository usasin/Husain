import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Contrôleur volontairement simple : PRONO4 propose uniquement Clair/Sombre.
/// Pas de mode système afin d'éviter les bascules implicites et les états
/// intermédiaires difficiles à comprendre pour l'utilisateur.
class AppThemeController extends ChangeNotifier {
  static const _key = 'prono4_theme_mode';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _mode = raw == 'light' ? ThemeMode.light : ThemeMode.dark;
    _syncPalette();
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    // Toute ancienne valeur "system" est volontairement rabattue sur sombre.
    final next = value == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    if (_mode == next) return;

    // La palette est mise à jour AVANT notifyListeners pour que tous les
    // widgets reconstruits lisent immédiatement les bonnes AppColors.
    _mode = next;
    _syncPalette();
    notifyListeners();

    // La persistance ne bloque pas le rendu visuel.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.light ? 'light' : 'dark');
  }

  Brightness resolvedBrightness() =>
      _mode == ThemeMode.light ? Brightness.light : Brightness.dark;

  void _syncPalette() {
    AppColors.lightMode = _mode == ThemeMode.light;
  }
}
