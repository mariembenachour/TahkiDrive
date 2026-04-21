import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GarageService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ===================== API =====================

  static Future<List<dynamic>> getAllGarages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/garages'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("getAllGarages error: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getTopRatedGarages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/garages/top'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("getTopRatedGarages error: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getNearestGarages({
    int limit = 10,
    double? minRating,
    required double latitude,
    required double longitude,
  }) async {
    try {
      String url =
          '$baseUrl/garages/nearest?limit=$limit&lat=$latitude&lon=$longitude';

      if (minRating != null && minRating > 0) {
        url += '&min_rating=$minRating';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("getNearestGarages error: $e");
      return [];
    }
  }

  // ===================== FORMATAGE DES HEURES =====================

  static String _formatHour(String hour) {
    if (hour == null || hour.isEmpty) return "";
    final parts = hour.split(':');
    if (parts.length != 2) return hour;
    final hourPart = parts[0].padLeft(2, '0');
    final minutePart = parts[1].padLeft(2, '0');
    return "$hourPart:$minutePart";
  }

  // ===================== OPEN LOGIC =====================

  static bool isOpenNow(Map<String, dynamic> garage) {
    final open = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];
    final conge = garage['conge'];

    if (open == null || close == null) return false;

    final now = DateTime.now();
    final currentHour = now.hour.toString().padLeft(2, '0');
    final currentMinute = now.minute.toString().padLeft(2, '0');
    final currentTime = "$currentHour:$currentMinute";

    // Formater les heures
    final openFormatted = _formatHour(open.toString());
    final closeFormatted = _formatHour(close.toString());

    // mapping jours FR vers EN (car backend utilise anglais)
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    final today = days[now.weekday % 7];

    // Vérifier les congés
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

    if (open == null || close == null) return "Horaires non disponibles";

    final isOpen = isOpenNow(garage);
    final openFormatted = _formatHour(open.toString());
    final closeFormatted = _formatHour(close.toString());

    if (isOpen) {
      return "Ouvert • Ferme à $closeFormatted";
    } else {
      // Vérifier si c'est avant ou après l'ouverture
      final now = DateTime.now();
      final currentHour = now.hour.toString().padLeft(2, '0');
      final currentMinute = now.minute.toString().padLeft(2, '0');
      final currentTime = "$currentHour:$currentMinute";

      if (currentTime.compareTo(openFormatted) < 0) {
        return "Fermé • Ouvre à $openFormatted";
      } else {
        return "Fermé";
      }
    }
  }

  static Color getOpenStatusColor(Map<String, dynamic> garage) {
    return isOpenNow(garage) ? Colors.green : Colors.red;
  }

  static String getTodayHours(Map<String, dynamic> garage) {
    final open = garage['heure_ouverture'];
    final close = garage['heure_fermeture'];

    if (open == null || close == null) return "";

    final openFormatted = _formatHour(open.toString());
    final closeFormatted = _formatHour(close.toString());

    return "🕐 $openFormatted - $closeFormatted";
  }
}