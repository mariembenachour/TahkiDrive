// ─────────────────────────────────────────────────────────────────────────────
// lib/services/path_service.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PathService {
  static const String _baseUrl = 'http://10.0.2.2:8000'; // ← adapte

  // ── Récupère les N derniers trajets du device lié au chauffeur ─────────────
  static Future<List<Map<String, dynamic>>> getRecentPaths({
    int limit = 5,
    int offset = 0,
  }) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final token    = prefs.getString('auth_token') ?? '';
      final deviceId = prefs.getString('device_id')  ?? '';

      final uri = Uri.parse(
        '$_baseUrl/paths?device_id=$deviceId&limit=$limit&offset=$offset',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['paths'] ?? data ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('PathService.getRecentPaths error: $e');
      return [];
    }
  }
}
