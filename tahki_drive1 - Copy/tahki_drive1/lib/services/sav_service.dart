import 'dart:convert';
import 'package:http/http.dart' as http;

class SavService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // =========================
  // GENERIC GET
  // =========================
  static Future<List<dynamic>> fetchSav({String? type}) async {
    try {
      final uri = Uri.parse('$baseUrl/sav/me').replace(
        queryParameters: type != null ? {'category': type} : null,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['sav'] ?? [];
      }

      throw Exception("Erreur API : ${response.statusCode}");
    } catch (e) {
      throw Exception("Erreur récupération SAV : $e");
    }
  }

  // =========================
  // ACCIDENTS
  // =========================
  static Future<List<dynamic>> fetchAccidents() async {
    return fetchSav(type: 'accident');
  }

  // =========================
  // PANNES
  // =========================
  static Future<List<dynamic>> fetchPannes() async {
    return fetchSav(type: 'panne');
  }

  // =========================
  // TOUS SAV
  // =========================
  static Future<List<dynamic>> fetchAllSav() async {
    return fetchSav(); // aucun filtre
  }
}