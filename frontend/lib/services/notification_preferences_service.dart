import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _get(String endpoint) async {
    try {
      final headers = await _headers();
      final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      if (response.statusCode == 200) return json.decode(response.body);
      print("Erreur API ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("GET Error ($endpoint): $e");
      return null;
    }
  }

  static Future<dynamic> _put(String endpoint, dynamic body) async {
    try {
      final headers = await _headers();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      print("Erreur PUT ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("PUT Error ($endpoint): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPreferences() async {
    return await _get('/api/agent/notif-preferences');
  }

  // ← notifPreferences est Map<String, dynamic> pour supporter daily_report_hour (int)
  static Future<bool> updatePreferences({
    required Map<String, dynamic> notifPreferences,
    required List<int> reminderThresholds,
  }) async {
    final result = await _put('/api/agent/notif-preferences', {
      'notif_preferences': notifPreferences,
      'reminder_thresholds': reminderThresholds,
    });
    return result != null && result['success'] == true;
  }

  static Map<String, dynamic> getDefaultNotifPreferences() {
    return {
      'pannes':             true,
      'vitesse':            true,
      'telephone':          true,
      'distraction':        true,
      'fatigue':            true,
      'fume':               true,
      'securite':           true,
      'info':               true,
      'daily_report':       true,
      'daily_report_hour':  20,
    };
  }

  static List<int> getDefaultReminderThresholds() {
    return [1800, 3600, 86400, 259200, 604800, 1209600];
  }

  static String thresholdToLabel(int seconds) {
    switch (seconds) {
      case 1800:    return '30 minutes';
      case 3600:    return '1 heure';
      case 86400:   return '24 heures';
      case 259200:  return '3 jours';
      case 604800:  return '7 jours';
      case 1209600: return '14 jours';
      default:      return '$seconds secondes';
    }
  }

  static List<int> getAvailableThresholds() {
    return [1800, 3600, 86400, 259200, 604800, 1209600];
  }

  static String hourToLabel(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
}
