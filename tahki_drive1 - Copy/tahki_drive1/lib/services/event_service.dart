import 'dart:convert';
import 'package:http/http.dart' as http;

class EventService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Retourne le dict complet {"all_events": [...], "upcoming_events": [...]}
  static Future<Map<String, dynamic>> fetchEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/events'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> fullData = json.decode(response.body);
      // Le backend renvoie {"events": {"all_events": [...], "upcoming_events": [...]}}
      // On retourne directement le sous-objet "events"
      return fullData['events'] as Map<String, dynamic>? ?? {};
    } else {
      throw Exception('Erreur API : ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> fetchAllEvents() async {
    final data = await fetchEvents();
    return data['all_events'] ?? [];
  }

  static Future<List<dynamic>> fetchUpcomingEvents() async {
    final data = await fetchEvents();
    return data['upcoming_events'] ?? [];
  }

  static Future<List<dynamic>> fetchHistoriqueEvents() async {
    final data = await fetchEvents();
    final List<dynamic> all = data['all_events'] ?? [];
    return all.where((e) => e['is_upcoming'] == false).toList();
  }
}