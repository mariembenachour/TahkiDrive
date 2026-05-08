// services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
  );
}

class AuraChatService {
  static const String _baseUrl = 'http://10.0.2.2:8000';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Non authentifié — veuillez vous reconnecter');
    }

    final response = await http
        .post(
      Uri.parse('$_baseUrl/api/chat/message'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'message': message,
        'history': history.map((m) => m.toJson()).toList(),
      }),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reply'] as String;
    }

    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['detail'] ?? 'Erreur serveur ${response.statusCode}');
  }
}