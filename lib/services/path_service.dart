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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final uri = Uri.parse(
        '$_baseUrl/paths?limit=$limit&offset=$offset',
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

        // ── Réponse groupée {today, yesterday, older} ──────────────────
        final List today     = data['today']     ?? [];
        final List yesterday = data['yesterday'] ?? [];
        final List older     = data['older']     ?? [];

        // Combine tout dans une seule liste ordonnée
        return [
          ...today,
          ...yesterday,
          ...older,
        ].cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('PathService.getRecentPaths error: $e');
      return [];
    }
  }}
