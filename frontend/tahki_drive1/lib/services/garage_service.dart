// services/garage_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GarageService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Récupérer tous les garages
  static Future<List<dynamic>> getAllGarages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/garages'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Erreur getAllGarages: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Erreur getAllGarages: $e");
      return [];
    }
  }

  // Récupérer TOUS les garages triés par note
  static Future<List<dynamic>> getTopRatedGarages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/garages/top'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Erreur getTopRatedGarages: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Erreur getTopRatedGarages: $e");
      return [];
    }
  }

  // Récupérer les garages les plus proches
  static Future<List<dynamic>> getNearestGarages({
    int limit = 10,
    double? minRating,
    required double latitude,
    required double longitude,
  }) async {
    try {
      String url = '$baseUrl/garages/nearest?limit=$limit&lat=$latitude&lon=$longitude';
      if (minRating != null && minRating > 0) {
        url += '&min_rating=$minRating';
      }

      print("📡 Appel API: $url");

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Erreur getNearestGarages: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Erreur getNearestGarages: $e");
      return [];
    }
  }
}

class GarageOpenHelper {
  // Formater une heure (8:00 -> 08:00)
  static String _formatHour(String hour) {
    if (hour.isEmpty) return hour;
    final parts = hour.split(':');
    if (parts[0].length == 1) {
      return '0$hour';
    }
    return hour;
  }

  static bool isOpenNow(List<dynamic> horaires) {
    if (horaires == null || horaires.isEmpty) {
      return false;
    }

    // Obtenir le jour actuel en français
    final now = DateTime.now();
    final joursFrancais = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    final currentDay = joursFrancais[now.weekday - 1];
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Chercher l'horaire du jour
    for (var horaire in horaires) {
      if (horaire['jour'] == currentDay) {
        // Si le garage est fermé ce jour
        if (horaire['est_ferme'] == true) {
          return false;
        }

        final ouverture = _formatHour(horaire['heure_debut'] ?? '');
        final fermeture = _formatHour(horaire['heure_fin'] ?? '');

        if (ouverture.isNotEmpty && fermeture.isNotEmpty) {
          return currentTime.compareTo(ouverture) >= 0 &&
              currentTime.compareTo(fermeture) <= 0;
        }
        break;
      }
    }

    return false;
  }

  // Obtenir le message d'ouverture/fermeture
  static String getOpenStatusText(List<dynamic> horaires) {
    if (horaires == null || horaires.isEmpty) {
      return "Horaires non disponibles";
    }

    final now = DateTime.now();
    final joursFrancais = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    final currentDay = joursFrancais[now.weekday - 1];
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (var horaire in horaires) {
      if (horaire['jour'] == currentDay) {
        if (horaire['est_ferme'] == true) {
          return "Fermé aujourd'hui";
        }

        final ouverture = horaire['heure_debut'] ?? '';
        final fermeture = horaire['heure_fin'] ?? '';
        final ouvertureFmt = _formatHour(ouverture);
        final fermetureFmt = _formatHour(fermeture);

        if (ouverture.isNotEmpty && fermeture.isNotEmpty) {
          final isOpen = currentTime.compareTo(ouvertureFmt) >= 0 &&
              currentTime.compareTo(fermetureFmt) <= 0;
          if (isOpen) {
            return "Ouvert • Ferme à $fermeture";
          } else if (currentTime.compareTo(ouvertureFmt) < 0) {
            return "Fermé • Ouvre à $ouverture";
          } else {
            return "Fermé";
          }
        }
        break;
      }
    }

    return "Horaires non disponibles";
  }

  // Obtenir la couleur du statut
  static Color getOpenStatusColor(List<dynamic> horaires) {
    if (horaires == null || horaires.isEmpty) {
      return Colors.grey;
    }

    final isOpen = isOpenNow(horaires);
    return isOpen ? Colors.green : Colors.red;
  }

  // Obtenir les horaires du jour
  static String getTodayHours(List<dynamic> horaires) {
    if (horaires == null || horaires.isEmpty) {
      return "";
    }

    const joursFrancais = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final now = DateTime.now();
    final currentDay = joursFrancais[now.weekday - 1];

    for (var horaire in horaires) {
      if (horaire['jour'] == currentDay) {
        if (horaire['est_ferme'] == true) {
          return "Fermé aujourd'hui";
        }
        final ouverture = horaire['heure_debut'] ?? '';
        final fermeture = horaire['heure_fin'] ?? '';
        return "🕐 $ouverture - $fermeture";
      }
    }
    return "";
  }
}