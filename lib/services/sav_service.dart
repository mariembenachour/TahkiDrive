

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SavService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> fetchSav({String? type}) async {
    try {
      final uri = Uri.parse('$baseUrl/sav/me').replace(
        queryParameters: type != null ? {'category': type} : null,
      );

      final response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['sav'] ?? [];
      }

      throw Exception("Erreur API : ${response.statusCode}");
    } catch (e) {
      throw Exception("Erreur récupération SAV : $e");
    }
  }

  static Future<List<dynamic>> fetchAccidents() async =>
      fetchSav(type: 'accident');


  static Future<List<dynamic>> fetchAllSav() async =>
      fetchSav();
}



