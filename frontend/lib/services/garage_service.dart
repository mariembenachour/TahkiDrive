import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GarageService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Auth token ─────────────────────────────────────────────────────────────
  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
  }

  static Future<dynamic> _get(String path) async {
    final token = await _token();
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur HTTP ${response.statusCode} — $path');
  }

  // ── Endpoints ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAllGarages({int limit = 50}) async {
    try {
      final decoded = await _get('/garages?limit=$limit');
      if (decoded is List) return decoded;
      return decoded['garages'] ?? [];
    } catch (e) {
      print('GarageService.getAllGarages error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getTopRatedGarages({int limit = 10}) async {
    try {
      final decoded = await _get('/garages/top?limit=$limit');
      if (decoded is List) return decoded;
      return decoded['garages'] ?? [];
    } catch (e) {
      print('GarageService.getTopRatedGarages error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getNearestGarages({
    required double latitude,
    required double longitude,
    int limit = 10,
    int radiusM = 10000,
    double? minRating,
  }) async {
    try {
      String path =
          '/garages/nearest?lat=$latitude&lon=$longitude&limit=$limit&radius_m=$radiusM';
      if (minRating != null && minRating > 0) {
        path += '&min_rating=$minRating';
      }
      final decoded = await _get(path);
      if (decoded is List) return decoded;
      return decoded['garages'] ?? [];
    } catch (e) {
      print('GarageService.getNearestGarages error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getGarageStatus(int id) async {
    try {
      return await _get('/garages/$id/status') as Map<String, dynamic>?;
    } catch (e) {
      print('GarageService.getGarageStatus error: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getAllGaragesStatus({int limit = 50}) async {
    try {
      final decoded = await _get('/garages/status/all?limit=$limit');
      if (decoded is List) return decoded;
      return decoded['garages'] ?? [];
    } catch (e) {
      print('GarageService.getAllGaragesStatus error: $e');
      return [];
    }
  }

  // ── Utilitaires horaires ───────────────────────────────────────────────────

  /// Parse "HH:MM" ou "H:MM" → minutes depuis minuit.
  /// Retourne null si le format est invalide.
  static int? _parseMinutes(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    final parts = str.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// "HH:MM" normalisé pour l'affichage.
  static String _formatHour(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    final parts = str.split(':');
    if (parts.length != 2) return str;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static bool isOpenNow(Map<String, dynamic> garage) {
    final openMin  = _parseMinutes(garage['heure_ouverture']);
    final closeMin = _parseMinutes(garage['heure_fermeture']);

    // Horaires manquants ou invalides → considéré fermé
    if (openMin == null || closeMin == null) return false;

    final now        = DateTime.now();
    final nowMin     = now.hour * 60 + now.minute;
    final conge      = garage['conge'];

    // Vérification du jour de congé
    if (conge != null && conge.toString().trim().isNotEmpty) {
      const joursFr = {
        1: 'Lundi', 2: 'Mardi',    3: 'Mercredi',
        4: 'Jeudi', 5: 'Vendredi', 6: 'Samedi', 7: 'Dimanche',
      };
      final today  = joursFr[now.weekday] ?? '';
      final conges = conge.toString().split('-').map((e) => e.trim()).toList();
      if (conges.contains(today)) return false;
    }

    // Comparaison entière — plus de bug de string
    return nowMin >= openMin && nowMin <= closeMin;
  }

  static String getOpenStatusText(Map<String, dynamic> garage) {
    final openMin  = _parseMinutes(garage['heure_ouverture']);
    final closeMin = _parseMinutes(garage['heure_fermeture']);

    if (openMin == null || closeMin == null) return 'Horaires non disponibles';

    final openF  = _formatHour(garage['heure_ouverture']);
    final closeF = _formatHour(garage['heure_fermeture']);
    final conge  = garage['conge'];

    // Jour de congé ?
    if (conge != null && conge.toString().trim().isNotEmpty) {
      final now = DateTime.now();
      const joursFr = {
        1: 'Lundi', 2: 'Mardi',    3: 'Mercredi',
        4: 'Jeudi', 5: 'Vendredi', 6: 'Samedi', 7: 'Dimanche',
      };
      final today  = joursFr[now.weekday] ?? '';
      final conges = conge.toString().split('-').map((e) => e.trim()).toList();
      if (conges.contains(today)) return 'Fermé aujourd\'hui (repos)';
    }

    if (isOpenNow(garage)) return 'Ouvert • Ferme à $closeF';

    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    if (nowMin < openMin) return 'Fermé • Ouvre à $openF';
    return 'Fermé';
  }

  static Color getOpenStatusColor(Map<String, dynamic> garage) =>
      isOpenNow(garage) ? Colors.green : Colors.red;

  static String getTodayHours(Map<String, dynamic> garage) {
    final open  = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];
    if (open == null || close == null) return '';
    return '🕐 ${_formatHour(open)} - ${_formatHour(close)}';
  }
}
