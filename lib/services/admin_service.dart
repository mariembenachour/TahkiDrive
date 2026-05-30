import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static String get _base =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  static const String _keyAdminToken = 'admin_token';

  // ─── TOKEN ───────────────────────────────────────────────────────────────
  static Future<void> setToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyAdminToken, token);
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyAdminToken);
  }

  static Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyAdminToken);
  }

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  static Future<Map<String, String>> _headers() async {
    final t = await getToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  static Future<void> loginAdmin(
      {required String email, required String password}) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login/admin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await setToken(data['access_token']);
      return;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Erreur de connexion admin');
  }

  // ─── STATS ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final res = await http.get(
      Uri.parse('$_base/admin/stats'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Erreur stats');
  }

  // ─── DRIVERS ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDrivers(
      {String status = 'all'}) async {
    final res = await http.get(
      Uri.parse('$_base/admin/drivers?status=$status'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Erreur drivers');
  }

// ← Changer int userId → String cin partout

  static Future<Map<String, dynamic>> getDriverDetail(String cin) async {
    final res = await http.get(
      Uri.parse('$_base/admin/drivers/$cin'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Erreur détail driver');
  }

  static Future<void> activateDriver(String cin) async {
    final res = await http.post(
      Uri.parse('$_base/admin/drivers/$cin/activate'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw Exception('Erreur activation');
  }

  static Future<void> blockDriver(String cin) async {
    final res = await http.post(
      Uri.parse('$_base/admin/drivers/$cin/block'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw Exception('Erreur blocage');
  }

  // ─── DEVICES ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDevices() async {
    final res = await http.get(
      Uri.parse('$_base/admin/devices'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Erreur devices');
  }

  static Future<Map<String, dynamic>> getDeviceQrData(int deviceId) async {
    final res = await http.get(
      Uri.parse('$_base/admin/devices/$deviceId/qr-data'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Erreur QR device');
  }

  // ─── VENDOR TOKENS ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getVendorTokens() async {
    final res = await http.get(
      Uri.parse('$_base/admin/vendor-tokens'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Erreur vendor tokens');
  }

  static Future<Map<String, dynamic>> generateVendorToken({
    required int uses,
    required int daysValid,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/admin/vendor-tokens/generate'),
      headers: await _headers(),
      body: jsonEncode({
        'uses': uses,
        'days_valid': daysValid,
        // ✅ vendor_id supprimé
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Erreur génération token');
  }

  static Future<void> deleteVendorToken(int tokenId) async {
    final res = await http.delete(
      Uri.parse('$_base/admin/vendor-tokens/$tokenId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw Exception('Erreur suppression token');
  }
}
