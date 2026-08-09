import 'package:flutter/material.dart';
import '../core/storage/app_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs) {
    _load();
  }

  final AppPreferences _prefs;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    _isDarkMode = await _prefs.isDarkModeEnabled;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await _prefs.setDarkModeEnabled(value);
  }
}
