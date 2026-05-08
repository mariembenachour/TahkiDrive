

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GarageService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Auth token ────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Tous les garages ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getAllGarages() async {
    try {
      final headers = await _headers();
      final response =
      await http.get(Uri.parse('$baseUrl/garages'), headers: headers);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        return decoded['garages'] ?? [];
      }
      return [];
    } catch (e) {
      print('GarageService.getAllGarages error: $e');
      return [];
    }
  }

  // ── Top rated ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getTopRatedGarages({int limit = 10}) async {
    try {
      final headers = await _headers();
      final response = await http.get(
          Uri.parse('$baseUrl/garages/top?limit=$limit'),
          headers: headers);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        return decoded['garages'] ?? [];
      }
      return [];
    } catch (e) {
      print('GarageService.getTopRatedGarages error: $e');
      return [];
    }
  }

  // ── Garages les plus proches (NearestMechanicsPage) ───────────────────────
  static Future<List<dynamic>> getNearestGarages({
    int limit = 10,
    double? minRating,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final headers = await _headers();
      String url =
          '$baseUrl/garages/nearest?limit=$limit&lat=$latitude&lon=$longitude';
      if (minRating != null && minRating > 0) {
        url += '&min_rating=$minRating';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        return decoded['garages'] ?? [];
      }
      return [];
    } catch (e) {
      print('GarageService.getNearestGarages error: $e');
      return [];
    }
  }

  // ── Garages les plus proches avec détails (DiagnosticDetailPage) ──────────
  static Future<List<dynamic>> getNearestGaragesWithDetails({
    required double lat,
    required double lon,
    int limit = 5,
  }) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse(
          '$baseUrl/api/garages/nearest?lat=$lat&lon=$lon&limit=$limit');
      final response = await http.get(uri, headers: headers);

      print('>>> GarageService nearest status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['garages'] is List) {
          return decoded['garages'];
        }
      }
      print('>>> GarageService error: ${response.body}');
      return [];
    } catch (e) {
      print('GarageService.getNearestGaragesWithDetails error: $e');
      return [];
    }
  }

  // ── Garage par ID ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getGarageById(int id) async {
    try {
      final headers = await _headers();
      final response = await http.get(
          Uri.parse('$baseUrl/api/garages/$id'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('GarageService.getGarageById error: $e');
      return null;
    }
  }

  // ── Utilitaires horaires ──────────────────────────────────────────────────
  static String _formatHour(String hour) {
    if (hour.isEmpty) return '';
    final parts = hour.split(':');
    if (parts.length != 2) return hour;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static bool isOpenNow(Map<String, dynamic> garage) {
    final open = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];
    final conge = garage['conge'];

    if (open == null || close == null) return false;

    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final openFormatted = _formatHour(open.toString());
    final closeFormatted = _formatHour(close.toString());

    const days = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday'
    ];
    final today = days[now.weekday % 7];

    if (conge != null && conge.toString().isNotEmpty) {
      final joursConge = conge.toString().split('-');
      if (joursConge.contains(today)) return false;
    }

    return currentTime.compareTo(openFormatted) >= 0 &&
        currentTime.compareTo(closeFormatted) <= 0;
  }

  static String getOpenStatusText(Map<String, dynamic> garage) {
    final open = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];

    if (open == null || close == null) return 'Horaires non disponibles';

    final openFormatted = _formatHour(open.toString());
    final closeFormatted = _formatHour(close.toString());

    if (isOpenNow(garage)) {
      return 'Ouvert • Ferme à $closeFormatted';
    }

    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (currentTime.compareTo(openFormatted) < 0) {
      return 'Fermé • Ouvre à $openFormatted';
    }
    return 'Fermé';
  }

  static Color getOpenStatusColor(Map<String, dynamic> garage) {
    return isOpenNow(garage) ? Colors.green : Colors.red;
  }

  static String getTodayHours(Map<String, dynamic> garage) {
    final open = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];
    if (open == null || close == null) return '';
    return '🕐 ${_formatHour(open.toString())} - ${_formatHour(close.toString())}';
  }
}
