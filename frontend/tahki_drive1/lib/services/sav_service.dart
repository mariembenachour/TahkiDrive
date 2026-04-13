import 'dart:convert';
import 'package:http/http.dart' as http;

class SavSinistreService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // =========================
  // GENERIC GET
  // =========================
  static Future<List<dynamic>> fetchSav({String? type}) async {
    try {
      final uri = type != null
          ? Uri.parse('$baseUrl/sav/me?category=$type')
          : Uri.parse('$baseUrl/sav/me');

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
    return await fetchSav(type: 'accident');
  }

  // =========================
  // PANNES
  // =========================
  static Future<List<dynamic>> fetchPannes() async {
    return await fetchSav(type: 'panne');
  }

  // =========================
  // TOUS SAV
  // =========================
  static Future<List<dynamic>> fetchAllSav() async {
    return await fetchSav();
  }
}