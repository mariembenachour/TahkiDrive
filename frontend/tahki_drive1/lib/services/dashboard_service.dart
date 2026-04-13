import 'dart:convert';
import 'package:http/http.dart' as http;

class DashService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static int? vehiculeId;

  // =========================
  // GENERIC GET
  // =========================
  static Future<dynamic> _get(String endpoint) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      print("Erreur API ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("GET Error ($endpoint): $e");
      return null;
    }
  }

  // =========================
  // VEHICULES
  // =========================
  static Future<List<dynamic>> getUserVehicules() async {
    final data = await _get('/vehicules');
    return data?['vehicules'] ?? [];
  }

  // =========================
  // ODO
  // =========================
  static Future<Map<String, dynamic>?> fetchOdo() async {
    return await _get('/odo');
  }

  // =========================
  // TEMPÉRATURE
  // =========================
  static Future<double?> getLastTemp() async {
    final url = vehiculeId == null
        ? '/vehicule/temp'
        : '/vehicule/temp?vehicule_id=$vehiculeId';

    final data = await _get(url);

    if (data == null) return null;

    final temp = data['last_temp'];

    if (temp == null || temp.toString() == "Pas de donnée") {
      return null;
    }

    return double.tryParse(temp.toString());
  }

  // =========================
  // OIL CHANGE (AJOUTÉ)
  // =========================
  static Future<Map<String, dynamic>?> getLastOilChange() async {
    final url = vehiculeId == null
        ? '/oil-change/last'
        : '/oil-change/last?vehicule_id=$vehiculeId';

    final data = await _get(url);

    if (data == null) return null;

    if (data.containsKey('message')) return null;

    return data;
  }

  // =========================
  // BATTERY (AJOUTÉ)
  // =========================
  static Future<Map<String, dynamic>?> getLastBattery() async {
    final url = vehiculeId == null
        ? '/battery/last'
        : '/battery/last?vehicule_id=$vehiculeId';

    final data = await _get(url);

    if (data == null) return null;

    if (data.containsKey('message')) return null;

    return data;
  }

  // =========================
  // DASHBOARD GLOBAL
  // =========================
  static Future<Map<String, dynamic>?> getAllDashboardData() async {
    final url = vehiculeId == null
        ? '/dashboard/all'
        : '/dashboard/all?vehicule_id=$vehiculeId';

    return await _get(url);
  }

  // =========================
  // FUEL
  // =========================
  static Future<Map<String, dynamic>?> fetchFuel() async {
    return await _get('/fuelings');
  }

  // =========================
  // LOCATION
  // =========================
  static Future<Map<String, dynamic>?> fetchLocation() async {
    return await _get('/location');
  }

  // =========================
  // SET VEHICULE
  // =========================
  static void setVehicule(int id) {
    vehiculeId = id;
  }
}