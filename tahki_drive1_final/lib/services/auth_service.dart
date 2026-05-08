import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyCin        = 'driver_cin';
  static const String _keyToken      = 'auth_token';
  static const String _keySetupToken = 'setup_token';
  static const String _base          = 'http://10.0.2.2:8000';

  // ─── FIREBASE ─────────────────────────────────────────────────────────────

  static Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  static Future<void> requireEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();

    if (user == null || user.emailVerified != true) {
      throw Exception("Veuillez vérifier votre email avant de continuer");
    }
  }

  // ─── SHARED PREFERENCES ───────────────────────────────────────────────────

  static Future<void> setCin(String cin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCin, cin);
  }

  static Future<String?> getCin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCin);
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }


  static Future<void> setSetupToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString(_keySetupToken, token);
    print("Token sauvegardé: $success"); // Vérifie dans la console
  }

  static Future<String?> getSetupToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_keySetupToken);
    print("Token récupéré: ${token != null ? 'OUI' : 'NON'}"); // Vérifie ici
    return token;
  }

  static Future<void> clearSetupToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySetupToken);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCin);
    await prefs.remove(_keyToken);
    await prefs.remove(_keySetupToken);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getAuthToken() ?? await getSetupToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── LOGIN DRIVER ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginDriver({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login/driver'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['access_token'] != null) {
        await setAuthToken(data['access_token']);
      }

      if (data['cin'] != null) {
        await setCin(data['cin']);
      }

      return data;
    }

    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Erreur de connexion');
  }

  // ─── SCAN REGISTER ────────────────────────────────────────────────────────



  // ─── SETUP PROFILE ────────────────────────────────────────────────────────



  // ─── CHECK ACTIVATION ─────────────────────────────────────────────────────

  static Future<bool> checkActivationStatus() async {
    final headers = await authHeaders();

    try {
      final res = await http.get(
        Uri.parse('$_base/auth/status'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        if (data['activated'] == true) {
          await setAuthToken(data['access_token']);
          if (data['cin'] != null) await setCin(data['cin']);
          await clearSetupToken();
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    await clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
  static Future<Map<String, dynamic>> scanRegister({
    required String cin,
    required String deviceQrData,
    required String vendorQrData,
    required String email,
    required String password,
    String? camQrData,  // ← ajouté
  }) async {
    final body = {
      'cin': cin,
      'device_qr_data': deviceQrData,
      'vendor_qr_data': vendorQrData,
      'email': email,
      'password': password,
      if (camQrData != null) 'cam_qr_data': camQrData,
    };

    final res = await http.post(
      Uri.parse('$_base/auth/scan-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Erreur inscription');
    }

    final data = jsonDecode(res.body);

    try {
      final user = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await user.user?.sendEmailVerification();
    } catch (e) { print("Firebase: $e"); }

    await setCin(cin);
    if (data['setup_token'] != null) {
      await setSetupToken(data['setup_token']);
    }

    return data;
  }


  static Future<void> setupProfile({
    required String setupToken, // ← reçu directement
    required String cin,        // ← reçu directement
    required String firstName,
    required String lastName,
    required String telephone,
    String language = 'fr',
  }) async {
    final res = await http.patch(
      Uri.parse('$_base/auth/setup-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $setupToken',
      },
      body: jsonEncode({
        'first_name': firstName,
        'last_name':  lastName,
        'cin':        cin,
        'telephone':  telephone,
        'language':   language,
      }),
    );

    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Erreur setup profile');
    }
  }

}
