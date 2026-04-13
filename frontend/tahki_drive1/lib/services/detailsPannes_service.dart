import 'dart:convert';
import 'package:http/http.dart' as http;

class DetailPannesService {
  static const String baseUrl = "http://10.0.2.2:8000";

  // =========================
  // GENERIC GET
  // =========================
  static Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      print("Erreur API ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("Connexion impossible ($endpoint): $e");
      return null;
    }
  }

  // =========================
  // MAINTENANCE - BATTERY
  // =========================
  static Future<Map<String, dynamic>?> fetchBattery() async {
    return await _get('/maintenance/battery');
  }

  // =========================
  // BRAKE
  // =========================
  static Future<Map<String, dynamic>?> fetchBrake() async {
    return await _get('/maintenance/brake');
  }

  // =========================
  // DISTRIBUTION
  // =========================
  static Future<Map<String, dynamic>?> fetchDistribution() async {
    return await _get('/maintenance/distribution');
  }

  // =========================
  // TIRES
  // =========================
  static Future<Map<String, dynamic>?> fetchTire() async {
    return await _get('/maintenance/tire');
  }

  // =========================
  // EMBRAYAGE
  // =========================
  static Future<Map<String, dynamic>?> fetchEmbrayage() async {
    return await _get('/maintenance/embrayage');
  }

  // =========================
  // OIL CHANGE (AJOUTÉ)
  // =========================
  static Future<Map<String, dynamic>?> fetchOilChange() async {
    return await _get('/maintenance/oil-change');
  }
}