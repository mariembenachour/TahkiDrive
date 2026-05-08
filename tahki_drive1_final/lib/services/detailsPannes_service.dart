import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DetailPannesService {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); // ← clé utilisée dans ton service
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      print("Erreur API ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("Connexion impossible ($endpoint): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createSav(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sav/me'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      debugPrint("📡 Status: ${response.statusCode}");
      debugPrint("📡 Body: ${response.body}");  // ← ajoute ça

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("Erreur createSav: $e");
      return null;
    }
  }
  static Future<bool> updateSav(int idSav, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sav/$idSav'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      debugPrint("📡 Update SAV: ${response.statusCode} - ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Erreur updateSav: $e");
      return false;
    }
  }

  static Future<bool> deleteSav(int idSav) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sav/$idSav'),
        headers: await _headers(),
      );
      debugPrint("📡 Delete SAV: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Erreur deleteSav: $e");
      return false;
    }
  }
  static Future<List<String>> fetchMaintenanceTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sav/maintenance-types'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      }
      return [];
    } catch (e) {
      print("Erreur fetchMaintenanceTypes: $e");
      return [];
    }
  }
  // Méthodes existantes
  static Future<Map<String, dynamic>?> fetchBattery() async =>
      await _get('/maintenance/battery');
  static Future<Map<String, dynamic>?> fetchBrake() async =>
      await _get('/maintenance/brake');
  static Future<Map<String, dynamic>?> fetchDistribution() async =>
      await _get('/maintenance/distribution');
  static Future<Map<String, dynamic>?> fetchTire() async =>
      await _get('/maintenance/tire');
  static Future<Map<String, dynamic>?> fetchEmbrayage() async =>
      await _get('/maintenance/embrayage');
  static Future<Map<String, dynamic>?> fetchOilChange() async =>
      await _get('/maintenance/oil-change');
  static Future<Map<String, dynamic>?> fetchMoteur() async =>
      await _get('/maintenance/moteur');
}

