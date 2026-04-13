import 'dart:convert';
import 'package:http/http.dart' as http;

class EventService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> fetchEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/api/event/events'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception('Erreur lors de la récupération des événements : ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> fetchAllEvents() async {
    final data = await fetchEvents();
    return data['events']['all_events'] ?? [];
  }

  static Future<List<dynamic>> fetchUpcomingEvents() async {
    final data = await fetchEvents();
    return data['events']['upcoming_events'] ?? [];
  }

  static Future<List<dynamic>> fetchHistoriqueEvents() async {
    final data = await fetchEvents();
    final all = data['events']['all_events'] as List<dynamic>? ?? [];
    return all.where((e) => e['is_upcoming'] == false).toList();
  }
}