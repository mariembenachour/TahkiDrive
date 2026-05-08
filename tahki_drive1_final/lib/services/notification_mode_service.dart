import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationModeService {
  static const String _key = 'notification_modes';

  static const String SON = 'son';
  static const String VIBRATION = 'vibration';
  static const String SON_VIBRATION = 'son_vibration';
  static const String SILENCIEUX = 'silencieux';

  static Future<Map<String, String>> getModes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return _defaults();
    try {
      return Map<String, String>.from(jsonDecode(raw));
    } catch (_) {
      return _defaults();
    }
  }

  static Future<void> saveModes(Map<String, String> modes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(modes));
  }

  static Map<String, String> _defaults() => {
    'critique': SON_VIBRATION,
    'conduite': SON,
    'rappels':  SON,
  };
}
