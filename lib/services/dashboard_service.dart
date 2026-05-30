import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashService {
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
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      print("Erreur API ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("GET Error ($endpoint): $e");
      return null;
    }
  }

  // ── VEHICULES ─────────────────────────────────────────────────────────────
  // Le back retourne { "vehicule": { ... } } — un seul objet, pas une liste
  static Future<List<dynamic>> getUserVehicules() async {
    final data = await _get('/vehicules');
    if (data == null) return [];

    // Le backend retourne { "vehicule": { ... } }
    if (data['vehicule'] != null) {
      return [data['vehicule']];
    }

    // Fallback si jamais le back retourne une liste { "vehicules": [...] }
    if (data['vehicules'] != null) {
      return List<dynamic>.from(data['vehicules']);
    }

    return [];
  }

  // ── ODO ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchOdo() async {
    return await _get('/odo');
  }

  // ── TEMPÉRATURE ───────────────────────────────────────────────────────────
  static Future<double?> getLastTemp() async {
    final data = await _get('/vehicule/temp');
    if (data == null) return null;

    final temp = data['last_temp'];
    if (temp == null || temp.toString() == "Pas de donnée") return null;

    return double.tryParse(temp.toString());
  }

  // ── MAINTENANCE ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getLastOilChange() async {
    final data = await _get('/oil-change/last');
    if (data == null) return null;
    if (data.containsKey('message')) return null;
    return data;
  }

  static Future<Map<String, dynamic>?> getLastBattery() async {
    final data = await _get('/battery/last');
    if (data == null) return null;
    if (data.containsKey('message')) return null;
    return data;
  }

  static Future<Map<String, dynamic>?> getAllDashboardData() async {
    return await _get('/dashboard/all');
  }

  // ── CARBURANT ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchFuel() async {
    return await _get('/fuelings');
  }

  // ── LOCALISATION ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchLocation() async {
    return await _get('/location');
  }
}
