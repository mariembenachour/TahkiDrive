import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfileService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // --- Récupérer le profil du driver connecté ---
  static Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/me'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['driver'];
    } else {
      throw Exception('Erreur lors de la récupération du profil : ${response.statusCode}');
    }
  }
}