import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tahki_drive1/services/auth_service.dart';

class EventService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── HTTP HELPERS ──────────────────────────────────────────────────────────

  static Future<dynamic> _get(String endpoint) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      if (response.statusCode == 200) return json.decode(response.body);
      print("Erreur GET ($endpoint): ${response.statusCode}");
      return null;
    } catch (e) {
      print("GET Error ($endpoint): $e");
      return null;
    }
  }

  static Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return json.decode(response.body);
      print("Erreur POST ($endpoint): ${response.statusCode} — ${response.body}");
      return null;
    } catch (e) {
      print("POST Error ($endpoint): $e");
      return null;
    }
  }

  static Future<dynamic> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      print("Erreur PUT ($endpoint): ${response.statusCode} — ${response.body}");
      return null;
    } catch (e) {
      print("PUT Error ($endpoint): $e");
      return null;
    }
  }

  static Future<bool> _delete(String endpoint) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      print("Erreur DELETE ($endpoint): ${response.statusCode} — ${response.body}");
      return false;
    } catch (e) {
      print("DELETE Error ($endpoint): $e");
      return false;
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  static Future<bool> createDocument({
    required String docType,
    required DateTime endDate,
  }) async {
    final result = await _post('/events/document', {
      'doc_type': docType,
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    return result != null;
  }

  static Future<bool> createOffense({
    required String offenseType,
    required DateTime offenseDate,
    required double paying,
  }) async {
    final result = await _post('/events/offense', {
      'offense_type': offenseType,
      'offense_date': offenseDate.toIso8601String().split('T')[0],
      'paying': paying,
    });
    return result != null;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  static Future<bool> updateEvent({
    required Map event,
    String? docType,
    DateTime? endDate,
    String? offenseType,   // ← nouveau
    DateTime? offenseDate,
    double? paying,
  }) async {
    final id = event['id'];
    if (id == null) return false;

    final isOffense = (event['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';

    dynamic result;
    if (isOffense) {
      result = await _put('/events/offense/$id', {
        'offense_type': offenseType!,   // ← manquait
        'offense_date': offenseDate!.toIso8601String().split('T')[0],
        'paying': paying,
      });
    } else {
      result = await _put('/events/document/$id', {
        'doc_type': docType!,
        'end_date': endDate!.toIso8601String().split('T')[0],
      });
    }
    return result != null;
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  static Future<bool> deleteEvent(Map event) async {
    final id = event['id'];
    if (id == null) {
      print("deleteEvent: id est null, keys disponibles: ${event.keys.toList()}");
      return false;
    }
    return await _delete('/events/$id');
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchEvents() async {
    final data = await _get('/events');
    if (data == null) return {'all_events': [], 'upcoming_events': [], 'recent_events': []};
    final raw = data['events'] as Map<String, dynamic>? ?? data;
    final all = List<dynamic>.from(raw['all_events'] ?? [])
        .map((e) => normalizeEvent(Map<String, dynamic>.from(e))).toList();
    final upcoming = List<dynamic>.from(raw['upcoming_events'] ?? [])
        .map((e) => normalizeEvent(Map<String, dynamic>.from(e))).toList();
    final recent = List<dynamic>.from(raw['recent_events'] ?? [])
        .map((e) => normalizeEvent(Map<String, dynamic>.from(e))).toList();
    return {'all_events': all, 'upcoming_events': upcoming, 'recent_events': recent};
  }

  static Future<List<dynamic>> fetchAllEvents() async => (await fetchEvents())['all_events'] ?? [];
  static Future<List<dynamic>> fetchUpcomingEvents() async => (await fetchEvents())['upcoming_events'] ?? [];
  static Future<List<dynamic>> fetchRecentEvents() async => (await fetchEvents())['recent_events'] ?? [];
  static Future<List<dynamic>> fetchHistoriqueEvents() async => fetchRecentEvents();

  static Map<String, dynamic> normalizeEvent(Map<String, dynamic> e) {
    final event = Map<String, dynamic>.from(e);
    final isOffense = (event['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';

    if (event['event_category'] == 'maintenance') {
      event['_calendar_date'] = event['date_reparation'];
    } else if (isOffense) {
      event['_calendar_date'] = event['offense_date'];  // ← date de l'infraction
    } else {
      event['_calendar_date'] = event['end_date'];  // ← date d'expiration du doc (pas 'date' !)
    }

    if (event['estimated_next_date'] != null) {
      event['_next_date'] = event['estimated_next_date'];
      event['display_mode'] = 'date';
    } else if (event['next_oil_km'] != null) {
      event['display_mode'] = 'km';
    }
    if (event['event_category'] == 'document') event['display_mode'] = 'date';
    return event;
  }}
