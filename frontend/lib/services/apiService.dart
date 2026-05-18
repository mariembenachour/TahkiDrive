// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'language_service.dart';
import 'auth_service.dart';

class ApiService {
  static String get _base =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  static LanguageService? _langService;

  static void init(LanguageService ls) => _langService = ls;

  /// If [bearerToken] is non-`null`, Authorization uses it when non-empty (empty = no header).
  /// If [bearerToken] is `null`, [includeAuth] selects AuthService tokens when true.
  static Future<Map<String, String>> _buildHeaders({
    String? bearerToken,
    bool includeAuth = true,
  }) async {
    final lang = _langService?.lang ?? 'fr';
    String? authHeader;
    if (bearerToken != null) {
      if (bearerToken.isNotEmpty) authHeader = bearerToken;
    } else if (includeAuth) {
      authHeader =
          await AuthService.getAuthToken() ?? await AuthService.getSetupToken();
    }
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept-Language': lang,
      if (authHeader != null && authHeader.isNotEmpty)
        'Authorization': 'Bearer $authHeader',
    };
  }

  static dynamic _decodeBody(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final decoded = _decodeBody(res);
    if (decoded is Map && decoded['detail'] != null) {
      throw Exception(decoded['detail'].toString());
    }
    throw Exception('HTTP ${res.statusCode}');
  }

  static Future<dynamic> get(
      String path, {
        String? bearerToken,
        bool includeAuth = true,
      }) async {
    final headers = await _buildHeaders(
      bearerToken: bearerToken,
      includeAuth: includeAuth,
    );

    // DEBUG TEMPORAIRE
    print('>>> GET $_base$path');
    print('>>> LANG: ${headers['Accept-Language']}');
    print('>>> AUTH: ${headers['Authorization']}');

    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: headers,
    );

    // DEBUG TEMPORAIRE
    print('>>> STATUS: ${res.statusCode}');
    print('>>> BODY: ${res.body}');

    _ensureSuccess(res);
    return _decodeBody(res);
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
    bool includeAuth = true,
  }) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: await _buildHeaders(
        bearerToken: bearerToken,
        includeAuth: includeAuth,
      ),
      body: jsonEncode(body),
    );
    _ensureSuccess(res);
    return _decodeBody(res);
  }

  static Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
    bool includeAuth = true,
  }) async {
    final res = await http.put(
      Uri.parse('$_base$path'),
      headers: await _buildHeaders(
        bearerToken: bearerToken,
        includeAuth: includeAuth,
      ),
      body: jsonEncode(body),
    );
    _ensureSuccess(res);
    return _decodeBody(res);
  }

  static Future<dynamic> delete(
    String path, {
    String? bearerToken,
    bool includeAuth = true,
  }) async {
    final res = await http.delete(
      Uri.parse('$_base$path'),
      headers: await _buildHeaders(
        bearerToken: bearerToken,
        includeAuth: includeAuth,
      ),
    );
    _ensureSuccess(res);
    return _decodeBody(res);
  }

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
    bool includeAuth = true,
  }) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: await _buildHeaders(
        bearerToken: bearerToken,
        includeAuth: includeAuth,
      ),
      body: jsonEncode(body),
    );
    _ensureSuccess(res);
    return _decodeBody(res);
  }

  static Future<void> updateUserLanguage(String langCode) async {
    try {
      final token = await AuthService.getAuthToken();
      final response = await http.patch(
        Uri.parse('$_base/api/users/update-language/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept-Language': langCode,
        },
        body: jsonEncode({'language': langCode}),
      );
      print('Language updated on backend: ${response.statusCode}');
    } catch (e) {
      print('Failed to update language on backend: $e');
    }
  }

}
