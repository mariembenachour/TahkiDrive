// lib/services/driver_dashboard_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DriverDashboardService {
  static const String _baseUrl = 'http://10.0.2.2:8000';

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
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));

      print('>>> [DASHBOARD] GET $endpoint - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print('>>> [DASHBOARD] Error body: ${response.body}');
      return null;
    } catch (e) {
      print('>>> [DASHBOARD] GET Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDashboard() async {
    final data = await _get('/driver/dashboard');
    return data as Map<String, dynamic>?;
  }

  // ← NOUVEAU : Récupérer les stats hebdomadaires
  static Future<Map<String, dynamic>?> getWeeklyStats() async {
    final data = await _get('/driver/dashboard/stats');
    return data as Map<String, dynamic>?;
  }
}
