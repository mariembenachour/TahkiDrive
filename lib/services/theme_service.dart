import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  ThemeService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') _mode = ThemeMode.light;
    else if (saved == 'dark') _mode = ThemeMode.dark;
    else _mode = ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final val = mode == ThemeMode.light ? 'light'
        : mode == ThemeMode.dark  ? 'dark'
        : 'system';
    await prefs.setString(_key, val);
  }

  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }
}
