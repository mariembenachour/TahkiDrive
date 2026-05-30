import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  static Future<Map<String, dynamic>> fetchThresholds() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/agent/thresholds'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur fetch thresholds: ${response.statusCode}');
    }
  }

  static Future<bool> updateThresholds(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/agent/thresholds'),
      headers: await _headers(),
      body: json.encode(data),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/me'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['driver'];
    } else {
      throw Exception(
          'Erreur lors de la récupération du profil : ${response.statusCode}');
    }
  }
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/auth/update-profile'),
      headers: await _headers(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print("Erreur update profile: ${response.body}");
      return false;
    }
  }
}
